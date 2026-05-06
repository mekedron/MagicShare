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
    lastSeenAt: {},
    signalingDevices: {},
  );
}

/// TTL for an IP-keyed entry in [NearbyDevicesState.devices]. A peer
/// that has not announced itself, responded to a scan, or hit our HTTP
/// register endpoint within this window is considered stale and pruned
/// by [PruneStaleDevicesAction]. Sized at three times the foreground
/// re-announce period (20 s) so two consecutive dropped multicast
/// packets don't flap the device offline.
const Duration kLanDeviceTtl = Duration(seconds: 60);

/// Binds the UDP port and listens for incoming announcements.
/// This should run forever as long as the app is running.
class StartMulticastListener extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  Future<NearbyDevicesState> reduce() async {
    await for (final event in notifier._isolateController.state.multicastDiscovery!.receiveFromIsolate) {
      switch (event) {
        case MulticastDiscovered(:final device):
          _logger.info('[presence:lan-recv] discovered ip=${device.ip} fp=${_short(device.fingerprint)} alias=${device.alias}');
          await dispatchAsync(RegisterDeviceAction(device));
          notifier._discoveryLogger.addLog('[DISCOVER/UDP] ${device.alias} (${device.ip}, model: ${device.deviceModel})');
        case MulticastGoodbye(:final fingerprint):
          _logger.info('[presence:lan-recv] goodbye fp=${_short(fingerprint)}');
          dispatch(UnregisterDeviceAction(fingerprint));
          notifier._discoveryLogger.addLog('[DISCOVER/UDP] goodbye fingerprint=$fingerprint');
      }
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
      lastSeenAt: {},
    );
  }
}

/// Drops devices whose [NearbyDevicesState.lastSeenAt] is older than
/// [kLanDeviceTtl]. Runs on the lifecycle prune timer in main.dart and
/// is also a sensible no-op fallback when no entries are stale.
class PruneStaleDevicesAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  bool get trackOrigin => false;

  @override
  NearbyDevicesState reduce() {
    final now = DateTime.now();
    final keep = <String, Device>{};
    final keepSeen = <String, DateTime>{};
    state.devices.forEach((ip, device) {
      final seen = state.lastSeenAt[ip];
      if (seen != null && now.difference(seen) <= kLanDeviceTtl) {
        keep[ip] = device;
        keepSeen[ip] = seen;
      }
    });
    if (keep.length == state.devices.length) {
      // Fast path — nothing aged out, skip the rebuild. Keeps refena's
      // listeners from firing on every prune tick when the network is
      // quiet.
      _logger.fine('[presence:lan-prune] no-op kept=${keep.length}');
      return state;
    }
    final dropped = state.devices.length - keep.length;
    _logger.info('[presence:lan-prune] dropped=$dropped kept=${keep.length}');
    return state.copyWith(
      devices: keep,
      lastSeenAt: keepSeen,
    );
  }
}

/// Removes a device by fingerprint regardless of which IP it is keyed
/// under. Used by the multicast goodbye listener: a peer that hits
/// `paused` / `hidden` on mobile broadcasts a goodbye packet so its
/// row disappears immediately on receivers, ahead of [kLanDeviceTtl].
class UnregisterDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final String fingerprint;

  UnregisterDeviceAction(this.fingerprint);

  @override
  bool get trackOrigin => false;

  @override
  NearbyDevicesState reduce() {
    if (fingerprint.isEmpty) return state;
    final keep = <String, Device>{};
    final keepSeen = <String, DateTime>{};
    state.devices.forEach((ip, device) {
      if (device.fingerprint == fingerprint) return;
      keep[ip] = device;
      final seen = state.lastSeenAt[ip];
      if (seen != null) keepSeen[ip] = seen;
    });
    if (keep.length == state.devices.length) return state;
    _logger.info('[presence:lan-unregister] fp=${_short(fingerprint)} kept=${keep.length}');
    return state.copyWith(
      devices: keep,
      lastSeenAt: keepSeen,
    );
  }
}

/// Truncates a SHA-256 hex fingerprint for log readability. Leaves
/// enough characters to disambiguate while keeping log lines tight.
String _short(String fp) => fp.length <= 8 ? fp : fp.substring(0, 8);

/// Registers a device in the state.
/// It will override any existing device with the same IP.
class RegisterDeviceAction extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterDeviceAction(this.device);

  @override
  bool get trackOrigin => false;

  @override
  Future<NearbyDevicesState> reduce() async {
    assert(device.ip?.isNotEmpty ?? false, 'IP must not be empty');

    // Note: dev-mode loopback rewrite (qemu user-mode NAT / iOS
    // Simulator shared loopback) used to live here, but that ran
    // *after* `MulticastService._answerAnnouncement` had already
    // looped back to our own IP. The rewrite now happens upstream in
    // `multicast_discovery.dart` so both the auto-respond and this
    // registration see the same corrected address.

    final favoriteDevice = notifier._favoriteService.state.firstWhereOrNull((e) => e.fingerprint == device.fingerprint);
    if (favoriteDevice != null && !favoriteDevice.customAlias) {
      // Update existing favorite with new alias
      await external(notifier._favoriteService).dispatchAsync(UpdateFavoriteAction(favoriteDevice.copyWith(alias: device.alias)));
    } else {
      await Future.microtask(() {});
    }
    // The map is keyed by IP. When a peer's IP shifts — e.g. an
    // Android emulator hot-restarts and qemu's user-mode NAT picks a
    // different source IP for the new socket, or a real device
    // reconnects on a different network interface — the old IP-keyed
    // entry is stale and should be evicted before we add the new one.
    // Otherwise the same physical device shows up twice in the Send
    // tab (and the user's "after I hit Shift+R got a new copy of the
    // device in Nearby Devices" report). Dedup by fingerprint here.
    final next = <String, Device>{};
    final nextSeen = <String, DateTime>{};
    state.devices.forEach((ip, existing) {
      if (existing.fingerprint != device.fingerprint) {
        next[ip] = existing;
        final seen = state.lastSeenAt[ip];
        if (seen != null) nextSeen[ip] = seen;
      }
    });
    next[device.ip!] = device;
    nextSeen[device.ip!] = DateTime.now();
    _logger.info(
      '[presence:lan-register] ip=${device.ip} port=${device.port} '
      'fp=${_short(device.fingerprint)} alias=${device.alias} '
      'totalDevices=${next.length}',
    );
    return state.copyWith(devices: next, lastSeenAt: nextSeen);
  }
}

/// Registers a new device found via signaling.
class RegisterSignalingDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterSignalingDeviceAction(this.device);

  @override
  NearbyDevicesState reduce() {
    final Set<Device> existingDevices = state.signalingDevices[device.fingerprint]?.toSet() ?? {};
    final existingDevice = existingDevices.firstWhereOrNull((e) => e.signalingId == device.signalingId);
    if (existingDevice != null) {
      existingDevices.remove(existingDevice);
    }
    existingDevices.add(device);

    return state.copyWith(
      signalingDevices: {
        ...state.signalingDevices,
        device.fingerprint: existingDevices,
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
        for (final entry in state.signalingDevices.entries) entry.key: entry.value.where((e) => e.signalingId != signalingId).toSet(),
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
      notifier._discoveryLogger.addLog('[DISCOVER/TCP] ${device.alias} (${device.ip}, model: ${device.deviceModel})');
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
      notifier._discoveryLogger.addLog('[DISCOVER/TCP] ${device.alias} (${device.ip}, model: ${device.deviceModel})');
      await dispatchAsync(RegisterDeviceAction(device));
    }

    return state.copyWith(
      runningFavoriteScan: false,
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
