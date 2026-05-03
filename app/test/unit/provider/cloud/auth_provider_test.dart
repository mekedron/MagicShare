import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _FakeAuthBackend {
  String? currentUid;
  final StreamController<String?> _controller = StreamController<String?>.broadcast();
  int signInCallCount = 0;
  Object? signInThrows;

  /// When non-null, simulates the slot of time between calling
  /// signInAnonymously and the auth-state stream emitting the new UID.
  /// The test pumps the completer manually to control timing.
  Completer<void>? signInDelay;

  Stream<String?> userIdChanges() => _controller.stream;

  Future<String> signInAnonymously() async {
    signInCallCount++;
    if (signInThrows != null) throw signInThrows!;
    if (signInDelay != null) await signInDelay!.future;
    const newUid = 'anon-uid-1';
    currentUid = newUid;
    _controller.add(newUid);
    return newUid;
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

    test('signs in anonymously when no UID exists', () async {
      final backend = _FakeAuthBackend();
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );

      // The transition through SigningIn is racy with microtask scheduling
      // — assert the eventual outcome rather than the intermediate state.
      await pumpEventQueue();
      expect(backend.signInCallCount, 1);
      expect(tester.state, isA<CloudAuthAuthenticated>());
      expect((tester.state as CloudAuthAuthenticated).uid, 'anon-uid-1');
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

    test('signs back in when stream emits null mid-session', () async {
      final backend = _FakeAuthBackend()..currentUid = 'existing';
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      expect(tester.state, isA<CloudAuthAuthenticated>());

      backend.emit(null);
      await Future<void>.delayed(Duration.zero);
      // SigningIn observed transiently — then anon-uid-1 emitted via the
      // sign-in path's emit().
      await Future<void>.delayed(Duration.zero);

      expect(backend.signInCallCount, 1);
      expect(tester.state, isA<CloudAuthAuthenticated>());
      expect((tester.state as CloudAuthAuthenticated).uid, 'anon-uid-1');
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

      expect(tester.state, isA<CloudAuthSigningIn>());
      await Future<void>.delayed(Duration.zero);

      expect(tester.state, isA<CloudAuthFailed>());
      expect((tester.state as CloudAuthFailed).message, contains('sign-in unavailable'));
      await backend.dispose();
    });

    test('retrySignIn re-attempts after a failure', () async {
      final backend = _FakeAuthBackend()..signInThrows = StateError('sign-in unavailable');
      final tester = Notifier.test<CloudAuthService, CloudAuthState>(
        notifier: CloudAuthService(gateway: backend.gateway()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tester.state, isA<CloudAuthFailed>());

      backend.signInThrows = null;
      await tester.notifier.retrySignIn();
      await Future<void>.delayed(Duration.zero);

      expect(backend.signInCallCount, 2);
      expect(tester.state, isA<CloudAuthAuthenticated>());
      await backend.dispose();
    });
  });
}
