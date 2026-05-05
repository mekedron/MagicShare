import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/wake/link_payload.dart';
import 'package:magicshare_app/cloud/wake/link_payload_codec.dart';

Uint8List _fixtureKey() => Uint8List.fromList(List<int>.generate(32, (i) => i));

void main() {
  group('LinkPayload', () {
    test('toJson elides null title (ignoreNull)', () {
      const p = LinkPayload(url: 'https://example.com');
      expect(p.toJson(), {'url': 'https://example.com'});
    });

    test('toJson includes title when set', () {
      const p = LinkPayload(url: 'https://example.com', title: 'Hi');
      expect(p.toJson(), {'url': 'https://example.com', 'title': 'Hi'});
    });
  });

  group('encode/decodeLinkPayload', () {
    final key = _fixtureKey();

    test('round-trip preserves url and title', () {
      const p = LinkPayload(url: 'https://example.com/article', title: 'Example');
      final wire = encodeLinkPayload(p, key);
      final decoded = decodeLinkPayload(wire, key);
      expect(decoded.url, p.url);
      expect(decoded.title, p.title);
    });

    test('round-trip preserves url-only payload', () {
      const p = LinkPayload(url: 'https://example.com');
      final wire = encodeLinkPayload(p, key);
      final decoded = decodeLinkPayload(wire, key);
      expect(decoded.url, 'https://example.com');
      expect(decoded.title, isNull);
    });

    test('throws GroupKeyAuthFailure when ciphertext is tampered', () {
      const p = LinkPayload(url: 'https://example.com');
      final wire = encodeLinkPayload(p, key);
      final raw = base64Decode(wire);
      raw[raw.length - 1] ^= 0x55;
      final tampered = base64Encode(raw);
      expect(() => decodeLinkPayload(tampered, key), throwsA(isA<GroupKeyAuthFailure>()));
    });
  });
}
