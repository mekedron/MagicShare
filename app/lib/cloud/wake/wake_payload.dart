import 'package:dart_mappable/dart_mappable.dart';

part 'wake_payload.mapper.dart';

/// Plaintext shape of a wake-notification payload before it is encrypted
/// with the device-group key and base64-encoded for `sendWake`.
///
/// The receiver decrypts the blob, registers the [sessionNonce] in its
/// short-lived expected-nonce map (Epic 13) and auto-accepts the
/// upcoming `prepareUpload` request that carries a matching
/// `wakeSessionId`. [sourceFingerprint] is informational — it lets the
/// receiver double-check that the sender claims the same identity it
/// will later present on the LAN handshake. [initiatedAtMs] is a coarse
/// replay-protection signal; the receiver may discard payloads older
/// than a few minutes.
@MappableClass()
class WakePayload with WakePayloadMappable {
  final String sessionNonce;
  final String sourceFingerprint;
  final int initiatedAtMs;

  const WakePayload({
    required this.sessionNonce,
    required this.sourceFingerprint,
    required this.initiatedAtMs,
  });

  static const fromJson = WakePayloadMapper.fromJson;
}
