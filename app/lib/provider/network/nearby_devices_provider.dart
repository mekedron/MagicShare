import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/model/persistence/favorite_device.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';
import 'package:magicshare_app/provider/favorites_provider.dart';
import 'package:magicshare_app/provider/logging/discovery_logs_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('NearbyDevices');

/// This provider is responsible for:
/// - Scanning the network for other LocalSend instances
/// - Keeping track of all found devices (they are only stored in RAM)
///
/// Use [scanProvider] to have a high-level API to perform discovery operations.
final nearbyDevicesProvider = ReduxProvider<NearbyDevicesService, NearbyDevicesState>((ref) {
  return NearbyDevicesService(
    isolateController: ref.notifier(parentIsolateProvider),
    favoriteService: ref.notifier(favoritesProvider),
    discoveryLogs: ref.notifier(discoveryLoggerProvider),
  );
});

class NearbyDevicesService extends ReduxNotifier<NearbyDevicesState> {
  final IsolateController _isolateController;
  final FavoritesService _favoriteService;
  final DiscoveryLogger _discoveryLogger;

  NearbyDevicesService({
    required IsolateController isolateController,
    required FavoritesService favoriteService,
    required DiscoveryLogger discoveryLogs,
  }) : _discoveryLogger = discoveryLogs,
       _isolateController = isolateController,
       _favoriteService = favoriteService;

  @override
  NearbyDevicesState init() => const NearbyDevicesState(
    runningFavoriteScan: false,
    runningIps: {},
    devices: {},
    signalingDevices: {},
  );
}

/// Binds the UDP port and listens for incoming announcements.
/// This should run forever as long as the app is running.
class StartMulticastListener extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  Future<NearbyDevicesState> reduce() async {
    await for (final device in notifier._isolateController.state.multicastDiscovery!.receiveFromIsolate) {
      await dispatchAsync(RegisterDeviceAction(device));
      notifier._discoveryLogger.addLog('[DISCOVER/UDP] ${device.alias} (${device.firstHttpEndpoint?.ip}, model: ${device.deviceModel})');
    }
    return state;
  }
}

/// Removes all found devices from the state.
class ClearFoundDevicesAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      devices: {},
    );
  }
}

/// Registers a device in the state.
/// It will override any existing device with the same IP.
class RegisterDeviceAction extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterDeviceAction(this.device);

  @override
  bool get trackOrigin => false;

  @override
  Future<NearbyDevicesState> reduce() async {
    final endpoint = device.firstHttpEndpoint;
    assert(endpoint != null && endpoint.ip.isNotEmpty, 'HTTP endpoint with non-empty IP required');
    if (endpoint == null || endpoint.ip.isEmpty) {
      _logger.warning('RegisterDeviceAction: skipping device without HTTP endpoint: ${device.alias}');
      return state;
    }
    final certHashShort = endpoint.certHash.substring(0, endpoint.certHash.length.clamp(0, 8));
    final existing = state.devices[endpoint.ip];
    if (existing == null) {
      _logger.fine('Register: NEW LAN ${device.alias} ip=${endpoint.ip} cert=$certHashShort…');
    } else {
      final prevCert = existing.firstHttpEndpoint?.certHash ?? '';
      _logger.fine(
        'Register: UPDATE LAN ${device.alias} ip=${endpoint.ip} '
        'cert=$certHashShort… (was alias=${existing.alias}, '
        'cert=${prevCert.substring(0, prevCert.length.clamp(0, 8))}…)',
      );
    }
    final certHashes = device.certHashes;
    final favoriteDevice = notifier._favoriteService.state.firstWhereOrNull((e) => certHashes.contains(e.fingerprint));
    if (favoriteDevice != null && !favoriteDevice.customAlias) {
      // Update existing favorite with new alias
      await external(notifier._favoriteService).dispatchAsync(UpdateFavoriteAction(favoriteDevice.copyWith(alias: device.alias)));
    } else {
      await Future.microtask(() {});
    }
    return state.copyWith(
      devices: {...state.devices}..update(endpoint.ip, (_) => device, ifAbsent: () => device),
    );
  }
}

/// Registers a new device found via signaling.
class RegisterSignalingDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterSignalingDeviceAction(this.device);

  @override
  NearbyDevicesState reduce() {
    final endpoint = device.firstSignalingEndpoint;
    if (endpoint == null) {
      _logger.warning('RegisterSignalingDeviceAction: skipping device without SignalingEndpoint: ${device.alias}');
      return state;
    }
    final token = endpoint.serverToken;
    final signalingId = endpoint.signalingId;
    final tokenShort = token.substring(0, token.length.clamp(0, 8));
    _logger.fine(
      'Register: SIGNALING ${device.alias} sigId=$signalingId tok=$tokenShort…',
    );
    final Set<Device> existingDevices = state.signalingDevices[token]?.toSet() ?? {};
    final existingDevice = existingDevices.firstWhereOrNull(
      (e) => e.signalingEndpoints.any((sig) => sig.signalingId == signalingId),
    );
    if (existingDevice != null) {
      existingDevices.remove(existingDevice);
    }
    existingDevices.add(device);

    return state.copyWith(
      signalingDevices: {
        ...state.signalingDevices,
        token: existingDevices,
      },
    );
  }
}

class UnregisterSignalingDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final String signalingId;

  UnregisterSignalingDeviceAction(this.signalingId);

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      signalingDevices: {
        for (final entry in state.signalingDevices.entries)
          entry.key: entry.value.where((e) => e.signalingEndpoints.every((sig) => sig.signalingId != signalingId)).toSet(),
      },
    );
  }
}

/// It does not really "scan".
/// It just sends an announcement which will cause a response on every other LocalSend member of the network.
class StartMulticastScan extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  NearbyDevicesState reduce() {
    external(notifier._isolateController).dispatch(IsolateSendMulticastAnnouncementAction());
    return state;
  }
}

/// Scans one particular subnet with traditional HTTP/TCP discovery.
/// This method awaits until the scan is finished.
class StartLegacyScan extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final int port;
  final String localIp;
  final bool https;

  StartLegacyScan({
    required this.port,
    required this.localIp,
    required this.https,
  });

  @override
  Future<NearbyDevicesState> reduce() async {
    if (state.runningIps.contains(localIp)) {
      // already running for the same localIp
      await Future.microtask(() {});
      return state;
    }

    dispatch(_SetRunningIpsAction({...state.runningIps, localIp}));

    final stream = external(notifier._isolateController).dispatchTakeResult(
      IsolateInterfaceHttpDiscoveryAction(
        networkInterface: localIp,
        port: port,
        https: https,
      ),
    );

    await for (final device in stream) {
      notifier._discoveryLogger.addLog('[DISCOVER/TCP] ${device.alias} (${device.firstHttpEndpoint?.ip}, model: ${device.deviceModel})');
      await dispatchAsync(RegisterDeviceAction(device));
    }

    return state.copyWith(
      runningIps: state.runningIps.where((ip) => ip != localIp).toSet(),
    );
  }
}

class StartFavoriteScan extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final List<FavoriteDevice> devices;
  final bool https;

  StartFavoriteScan({
    required this.devices,
    required this.https,
  });

  @override
  Future<NearbyDevicesState> reduce() async {
    if (devices.isEmpty) {
      return state;
    }
    dispatch(_SetRunningFavoriteScanAction(true));

    final stream = external(notifier._isolateController).dispatchTakeResult(
      IsolateFavoriteHttpDiscoveryAction(
        favorites: devices.map((e) => (e.ip, e.port)).toList(),
        https: https,
      ),
    );

    await for (final device in stream) {
      notifier._discoveryLogger.addLog('[DISCOVER/TCP] ${device.alias} (${device.firstHttpEndpoint?.ip}, model: ${device.deviceModel})');
      await dispatchAsync(RegisterDeviceAction(device));
    }

    return state.copyWith(
      runningFavoriteScan: false,
    );
  }
}

/// Probes /info on every currently-known LAN HTTP device and removes
/// entries that don't respond. Use after a user-triggered refresh:
/// the receiver no longer answers when the peer's app is backgrounded
/// or has left the network, but the multicast/HTTP entry stays in
/// `state.devices` indefinitely otherwise — leading to "online" tiles
/// for unreachable peers and crashing transfer attempts with a raw
/// reqwest connection error.
///
/// Does NOT touch `signalingDevices` — the signaling server emits its
/// own Left messages when a peer disconnects, so that side
/// self-cleans. This action is targeted only at the LAN HTTP map.
class ProbeAndPruneKnownDevicesAction extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final bool https;

  ProbeAndPruneKnownDevicesAction({required this.https});

  @override
  bool get trackOrigin => false;

  @override
  Future<NearbyDevicesState> reduce() async {
    final probeTargets = <(String, int)>[];
    for (final device in state.devices.values) {
      final endpoint = device.firstHttpEndpoint;
      if (endpoint == null || endpoint.ip.isEmpty) continue;
      probeTargets.add((endpoint.ip, endpoint.port));
    }
    if (probeTargets.isEmpty) {
      return state;
    }
    final probedIps = probeTargets.map((t) => t.$1).toSet();
    _logger.fine('Probe-prune: probing ${probeTargets.length} known IPs');

    final stream = external(notifier._isolateController).dispatchTakeResult(
      IsolateFavoriteHttpDiscoveryAction(
        favorites: probeTargets,
        https: https,
      ),
    );

    final seenIps = <String>{};
    await for (final device in stream) {
      final endpoint = device.firstHttpEndpoint;
      if (endpoint != null && endpoint.ip.isNotEmpty) {
        seenIps.add(endpoint.ip);
      }
      // Re-register to refresh the cached entry (alias / model may
      // have changed since the original announce).
      await dispatchAsync(RegisterDeviceAction(device));
    }

    final toRemove = probedIps.difference(seenIps);
    if (toRemove.isEmpty) {
      _logger.fine('Probe-prune: every probed IP responded; nothing to remove');
      return state;
    }
    _logger.info('Probe-prune: removing stale entries for $toRemove');
    return state.copyWith(
      devices: {...state.devices}..removeWhere((ip, _) => toRemove.contains(ip)),
    );
  }
}

class _SetRunningIpsAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Set<String> runningIps;

  _SetRunningIpsAction(this.runningIps);

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      runningIps: runningIps,
    );
  }
}

class _SetRunningFavoriteScanAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final bool running;

  _SetRunningFavoriteScanAction(this.running);

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      runningFavoriteScan: running,
    );
  }
}
