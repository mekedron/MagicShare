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

/// Subscribes to Firebase auth state. On startup, if no user is signed in,
/// triggers anonymous sign-in. The persisted Firebase auth session means
/// the same UID survives app restarts (the FirebaseAuth SDK caches it
/// locally).
class CloudAuthService extends Notifier<CloudAuthState> {
  CloudAuthService({CloudAuthGateway? gateway}) : _gateway = gateway ?? CloudAuthGateway.live();

  final CloudAuthGateway _gateway;
  StreamSubscription<String?>? _subscription;
  bool _started = false;

  @override
  CloudAuthState init() {
    final currentUid = _gateway.currentUserId();
    // Idempotent: NotifierTester invokes init() twice during construction;
    // production RefenaScope invokes it once. Subscribing or kicking off
    // sign-in more than once would double-bill the side-effects.
    if (!_started) {
      _started = true;
      _subscription = _gateway.userIdChanges().listen(
        _handleUidChange,
        onError: _handleStreamError,
      );
      if (currentUid == null) {
        // Fire-and-forget: sign-in proceeds in the background, results are
        // surfaced via state transitions on the auth-state stream listener.
        unawaited(_signIn());
      }
    }
    if (currentUid != null) {
      return CloudAuthAuthenticated(currentUid);
    }
    return const CloudAuthSigningIn();
  }

  void _handleUidChange(String? uid) {
    if (uid != null) {
      state = CloudAuthAuthenticated(uid);
      return;
    }
    // Stream emitted null — Firebase signed the user out (e.g. account
    // deletion). Re-trigger sign-in unless we're already in flight.
    if (state is! CloudAuthSigningIn) {
      state = const CloudAuthSigningIn();
      unawaited(_signIn());
    }
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

  /// Public retry hook for the rare path where sign-in failed and the user
  /// (or a UI button) wants to try again.
  Future<void> retrySignIn() async {
    if (state is CloudAuthSigningIn) return;
    state = const CloudAuthSigningIn();
    await _signIn();
  }

  /// Deletes the current Firebase Auth user. The auth-state stream then
  /// emits `null`, which [_handleUidChange] picks up and turns into a
  /// fresh anonymous sign-in. The next [CloudAuthAuthenticated] carries
  /// a brand new UID — this is what callers (e.g. destroy-group) rely
  /// on to re-bootstrap with a new account. State is intentionally not
  /// pre-set here so [_handleUidChange]'s SigningIn guard can still
  /// trigger the re-sign-in path.
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
