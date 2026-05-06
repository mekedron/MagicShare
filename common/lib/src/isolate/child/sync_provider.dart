import 'package:common/model/device_info_result.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/stored_security_context.dart';
import 'package:common/src/isolate/child/http_provider.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:refena/refena.dart';

part 'sync_provider.mapper.dart';

/// Represents the state that is synchronized from the main isolate to the child isolate.
/// In other words, the main isolate sends this state to the child isolate.
@MappableClass()
class SyncState with SyncStateMappable {
  final Future<void> Function() init;
  final Object rootIsolateToken;
  final CustomHttpClient Function(Duration timeout, StoredSecurityContext) httpClientFactory;
  final StoredSecurityContext securityContext;
  final DeviceInfoResult deviceInfo;
  final String alias;

  /// Port the HTTP/HTTPS LocalSend server binds and announces over
  /// multicast as the address peers should connect to. May differ
  /// from [multicastPort] in dev setups where multiple instances
  /// share the host's loopback (e.g. macOS + iOS Simulator); the
  /// `LOCALSEND_PORT` dart-define lets each side bind a distinct
  /// HTTP port without breaking multicast interop.
  final int port;

  /// Port the multicast discovery socket binds + sends on. The well-
  /// known LocalSend value (53317) by default — kept stable across a
  /// dev setup so every co-located instance receives every other
  /// instance's announces (multicast packets are addressed to
  /// `<group>:<port>`, so a listener bound to a different port
  /// silently misses everything). The HTTP port travels in the
  /// announce DTO itself, so receivers still know how to reach the
  /// sender's HTTP listener even when the two ports differ.
  final int multicastPort;

  final List<String>? networkWhitelist;
  final List<String>? networkBlacklist;
  final ProtocolType protocol;
  final String multicastGroup;
  final int discoveryTimeout;

  final bool serverRunning;
  final bool download;

  /// LAN IPs this host owns. Used by the multicast listener to detect
  /// "loopback" announces — packets that left a co-located runtime
  /// (Android emulator behind qemu user-mode NAT, iOS Simulator on
  /// the host loopback) and arrive back on our wire with their source
  /// IP rewritten to one of our own. Empty in production. Populated
  /// in dev by the app pushing fresh `localIpProvider` values via
  /// `UpdateSyncStateAction`.
  final Set<String> ownLocalIps;

  /// Dev-only override: when an announce is detected as a loopback
  /// (source IP ∈ [ownLocalIps]) the multicast listener rewrites
  /// `peer.ip` to [devLoopbackRewriteHost]. Port handling is
  /// port-aware — see `multicast_discovery.dart` for the rule.
  /// Both null in production.
  final String? devLoopbackRewriteHost;

  /// Dev-only override: forward port the host has wired to a
  /// co-located qemu emulator's well-known LocalSend port (default
  /// 53317) via `adb forward tcp:<this> tcp:53317`. Used when the
  /// loopback announce's port matches our own [multicastPort] —
  /// that's the Android-emulator case. Null in production.
  final int? devLoopbackRewritePort;

  SyncState({
    required this.init,
    required this.rootIsolateToken,
    required this.httpClientFactory,
    required this.securityContext,
    required this.deviceInfo,
    required this.alias,
    required this.port,
    int? multicastPort,
    required this.networkWhitelist,
    required this.networkBlacklist,
    required this.protocol,
    required this.multicastGroup,
    required this.discoveryTimeout,
    required this.serverRunning,
    required this.download,
    Set<String>? ownLocalIps,
    this.devLoopbackRewriteHost,
    this.devLoopbackRewritePort,
  })  : multicastPort = multicastPort ?? port,
        ownLocalIps = ownLocalIps ?? const <String>{};

  @override
  String toString() {
    return 'SyncState(securityContext: <SecurityContext>, deviceInfo: $deviceInfo, alias: $alias, port: $port, multicastPort: $multicastPort, ownLocalIps: $ownLocalIps, devLoopbackRewriteHost: $devLoopbackRewriteHost, devLoopbackRewritePort: $devLoopbackRewritePort, networkWhitelist: $networkWhitelist, networkBlacklist: $networkBlacklist, protocol: $protocol, multicastGroup: $multicastGroup, discoveryTimeout: $discoveryTimeout, serverRunning: $serverRunning, download: $download)';
  }
}

@internal
final syncProvider = ReduxProvider<SyncService, SyncState>((ref) {
  throw 'Not initialized';
});

class SyncService extends ReduxNotifier<SyncState> {
  final SyncState initial;

  SyncService({
    required this.initial,
  });

  @override
  SyncState init() => initial;
}

class UpdateSyncStateAction extends ReduxAction<SyncService, SyncState> {
  final SyncState newState;

  UpdateSyncStateAction(this.newState);

  @override
  SyncState reduce() {
    return newState;
  }
}
