import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/fcm_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _FakeFcmBackend {
  String? token;
  String? apnsToken;
  Object? getTokenThrows;
  final StreamController<String> _refresh = StreamController<String>.broadcast();
  int getTokenCallCount = 0;
  int getApnsCallCount = 0;

  Future<String?> getToken() async {
    getTokenCallCount++;
    if (getTokenThrows != null) throw getTokenThrows!;
    return token;
  }

  Future<String?> getApnsToken() async {
    getApnsCallCount++;
    return apnsToken;
  }

  Stream<String> onTokenRefresh() => _refresh.stream;

  void emitRefresh(String newToken) {
    token = newToken;
    _refresh.add(newToken);
  }

  void emitError(Object error) {
    _refresh.addError(error);
  }

  Future<void> dispose() => _refresh.close();

  FcmGateway gateway() => FcmGateway(
    getToken: getToken,
    onTokenRefresh: onTokenRefresh,
    getApnsToken: getApnsToken,
  );
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('FcmService.init', () {
    test('emits Unsupported on Linux', () async {
      final backend = _FakeFcmBackend();
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: false),
      );

      expect(tester.state, isA<FcmUnsupported>());
      expect(backend.getTokenCallCount, 0);
      await backend.dispose();
    });

    test('acquires the FCM token on supported platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = _FakeFcmBackend()..token = 'fcm-token-1';
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: true),
      );

      await pumpEventQueue();

      expect(tester.state, isA<FcmReady>());
      expect((tester.state as FcmReady).token, 'fcm-token-1');
      expect(backend.getTokenCallCount, 1);
      await backend.dispose();
    });

    test('stays in Acquiring when getToken returns null transiently', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = _FakeFcmBackend(); // token = null
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: true),
      );

      await pumpEventQueue();

      expect(tester.state, isA<FcmAcquiring>());

      // Refresh later delivers the token.
      backend.emitRefresh('fcm-token-late');
      await Future<void>.delayed(Duration.zero);
      expect((tester.state as FcmReady).token, 'fcm-token-late');
      await backend.dispose();
    });

    test('iOS waits for APNS token before getToken', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final backend = _FakeFcmBackend()
        ..apnsToken = 'apns-1'
        ..token = 'fcm-token-ios';
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: true),
      );

      await pumpEventQueue();

      expect(tester.state, isA<FcmReady>());
      expect((tester.state as FcmReady).token, 'fcm-token-ios');
      expect(backend.getApnsCallCount, greaterThanOrEqualTo(1));
      await backend.dispose();
    });
  });

  group('FcmService refresh', () {
    test('updates state on a refresh event', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = _FakeFcmBackend()..token = 'initial';
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: true),
      );
      await pumpEventQueue();
      expect((tester.state as FcmReady).token, 'initial');

      backend.emitRefresh('rotated');
      await Future<void>.delayed(Duration.zero);

      expect((tester.state as FcmReady).token, 'rotated');
      await backend.dispose();
    });

    test('surfaces refresh stream errors as Failed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = _FakeFcmBackend()..token = 'initial';
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: true),
      );
      await pumpEventQueue();

      backend.emitError(StateError('refresh blew up'));
      await Future<void>.delayed(Duration.zero);

      expect(tester.state, isA<FcmFailed>());
      await backend.dispose();
    });
  });

  group('FcmService.init errors', () {
    test('getToken throw surfaces as Failed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = _FakeFcmBackend()..getTokenThrows = StateError('messaging unavailable');
      final tester = Notifier.test<FcmService, FcmState>(
        notifier: FcmService(gateway: backend.gateway(), supportedOverride: true),
      );

      await pumpEventQueue();

      expect(tester.state, isA<FcmFailed>());
      expect((tester.state as FcmFailed).message, contains('messaging unavailable'));
      await backend.dispose();
    });
  });
}
