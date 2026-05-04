import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';

void main() {
  // 24 bytes of base64url-decoded entropy → 32 chars, the same shape
  // the cloud function returns from createJoinToken.
  const tokenIdFixture = 'aB1cD2eF3gH4iJ5kL6mN7oP8qR9sT0uV';
  // 33 bytes — SEC1 compressed P-256 public key shape (S2's output).
  final pubFixture = Uint8List.fromList([
    0x02,
    for (var i = 1; i <= 32; i++) i,
  ]);

  PairingPayload sample({String ip = '192.168.1.42', int port = 53317}) {
    return PairingPayload(
      tokenId: tokenIdFixture,
      issuerLanAddress: ip,
      issuerLanPort: port,
      issuerPubKeyCompressed: pubFixture,
    );
  }

  group('encodePairingPayload / decodePairingPayload', () {
    test('round-trips a representative payload', () {
      final p = sample();
      final bytes = encodePairingPayload(p);
      final back = decodePairingPayload(bytes);
      expect(back, equals(p));
    });

    test('encodes the address as four big-endian octets', () {
      final p = sample(ip: '10.0.0.1', port: 9090);
      final bytes = encodePairingPayload(p);
      // Skip version(1) + tokenLen(1) + token(32) + addrFamily(1)
      // = first 35 bytes; next 4 are the IPv4 octets.
      final ipStart = 1 + 1 + tokenIdFixture.length + 1;
      expect(bytes.sublist(ipStart, ipStart + 4), [10, 0, 0, 1]);
      // Then the 2-byte port.
      expect(bytes[ipStart + 4], (9090 >> 8) & 0xff);
      expect(bytes[ipStart + 5], 9090 & 0xff);
    });

    test('rejects bad checksum', () {
      final bytes = encodePairingPayload(sample());
      // Flip the last (CRC) byte.
      bytes[bytes.length - 1] ^= 0xff;
      expect(
        () => decodePairingPayload(bytes),
        throwsA(
          isA<PairingPayloadDecodeException>().having(
            (e) => e.error,
            'error',
            PairingPayloadDecodeError.badChecksum,
          ),
        ),
      );
    });

    test('rejects unknown version', () {
      final bytes = encodePairingPayload(sample());
      // Mutate the version byte and recompute the CRC so this test
      // exercises wrongVersion (not badChecksum).
      bytes[0] = 99;
      final core = Uint8List.sublistView(bytes, 0, bytes.length - 1);
      bytes[bytes.length - 1] = _crc8(core);
      expect(
        () => decodePairingPayload(bytes),
        throwsA(
          isA<PairingPayloadDecodeException>().having(
            (e) => e.error,
            'error',
            PairingPayloadDecodeError.wrongVersion,
          ),
        ),
      );
    });

    test('rejects truncated input', () {
      final bytes = encodePairingPayload(sample());
      expect(
        () => decodePairingPayload(Uint8List.sublistView(bytes, 0, 10)),
        throwsA(isA<PairingPayloadDecodeException>()),
      );
    });

    test('encode rejects bad IPv4', () {
      expect(
        () => encodePairingPayload(
          PairingPayload(
            tokenId: tokenIdFixture,
            issuerLanAddress: '999.0.0.1',
            issuerLanPort: 53317,
            issuerPubKeyCompressed: pubFixture,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('encode rejects port 0 and >65535', () {
      expect(
        () => encodePairingPayload(
          PairingPayload(
            tokenId: tokenIdFixture,
            issuerLanAddress: '10.0.0.1',
            issuerLanPort: 0,
            issuerPubKeyCompressed: pubFixture,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => encodePairingPayload(
          PairingPayload(
            tokenId: tokenIdFixture,
            issuerLanAddress: '10.0.0.1',
            issuerLanPort: 70000,
            issuerPubKeyCompressed: pubFixture,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('encodePairingUri / tryDecodePairingUri', () {
    test('round-trips with the magicshare-pair: scheme', () {
      final p = sample();
      final uri = encodePairingUri(p);
      expect(uri, startsWith('magicshare-pair:'));
      final back = tryDecodePairingUri(uri);
      expect(back, equals(p));
    });

    test('decodes raw base64url without the scheme prefix', () {
      final p = sample();
      final withScheme = encodePairingUri(p);
      final raw = withScheme.substring('magicshare-pair:'.length);
      expect(tryDecodePairingUri(raw), equals(p));
    });

    test('tolerates leading / trailing whitespace', () {
      final p = sample();
      final uri = '  ${encodePairingUri(p)}\n';
      expect(tryDecodePairingUri(uri), equals(p));
    });

    test('returns null on garbage input rather than throwing', () {
      expect(tryDecodePairingUri('not-a-pairing-uri'), isNull);
      expect(tryDecodePairingUri(''), isNull);
      expect(tryDecodePairingUri('magicshare-pair:!!!'), isNull);
    });
  });

  group('encodePairingManualCode / tryDecodePairingManualCode', () {
    test('round-trips a representative payload', () {
      final p = sample();
      final code = encodePairingManualCode(p);
      expect(tryDecodePairingManualCode(code), equals(p));
    });

    test('emits 4-char chunks separated by hyphens', () {
      final code = encodePairingManualCode(sample());
      final chunks = code.split('-');
      // Every chunk except the last is exactly 4 chars.
      for (var i = 0; i < chunks.length - 1; i++) {
        expect(chunks[i].length, 4);
      }
      expect(chunks.last.length, lessThanOrEqualTo(4));
      // No internal whitespace.
      expect(code.contains(' '), isFalse);
    });

    test('decode is case-insensitive', () {
      final code = encodePairingManualCode(sample());
      expect(tryDecodePairingManualCode(code.toLowerCase()), equals(sample()));
    });

    test('decode tolerates user-typed extra spaces and missing/extra hyphens', () {
      final code = encodePairingManualCode(sample());
      final mangled = code.replaceAll('-', ' ');
      expect(tryDecodePairingManualCode(mangled), equals(sample()));

      final extraHyphens = code.replaceAll('', '-').substring(1);
      // Some chars now have hyphens around them; should still decode.
      expect(tryDecodePairingManualCode(extraHyphens), equals(sample()));
    });

    test('decode loose-maps I/L → 1, O → 0, U → V', () {
      // Construct a manual code that uses only chars that don't trip
      // the loose remap (so we know what the canonical form looks
      // like), then verify substituting the loose chars round-trips.
      final code = encodePairingManualCode(sample());
      final substituted = code.replaceAll('1', 'I').replaceAll('0', 'O').replaceAll('V', 'U');
      // We only care that decoding it produces the same payload.
      expect(tryDecodePairingManualCode(substituted), equals(sample()));
    });

    test('returns null on a single-character typo (caught by CRC-8)', () {
      final code = encodePairingManualCode(sample());
      // Flip a single character in the middle to one with the same
      // alphabet so we don't trip the badAlphabet path first.
      final chars = code.split('');
      // Find the first char that's a valid Crockford symbol, swap to
      // a different one. Pick a position deep enough to not be in the
      // version byte's encoding so we test the CRC, not version.
      for (var i = 30; i < chars.length; i++) {
        if (chars[i] == '-') continue;
        chars[i] = chars[i] == 'A' ? 'B' : 'A';
        break;
      }
      final mangled = chars.join();
      expect(tryDecodePairingManualCode(mangled), isNull);
    });

    test('returns null on a wrong-length input', () {
      expect(tryDecodePairingManualCode(''), isNull);
      expect(tryDecodePairingManualCode('AB-CD-EF'), isNull);
    });

    test('returns null when the alphabet is wrong', () {
      // `?` is never a Crockford char. Fail fast.
      expect(tryDecodePairingManualCode('AB?D-EFGH'), isNull);
    });
  });
}

int _crc8(Uint8List bytes) {
  var crc = 0;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = ((crc & 0x80) != 0) ? ((crc << 1) ^ 0x07) & 0xff : (crc << 1) & 0xff;
    }
  }
  return crc;
}
