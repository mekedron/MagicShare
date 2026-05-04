import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';
import 'package:pointycastle/ecc/api.dart' show ECPrivateKey;

final _logger = Logger('PairingLanServer');

/// Default lifetime of an open pairing listener — matches the
/// 5-minute join-token TTL the cloud function mints. After this the
/// server tears itself down so an issuing-side dialog left open
/// indefinitely doesn't leave a port listening.
const Duration kDefaultPairingHandshakeTimeout = Duration(minutes: 5);

/// HTTP route the joiner POSTs to. Versioned so we can iterate
/// without breaking older installs that already shipped the
/// pairing flow.
const String kPairingExchangeKeyPath = '/v1/pair/exchange-key';

/// Minimal abstract surface the issuing-side dialog talks to. The
/// production implementation is [PairingLanServer]; widget tests use
/// a fake to avoid binding a real socket and to drive the
/// handshake-completed signal deterministically.
abstract class PairingLanServerHandle {
  /// Bind the listener and return the bound port. Idempotent: a
  /// second call returns the existing port.
  Future<int> start();

  /// Tear down the underlying listener. Safe to call from any state;
  /// subsequent calls are no-ops.
  Future<void> stop();

  /// The bound port. Throws [StateError] if [start] has not yet been
  /// called or [stop] has already torn the server down.
  int get port;

  /// Resolves on a successful handshake; completes with a
  /// [TimeoutException] if the lifetime expires without one.
  Future<void> get handshakeCompleted;
}

/// One-shot LAN-side server hosted by the issuing device for the
/// duration of the *Invite a device* dialog. Accepts a single key
/// exchange request, hands the requesting device the group's shared
/// key wrapped under an ECDH-derived AES-256 key, then tears down.
///
/// Plain HTTP is intentional. The actual security comes from the
/// ECDH derivation: an eavesdropper on the LAN cannot derive the
/// shared secret without the issuer's ephemeral private key, and the
/// issuer rejects requests whose `tokenId` does not match the one it
/// minted in this dialog. TLS would just add operational complexity
/// (cert serving + hostname binding) without changing the threat
/// model.
class PairingLanServer implements PairingLanServerHandle {
  PairingLanServer({
    required this.tokenId,
    required this.issuerPrivateKey,
    required this.groupKey,
    Duration timeout = kDefaultPairingHandshakeTimeout,
    int desiredPort = 0,
  }) : _timeout = timeout,
       _desiredPort = desiredPort;

  final String tokenId;
  final ECPrivateKey issuerPrivateKey;
  final Uint8List groupKey;
  final Duration _timeout;
  // 0 = let the OS pick a free port. Non-zero values are used by the
  // debug `CLOUD_PAIRING_LAN_PORT` knob so an `adb forward tcp:N
  // tcp:N` from the host to the emulator can target a stable port.
  final int _desiredPort;

  HttpServer? _server;
  Timer? _timeoutTimer;
  final Completer<void> _handshakeCompleted = Completer<void>();
  bool _consumed = false;

  /// Resolves when a joining device has successfully completed the
  /// handshake. Never completes with an error — failed handshake
  /// attempts (wrong token, malformed request, etc.) leave the
  /// server open for the next attempt within the [_timeout] window.
  /// Completes with `TimeoutException` only if [_timeout] elapses
  /// without a successful exchange.
  @override
  Future<void> get handshakeCompleted => _handshakeCompleted.future;

  /// The bound port. Throws [StateError] if [start] has not yet been
  /// called or [stop] has already torn the server down.
  @override
  int get port {
    final s = _server;
    if (s == null) throw StateError('PairingLanServer not started');
    return s.port;
  }

  /// Bind on `anyIPv4:_desiredPort` (defaults to 0 — OS picks a
  /// free port). The bound port is read back via [port]. Idempotent:
  /// calling start twice returns the existing port.
  @override
  Future<int> start() async {
    if (_server != null) return _server!.port;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, _desiredPort);
    _server = server;
    server.listen(_handleRequest, onError: _onServerError);
    _timeoutTimer = Timer(_timeout, () {
      if (!_handshakeCompleted.isCompleted) {
        _handshakeCompleted.completeError(
          TimeoutException(
            'PairingLanServer timed out after $_timeout',
            _timeout,
          ),
        );
      }
      unawaited(stop());
    });
    _logger.info('Pairing LAN server bound on port ${server.port}');
    return server.port;
  }

  /// Tear down the underlying HTTP server. Safe to call from any
  /// state; subsequent calls are no-ops.
  @override
  Future<void> stop() async {
    final timer = _timeoutTimer;
    _timeoutTimer = null;
    timer?.cancel();
    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (e, st) {
        _logger.warning('Error closing pairing LAN server', e, st);
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != 'POST' || request.uri.path != kPairingExchangeKeyPath) {
        await _writeErrorAndClose(request, HttpStatus.notFound, 'unknownRoute');
        return;
      }
      if (_consumed) {
        await _writeErrorAndClose(
          request,
          HttpStatus.gone,
          'alreadyConsumed',
        );
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        await _writeErrorAndClose(request, HttpStatus.badRequest, 'malformedJson');
        return;
      }

      final requestTokenId = json['tokenId'];
      final joinerPubKeyB64 = json['joinerPubKeyB64'];
      if (requestTokenId is! String || joinerPubKeyB64 is! String) {
        await _writeErrorAndClose(request, HttpStatus.badRequest, 'missingFields');
        return;
      }
      if (requestTokenId != tokenId) {
        // Wrong tokenId — reject without consuming the handshake so
        // the legitimate joiner can still complete it.
        await _writeErrorAndClose(
          request,
          HttpStatus.forbidden,
          'tokenMismatch',
        );
        return;
      }

      Uint8List joinerPubBytes;
      try {
        joinerPubBytes = Uint8List.fromList(base64Url.decode(_padBase64Url(joinerPubKeyB64)));
      } catch (_) {
        await _writeErrorAndClose(
          request,
          HttpStatus.badRequest,
          'badJoinerPubKey',
        );
        return;
      }

      try {
        final joinerPub = decompressPublicKey(joinerPubBytes);
        final shared = deriveSharedSecret(issuerPrivateKey, joinerPub);
        final aesKey = derivePairingAesKey(shared);
        final wrapped = encryptWithGroupKey(aesKey, groupKey);

        // Mark consumed BEFORE writing the response to defeat any
        // "the OS reports the response sent but it actually didn't"
        // race. Worst case: the joiner doesn't get the wrapped key,
        // they retry, the server is closed, they fall back to the
        // recoverable "couldn't receive group key" error. Better
        // than letting a second joiner re-exchange.
        _consumed = true;
        final response = request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json;
        response.write(jsonEncode({'wrappedGroupKeyB64': base64Url.encode(wrapped)}));
        await response.close();

        if (!_handshakeCompleted.isCompleted) {
          _handshakeCompleted.complete();
        }
        // Tear down so the port is released and a stray duplicate
        // doesn't slip through after the dialog closes.
        unawaited(stop());
      } catch (e, st) {
        _logger.warning('Failed key exchange', e, st);
        // Leave the server open: this might be a malformed pubkey
        // attempt by an attacker; the legitimate joiner can retry.
        await _writeErrorAndClose(
          request,
          HttpStatus.badRequest,
          'exchangeFailed',
        );
      }
    } catch (e, st) {
      _logger.warning('Unexpected error in handler', e, st);
      try {
        await _writeErrorAndClose(
          request,
          HttpStatus.internalServerError,
          'internal',
        );
      } catch (_) {
        // Connection might already be torn down; nothing more to do.
      }
    }
  }

  Future<void> _writeErrorAndClose(
    HttpRequest request,
    int status,
    String code,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': code}));
    await request.response.close();
  }

  void _onServerError(Object error, StackTrace stack) {
    _logger.warning('Pairing LAN server stream error', error, stack);
  }

  static String _padBase64Url(String input) => input.padRight((input.length + 3) & ~3, '=');
}
