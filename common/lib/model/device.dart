import 'package:dart_mappable/dart_mappable.dart';

part 'device.mapper.dart';

@MappableEnum(defaultValue: DeviceType.desktop)
enum DeviceType {
  mobile,
  desktop,
  web,
  headless,
  server,
}

/// How we *learned* about a device. Distinct from how we can *reach*
/// it (see [DeviceEndpoint]). Drives the discovery-log markers
/// (`[DISCOVER/UDP]` vs `[DISCOVER/TCP]`) and lets the UI tell apart
/// passively-announced devices from manually-entered or scanned ones.
@MappableClass()
sealed class DiscoveryMethod with DiscoveryMethodMappable {
  const DiscoveryMethod();
}

@MappableClass()
class MulticastDiscovery extends DiscoveryMethod with MulticastDiscoveryMappable {
  const MulticastDiscovery();
}

@MappableClass()
class HttpDiscovery extends DiscoveryMethod with HttpDiscoveryMappable {
  final String ip;

  const HttpDiscovery({required this.ip});
}

@MappableClass()
class SignalingDiscovery extends DiscoveryMethod with SignalingDiscoveryMappable {
  final String signalingServer;

  const SignalingDiscovery({required this.signalingServer});
}

/// A way to reach a device. A single [Device] can carry multiple
/// endpoints simultaneously — e.g. discovered via LAN multicast HTTP
/// AND via the WebRTC signaling server. Merging two devices unions
/// their endpoints so neither side's connectivity info is lost.
///
/// Endpoint subtypes intentionally use *different* identifier field
/// names (`certHash` vs `serverToken`) — the LocalSend HTTPS cert
/// hash and the signaling-server-minted token live in distinct value
/// spaces and must never be compared for equality. Folding them under
/// a generic `fingerprint` getter is the abstraction that hid the
/// original two-tile-after-merge bug; we deliberately do NOT provide
/// one.
@MappableClass()
sealed class DeviceEndpoint with DeviceEndpointMappable {
  const DeviceEndpoint();
}

/// LAN HTTP / multicast endpoint. Reachable directly by HTTP(S) on
/// `ip:port`. Carries the LocalSend cert hash — the cross-channel
/// identity persisted in favorites and the cloud device-group
/// registry.
@MappableClass()
class HttpEndpoint extends DeviceEndpoint with HttpEndpointMappable {
  final String ip;
  final int port;
  final bool https;

  /// LocalSend HTTPS cert SHA-256 (hex). Stable per device install.
  /// Compare with `CloudDevice.fingerprint` and
  /// `FavoriteDevice.fingerprint`. Never compare against a
  /// [SignalingEndpoint.serverToken].
  final String certHash;

  const HttpEndpoint({
    required this.ip,
    required this.port,
    required this.https,
    required this.certHash,
  });
}

/// WebRTC signaling endpoint. Reached by relaying through the
/// `signalingServer` WebSocket and addressing the peer by
/// `signalingId`.
@MappableClass()
class SignalingEndpoint extends DeviceEndpoint with SignalingEndpointMappable {
  final String signalingId;
  final String signalingServer;

  /// Token minted by the signaling server. Per-server, distinct
  /// value space from cert hash. Used as a dedup key within the
  /// signaling channel only — never persisted, never compared
  /// against a cert hash.
  final String serverToken;

  const SignalingEndpoint({
    required this.signalingId,
    required this.signalingServer,
    required this.serverToken,
  });
}

enum TransmissionMethod {
  http('HTTP'),
  webrtc('WebRTC');

  final String label;

  const TransmissionMethod(this.label);
}

/// Internal device model.
/// It gets not serialized.
@MappableClass()
class Device with DeviceMappable {
  final String version;
  final String alias;
  final String? deviceModel;
  final DeviceType deviceType;
  final bool download;

  /// Every connectivity record the device has announced across all
  /// channels. Unioned losslessly when two device instances merge
  /// (see `Device.merge`).
  final Set<DeviceEndpoint> endpoints;

  /// How we learned about this device. Separate axis from how we can
  /// reach it ([endpoints]) — kept for discovery telemetry and so the
  /// UI can distinguish passively-announced from actively-scanned.
  final Set<DiscoveryMethod> discoveryMethods;

  Iterable<HttpEndpoint> get httpEndpoints => endpoints.whereType<HttpEndpoint>();

  Iterable<SignalingEndpoint> get signalingEndpoints => endpoints.whereType<SignalingEndpoint>();

  HttpEndpoint? get firstHttpEndpoint => httpEndpoints.firstOrNull;

  SignalingEndpoint? get firstSignalingEndpoint => signalingEndpoints.firstOrNull;

  bool get hasHttpEndpoint => httpEndpoints.isNotEmpty;

  bool get hasSignalingEndpoint => signalingEndpoints.isNotEmpty;

  bool get hasAnyEndpoint => endpoints.isNotEmpty;

  /// Every cert hash this device announces across HTTP endpoints.
  /// Use only for cert-hash space lookups (cloud join, favorite match);
  /// signaling tokens live in a different value space and are NOT
  /// included.
  Set<String> get certHashes => httpEndpoints.map((e) => e.certHash).toSet();

  Set<TransmissionMethod> get transmissionMethods {
    final result = <TransmissionMethod>{};
    if (hasHttpEndpoint) result.add(TransmissionMethod.http);
    if (hasSignalingEndpoint) result.add(TransmissionMethod.webrtc);
    return result;
  }

  const Device({
    required this.version,
    required this.alias,
    required this.deviceModel,
    required this.deviceType,
    required this.download,
    required this.endpoints,
    required this.discoveryMethods,
  });

  static const empty = Device(
    version: '',
    alias: '',
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    endpoints: {},
    discoveryMethods: {},
  );
}
