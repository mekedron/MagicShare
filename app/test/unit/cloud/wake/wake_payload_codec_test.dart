import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';

Uint8List _fixtureKey() => Uint8List.fromList(List<int>.generate(32, (i) => i));

void main() {
  group('generateWakeSessionNonce', () {
    test('produces a non-empty url-safe string', () {
      final nonce = generateWakeSessionNonce();
      expect(nonce, isNotEmpty);
      // url-safe base64 charset, no padding
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(nonce), isTrue);
      expect(nonce.contains('='), isFalse);
    });

    test('emits distinct nonces across calls', () {
      final values = List.generate(50, (_) => generateWakeSessionNonce()).toSet();
      expect(values, hasLength(50));
    });
  });

  group('encode/decodeWakePayload', () {
    final key = _fixtureKey();
    const payload = WakePayload(
      sessionNonce: 'fixture-nonce',
      sourceFingerprint: 'fp-source',
      initiatedAtMs: 1714780800000,
    );

    test('round-trip preserves all fields', () {
      final wire = encodeWakePayload(payload, key);
      final decoded = decodeWakePayload(wire, key);
      expect(decoded.sessionNonce, payload.sessionNonce);
      expect(decoded.sourceFingerprint, payload.sourceFingerprint);
      expect(decoded.initiatedAtMs, payload.initiatedAtMs);
    });

    test('encodes to a base64 string carrying nonce + ciphertext + tag', () {
      final wire = encodeWakePayload(payload, key);
      // base64 → ciphertext+tag header is at least nonce(12) + tag(16) = 28 raw
      // bytes ≈ 38 base64 chars before any payload content.
      final raw = base64Decode(wire);
      expect(raw.length, greaterThanOrEqualTo(28));
    });

    test('throws GroupKeyAuthFailure when the key is wrong', () {
      final wire = encodeWakePayload(payload, key);
      final wrongKey = Uint8List.fromList(List<int>.generate(32, (i) => 0xff - i));
      expect(() => decodeWakePayload(wire, wrongKey), throwsA(isA<GroupKeyAuthFailure>()));
    });

    test('throws GroupKeyAuthFailure when the ciphertext is tampered', () {
      final wire = encodeWakePayload(payload, key);
      final raw = base64Decode(wire);
      // Flip one byte in the ciphertext region.
      raw[raw.length - 1] ^= 0xaa;
      final tampered = base64Encode(raw);
      expect(() => decodeWakePayload(tampered, key), throwsA(isA<GroupKeyAuthFailure>()));
    });
  });
}
