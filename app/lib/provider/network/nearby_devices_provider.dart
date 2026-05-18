import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/model/persistence/favorite_device.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';
import 'package:magicshare_app/provider/favorites_provider.dart';
import 'package:magicshare_app/provider/logging/discovery_logs_provider.dart';
import 'package:magicshare_app/provider/network/send_provider.dart';
import 'package:magicshare_app/provider/network/server/server_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('NearbyDevices');

/// Number of consecutive failed probes before [ProbeAndPruneKnownDevicesAction]
/// evicts a device. A single timeout is not enough — iOS HTTPS first-byte can
/// be slow when the peer's uplink is saturated by an ongoing upload, and a
/// transient Wi-Fi blip should not nuke a working entry.
const _kMaxConsecutiveProbeFailures = 3;

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
    httpsReader: () => ref.read(settingsProvider).https,
    activeIpsReader: () => _readActiveSessionIps(ref),
  );
});

/// IPs of peers currently in an outbound send or inbound receive that's still
/// in flight. A peer's uplink can be saturated mid-transfer, causing /info to
/// time out — but it is still very much reachable. Skipping these in
/// [ProbeAndPruneKnownDevicesAction] prevents the active partner from being
/// evicted out from under the user's own transfer.
Set<String> _readActiveSessionIps(Ref ref) {
  final result = <String>{};
  for (final session in ref.read(sendProvider).values) {
    if (_isActiveSession(session.status)) {
      final ip = session.target.firstHttpEndpoint?.ip;
      if (ip != null && ip.isNotEmpty) result.add(ip);
    }
  }
  final receive = ref.read(serverProvider)?.session;
  if (receive != null && _isActiveSession(receive.status)) {
    final ip = receive.sender.firstHttpEndpoint?.ip;
    if (ip != null && ip.isNotEmpty) result.add(ip);
  }
  return result;
}

bool _isActiveSession(SessionStatus status) {
  return status == SessionStatus.waiting || status == SessionStatus.sending;
}

class NearbyDevicesService extends ReduxNotifier<NearbyDevicesState> {
  final IsolateController _isolateController;
  final FavoritesService _favoriteService;
  final DiscoveryLogger _discoveryLogger;
  final bool Function() _httpsReader;
  final Set<String> Function() _activeIpsReader;

  /// Per-IP count of consecutive failed probes since the last successful
  /// probe. Reset when a probe succeeds; entries are removed when the IP is
  /// evicted. Kept off the public [NearbyDevicesState] because consumers
  /// don't need to rebuild on transient counter changes.
  final Map<String, int> _consecutiveProbeFailures = {};

  NearbyDevicesService({
    required IsolateController isolateController,
    required FavoritesService favoriteService,
    required DiscoveryLogger discoveryLogs,
    required bool Function() httpsReader,
    required Set<String> Function() activeIpsReader,
  }) : _discoveryLogger = discoveryLogs,
       _isolateController = isolateController,
       _favoriteService = favoriteService,
       _httpsReader = httpsReader,
       _activeIpsReader = activeIpsReader;

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

/// Long-lived background poller. On every [kNearbyDevicesPollInterval]
/// tick: re-announces over multicast (so peers respond and refresh
/// their entries) and probe-prunes existing LAN HTTP entries (so
/// peers that have left the network or backgrounded their app fall
/// off automatically without the user having to tap refresh).
///
/// Runs serially: each cycle awaits the probe round before sleeping,
/// so cycles never overlap regardless of how long an HTTP timeout
/// takes on a dead IP. Errors inside a cycle are logged and the loop
/// continues — we never want a transient failure to silently kill
/// the freshness guarantee.
class StartNearbyDevicesPoller extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  Future<NearbyDevicesState> reduce() async {
    while (true) {
      try {
        dispatch(StartMulticastScan());
        await dispatchAsync(
          ProbeAndPruneKnownDevicesAction(https: notifier._httpsReader()),
        );
      } catch (e, st) {
        _logger.warning('Nearby-devices poll cycle failed', e, st);
      }
      await Future<void>.delayed(kNearbyDevicesPollInterval);
    }
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
///
/// [localIdentities] holds the `signalingId` and `serverToken` values of the
/// connections this client has opened against the same signaling server.
/// Any incoming device whose endpoint matches one of those values is the
/// local device looping back through the server's room and is dropped —
/// equivalent to the cert-hash self-filter the LAN multicast path performs.
class RegisterSignalingDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;
  final Set<String> localIdentities;

  RegisterSignalingDeviceAction(
    this.device, {
    this.localIdentities = const <String>{},
  });

  @override
  NearbyDevicesState reduce() {
    final endpoint = device.firstSignalingEndpoint;
    if (endpoint == null) {
      _logger.warning('RegisterSignalingDeviceAction: skipping device without SignalingEndpoint: ${device.alias}');
      return state;
    }
    final token = endpoint.serverToken;
    final signalingId = endpoint.signalingId;
    if (localIdentities.contains(signalingId) || localIdentities.contains(token)) {
      _logger.fine(
        'Register: SIGNALING ${device.alias} dropped (matches local identity)',
      );
      return state;
    }
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

/// How often the background poller (see [StartNearbyDevicesPoller])
/// re-announces over multicast and probes every known LAN HTTP entry.
///
/// The poll loop is *serial* — each cycle awaits its probe round
/// before sleeping, so cycles can never overlap regardless of probe
/// duration. A peer that drops off the network (app backgrounded,
/// Wi-Fi toggled) is evicted within ~probe_duration + this delay.
/// Two seconds gives ~2-5 s real-world freshness without flooding
/// the LAN.
const Duration kNearbyDevicesPollInterval = Duration(seconds: 2);

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
    // Step 1: figure out which peers we should NOT probe right now.
    //
    // A peer that is currently the target of an outgoing send (or the source
    // of an active receive) has its uplink saturated by the transfer itself.
    // Its /info handler is still alive — it just can't get a packet in
    // edgewise behind the upload window. Probing it would consistently time
    // out and the prune step would then yank the LAN HTTP endpoint out from
    // under the very transfer in progress, dropping the device into
    // signaling-only / WebRTC mode mid-flight and breaking subsequent sends.
    final activeIps = notifier._activeIpsReader();

    final probeTargets = <(String, int)>[];
    final skippedIps = <String>{};
    for (final device in state.devices.values) {
      final endpoint = device.firstHttpEndpoint;
      if (endpoint == null || endpoint.ip.isEmpty) continue;
      if (activeIps.contains(endpoint.ip)) {
        skippedIps.add(endpoint.ip);
        // Reset the failure counter — an active session is positive evidence
        // the peer is up, even when /info wouldn't have made it through.
        notifier._consecutiveProbeFailures.remove(endpoint.ip);
        continue;
      }
      probeTargets.add((endpoint.ip, endpoint.port));
    }
    if (skippedIps.isNotEmpty) {
      _logger.fine('Probe-prune: skipping $skippedIps — active session in flight');
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

    // Step 2: tolerate transient probe failures. iOS HTTPS first-byte can
    // exceed the per-probe timeout when the peer is busy serving another
    // request; a single miss is not enough evidence to prune. Track
    // consecutive failures per IP and only evict after
    // [_kMaxConsecutiveProbeFailures] strikes in a row.
    final failedIps = probedIps.difference(seenIps);
    for (final ip in seenIps) {
      notifier._consecutiveProbeFailures.remove(ip);
    }
    final toRemove = <String>{};
    for (final ip in failedIps) {
      final count = (notifier._consecutiveProbeFailures[ip] ?? 0) + 1;
      if (count >= _kMaxConsecutiveProbeFailures) {
        toRemove.add(ip);
        notifier._consecutiveProbeFailures.remove(ip);
      } else {
        notifier._consecutiveProbeFailures[ip] = count;
        _logger.fine('Probe-prune: $ip missed probe ($count/$_kMaxConsecutiveProbeFailures) — keeping');
      }
    }
    if (toRemove.isEmpty) {
      _logger.fine('Probe-prune: every probed IP responded (or under failure threshold)');
      return state;
    }
    _logger.info('Probe-prune: removing stale entries for $toRemove (exceeded $_kMaxConsecutiveProbeFailures consecutive misses)');
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
