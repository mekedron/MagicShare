import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/wake/cloud_background_handler.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_persistence.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _fixtureKey() => Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists a well-formed wake nonce', () async {
    final key = _fixtureKey();
    final payload = WakePayload(
      sessionNonce: 'bg-nonce',
      sourceFingerprint: 'fp',
      initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);

    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'wake', 'payload': wire}),
      readGroupKey: () async => key,
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, hasLength(1));
    expect(drained.single.nonce, 'bg-nonce');
  });

  test('swallows tampered ciphertext without writing', () async {
    final key = _fixtureKey();
    final payload = WakePayload(
      sessionNonce: 'bg-nonce',
      sourceFingerprint: 'fp',
      initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);
    final raw = base64Decode(wire);
    raw[raw.length - 1] ^= 0x42;
    final tampered = base64Encode(raw);

    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'wake', 'payload': tampered}),
      readGroupKey: () async => key,
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, isEmpty);
  });

  test('swallows missing group key without writing', () async {
    final key = _fixtureKey();
    final payload = WakePayload(
      sessionNonce: 'bg-nonce',
      sourceFingerprint: 'fp',
      initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);

    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'wake', 'payload': wire}),
      readGroupKey: () async => null,
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, isEmpty);
  });

  test('swallows readGroupKey exception without throwing', () async {
    final payload = WakePayload(
      sessionNonce: 'bg-nonce',
      sourceFingerprint: 'fp',
      initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, _fixtureKey());

    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'wake', 'payload': wire}),
      readGroupKey: () async => throw StateError('keychain unavailable'),
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, isEmpty);
  });

  test('drops a wake whose sender timestamp is too far in the past', () async {
    final key = _fixtureKey();
    // Sender clock 10 minutes behind us — receiver-side window is 2 min.
    final stale = DateTime.now().subtract(const Duration(minutes: 10));
    final payload = WakePayload(
      sessionNonce: 'stale-bg',
      sourceFingerprint: 'fp',
      initiatedAtMs: stale.millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);

    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'wake', 'payload': wire}),
      readGroupKey: () async => key,
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, isEmpty);
  });

  test('caps a wildly future sender timestamp at local now + ttl', () async {
    final key = _fixtureKey();
    // Sender clock 1 hour ahead of us; we should still register, but cap
    // the expiry at our local now + 2 min.
    final faraway = DateTime.now().add(const Duration(hours: 1));
    final payload = WakePayload(
      sessionNonce: 'future-bg',
      sourceFingerprint: 'fp',
      initiatedAtMs: faraway.millisecondsSinceEpoch,
    );
    final wire = encodeWakePayload(payload, key);

    final receivedAt = DateTime.now();
    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'wake', 'payload': wire}),
      readGroupKey: () async => key,
      now: () => receivedAt,
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, hasLength(1));
    final cap = receivedAt.add(const Duration(minutes: 2));
    expect(drained.single.expiresAt.millisecondsSinceEpoch, cap.millisecondsSinceEpoch);
  });

  test('link messages are dropped (deferred to UI surface)', () async {
    await handleCloudBackgroundMessage(
      RemoteMessage(
        data: <String, dynamic>{
          'type': 'link',
          'url': 'https://example.com/page',
        },
      ),
      readGroupKey: () async => _fixtureKey(),
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, isEmpty);
  });

  test('unknown types are dropped without writing', () async {
    await handleCloudBackgroundMessage(
      RemoteMessage(data: <String, dynamic>{'type': 'mystery'}),
      readGroupKey: () async => _fixtureKey(),
    );

    const persistence = WakeNoncePersistence();
    final drained = await persistence.drain();
    expect(drained, isEmpty);
  });
}
