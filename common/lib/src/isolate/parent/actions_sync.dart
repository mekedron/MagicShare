import 'package:common/model/device_info_result.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/stored_security_context.dart';
import 'package:common/src/isolate/child/sync_provider.dart';
import 'package:common/src/isolate/dto/send_to_isolate_data.dart';
import 'package:common/src/isolate/parent/parent_isolate_provider.dart';
import 'package:refena/refena.dart';

/// Publishes the new security context to all child isolates.
class IsolateSyncSecurityContextAction extends ReduxAction<IsolateController, ParentIsolateState> {
  final StoredSecurityContext securityContext;

  IsolateSyncSecurityContextAction({
    required this.securityContext,
  });

  @override
  ParentIsolateState reduce() {
    dispatch(_PublishSyncStateAction(
      syncState: state.syncState.copyWith(
        securityContext: securityContext,
      ),
    ));
    return state;
  }
}

/// Publishes the new device info to all child isolates.
class IsolateSyncDeviceInfoAction extends ReduxAction<IsolateController, ParentIsolateState> {
  final DeviceInfoResult deviceInfo;

  IsolateSyncDeviceInfoAction({
    required this.deviceInfo,
  });

  @override
  ParentIsolateState reduce() {
    dispatch(_PublishSyncStateAction(
      syncState: state.syncState.copyWith(
        deviceInfo: deviceInfo,
      ),
    ));
    return state;
  }
}

class IsolateSyncSettingsAction extends ReduxAction<IsolateController, ParentIsolateState> {
  final List<String>? networkWhitelist;
  final List<String>? networkBlacklist;
  final String multicastGroup;
  final int discoveryTimeout;

  IsolateSyncSettingsAction({
    required this.networkWhitelist,
    required this.networkBlacklist,
    required this.multicastGroup,
    required this.discoveryTimeout,
  });

  @override
  ParentIsolateState reduce() {
    dispatch(_PublishSyncStateAction(
      syncState: state.syncState.copyWith(
        networkWhitelist: networkWhitelist,
        networkBlacklist: networkBlacklist,
        multicastGroup: multicastGroup,
        discoveryTimeout: discoveryTimeout,
      ),
    ));
    return state;
  }
}

/// Publishes the host's current LAN IPs to all child isolates so the
/// multicast listener can detect loopback announces (qemu user-mode
/// NAT and iOS Simulator both rewrite the source IP to one of these).
/// Only meaningful in the dev setup that sets DEV_EMULATOR_FORWARD_PORT;
/// in production the multicast listener doesn't act on this field.
class IsolateSyncLocalIpsAction extends ReduxAction<IsolateController, ParentIsolateState> {
  final Set<String> ownLocalIps;

  IsolateSyncLocalIpsAction({required this.ownLocalIps});

  @override
  ParentIsolateState reduce() {
    dispatch(_PublishSyncStateAction(
      syncState: state.syncState.copyWith(
        ownLocalIps: ownLocalIps,
      ),
    ));
    return state;
  }
}

class IsolateSyncServerStateAction extends ReduxAction<IsolateController, ParentIsolateState> {
  final String alias;
  final int port;
  final ProtocolType protocol;
  final bool serverRunning;
  final bool download;

  IsolateSyncServerStateAction({
    required this.alias,
    required this.port,
    required this.protocol,
    required this.serverRunning,
    required this.download,
  });

  @override
  ParentIsolateState reduce() {
    dispatch(_PublishSyncStateAction(
      syncState: state.syncState.copyWith(
        alias: alias,
        port: port,
        protocol: protocol,
        serverRunning: serverRunning,
        download: download,
      ),
    ));
    return state;
  }
}

/// Publishes the new [SyncState] to all child isolates.
class _PublishSyncStateAction extends ReduxAction<IsolateController, ParentIsolateState> {
  final SyncState syncState;

  _PublishSyncStateAction({
    required this.syncState,
  });

  @override
  ParentIsolateState reduce() {
    state.httpScanDiscovery?.sendToIsolate(SendToIsolateData(
      syncState: syncState,
      data: null,
    ));
    state.multicastDiscovery?.sendToIsolate(SendToIsolateData(
      syncState: syncState,
      data: null,
    ));

    return state.copyWith(
      syncState: syncState,
    );
  }
}
