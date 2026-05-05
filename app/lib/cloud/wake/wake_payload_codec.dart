import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';

/// 16 random bytes encoded as URL-safe base64 → 22 chars without
/// padding. Ample collision resistance for a per-send nonce; short
/// enough to fit comfortably in a `prepareUpload` field.
const int _wakeSessionNonceBytes = 16;

final Random _rng = Random.secure();

/// Generates a fresh wake-session nonce. The same value travels in the
/// encrypted [WakePayload] (via `sendWake`) and the upcoming
/// `prepareUpload` request body so the receiver can match them up.
String generateWakeSessionNonce() {
  final out = Uint8List(_wakeSessionNonceBytes);
  for (var i = 0; i < _wakeSessionNonceBytes; i++) {
    out[i] = _rng.nextInt(256);
  }
  return base64UrlEncode(out).replaceAll('=', '');
}

/// Encrypts [payload] with [groupKey] and returns the base64 wire form
/// expected by `sendWake.payload`.
String encodeWakePayload(WakePayload payload, Uint8List groupKey) {
  final plaintext = utf8.encode(jsonEncode(payload.toJson()));
  final encrypted = encryptWithGroupKey(groupKey, Uint8List.fromList(plaintext));
  return base64Encode(encrypted);
}

/// Decrypts a wire blob produced by [encodeWakePayload]. Used by tests
/// and (in a later epic) by the receive path. Throws
/// [GroupKeyAuthFailure] on tag mismatch.
WakePayload decodeWakePayload(String wire, Uint8List groupKey) {
  final blob = Uint8List.fromList(base64Decode(wire));
  final plaintext = decryptWithGroupKey(groupKey, blob);
  final decoded = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
  return WakePayload.fromJson(decoded);
}
