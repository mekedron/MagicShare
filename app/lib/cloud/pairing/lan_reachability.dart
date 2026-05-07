import 'dart:async';
import 'dart:io';

/// TCP-connect probe to confirm the issuer's LAN endpoint is
/// actually reachable from this device before we touch the cloud.
/// Returns `true` on a successful TCP handshake within [timeout],
/// `false` for any failure (timeout, refused, DNS failure, no route
/// to host) across [retries] consecutive attempts.
///
/// We use this on the joining side as the first gate of the pairing
/// flow: failing fast here surfaces the *"Both devices need to be
/// on the same Wi-Fi to pair"* error before we consume the join
/// token, which would otherwise leave a stale `joinTokens/{id}` doc
/// behind for the 5-minute TTL to clean up.
///
/// The default [retries]=3 with a 100ms backoff masks the two flaky
/// modes we hit in practice: (1) the issuer's `HttpServer.bind`
/// hasn't finished by the time the joiner probes, and (2) NAT'd
/// networks (notably the Android emulator) occasionally drop the
/// first SYN. Total worst-case wait is `retries * timeout` plus
/// inter-attempt sleeps; bound this carefully.
Future<bool> isLanReachable({
  required String host,
  required int port,
  Duration timeout = const Duration(seconds: 3),
  int retries = 3,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  for (var attempt = 0; attempt < retries; attempt++) {
    if (await _tryConnectOnce(host: host, port: port, timeout: timeout)) {
      return true;
    }
    if (attempt < retries - 1) {
      await Future<void>.delayed(retryDelay);
    }
  }
  return false;
}

/// Race [isLanReachable] across every host in [hosts] in parallel and
/// return the first one whose TCP handshake completes successfully,
/// or `null` if none do.
///
/// This is the joining-side primitive for v2 PairingPayloads, which
/// can carry up to four candidate LAN addresses (e.g. `127.0.0.1`
/// for an Android-emulator joiner reaching the host via `adb
/// reverse`, plus the host's real LAN IP for a physical-device
/// joiner). The joiner shouldn't probe them serially — that would
/// stack the per-host timeout — so we kick off every probe at the
/// same moment and resolve as soon as one wins.
///
/// Order in the [hosts] iterable is preserved when ties happen
/// (parallel probes that all complete in the same microtask): the
/// first iteration index wins. In practice the network race
/// dominates, so the address that the network resolves first is the
/// one returned.
Future<String?> firstReachableLanAddress({
  required Iterable<String> hosts,
  required int port,
  Duration timeout = const Duration(seconds: 3),
  int retries = 3,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  final hostList = hosts.toList(growable: false);
  if (hostList.isEmpty) return null;
  final completer = Completer<String?>();
  var pending = hostList.length;
  for (final host in hostList) {
    // Don't await here — we want all probes in flight at once.
    unawaited(
      isLanReachable(
        host: host,
        port: port,
        timeout: timeout,
        retries: retries,
        retryDelay: retryDelay,
      ).then(
        (reachable) {
          if (completer.isCompleted) return;
          if (reachable) {
            completer.complete(host);
            return;
          }
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        },
        onError: (Object _) {
          if (completer.isCompleted) return;
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        },
      ),
    );
  }
  return completer.future;
}

Future<bool> _tryConnectOnce({
  required String host,
  required int port,
  required Duration timeout,
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
