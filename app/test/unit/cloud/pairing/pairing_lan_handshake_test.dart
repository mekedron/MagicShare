import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';
import 'package:magicshare_app/cloud/pairing/lan_reachability.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_client.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_server.dart';

void main() {
  group('PairingLanServer + PairingLanClient round-trip', () {
    late PairingLanServer server;
    late Uint8List groupKey;
    late PairingKeyPair issuerKeys;
    const tokenId = 'fixture-token-id-1234567890abcdef';

    setUp(() async {
      groupKey = generateGroupKey();
      issuerKeys = generatePairingKeyPair();
      server = PairingLanServer(
        tokenId: tokenId,
        issuerPrivateKey: issuerKeys.privateKey,
        groupKey: groupKey,
        // Short timeout keeps the test fast even when the success
        // path is exercised first.
        timeout: const Duration(seconds: 5),
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('joiner receives the issuer\'s group key bit-for-bit', () async {
      final joinerKeys = generatePairingKeyPair();
      final client = PairingLanClient();
      try {
        final received = await client.exchangeKey(
          issuerHost: '127.0.0.1',
          issuerPort: server.port,
          tokenId: tokenId,
          joinerPrivateKey: joinerKeys.privateKey,
          joinerPublicKey: joinerKeys.publicKey,
          issuerPublicKey: issuerKeys.publicKey,
        );
        expect(received, equals(groupKey));
        expect(received.length, groupKeyLengthBytes);
      } finally {
        client.close();
      }
      // Server completes its handshake-completed Future on success.
      await server.handshakeCompleted;
    });

    test('server tears down after one successful exchange', () async {
      // Capture the port before the first exchange — `server.port`
      // throws after the server tears itself down post-success.
      final port = server.port;
      final joinerKeys = generatePairingKeyPair();
      final client = PairingLanClient();
      try {
        await client.exchangeKey(
          issuerHost: '127.0.0.1',
          issuerPort: port,
          tokenId: tokenId,
          joinerPrivateKey: joinerKeys.privateKey,
          joinerPublicKey: joinerKeys.publicKey,
          issuerPublicKey: issuerKeys.publicKey,
        );
        // Give stop() a tick to actually close the listener.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // A second attempt should fail because the server is gone.
        await expectLater(
          client.exchangeKey(
            issuerHost: '127.0.0.1',
            issuerPort: port,
            tokenId: tokenId,
            joinerPrivateKey: generatePairingKeyPair().privateKey,
            joinerPublicKey: generatePairingKeyPair().publicKey,
            issuerPublicKey: issuerKeys.publicKey,
          ),
          throwsA(
            isA<PairingLanClientException>().having(
              (e) => e.error,
              'error',
              PairingLanClientError.transport,
            ),
          ),
        );
      } finally {
        client.close();
      }
    });

    test('rejects requests with the wrong tokenId without consuming the handshake', () async {
      final joinerKeys = generatePairingKeyPair();
      final client = PairingLanClient();
      try {
        // First attempt: wrong tokenId → tokenMismatch.
        await expectLater(
          client.exchangeKey(
            issuerHost: '127.0.0.1',
            issuerPort: server.port,
            tokenId: 'wrong-token',
            joinerPrivateKey: joinerKeys.privateKey,
            joinerPublicKey: joinerKeys.publicKey,
            issuerPublicKey: issuerKeys.publicKey,
          ),
          throwsA(
            isA<PairingLanClientException>().having(
              (e) => e.error,
              'error',
              PairingLanClientError.tokenMismatch,
            ),
          ),
        );

        // Second attempt with the right tokenId still succeeds —
        // the wrong-token attempt didn't burn the handshake.
        final received = await client.exchangeKey(
          issuerHost: '127.0.0.1',
          issuerPort: server.port,
          tokenId: tokenId,
          joinerPrivateKey: joinerKeys.privateKey,
          joinerPublicKey: joinerKeys.publicKey,
          issuerPublicKey: issuerKeys.publicKey,
        );
        expect(received, equals(groupKey));
      } finally {
        client.close();
      }
    });

    test('rejects malformed JSON body with HTTP 400', () async {
      // Drive the server with a raw HttpClient so we can send a
      // non-JSON body, which the typed PairingLanClient wouldn't
      // produce.
      final raw = HttpClient();
      try {
        final req = await raw.postUrl(
          Uri.http('127.0.0.1:${server.port}', kPairingExchangeKeyPath),
        );
        req.headers.contentType = ContentType.json;
        req.write('{ this is not json');
        final res = await req.close();
        expect(res.statusCode, HttpStatus.badRequest);
        final body = await utf8.decoder.bind(res).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        expect(decoded['error'], 'malformedJson');
      } finally {
        raw.close(force: true);
      }
    });

    test('returns 404 for unknown routes', () async {
      final raw = HttpClient();
      try {
        final res = await (await raw.getUrl(
          Uri.http('127.0.0.1:${server.port}', '/somewhere-else'),
        )).close();
        expect(res.statusCode, HttpStatus.notFound);
      } finally {
        raw.close(force: true);
      }
    });
  });

  group('PairingLanServer timeout', () {
    test('handshakeCompleted fails with TimeoutException after timeout', () async {
      final s = PairingLanServer(
        tokenId: 'tt',
        issuerPrivateKey: generatePairingKeyPair().privateKey,
        groupKey: generateGroupKey(),
        timeout: const Duration(milliseconds: 200),
      );
      await s.start();
      await expectLater(s.handshakeCompleted, throwsA(isA<TimeoutException>()));
      // Server has already torn down via its internal stop(); calling
      // again should be a no-op.
      await s.stop();
    });
  });

  group('isLanReachable', () {
    test('returns true for a live local TCP listener', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      try {
        expect(
          await isLanReachable(host: '127.0.0.1', port: server.port),
          isTrue,
        );
      } finally {
        await server.close();
      }
    });

    test('returns false for a closed port', () async {
      // Pick a port we just released.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      expect(
        await isLanReachable(
          host: '127.0.0.1',
          port: port,
          timeout: const Duration(seconds: 1),
        ),
        isFalse,
      );
    });

    test('returns false on timeout to an unreachable address', () async {
      // 192.0.2.0/24 is documented as test-only and should not route
      // anywhere — Socket.connect will timeout. Pin a small timeout
      // so the test stays fast.
      expect(
        await isLanReachable(
          host: '192.0.2.1',
          port: 9,
          timeout: const Duration(milliseconds: 300),
        ),
        isFalse,
      );
    });
  });
}
