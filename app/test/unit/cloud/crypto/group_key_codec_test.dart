import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';

void main() {
  group('generateGroupKey', () {
    test('returns 32 bytes', () {
      expect(generateGroupKey().length, 32);
    });

    test('successive calls produce different keys', () {
      final keys = List.generate(10, (_) => generateGroupKey()).map(_hex).toSet();
      expect(keys.length, 10);
    });
  });

  group('encryptWithGroupKey / decryptWithGroupKey', () {
    test('round-trips an arbitrary plaintext', () {
      final key = generateGroupKey();
      final plaintext = utf8.encode('Hello, MagicShare cloud sync!');
      final blob = encryptWithGroupKey(key, plaintext);
      final decrypted = decryptWithGroupKey(key, blob);
      expect(decrypted, plaintext);
    });

    test('round-trips an empty plaintext', () {
      final key = generateGroupKey();
      final blob = encryptWithGroupKey(key, Uint8List(0));
      final decrypted = decryptWithGroupKey(key, blob);
      expect(decrypted.length, 0);
    });

    test('produces unique nonces over 1000 encryptions of the same plaintext', () {
      final key = generateGroupKey();
      final plaintext = utf8.encode('static');
      final nonces = <String>{};
      for (var i = 0; i < 1000; i++) {
        final blob = encryptWithGroupKey(key, plaintext);
        nonces.add(_hex(Uint8List.sublistView(blob, 0, 12)));
      }
      expect(nonces.length, 1000);
    });

    test('rejects a key of the wrong length', () {
      expect(
        () => encryptWithGroupKey(Uint8List(31), Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => decryptWithGroupKey(Uint8List(33), Uint8List(50)),
        throwsArgumentError,
      );
    });

    test('rejects a malformed blob shorter than nonce + tag', () {
      final key = generateGroupKey();
      expect(
        () => decryptWithGroupKey(key, Uint8List(20)),
        throwsArgumentError,
      );
    });
  });

  group('tamper detection', () {
    test('flipping a single ciphertext byte raises GroupKeyAuthFailure', () {
      final key = generateGroupKey();
      final blob = encryptWithGroupKey(key, utf8.encode('payload'));
      // Flip a byte beyond the nonce so we hit the ciphertext / tag region.
      final tampered = Uint8List.fromList(blob);
      tampered[blob.length - 1] ^= 0xff;
      expect(
        () => decryptWithGroupKey(key, tampered),
        throwsA(isA<GroupKeyAuthFailure>()),
      );
    });

    test('decrypting with the wrong key raises GroupKeyAuthFailure', () {
      final blob = encryptWithGroupKey(generateGroupKey(), utf8.encode('hi'));
      expect(
        () => decryptWithGroupKey(generateGroupKey(), blob),
        throwsA(isA<GroupKeyAuthFailure>()),
      );
    });
  });

  group('AAD', () {
    test('round-trip with matching AAD succeeds', () {
      final key = generateGroupKey();
      final aad = utf8.encode('device-A:wake-session-42');
      final blob = encryptWithGroupKey(key, utf8.encode('inner'), aad: aad);
      expect(decryptWithGroupKey(key, blob, aad: aad), utf8.encode('inner'));
    });

    test('mismatched AAD raises GroupKeyAuthFailure', () {
      final key = generateGroupKey();
      final blob = encryptWithGroupKey(
        key,
        utf8.encode('inner'),
        aad: utf8.encode('one'),
      );
      expect(
        () => decryptWithGroupKey(key, blob, aad: utf8.encode('two')),
        throwsA(isA<GroupKeyAuthFailure>()),
      );
    });

    test('omitting AAD on decrypt when present on encrypt fails', () {
      final key = generateGroupKey();
      final blob = encryptWithGroupKey(
        key,
        utf8.encode('inner'),
        aad: utf8.encode('present'),
      );
      expect(
        () => decryptWithGroupKey(key, blob),
        throwsA(isA<GroupKeyAuthFailure>()),
      );
    });
  });
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
