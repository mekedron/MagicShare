import 'package:common/model/device.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'nearby_devices_state.mapper.dart';

@MappableClass()
class NearbyDevicesState with NearbyDevicesStateMappable {
  final bool runningFavoriteScan;
  final Set<String> runningIps; // list of local ips
  final Map<String, Device> devices; // ip -> device

  /// Wall-clock timestamp of the most recent multicast / register / scan
  /// signal we received per device, keyed identically to [devices] (by
  /// IP). Drives TTL-based pruning so a peer that goes silent — because
  /// it backgrounded, crashed, or lost the network — eventually
  /// disappears from the list. Lives in RAM only; never serialised over
  /// the wire (kept off [Device] to preserve stock-LocalSend
  /// compatibility).
  final Map<String, DateTime> lastSeenAt;

  /// Devices that are discovered via signaling server.
  /// The key is the fingerprint of the device.
  /// We do not trust the fingerprint, so we allow multiple devices with the same fingerprint.
  final Map<String, Set<Device>> signalingDevices;

  const NearbyDevicesState({
    required this.runningFavoriteScan,
    required this.runningIps,
    required this.devices,
    required this.lastSeenAt,
    required this.signalingDevices,
  });

  /// All devices we know about, deduplicated to a single entry per
  /// physical device regardless of which channel observed them.
  ///
  /// Two distinct dedup problems converge here, both surfaced by the
  /// hot-restart "duplicate copy of the device shows up in Nearby
  /// Devices" report:
  ///
  /// 1. **Mixed-key bug.** [devices] is keyed by IP (multicast /
  ///    HTTP-register) and [signalingDevices] is keyed by fingerprint,
  ///    so the old getter — which `addAll`'d the IP-keyed map and then
  ///    wrote the signaling entries under fingerprint keys — produced
  ///    two map entries for one device whenever both channels had
  ///    observed it.
  /// 2. **Cross-channel fingerprint drift.** The WebRTC signaling
  ///    handshake generates a fresh keypair on every connection
  ///    (signaling_provider.dart marks this with a TODO), so the
  ///    `token` the signaling server hands us as the peer's fingerprint
  ///    is *different* from the LocalSend cert hash that the multicast
  ///    announce carries. After a hot-restart the *new* signaling
  ///    fingerprint also differs from the *old* signaling fingerprint
  ///    — and until the signaling server's `Left` event arrives the
  ///    receiver has both stale and fresh signaling entries. None of
  ///    those share a fingerprint with the multicast entry, so a pure
  ///    fingerprint-keyed dedup leaves them all visible.
  ///
  /// The strategy: re-key everything by fingerprint, then collapse
  /// signaling-only fingerprints into a co-aliased multicast entry
  /// (preferring the LAN ip+port for the transport layer). When no
  /// alias-matched LAN entry exists the signaling entry stays under
  /// its own fingerprint key — that's the legitimate "WebRTC-only
  /// peer the user is talking to remotely" case.
  Map<String, Device> get allDevices {
    final byFingerprint = <String, Device>{};
    for (final device in devices.values) {
      if (device.fingerprint.isEmpty) continue;
      byFingerprint[device.fingerprint] = device;
    }
    for (final group in signalingDevices.values) {
      for (final candidate in group) {
        if (candidate.fingerprint.isEmpty) continue;
        final fingerprintMatch = byFingerprint[candidate.fingerprint];
        if (fingerprintMatch != null) {
          if (fingerprintMatch.alias == candidate.alias) {
            byFingerprint[candidate.fingerprint] = fingerprintMatch.merge(candidate);
          }
          // else: keep the LAN-side entry as-is; alias mismatch on the
          // same fingerprint is unexpected.
          continue;
        }
        // Fold signaling entries into a same-alias multicast / HTTP-
        // register entry under the LAN-side fingerprint, so we don't
        // render the same physical device twice when the signaling
        // token differs from the cert hash.
        String? aliasMatchKey;
        for (final entry in byFingerprint.entries) {
          if (entry.value.alias == candidate.alias) {
            aliasMatchKey = entry.key;
            break;
          }
        }
        if (aliasMatchKey != null) {
          byFingerprint[aliasMatchKey] = byFingerprint[aliasMatchKey]!.merge(candidate);
          continue;
        }
        byFingerprint[candidate.fingerprint] = candidate;
      }
    }
    return byFingerprint;
  }
}

extension on Device {
  Device merge(Device other) {
    return Device(
      signalingId: signalingId ?? other.signalingId,
      ip: ip ?? other.ip,
      version: version,
      port: port,
      https: https,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: download,
      discoveryMethods: {
        ...discoveryMethods,
        ...other.discoveryMethods,
      },
    );
  }
}
