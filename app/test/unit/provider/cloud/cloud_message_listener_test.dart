import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/cloud_message_listener_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _FakeGateway {
  final StreamController<RemoteMessage> onMessage = StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> onTap = StreamController<RemoteMessage>.broadcast();
  RemoteMessage? initial;

  CloudMessageListenerGateway gateway() => CloudMessageListenerGateway(
    onMessage: () => onMessage.stream,
    onMessageOpenedApp: () => onTap.stream,
    getInitialMessage: () async => initial,
  );

  Future<void> close() async {
    await onMessage.close();
    await onTap.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports Unsupported state when FCM platform support is off', () {
    final container = RefenaContainer(
      overrides: [
        cloudMessageListenerProvider.overrideWithNotifier(
          (_) => CloudMessageListenerService(supportedOverride: false),
        ),
      ],
    );
    expect(container.read(cloudMessageListenerProvider), isA<CloudMessageListenerUnsupported>());
  });

  test('subscribes to onMessage / onMessageOpenedApp when supported', () async {
    final fake = _FakeGateway();
    final container = RefenaContainer(
      overrides: [
        cloudMessageListenerProvider.overrideWithNotifier(
          (_) => CloudMessageListenerService(
            supportedOverride: true,
            gateway: fake.gateway(),
          ),
        ),
      ],
    );
    expect(container.read(cloudMessageListenerProvider), isA<CloudMessageListenerRunning>());

    // Sending a foreground message + a tap must not throw — the listener
    // is logging-only now, no routing, no decryption.
    fake.onMessage.add(RemoteMessage(data: const {'type': 'transfer', 'kind': 'file'}));
    fake.onTap.add(RemoteMessage(data: const {'type': 'transfer', 'kind': 'text'}));
    await Future<void>.delayed(Duration.zero);

    await fake.close();
  });
}
