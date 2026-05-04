import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudAuth');

/// Surface of [FirebaseAuth] that [CloudAuthService] consumes. Modelled as
/// a typedef-bag so tests can supply fakes without mocking [FirebaseAuth]
/// directly (which has private constructors and platform-channel deps).
class CloudAuthGateway {
  CloudAuthGateway({
    required this.userIdChanges,
    required this.signInAnonymously,
    required this.currentUserId,
    required this.deleteCurrentUser,
  });

  /// Stream of UID values — null when signed out.
  final Stream<String?> Function() userIdChanges;

  /// Triggers anonymous sign-in. Returns the new UID.
  final Future<String> Function() signInAnonymously;

  /// Synchronously reads the current UID, or null when signed out.
  final String? Function() currentUserId;

  /// Permanently deletes the current Firebase Auth user. Used during
  /// destroy-this-device-group so the next anonymous sign-in produces a
  /// fresh UID rather than reattaching to the just-deleted account.
  /// No-op when there is no current user.
  final Future<void> Function() deleteCurrentUser;

  factory CloudAuthGateway.live() {
    return CloudAuthGateway(
      userIdChanges: () => FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
      signInAnonymously: () async {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        final uid = credential.user?.uid;
        if (uid == null) {
          throw StateError('signInAnonymously returned a credential with no uid');
        }
        return uid;
      },
      currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
      deleteCurrentUser: () async {
        await FirebaseAuth.instance.currentUser?.delete();
      },
    );
  }
}

/// Discriminated state for the anonymous-auth lifecycle.
sealed class CloudAuthState {
  const CloudAuthState();
}

class CloudAuthIdle extends CloudAuthState {
  const CloudAuthIdle();
}

/// No Firebase user is signed in and the app is waiting for the user to
/// pick *Create new group*, *Join existing group* (Epic 11), or *Use
/// without cloud*. The previous default of auto-creating an anonymous
/// account on first launch is gone — that produced orphaned accounts
/// whenever the user paired into an existing group right after install.
/// The welcome-card UI in the device-group settings section gates
/// progression out of this state.
class CloudAuthAwaitingChoice extends CloudAuthState {
  const CloudAuthAwaitingChoice();
}

class CloudAuthSigningIn extends CloudAuthState {
  const CloudAuthSigningIn();
}

class CloudAuthAuthenticated extends CloudAuthState {
  final String uid;
  const CloudAuthAuthenticated(this.uid);

  @override
  bool operator ==(Object other) => identical(this, other) || other is CloudAuthAuthenticated && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

class CloudAuthFailed extends CloudAuthState {
  final String message;
  final Object error;
  const CloudAuthFailed({required this.message, required this.error});

  @override
  bool operator ==(Object other) => identical(this, other) || other is CloudAuthFailed && other.message == message && other.error == error;

  @override
  int get hashCode => Object.hash(message, error);
}

/// Subscribes to Firebase auth state. If a Firebase user already exists
/// (from a prior run), surfaces it as [CloudAuthAuthenticated]. Otherwise
/// holds in [CloudAuthAwaitingChoice] until the user explicitly picks
/// *Create new group* (which calls [signInForNewGroup]) or pairs into an
/// existing group via Epic 11.
class CloudAuthService extends Notifier<CloudAuthState> {
  CloudAuthService({CloudAuthGateway? gateway}) : _gateway = gateway ?? CloudAuthGateway.live();

  final CloudAuthGateway _gateway;
  StreamSubscription<String?>? _subscription;
  bool _started = false;

  @override
  CloudAuthState init() {
    final currentUid = _gateway.currentUserId();
    // Idempotent: NotifierTester invokes init() twice during construction;
    // production RefenaScope invokes it once. Subscribing twice would
    // double-bill the stream listener.
    if (!_started) {
      _started = true;
      _subscription = _gateway.userIdChanges().listen(
        _handleUidChange,
        onError: _handleStreamError,
      );
    }
    if (currentUid != null) {
      return CloudAuthAuthenticated(currentUid);
    }
    return const CloudAuthAwaitingChoice();
  }

  void _handleUidChange(String? uid) {
    if (uid != null) {
      state = CloudAuthAuthenticated(uid);
      return;
    }
    // Stream emitted null — the Firebase user is gone (sign-out, account
    // deletion, etc.). Drop back to AwaitingChoice unless a destroy-group
    // sign-in is already running (which pre-sets SigningIn, see
    // [deleteAndReset]).
    if (state is CloudAuthSigningIn) return;
    state = const CloudAuthAwaitingChoice();
  }

  void _handleStreamError(Object error, StackTrace stack) {
    _logger.warning('Auth state stream errored', error, stack);
    state = CloudAuthFailed(message: 'Auth stream error', error: error);
  }

  Future<void> _signIn() async {
    try {
      await _gateway.signInAnonymously();
      // Stream listener emits Authenticated on success — no direct write here.
    } catch (e, st) {
      _logger.warning('Anonymous sign-in failed', e, st);
      state = CloudAuthFailed(message: 'Sign-in failed: $e', error: e);
    }
  }

  /// User explicitly picked *Create new group* on the welcome card.
  /// Triggers anonymous sign-in; [CloudBootstrapService] then provisions
  /// the cloud account and registers this device. No-op if already
  /// signed in or already mid-sign-in.
  Future<void> signInForNewGroup() async {
    if (state is CloudAuthAuthenticated) return;
    if (state is CloudAuthSigningIn) return;
    state = const CloudAuthSigningIn();
    await _signIn();
  }

  /// Public retry hook for the rare path where sign-in failed and the user
  /// (or a UI button) wants to try again.
  Future<void> retrySignIn() async {
    if (state is CloudAuthSigningIn) return;
    state = const CloudAuthSigningIn();
    await _signIn();
  }

  /// Deletes the current Firebase Auth user and lets the auth-state
  /// stream emit null, which [_handleUidChange] resolves to
  /// [CloudAuthAwaitingChoice]. The user is then re-prompted via the
  /// welcome card to *Create*, *Join*, or *Use without cloud* — same
  /// model as first launch. This is intentional: a destroy-group flow
  /// is a fresh-start moment, and silently re-creating an account
  /// would re-introduce the orphaned-account problem the welcome card
  /// is designed to avoid.
  Future<void> deleteAndReset() async {
    try {
      await _gateway.deleteCurrentUser();
    } catch (e, st) {
      _logger.warning('Auth user deletion failed', e, st);
      state = CloudAuthFailed(message: 'Auth user deletion failed: $e', error: e);
      rethrow;
    }
  }

  @override
  void dispose() {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}

final cloudAuthProvider = NotifierProvider<CloudAuthService, CloudAuthState>((ref) {
  return CloudAuthService();
});
