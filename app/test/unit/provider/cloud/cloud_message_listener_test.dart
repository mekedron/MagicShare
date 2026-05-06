import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/wake/link_payload.dart';
import 'package:magicshare_app/cloud/wake/link_payload_codec.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_persistence.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_registry.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';
import 'package:magicshare_app/provider/cloud/cloud_message_listener_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/provider/cloud/wake_nonce_registry_provider.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _fixtureKey() => Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

class _FakeGateway {
  final StreamController<RemoteMessage> onMessage = StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> onTap = StreamController<RemoteMessage>.broadcast();
  RemoteMessage? initial;

  CloudMessageListenerGateway gateway() => CloudMessageListenerGateway(
    onMessage: () => onMessage.stream,
    onMessageOpenedApp: () => onTap.stream,
    getInitialMessage: () async => initial,
  );

  Future<void> dispose() async {
    await onMessage.close();
    await onTap.close();
  }
}

class _LaunchRecorder {
  final List<Uri> calls = <Uri>[];
  bool returnValue = true;

  Future<bool> launch(Uri uri) async {
    calls.add(uri);
    return returnValue;
  }
}

SecureStorageService _seededStorage(Uint8List key) {
  final store = <String, String>{cloudGroupKeyKey: base64Encode(key)};
  return SecureStorageService(
    gateway: SecureStorageGateway(
      read: (k) async => store[k],
      write: (k, v) async => store[k] = v,
      delete: (k) async => store.remove(k),
    ),
  );
}

/// Builds a refena container with the listener wired against a fake
/// gateway, and the group-key service pre-seeded so it transitions to
/// `GroupKeyReady` deterministically before any FCM message lands.
Future<RefenaContainer> _buildContainer({
  required _FakeGateway gateway,
  required _LaunchRecorder launcher,
  required WakeNonceRegistry registry,
  required Uint8List key,
  WakeNoncePersistence persistence = const WakeNoncePersistence(),
  DateTime Function()? clock,
}) async {
  final container = RefenaContainer(
    overrides: [
      wakeNonceRegistryProvider.overrideWithValue(registry),
      groupKeyProvider.overrideWithNotifier(
        (ref) => GroupKeyService(
          storage: _seededStorage(key),
          clearDeviceId: () async {},
        ),
      ),
      cloudMessageListenerProvider.overrideWithNotifier(
        (ref) => CloudMessageListenerService(
          gateway: gateway.gateway(),
          launchUrl: launcher.launch,
          persistence: persistence,
          supportedOverride: true,
          clock: clock,
        ),
      ),
    ],
  );
  // Bring the group key service to Ready before the listener subscribes.
  container.notifier(groupKeyProvider);
  await pumpEventQueue();
  expect(container.read(groupKeyProvider), isA<GroupKeyReady>());
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('wake message registers the nonce in the registry', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    final payload = WakePayload(
      sessionNonce: 'nonce-from-fcm',
      sourceFingerprint: 'fp-source',
      initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);

    gateway.onMessage.add(
      RemoteMessage(
        data: <String, dynamic>{'type': 'wake', 'payload': wire},
      ),
    );
    await pumpEventQueue();

    expect(registry.consume('nonce-from-fcm'), isTrue);
    expect(launcher.calls, isEmpty);
    await gateway.dispose();
  });

  test('link message launches the URL with url_launcher', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    gateway.onMessage.add(
      RemoteMessage(
        data: <String, dynamic>{
          'type': 'link',
          'url': 'https://example.com/news',
          'title': 'News',
        },
      ),
    );
    await pumpEventQueue();

    expect(launcher.calls, hasLength(1));
    expect(launcher.calls.single, Uri.parse('https://example.com/news'));
    expect(registry.size, 0);
    await gateway.dispose();
  });

  test('encrypted link message decrypts and launches the URL', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    const payload = LinkPayload(url: 'https://example.com/secret');
    final wire = encodeLinkPayload(payload, key);

    gateway.onMessage.add(
      RemoteMessage(
        data: <String, dynamic>{'type': 'link', 'payload': wire},
      ),
    );
    await pumpEventQueue();

    expect(launcher.calls, hasLength(1));
    expect(launcher.calls.single, Uri.parse('https://example.com/secret'));
    await gateway.dispose();
  });

  test('non-http(s) URLs are rejected without launching', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    gateway.onMessage.add(
      RemoteMessage(
        data: <String, dynamic>{
          'type': 'link',
          'url': 'javascript:alert(1)',
        },
      ),
    );
    await pumpEventQueue();

    expect(launcher.calls, isEmpty);
    await gateway.dispose();
  });

  test('tampered wake message does not register a nonce', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    final payload = WakePayload(
      sessionNonce: 'good-nonce',
      sourceFingerprint: 'fp',
      initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);
    final raw = base64Decode(wire);
    raw[raw.length - 1] ^= 0xff;
    final tampered = base64Encode(raw);

    gateway.onMessage.add(
      RemoteMessage(
        data: <String, dynamic>{'type': 'wake', 'payload': tampered},
      ),
    );
    await pumpEventQueue();

    expect(registry.size, 0);
    expect(launcher.calls, isEmpty);
    await gateway.dispose();
  });

  test('drains pending nonces from persistence on init', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    // Seed persistence BEFORE container build so init() drains it.
    const persistence = WakeNoncePersistence();
    await persistence.append(
      'persisted-nonce',
      DateTime.now().add(const Duration(minutes: 2)),
    );

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);
    await pumpEventQueue();

    expect(registry.consume('persisted-nonce'), isTrue);
    await gateway.dispose();
  });

  test('initial message (cold-start tap) is dispatched', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    gateway.initial = RemoteMessage(
      data: <String, dynamic>{
        'type': 'link',
        'url': 'https://example.com/initial',
      },
    );

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);
    await pumpEventQueue();

    expect(launcher.calls, hasLength(1));
    expect(launcher.calls.single, Uri.parse('https://example.com/initial'));
    await gateway.dispose();
  });

  test('onMessageOpenedApp tap is dispatched', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    gateway.onTap.add(
      RemoteMessage(
        data: <String, dynamic>{
          'type': 'link',
          'url': 'https://example.com/tapped',
        },
      ),
    );
    await pumpEventQueue();

    expect(launcher.calls, hasLength(1));
    expect(launcher.calls.single, Uri.parse('https://example.com/tapped'));
    await gateway.dispose();
  });

  test('listener is unsupported on platforms without FCM', () async {
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = RefenaContainer(
      overrides: [
        wakeNonceRegistryProvider.overrideWithValue(registry),
        groupKeyProvider.overrideWithNotifier(
          (ref) => GroupKeyService(
            storage: _seededStorage(_fixtureKey()),
            clearDeviceId: () async {},
          ),
        ),
        cloudMessageListenerProvider.overrideWithNotifier(
          (ref) => CloudMessageListenerService(
            gateway: gateway.gateway(),
            launchUrl: launcher.launch,
            supportedOverride: false,
          ),
        ),
      ],
    );

    final state = container.read(cloudMessageListenerProvider);
    expect(state, isA<CloudMessageListenerUnsupported>());
    await gateway.dispose();
  });

  test('wake message with stale timestamp does not register (replay guard)', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    container.read(cloudMessageListenerProvider);

    // Sender clock 10 minutes in the past — receiver-side window is 2 min.
    final stale = DateTime.now().subtract(const Duration(minutes: 10));
    final payload = WakePayload(
      sessionNonce: 'stale-nonce',
      sourceFingerprint: 'fp',
      initiatedAtMs: stale.millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);

    gateway.onMessage.add(
      RemoteMessage(
        data: <String, dynamic>{'type': 'wake', 'payload': wire},
      ),
    );
    await pumpEventQueue();

    expect(registry.consume('stale-nonce'), isFalse);
    await gateway.dispose();
  });

  test('drainPersistence picks up nonces written after init (resume case)', () async {
    final key = _fixtureKey();
    final gateway = _FakeGateway();
    final launcher = _LaunchRecorder();
    final registry = WakeNonceRegistry();

    final container = await _buildContainer(
      gateway: gateway,
      launcher: launcher,
      registry: registry,
      key: key,
    );
    final service = container.notifier(cloudMessageListenerProvider);
    await pumpEventQueue();
    expect(registry.size, 0);

    // Simulate the background isolate writing to persistence while the
    // app is paused.
    const persistence = WakeNoncePersistence();
    await persistence.append(
      'background-nonce',
      DateTime.now().add(const Duration(minutes: 2)),
    );

    // Now simulate AppLifecycleState.resumed.
    await service.drainPersistence();

    expect(registry.consume('background-nonce'), isTrue);
    await gateway.dispose();
  });
}
