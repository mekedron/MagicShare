import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show AEADParameters, KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/export.dart' show InvalidCipherTextException;

/// 32 bytes — AES-256 key length.
const int groupKeyLengthBytes = 32;

/// 12 bytes — AES-GCM standard nonce length (96 bits). Random per call.
/// Birthday-bound for nonce collision is ~2^32 messages per key, well clear
/// of any per-device transfer cadence.
const int _nonceLengthBytes = 12;

/// 128 bits — full GCM auth-tag length.
const int _tagLengthBits = 128;
const int _tagLengthBytes = _tagLengthBits ~/ 8;

/// Thrown by [decryptWithGroupKey] when the auth tag does not verify against
/// the ciphertext, AAD, or key — i.e. the blob has been tampered with, the
/// AAD does not match the encryption-time AAD, or the wrong key was used.
class GroupKeyAuthFailure implements Exception {
  GroupKeyAuthFailure(this.message);
  final String message;

  @override
  String toString() => 'GroupKeyAuthFailure: $message';
}

/// Generates a fresh 32-byte group key using a cryptographic RNG.
Uint8List generateGroupKey() => _randomBytes(groupKeyLengthBytes);

/// Encrypts [plaintext] with AES-256-GCM using [key] (must be 32 bytes).
/// Optional [aad] is authenticated but not encrypted; pass the same value
/// to [decryptWithGroupKey] to verify it. Wire format:
/// `nonce(12) || ciphertext || tag(16)`.
Uint8List encryptWithGroupKey(
  Uint8List key,
  Uint8List plaintext, {
  Uint8List? aad,
}) {
  _assertKeyLength(key);
  final nonce = _randomBytes(_nonceLengthBytes);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(key), _tagLengthBits, nonce, aad ?? Uint8List(0)),
    );
  final ciphertextWithTag = cipher.process(plaintext);
  final blob = Uint8List(_nonceLengthBytes + ciphertextWithTag.length);
  blob.setRange(0, _nonceLengthBytes, nonce);
  blob.setRange(_nonceLengthBytes, blob.length, ciphertextWithTag);
  return blob;
}

/// Decrypts [blob] produced by [encryptWithGroupKey] with the matching
/// [key] and optional [aad]. Throws [GroupKeyAuthFailure] when the tag does
/// not verify, or [ArgumentError] when the wire format is malformed.
Uint8List decryptWithGroupKey(
  Uint8List key,
  Uint8List blob, {
  Uint8List? aad,
}) {
  _assertKeyLength(key);
  if (blob.length < _nonceLengthBytes + _tagLengthBytes) {
    throw ArgumentError(
      'Encrypted blob too short: ${blob.length} bytes (need at least '
      '${_nonceLengthBytes + _tagLengthBytes})',
    );
  }
  final nonce = Uint8List.sublistView(blob, 0, _nonceLengthBytes);
  final ciphertextWithTag = Uint8List.sublistView(blob, _nonceLengthBytes);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(KeyParameter(key), _tagLengthBits, nonce, aad ?? Uint8List(0)),
    );
  try {
    return cipher.process(ciphertextWithTag);
  } on InvalidCipherTextException catch (e) {
    throw GroupKeyAuthFailure(e.message);
  }
}

void _assertKeyLength(Uint8List key) {
  if (key.length != groupKeyLengthBytes) {
    throw ArgumentError(
      'Group key must be $groupKeyLengthBytes bytes; got ${key.length}',
    );
  }
}

final Random _rng = Random.secure();

Uint8List _randomBytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = _rng.nextInt(256);
  }
  return out;
}
