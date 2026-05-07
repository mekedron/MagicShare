import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:magicshare_app/provider/security_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('MergeNetworkDevices');

/// Combined record for a single physical device the user can target from
/// the Send tab. Pure LAN peers (e.g. a stock LocalSend client) appear
/// with [cloud] == null; the user's own cloud-registered devices appear
/// with [cloud] != null and merge with their LAN twin (when present)
/// using the cert hash as the join key.
@immutable
class MergedDevice {
  /// The Device handed to the existing tile widgets. For LAN-known
  /// entries this is the multicast-announced device verbatim. For
  /// cloud-only entries it is synthesized from the [CloudDevice] fields
  /// so existing tile widgets render without a separate code path.
  final Device displayDevice;

  /// Non-null when this physical device is registered in the user's
  /// cloud device group.
  final CloudDevice? cloud;

  /// True when a LAN multicast announce currently exists for this
  /// device (i.e. we have an IP/port to reach it directly).
  final bool isLanReachable;

  const MergedDevice({
    required this.displayDevice,
    required this.cloud,
    required this.isLanReachable,
  });

  /// Whether the device is currently reachable on the local network.
  /// Same signal for cloud-known and pure-LAN peers — the user has no
  /// reason to see them differently.
  bool get isOnline => isLanReachable;

  /// True when only the cloud side knows this device — the sender must
  /// fire a wake notification and wait for the receiver to come online
  /// before a P2P transfer can complete.
  bool get isOfflineCloud => cloud != null && !isLanReachable;

  /// Stable id used by the Send tab for keys + Hero tags. Prefers the
  /// cert hash (cross-channel identity), falls back to the signaling
  /// token, then the cloud deviceId.
  String get stableId {
    final certHash = displayDevice.firstHttpEndpoint?.certHash;
    if (certHash != null && certHash.isNotEmpty) return certHash;
    final token = displayDevice.firstSignalingEndpoint?.serverToken;
    if (token != null && token.isNotEmpty) return token;
    return cloud?.deviceId ?? '';
  }
}

/// Merge LAN-discovered devices with cloud-registered devices. The
/// join key is the cert hash — cloud's `fingerprint` field is the
/// LocalSend HTTPS cert hash, and we look it up only against
/// `Device.certHashes` (HTTP endpoints). A signaling-only LAN device
/// whose `serverToken` happens to equal a cloud cert hash must NOT
/// false-merge — different value spaces.
///
/// [ownFingerprint] is this install's LocalSend cert hash. The
/// upstream multicast listener already filters out our own announces
/// in `multicast_discovery.dart` line 59, but on the Android emulator
/// the multicast loopback can let a self-announce slip through —
/// either as a duplicated packet or a re-emit from the qemu NAT
/// stack. Keep this as a defence-in-depth filter so the Send tab
/// never lists the user themselves regardless of upstream's behaviour.
@visibleForTesting
List<MergedDevice> mergeNetworkDevices({
  required Iterable<Device> lan,
  required Iterable<CloudDevice> cloud,
  required String? currentDeviceId,
  String? ownFingerprint,
  Iterable<String>? ownLocalIps,
}) {
  final ownIpSet = ownLocalIps == null ? const <String>{} : ownLocalIps.toSet();
  _logger.fine(
    'mergeNetworkDevices start: lan=${lan.length}, cloud=${cloud.length}, '
    'currentDeviceId=$currentDeviceId, ownFingerprint=${ownFingerprint?.substring(0, ownFingerprint.length.clamp(0, 8))}…, '
    'ownLocalIps=$ownIpSet',
  );
  // Indexed list: stable order + look-up by cert hash for the cloud
  // join. LAN devices that share an alias with cloud-only entries are
  // also fold-able via `_findAliasMatchIndex`.
  final entries = <MergedDevice>[];
  for (final lanDevice in lan) {
    final endpointSummary =
        '${lanDevice.alias} '
        'http=${lanDevice.httpEndpoints.map((e) => '${e.ip}:${e.port}/${e.certHash.substring(0, e.certHash.length.clamp(0, 8))}…').toList()} '
        'sig=${lanDevice.signalingEndpoints.map((e) => 'tok=${e.serverToken.substring(0, e.serverToken.length.clamp(0, 8))}…').toList()}';
    if (!lanDevice.hasAnyEndpoint) {
      _logger.fine('Skipping LAN device with no endpoints: $endpointSummary');
      continue;
    }
    if (ownFingerprint != null && ownFingerprint.isNotEmpty && lanDevice.certHashes.contains(ownFingerprint)) {
      // Defensive: drop a LAN announce carrying this install's own
      // cert hash (the Android-emulator multicast-loopback case).
      _logger.fine('Filter: dropping LAN $endpointSummary — own cert hash matches');
      continue;
    }
    final selfIpHits = lanDevice.httpEndpoints.where((e) => e.ip.isNotEmpty && ownIpSet.contains(e.ip)).map((e) => e.ip).toList();
    if (selfIpHits.isNotEmpty) {
      // Same machine — typically a stock LocalSend instance running
      // side-by-side with MagicShare on the same host. The user can't
      // actually transfer to itself, and seeing it in the receiver
      // list invites the "Null check operator used on a null value"
      // crash on tap.
      _logger.fine('Filter: dropping LAN $endpointSummary — own IP hit on $selfIpHits');
      continue;
    }
    _logger.fine('LAN entry added: $endpointSummary');
    entries.add(
      MergedDevice(
        displayDevice: lanDevice,
        cloud: null,
        isLanReachable: true,
      ),
    );
  }

  for (final cloudDevice in cloud) {
    if (cloudDevice.deviceId == currentDeviceId) {
      _logger.fine('Skipping cloud device ${cloudDevice.deviceId} — current device');
      continue;
    }
    // Stale-self guard: a cloud row whose `fingerprint` matches our
    // own cert hash is THIS device's older device-doc entry from a
    // previous session. The Firebase-emulator-restart scenario is
    // canonical: each session minted a fresh deviceId but the local
    // securityContext (cert hash) persisted, so the cloud collected
    // multiple device docs all carrying our own fingerprint. The
    // current row is filtered above by deviceId; the older rows
    // would otherwise render as separate "Offline / Wake" tiles for
    // ourselves. Drop them.
    if (ownFingerprint != null && ownFingerprint.isNotEmpty && cloudDevice.fingerprint == ownFingerprint) {
      _logger.fine(
        'Skipping cloud device ${cloudDevice.deviceId} — fingerprint matches own cert hash '
        '(stale self-row from previous session)',
      );
      continue;
    }
    final certHash = cloudDevice.fingerprint;
    final fpPreview = certHash == null ? 'null' : '${certHash.substring(0, certHash.length.clamp(0, 8))}…';
    final cloudSummary = 'cloud[${cloudDevice.deviceId}] name="${cloudDevice.displayName}" fp=$fpPreview';
    if (certHash != null && certHash.isNotEmpty) {
      final idx = entries.indexWhere(
        (e) => e.cloud == null && e.displayDevice.certHashes.contains(certHash),
      );
      if (idx != -1) {
        // The user explicitly chose the cloud-side display name and
        // icon in the device-group settings; the LAN-side `alias` is
        // just the auto-generated default the receiving LocalSend
        // instance announces. Cloud-side metadata wins; LAN keeps the
        // network reachability fields (endpoints).
        _logger.fine('Cert-hash match: folding $cloudSummary into LAN entry $idx (${entries[idx].displayDevice.alias})');
        final existing = entries[idx];
        entries[idx] = MergedDevice(
          displayDevice: existing.displayDevice.copyWith(
            alias: cloudDevice.displayName,
            deviceType: _mapCloudIconToDeviceType(cloudDevice.icon),
          ),
          cloud: cloudDevice,
          isLanReachable: true,
        );
        continue;
      }
    }
    // No cert-hash match. Before we synthesize a separate cloud-only
    // tile, look for an existing entry whose alias / display name lines
    // up — this catches:
    //   * stale cloud rows from a previous install that minted a fresh
    //     deviceId and never cleaned up the old row,
    //   * cloud rows whose `fingerprint` field is null because they
    //     pre-date the field being populated,
    //   * the hot-restart race where the cert hash hasn't yet
    //     propagated back to the cloud doc,
    //   * a signaling-only entry that has no cert hash to match
    //     against (cloud.fingerprint is the cert hash, the LAN entry
    //     only carries a serverToken).
    // Fold the cloud info into the existing tile rather than render
    // the same physical device twice. Prefer LAN-reachable matches.
    final aliasIdx = _findAliasMatchIndex(entries, cloudDevice.displayName);
    if (aliasIdx != -1) {
      _logger.fine('Alias match: folding $cloudSummary into LAN entry $aliasIdx (${entries[aliasIdx].displayDevice.alias})');
      final existing = entries[aliasIdx];
      entries[aliasIdx] = MergedDevice(
        displayDevice: existing.displayDevice.copyWith(
          alias: cloudDevice.displayName,
          deviceType: _mapCloudIconToDeviceType(cloudDevice.icon),
        ),
        cloud: cloudDevice,
        isLanReachable: existing.isLanReachable,
      );
      continue;
    }
    _logger.fine('No match: synthesizing cloud-only entry for $cloudSummary');
    entries.add(
      MergedDevice(
        displayDevice: _synthesizeDevice(cloudDevice),
        cloud: cloudDevice,
        isLanReachable: false,
      ),
    );
  }
  _logger.fine('mergeNetworkDevices end: ${entries.length} entries');
  return List.unmodifiable(entries);
}

int _findAliasMatchIndex(List<MergedDevice> entries, String alias) {
  if (alias.isEmpty) return -1;
  final needle = alias.trim().toLowerCase();
  if (needle.isEmpty) return -1;
  // Prefer a LAN-reachable match so the picked tile keeps a working
  // endpoint for direct transfer. Skip entries already bound to a
  // different cloud doc — folding twice would silently overwrite the
  // first cloud's metadata.
  int cloudOnlyMatch = -1;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry.cloud != null) continue;
    if (entry.displayDevice.alias.trim().toLowerCase() != needle) continue;
    if (entry.isLanReachable) return i;
    if (cloudOnlyMatch == -1) cloudOnlyMatch = i;
  }
  return cloudOnlyMatch;
}

Device _synthesizeDevice(CloudDevice cloud) {
  return Device(
    version: '',
    alias: cloud.displayName,
    deviceModel: null,
    deviceType: _mapCloudIconToDeviceType(cloud.icon),
    download: false,
    // Cloud-only entry has no usable network endpoint — that's
    // exactly the signal that downstream code (e.g. send_provider)
    // uses to gate `sendWake` instead of attempting a direct
    // transfer.
    endpoints: const {},
    discoveryMethods: const {},
  );
}

DeviceType _mapCloudIconToDeviceType(CloudDeviceIcon icon) {
  return switch (icon) {
    CloudDeviceIcon.phone || CloudDeviceIcon.tablet => DeviceType.mobile,
    CloudDeviceIcon.server => DeviceType.server,
    CloudDeviceIcon.headless => DeviceType.headless,
    CloudDeviceIcon.laptop || CloudDeviceIcon.desktop || CloudDeviceIcon.other => DeviceType.desktop,
  };
}

final mergedNetworkDevicesProvider = ViewProvider<List<MergedDevice>>((ref) {
  final lan = ref.watch(nearbyDevicesProvider).allDevices.values;
  final accountState = ref.watch(accountRepositoryProvider);
  final cloud = accountState is AccountReady ? accountState.devices : const <CloudDevice>[];
  final currentDeviceId = accountState is AccountReady ? accountState.currentDeviceId : null;
  final ownFingerprint = ref.watch(securityProvider).certificateHash;
  final ownLocalIps = ref.watch(localIpProvider).localIps;
  return mergeNetworkDevices(
    lan: lan,
    cloud: cloud,
    currentDeviceId: currentDeviceId,
    ownFingerprint: ownFingerprint,
    ownLocalIps: ownLocalIps,
  );
});
