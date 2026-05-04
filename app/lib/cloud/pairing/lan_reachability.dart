import 'dart:async';
import 'dart:io';

/// Quick TCP-connect probe to confirm the issuer's LAN endpoint is
/// actually reachable from this device before we touch the cloud.
/// Returns `true` on a successful TCP handshake within [timeout],
/// `false` for any failure (timeout, refused, DNS failure, no route
/// to host).
///
/// We use this on the joining side as the first gate of the pairing
/// flow: failing fast here surfaces the *"Both devices need to be
/// on the same Wi-Fi to pair"* error before we consume the join
/// token, which would otherwise leave a stale `joinTokens/{id}` doc
/// behind for the 5-minute TTL to clean up.
Future<bool> isLanReachable({
  required String host,
  required int port,
  Duration timeout = const Duration(seconds: 2),
}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    return true;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } on Object {
    return false;
  } finally {
    try {
      socket?.destroy();
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
