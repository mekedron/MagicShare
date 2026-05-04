import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _FakeAuthBackend {
  String? currentUid;
  final StreamController<String?> _controller = StreamController<String?>.broadcast();
  int signInCallCount = 0;
  int deleteCallCount = 0;
  int signOutCallCount = 0;
  Object? signInThrows;
  Object? deleteThrows;
  Object? signOutThrows;
  String nextSignInUid = 'anon-uid-1';

  /// When non-null, simulates the slot of time between calling
  /// signInAnonymously and the auth-state stream emitting the new UID.
  /// The test pumps the completer manually to control timing.
  Completer<void>? signInDelay;

  Stream<String?> userIdChanges() => _controller.stream;

  Future<String> signInAnonymously() async {
    signInCallCount++;
    if (signInThrows != null) throw signInThrows!;
    if (signInDelay != null) await signInDelay!.future;
    final newUid = nextSignInUid;
    currentUid = newUid;
    _controller.add(newUid);
    return newUid;
  }

  Future<void> deleteCurrentUser() async {
    deleteCallCount++;
    if (deleteThrows != null) throw deleteThrows!;
    currentUid = null;
    _controller.add(null);
  }

  Future<void> signOut() async {
    signOutCallCount++;
    if (signOutThrows != null) throw signOutThrows!;
    currentUid = null;
    _controller.add(null);
  }

  String? read() => currentUid;

  void emit(String? uid) {
    currentUid = uid;
    _controller.add(uid);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  Future<void> dispose() => _controller.close();

  CloudAuthGateway gateway() => CloudAuthGateway(
    userIdChanges: userIdChanges,
    signInAnonymously: signInAnonymously,
    currentUserId: read,
    deleteCurrentUser: deleteCurrentUser,
    signOut: signOut,
  );
}

void main() {
  group('CloudAuthService.init', () {
    test('emits Authenticated when a UID already exists', () async {
      final backend = _FakeAuthBackend()..currentUid = 'existing-uid';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      expect(tester.state, isA<CloudAuthAuthenticated>());
      expect((tester.state as CloudAuthAuthenticated).uid, 'existing-uid');
      expect(backend.signInCallCount, 0);
      await backend.dispose();
    });

    test('rests in AwaitingChoice when no UID exists; no auto sign-in', () async {
      final backend = _FakeAuthBackend();
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      await pumpEventQueue();
      expect(tester.state, isA<CloudAuthAwaitingChoice>());
      expect(backend.signInCallCount, 0);
      await backend.dispose();
    });
  });

  group('CloudAuthService.signInForNewGroup', () {
    test('triggers anonymous sign-in and lands in Authenticated', () async {
      final backend = _FakeAuthBackend()..nextSignInUid = 'fresh-uid';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      expect(tester.state, isA<CloudAuthAwaitingChoice>());

      await tester.notifier.signInForNewGroup();
      await pumpEventQueue();

      expect(backend.signInCallCount, 1);
      expect(tester.state, isA<CloudAuthAuthenticated>());
      expect((tester.state as CloudAuthAuthenticated).uid, 'fresh-uid');
      await backend.dispose();
    });

    test('is a no-op when already authenticated', () async {
      final backend = _FakeAuthBackend()..currentUid = 'existing';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      await tester.notifier.signInForNewGroup();
      await pumpEventQueue();

      expect(backend.signInCallCount, 0);
      expect(tester.state, isA<CloudAuthAuthenticated>());
      await backend.dispose();
    });
  });

  group('CloudAuthService stream events', () {
    test('switches to Authenticated when stream emits a uid', () async {
      final backend = _FakeAuthBackend()..currentUid = 'existing';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      expect((tester.state as CloudAuthAuthenticated).uid, 'existing');

      backend.emit('rotated-uid');
      await Future<void>.delayed(Duration.zero);

      expect((tester.state as CloudAuthAuthenticated).uid, 'rotated-uid');
      await backend.dispose();
    });

    test('drops to AwaitingChoice when stream emits null mid-session', () async {
      final backend = _FakeAuthBackend()..currentUid = 'existing';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      expect(tester.state, isA<CloudAuthAuthenticated>());

      backend.emit(null);
      await Future<void>.delayed(Duration.zero);

      // Sign-out / external user deletion no longer auto-creates a fresh
      // anonymous account; the user lands at the welcome card instead.
      expect(backend.signInCallCount, 0);
      expect(tester.state, isA<CloudAuthAwaitingChoice>());
      await backend.dispose();
    });

    test('surfaces stream errors as CloudAuthFailed', () async {
      final backend = _FakeAuthBackend()..currentUid = 'existing';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      backend.emitError(StateError('network blip'));
      await Future<void>.delayed(Duration.zero);

      expect(tester.state, isA<CloudAuthFailed>());
      await backend.dispose();
    });
  });

  group('CloudAuthService.signIn errors', () {
    test('surfaces sign-in failure as CloudAuthFailed', () async {
      final backend = _FakeAuthBackend()..signInThrows = StateError('sign-in unavailable');
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      // No auto-sign-in: starts at AwaitingChoice. Trigger explicitly.
      expect(tester.state, isA<CloudAuthAwaitingChoice>());
      await tester.notifier.signInForNewGroup();
      await pumpEventQueue();

      expect(tester.state, isA<CloudAuthFailed>());
      expect((tester.state as CloudAuthFailed).message, contains('sign-in unavailable'));
      await backend.dispose();
    });

    test('retrySignIn re-attempts after a failure', () async {
      final backend = _FakeAuthBackend()..signInThrows = StateError('sign-in unavailable');
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      await tester.notifier.signInForNewGroup();
      await pumpEventQueue();
      expect(tester.state, isA<CloudAuthFailed>());

      backend.signInThrows = null;
      await tester.notifier.retrySignIn();
      await pumpEventQueue();

      expect(backend.signInCallCount, 2);
      expect(tester.state, isA<CloudAuthAuthenticated>());
      await backend.dispose();
    });
  });

  group('CloudAuthService.deleteAndReset', () {
    test('deletes the current user and drops to AwaitingChoice', () async {
      final backend = _FakeAuthBackend()..currentUid = 'old-uid';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      expect((tester.state as CloudAuthAuthenticated).uid, 'old-uid');

      await tester.notifier.deleteAndReset();
      await pumpEventQueue();

      // No auto re-sign-in: the user is re-prompted via the welcome card.
      expect(backend.deleteCallCount, 1);
      expect(backend.signInCallCount, 0);
      expect(tester.state, isA<CloudAuthAwaitingChoice>());
      await backend.dispose();
    });

    test('falls back to signOut when delete fails (stale UID case)', () async {
      final backend = _FakeAuthBackend()
        ..currentUid = 'stale-uid'
        ..deleteThrows = StateError('user-not-found');
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      await tester.notifier.deleteAndReset();
      await pumpEventQueue();

      // Delete attempted, then signOut fallback ran. Stream emits null
      // → AwaitingChoice. No exception surfaced to the caller.
      expect(backend.deleteCallCount, 1);
      expect(backend.signOutCallCount, 1);
      expect(tester.state, isA<CloudAuthAwaitingChoice>());
      await backend.dispose();
    });

    test('surfaces failure only when both delete and signOut fail', () async {
      final backend = _FakeAuthBackend()
        ..currentUid = 'stuck-uid'
        ..deleteThrows = StateError('requires-recent-login')
        ..signOutThrows = StateError('keychain locked');
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      await expectLater(
        tester.notifier.deleteAndReset(),
        throwsA(isA<StateError>()),
      );
      await pumpEventQueue();

      expect(backend.deleteCallCount, 1);
      expect(backend.signOutCallCount, 1);
      expect(tester.state, isA<CloudAuthFailed>());
      await backend.dispose();
    });
  });
}
