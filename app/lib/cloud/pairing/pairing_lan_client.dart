import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_server.dart' show kPairingExchangeKeyPath;
import 'package:pointycastle/ecc/api.dart' show ECPrivateKey, ECPublicKey;

/// Joining-side half of the LAN handshake. Connects to the issuer's
/// ephemeral [PairingLanServer], proves possession of the matching
/// `tokenId`, and decrypts the wrapped group key under the
/// ECDH-derived AES-256 key.
///
/// Throws [PairingLanClientException] for transport / protocol /
/// crypto failures so the caller can map them to user-facing
/// surfaces. Throws [TimeoutException] when [timeout] elapses
/// without a response (default 5 s — handshakes are tiny).
class PairingLanClient {
  PairingLanClient({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  /// Performs the key-exchange round-trip. On success, returns the
  /// 32-byte group shared key the issuer holds.
  Future<Uint8List> exchangeKey({
    required String issuerHost,
    required int issuerPort,
    required String tokenId,
    required ECPrivateKey joinerPrivateKey,
    required ECPublicKey joinerPublicKey,
    required ECPublicKey issuerPublicKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final uri = Uri.http('$issuerHost:$issuerPort', kPairingExchangeKeyPath);
    final joinerPubBytes = compressPublicKey(joinerPublicKey);
    final body = jsonEncode({
      'tokenId': tokenId,
      'joinerPubKeyB64': base64Url.encode(joinerPubBytes),
    });

    final HttpClientResponse response;
    try {
      final request = await _httpClient.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(body);
      response = await request.close().timeout(timeout);
    } on SocketException catch (e) {
      throw PairingLanClientException(
        PairingLanClientError.transport,
        'Could not reach issuer at $issuerHost:$issuerPort: $e',
      );
    } on HttpException catch (e) {
      throw PairingLanClientException(
        PairingLanClientError.transport,
        'HTTP error contacting issuer: $e',
      );
    }

    final responseBody = await utf8.decoder.bind(response).join().timeout(timeout);

    if (response.statusCode != HttpStatus.ok) {
      String? code;
      try {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        code = decoded['error'] as String?;
      } catch (_) {
        // Body wasn't JSON — leave code null and surface a generic
        // protocol error.
      }
      throw PairingLanClientException(
        _errorForStatusAndCode(response.statusCode, code),
        'Issuer rejected handshake (HTTP ${response.statusCode}, code=$code)',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw PairingLanClientException(
        PairingLanClientError.protocol,
        'Issuer returned malformed JSON',
      );
    }
    final wrappedB64 = json['wrappedGroupKeyB64'];
    if (wrappedB64 is! String || wrappedB64.isEmpty) {
      throw PairingLanClientException(
        PairingLanClientError.protocol,
        'Issuer response missing wrappedGroupKeyB64',
      );
    }

    final Uint8List wrappedBytes;
    try {
      wrappedBytes = Uint8List.fromList(base64Url.decode(_padBase64Url(wrappedB64)));
    } catch (_) {
      throw PairingLanClientException(
        PairingLanClientError.protocol,
        'wrappedGroupKeyB64 is not valid base64url',
      );
    }

    final shared = deriveSharedSecret(joinerPrivateKey, issuerPublicKey);
    final aesKey = derivePairingAesKey(shared);

    final Uint8List groupKey;
    try {
      groupKey = decryptWithGroupKey(aesKey, wrappedBytes);
    } on GroupKeyAuthFailure catch (e) {
      throw PairingLanClientException(
        PairingLanClientError.cryptoAuth,
        'AES-GCM auth failed: ${e.message}',
      );
    }

    if (groupKey.length != groupKeyLengthBytes) {
      throw PairingLanClientException(
        PairingLanClientError.protocol,
        'Issuer returned a group key of unexpected length: ${groupKey.length}',
      );
    }
    return groupKey;
  }

  void close() => _httpClient.close(force: true);

  static PairingLanClientError _errorForStatusAndCode(int status, String? code) {
    if (status == HttpStatus.gone || code == 'alreadyConsumed') {
      return PairingLanClientError.alreadyConsumed;
    }
    if (status == HttpStatus.forbidden || code == 'tokenMismatch') {
      return PairingLanClientError.tokenMismatch;
    }
    if (status == HttpStatus.notFound) {
      return PairingLanClientError.unknownRoute;
    }
    return PairingLanClientError.protocol;
  }

  static String _padBase64Url(String input) => input.padRight((input.length + 3) & ~3, '=');
}

enum PairingLanClientError {
  /// TCP / DNS / connection failure. Most often caused by the
  /// joiner not actually being on the same LAN as the issuer.
  transport,

  /// Issuer rejected the request because the supplied tokenId
  /// doesn't match the one it minted in the current dialog.
  tokenMismatch,

  /// Server already completed a handshake — the legitimate joiner
  /// is too late.
  alreadyConsumed,

  /// 404 from the route — server is up but doesn't speak the
  /// pairing protocol (wrong app, wrong version, etc.).
  unknownRoute,

  /// Malformed request/response or unexpected HTTP status.
  protocol,

  /// AES-GCM auth-tag verification failed — wrong AES key derived,
  /// which means either the issuer's public key in the QR/manual
  /// payload doesn't match the issuer running the LAN server, or an
  /// active MITM tampered with the response.
  cryptoAuth,
}

class PairingLanClientException implements Exception {
  PairingLanClientException(this.error, this.message);
  final PairingLanClientError error;
  final String message;

  @override
  String toString() => 'PairingLanClientException(${error.name}): $message';
}
