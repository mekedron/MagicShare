import 'package:common/model/device.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:logging/logging.dart';

part 'nearby_devices_state.mapper.dart';

final _logger = Logger('NearbyDevicesState');

@MappableClass()
class NearbyDevicesState with NearbyDevicesStateMappable {
  final bool runningFavoriteScan;
  final Set<String> runningIps; // list of local ips
  final Map<String, Device> devices; // ip -> device

  /// Devices that are discovered via signaling server.
  /// The key is the [SignalingEndpoint.serverToken] of the device.
  /// We do not trust the token, so we allow multiple devices that
  /// share one (different signalingIds within the set).
  final Map<String, Set<Device>> signalingDevices;

  const NearbyDevicesState({
    required this.runningFavoriteScan,
    required this.runningIps,
    required this.devices,
    required this.signalingDevices,
  });

  /// Single deduplicated view of every device known via either the LAN
  /// HTTP discovery channel or the WebRTC signaling channel.
  ///
  /// Two-pass merge:
  /// 1. **LAN multi-homed collapse.** `state.devices` is keyed by IP,
  ///    so a single physical device announced from multiple network
  ///    interfaces (WiFi en0 + Ethernet en1, or AirDrop awdl0 on
  ///    macOS) appears as multiple entries. Collapse same-cert-hash
  ///    entries by unioning their `HttpEndpoint`s into one Device —
  ///    otherwise each interface produces a duplicate tile.
  /// 2. **Signaling merge.** WebRTC signaling produces a different
  ///    identifier value space (server-minted token, not cert hash),
  ///    so cert-hash dedup doesn't apply to it. Fall back to the
  ///    user-visible identity tuple `(alias, deviceModel,
  ///    deviceType)`, which both channels announce identically for
  ///    the same device. This collapses the "iPhone shows up twice
  ///    — once labeled `LAN • HTTP`, once labeled `WebRTC`" surface.
  Map<String, Device> get allDevices {
    final result = <String, Device>{};

    // Pass 1: LAN multi-homed collapse.
    for (final device in devices.values) {
      final existingKey = _findCertHashMatch(result, device);
      if (existingKey != null) {
        _logger.fine(
          'LAN multi-homed collapse: ${device.alias} '
          'IPs=${device.httpEndpoints.map((e) => e.ip).toList()} '
          'certs=${device.certHashes} into existing key=$existingKey',
        );
        result[existingKey] = result[existingKey]!.merge(device);
        continue;
      }
      final key = _stableLanKey(device);
      if (key.isEmpty) {
        _logger.fine('Skipping LAN device with no usable key: ${device.alias}');
        continue;
      }
      result[key] = device;
    }

    // Pass 2: signaling merge.
    for (final group in signalingDevices.values) {
      for (final signaling in group) {
        final existingKey = _findCertHashMatch(result, signaling) ?? _findIdentityMatch(result, signaling);
        if (existingKey != null) {
          _logger.fine(
            'Signaling merge: ${signaling.alias} '
            'token=${signaling.firstSignalingEndpoint?.serverToken} '
            'into existing key=$existingKey',
          );
          result[existingKey] = result[existingKey]!.merge(signaling);
        } else {
          // Key signaling-only entries by their first serverToken.
          // Empty fallback shouldn't happen — signaling discovery
          // always produces a non-empty SignalingEndpoint — but we
          // guard anyway so a malformed input can't poison the map.
          final token = signaling.firstSignalingEndpoint?.serverToken ?? '';
          if (token.isEmpty) {
            _logger.fine('Skipping signaling device with empty serverToken: ${signaling.alias}');
            continue;
          }
          _logger.fine(
            'Signaling-only entry: ${signaling.alias} key=$token',
          );
          result[token] = signaling;
        }
      }
    }

    return result;
  }
}

/// Stable map key for an LAN-discovered Device. Prefers the cert hash
/// (cross-channel identity, supports dedup of multi-homed entries);
/// falls back to the first IP (legacy / cert-less). Returns empty when
/// the Device has no usable HTTP endpoint.
String _stableLanKey(Device device) {
  final certHash = device.firstHttpEndpoint?.certHash;
  if (certHash != null && certHash.isNotEmpty) return certHash;
  return device.firstHttpEndpoint?.ip ?? '';
}

/// Try to find an existing entry that shares a cert hash with [candidate].
/// Cert hashes only — never matched against signaling tokens.
String? _findCertHashMatch(Map<String, Device> map, Device candidate) {
  final candidateHashes = candidate.certHashes;
  if (candidateHashes.isEmpty) return null;
  for (final entry in map.entries) {
    final entryHashes = entry.value.certHashes;
    if (entryHashes.isEmpty) continue;
    if (entryHashes.any(candidateHashes.contains)) return entry.key;
  }
  return null;
}

String? _findIdentityMatch(Map<String, Device> map, Device candidate) {
  // Empty alias would over-merge across unrelated devices that
  // haven't announced one yet, so don't attempt the fallback.
  if (candidate.alias.isEmpty) return null;
  for (final entry in map.entries) {
    final existing = entry.value;
    if (existing.alias == candidate.alias && existing.deviceModel == candidate.deviceModel && existing.deviceType == candidate.deviceType) {
      return entry.key;
    }
  }
  return null;
}

/// Lossless union: returns a [Device] carrying the endpoints and
/// discovery methods of both [a] and [b]. Identity fields (alias,
/// deviceModel, etc.) are taken from [a] — callers control which side
/// "wins" for those by ordering.
extension DeviceMergeExt on Device {
  Device merge(Device other) {
    return Device(
      version: version,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: download,
      endpoints: {
        ...endpoints,
        ...other.endpoints,
      },
      discoveryMethods: {
        ...discoveryMethods,
        ...other.discoveryMethods,
      },
    );
  }
}
