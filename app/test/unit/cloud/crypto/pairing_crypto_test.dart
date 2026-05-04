import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';

void main() {
  group('generatePairingKeyPair', () {
    test('returns a usable P-256 keypair on every call', () {
      final pair = generatePairingKeyPair();
      expect(pair.privateKey.parameters?.curve, isNotNull);
      expect(pair.publicKey.Q, isNotNull);
      expect(pair.publicKey.Q!.isInfinity, isFalse);
    });

    test('successive calls produce different keypairs', () {
      final pubs = List.generate(
        20,
        (_) => _hex(compressPublicKey(generatePairingKeyPair().publicKey)),
      ).toSet();
      expect(pubs.length, 20);
    });
  });

  group('compressPublicKey / decompressPublicKey', () {
    test('round-trips an arbitrary keypair', () {
      final pair = generatePairingKeyPair();
      final compressed = compressPublicKey(pair.publicKey);
      expect(compressed.length, p256CompressedPubkeyBytes);
      // SEC1 compressed prefix is 0x02 (even Y) or 0x03 (odd Y).
      expect(compressed[0] == 0x02 || compressed[0] == 0x03, isTrue);

      final decoded = decompressPublicKey(compressed);
      expect(decoded.Q, isNotNull);
      // Re-compressing the decoded point yields the original bytes.
      expect(compressPublicKey(decoded), compressed);
    });

    test('rejects a wrong-length compressed point', () {
      expect(
        () => decompressPublicKey(Uint8List(32)),
        throwsArgumentError,
      );
      expect(
        () => decompressPublicKey(Uint8List(34)),
        throwsArgumentError,
      );
    });

    test('rejects a bad SEC1 prefix byte', () {
      final bad = Uint8List(p256CompressedPubkeyBytes);
      bad[0] = 0x04; // 0x04 is the *uncompressed* prefix, not allowed here.
      expect(() => decompressPublicKey(bad), throwsArgumentError);
    });

    test('rejects a prefix byte that is otherwise nonsense', () {
      final bad = Uint8List(p256CompressedPubkeyBytes);
      bad[0] = 0x99;
      expect(() => decompressPublicKey(bad), throwsArgumentError);
    });
  });

  group('deriveSharedSecret', () {
    test('ECDH symmetry: A.priv + B.pub == B.priv + A.pub', () {
      final a = generatePairingKeyPair();
      final b = generatePairingKeyPair();

      final ab = deriveSharedSecret(a.privateKey, b.publicKey);
      final ba = deriveSharedSecret(b.privateKey, a.publicKey);

      expect(ab, ba);
      expect(ab.length, p256FieldSizeBytes);
    });

    test('different pairs derive different secrets', () {
      final a = generatePairingKeyPair();
      final b = generatePairingKeyPair();
      final c = generatePairingKeyPair();

      final ab = deriveSharedSecret(a.privateKey, b.publicKey);
      final ac = deriveSharedSecret(a.privateKey, c.publicKey);

      expect(_hex(ab), isNot(equals(_hex(ac))));
    });
  });

  group('hkdfSha256', () {
    test('matches RFC 5869 Test Case 1 (Basic SHA-256)', () {
      // Vectors from https://tools.ietf.org/html/rfc5869 §A.1
      final ikm = _fromHex('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
      final salt = _fromHex('000102030405060708090a0b0c');
      final info = _fromHex('f0f1f2f3f4f5f6f7f8f9');
      const length = 42;
      final expected = _fromHex(
        '3cb25f25faacd57a90434f64d0362f2a'
        '2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
        '34007208d5b887185865',
      );

      final out = hkdfSha256(ikm: ikm, salt: salt, info: info, length: length);
      expect(out, expected);
    });

    test('rejects out-of-range length', () {
      expect(
        () => hkdfSha256(
          ikm: Uint8List(8),
          salt: Uint8List(0),
          info: Uint8List(0),
          length: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => hkdfSha256(
          ikm: Uint8List(8),
          salt: Uint8List(0),
          info: Uint8List(0),
          length: 255 * 32 + 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('derivePairingAesKey', () {
    test('returns a 32-byte AES-256 key', () {
      final secret = _fromHex(
        'a0b1c2d3e4f50607a0b1c2d3e4f50607'
        'a0b1c2d3e4f50607a0b1c2d3e4f50607',
      );
      final key = derivePairingAesKey(secret);
      expect(key.length, pairingAesKeyLengthBytes);
    });

    test('is deterministic for a given input', () {
      final secret = Uint8List.fromList(List.generate(32, (i) => i + 1));
      expect(derivePairingAesKey(secret), derivePairingAesKey(secret));
    });

    test('changes when the input changes', () {
      final a = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final b = Uint8List.fromList(List.generate(32, (i) => i + 2));
      expect(_hex(derivePairingAesKey(a)), isNot(equals(_hex(derivePairingAesKey(b)))));
    });

    test('end-to-end: two parties derive the same AES key from a paired ECDH agreement', () {
      // The contract that S4 (LAN handshake) relies on: both halves
      // of the handshake call deriveSharedSecret + derivePairingAesKey
      // independently and arrive at the same 32-byte symmetric key.
      final issuer = generatePairingKeyPair();
      final joiner = generatePairingKeyPair();

      final issuerSecret = deriveSharedSecret(issuer.privateKey, joiner.publicKey);
      final joinerSecret = deriveSharedSecret(joiner.privateKey, issuer.publicKey);

      final issuerKey = derivePairingAesKey(issuerSecret);
      final joinerKey = derivePairingAesKey(joinerSecret);

      expect(issuerKey, joinerKey);
      expect(issuerKey.length, pairingAesKeyLengthBytes);
    });
  });
}

String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _fromHex(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s'), '');
  if (clean.length.isOdd) {
    throw ArgumentError('Hex must be even-length');
  }
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
