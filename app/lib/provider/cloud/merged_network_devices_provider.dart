import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:magicshare_app/provider/security_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Combined record for a single physical device the user can target from
/// the Send tab. Pure LAN peers (e.g. a stock LocalSend client) appear
/// with [cloud] == null; the user's own cloud-registered devices appear
/// with [cloud] != null and merge with their LAN twin (when present)
/// using `Device.fingerprint` as the join key.
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

  /// Whether the user should perceive this device as "online" — i.e. the
  /// app on the other side is alive and we can hand a transfer over to
  /// it (directly via LAN or via the wake-then-send fallback).
  ///
  /// For a cloud-known peer the heartbeat presence is authoritative;
  /// LAN reachability is just the fast path. The Android emulator
  /// scenario is the canonical example: qemu user-mode NAT silently
  /// drops the emulator's multicast announce on its way to the host,
  /// so the macOS instance never sees an LAN entry for it. Returning
  /// `false` there made a foregrounded emulator render as "Offline" on
  /// the host even though presence said online — and tapping it still
  /// produced the wake-then-send flow because [isOfflineCloud] kicked
  /// in. The badge is now driven by presence; [isOfflineCloud] still
  /// gates the wake routing on tap.
  ///
  /// Stock LocalSend peers (cloud == null) have no presence signal, so
  /// LAN reachability is the only thing we can trust.
  bool get isOnline {
    final cloudDev = cloud;
    if (cloudDev == null) return isLanReachable;
    return cloudDev.presence == CloudDevicePresence.online;
  }

  /// True when only the cloud side knows this device — the sender must
  /// fire a wake notification and wait for the receiver to come online
  /// before a P2P transfer can complete.
  bool get isOfflineCloud => cloud != null && !isLanReachable;

  /// Stable id used by the Send tab for keys + Hero tags. Falls back to
  /// the cloud `deviceId` when no `Device.fingerprint` is available
  /// (synthesized cloud-only entries with a missing fingerprint).
  String get stableId {
    final fp = displayDevice.fingerprint;
    if (fp.isNotEmpty) return fp;
    return cloud?.deviceId ?? '';
  }
}

/// Merge LAN-discovered devices with cloud-registered devices. Dedup
/// key is `Device.fingerprint` (LocalSend cert hash) on both sides; a
/// cloud doc whose `fingerprint` field is null can't be deduped against
/// LAN, so it shows up only as a cloud-only tile.
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
  final byKey = <String, MergedDevice>{};
  for (final lanDevice in lan) {
    final fp = lanDevice.fingerprint;
    if (fp.isEmpty) continue;
    if (ownFingerprint != null && ownFingerprint.isNotEmpty && fp == ownFingerprint) {
      // Defensive: drop a LAN announce carrying this install's own
      // cert hash (the Android-emulator multicast-loopback case).
      continue;
    }
    final ip = lanDevice.ip;
    if (ip != null && ip.isNotEmpty && ownIpSet.contains(ip)) {
      // Same machine, different fingerprint — typically a stock
      // LocalSend instance running side-by-side with MagicShare on
      // the same host. The user can't actually transfer to itself,
      // and seeing it in the receiver list invites the "Null check
      // operator used on a null value" crash on tap (the synthesized
      // Device for a cloud-only twin has ip: null). Drop it.
      continue;
    }
    byKey[fp] = MergedDevice(
      displayDevice: lanDevice,
      cloud: null,
      isLanReachable: true,
    );
  }
  for (final cloudDevice in cloud) {
    if (cloudDevice.deviceId == currentDeviceId) continue;
    final fp = cloudDevice.fingerprint;
    if (fp != null && fp.isNotEmpty) {
      final existing = byKey[fp];
      if (existing != null) {
        // The user explicitly chose the cloud-side display name and
        // icon in the device-group settings; the LAN-side `alias` is
        // just the auto-generated default the receiving LocalSend
        // instance announces. Cloud-side metadata wins; LAN keeps the
        // network reachability fields (ip, port, https, etc.).
        byKey[fp] = MergedDevice(
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
    final key = (fp != null && fp.isNotEmpty) ? fp : 'cloud:${cloudDevice.deviceId}';
    byKey[key] = MergedDevice(
      displayDevice: _synthesizeDevice(cloudDevice),
      cloud: cloudDevice,
      isLanReachable: false,
    );
  }
  return byKey.values.toList(growable: false);
}

Device _synthesizeDevice(CloudDevice cloud) {
  return Device(
    signalingId: null,
    ip: null,
    version: '',
    port: -1,
    https: true,
    fingerprint: cloud.fingerprint ?? cloud.deviceId,
    alias: cloud.displayName,
    deviceModel: null,
    deviceType: _mapCloudIconToDeviceType(cloud.icon),
    download: false,
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
