import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/wake/cloud_message.dart';
import 'package:magicshare_app/cloud/wake/cloud_message_dispatcher.dart';
import 'package:magicshare_app/cloud/wake/link_payload.dart';
import 'package:magicshare_app/cloud/wake/link_payload_codec.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';

Uint8List _fixtureKey() => Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

void main() {
  const dispatcher = CloudMessageDispatcher();
  final key = _fixtureKey();

  group('dispatch wake', () {
    test('decrypts a well-formed wake payload', () {
      const payload = WakePayload(
        sessionNonce: 'nonce-xyz',
        sourceFingerprint: 'fp-source',
        initiatedAtMs: 1714780800000,
      );
      final wire = encodeWakePayload(payload, key);

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': wire},
        groupKey: key,
      );

      expect(result, isA<WakeMessage>());
      final wake = result as WakeMessage;
      expect(wake.nonce, 'nonce-xyz');
      expect(wake.sourceFingerprint, 'fp-source');
      expect(wake.initiatedAtMs, 1714780800000);
    });

    test('returns CloudMessageError when payload is missing', () {
      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake'},
        groupKey: key,
      );
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError when payload is empty', () {
      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': ''},
        groupKey: key,
      );
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError when no group key is available', () {
      const payload = WakePayload(
        sessionNonce: 'nonce-xyz',
        sourceFingerprint: 'fp',
        initiatedAtMs: 0,
      );
      final wire = encodeWakePayload(payload, key);

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': wire},
      );
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError on tampered ciphertext', () {
      const payload = WakePayload(
        sessionNonce: 'nonce-xyz',
        sourceFingerprint: 'fp',
        initiatedAtMs: 0,
      );
      final wire = encodeWakePayload(payload, key);
      final raw = base64Decode(wire);
      raw[raw.length - 1] ^= 0x42;
      final tampered = base64Encode(raw);

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': tampered},
        groupKey: key,
      );
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError when key is wrong', () {
      const payload = WakePayload(
        sessionNonce: 'nonce-xyz',
        sourceFingerprint: 'fp',
        initiatedAtMs: 0,
      );
      final wire = encodeWakePayload(payload, key);
      final wrongKey = Uint8List.fromList(List<int>.generate(32, (i) => 0xff - i));

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': wire},
        groupKey: wrongKey,
      );
      expect(result, isA<CloudMessageError>());
    });
  });

  group('dispatch link (encrypted mode)', () {
    test('decrypts a well-formed encrypted link payload', () {
      const payload = LinkPayload(
        url: 'https://example.com/article',
        title: 'Cool article',
      );
      final wire = encodeLinkPayload(payload, key);

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'link', 'payload': wire},
        groupKey: key,
      );

      expect(result, isA<LinkMessage>());
      final link = result as LinkMessage;
      expect(link.url, 'https://example.com/article');
      expect(link.title, 'Cool article');
    });

    test('returns CloudMessageError when no group key is available', () {
      const payload = LinkPayload(url: 'https://example.com');
      final wire = encodeLinkPayload(payload, key);

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'link', 'payload': wire},
      );
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError on tampered ciphertext', () {
      const payload = LinkPayload(url: 'https://example.com');
      final wire = encodeLinkPayload(payload, key);
      final raw = base64Decode(wire);
      raw[raw.length - 1] ^= 0x42;
      final tampered = base64Encode(raw);

      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'link', 'payload': tampered},
        groupKey: key,
      );
      expect(result, isA<CloudMessageError>());
    });
  });

  group('dispatch link (plaintext mode)', () {
    test('reads url + title from the data map', () {
      final result = dispatcher.dispatch(
        <String, dynamic>{
          'type': 'link',
          'url': 'https://example.com/page',
          'title': 'Page',
        },
      );
      expect(result, isA<LinkMessage>());
      final link = result as LinkMessage;
      expect(link.url, 'https://example.com/page');
      expect(link.title, 'Page');
    });

    test('title is optional', () {
      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'link', 'url': 'https://example.com'},
      );
      expect(result, isA<LinkMessage>());
      expect((result as LinkMessage).title, isNull);
    });

    test('returns CloudMessageError when neither payload nor url is present', () {
      final result = dispatcher.dispatch(<String, dynamic>{'type': 'link'});
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError when url is empty', () {
      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'link', 'url': ''},
      );
      expect(result, isA<CloudMessageError>());
    });
  });

  group('dispatch shape errors', () {
    test('returns CloudMessageError when type is missing', () {
      final result = dispatcher.dispatch(<String, dynamic>{});
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError when type is unknown', () {
      final result = dispatcher.dispatch(<String, dynamic>{'type': 'mystery'});
      expect(result, isA<CloudMessageError>());
    });

    test('returns CloudMessageError when type is non-string', () {
      final result = dispatcher.dispatch(<String, dynamic>{'type': 42});
      expect(result, isA<CloudMessageError>());
    });
  });
}
