import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';

Device _lan({
  required String fingerprint,
  String alias = 'LAN device',
  String ip = '192.168.1.10',
}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: '2.0',
    port: 53317,
    https: true,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: {const MulticastDiscovery()},
  );
}

CloudDevice _cloud({
  required String deviceId,
  String displayName = 'Cloud device',
  CloudDeviceIcon icon = CloudDeviceIcon.laptop,
  CloudDevicePresence presence = CloudDevicePresence.online,
  String? fingerprint,
}) {
  return CloudDevice(
    deviceId: deviceId,
    displayName: displayName,
    icon: icon,
    fcmToken: null,
    platform: CloudDevicePlatform.macos,
    lastSeenAtMs: 0,
    presence: presence,
    fingerprint: fingerprint,
  );
}

void main() {
  group('mergeNetworkDevices', () {
    test('dedups a LAN device against a cloud device by fingerprint', () {
      final lan = _lan(fingerprint: 'fp-1', alias: 'Stock-LocalSend-default-name');
      final cloud = _cloud(
        deviceId: 'cloud-1',
        displayName: 'Living-room laptop',
        fingerprint: 'fp-1',
        presence: CloudDevicePresence.online,
      );
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: [cloud],
        currentDeviceId: null,
      );

      expect(merged, hasLength(1));
      final entry = merged.single;
      expect(entry.cloud, cloud);
      expect(entry.isLanReachable, isTrue);
      expect(
        entry.displayDevice.alias,
        'Living-room laptop',
        reason: 'cloud-side display name wins over the LAN-announced auto-generated alias',
      );
      expect(entry.isOnline, isTrue);
    });

    test('cloud-side icon wins on dedup', () {
      // LAN announces deviceType=desktop (LocalSend default). The user
      // chose the phone icon in the device-group settings, so the tile
      // must render with the phone icon — not be reset to desktop on
      // every LAN refresh.
      final lan = _lan(fingerprint: 'fp-1');
      final cloud = _cloud(
        deviceId: 'cloud-1',
        fingerprint: 'fp-1',
        icon: CloudDeviceIcon.phone,
      );
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: [cloud],
        currentDeviceId: null,
      );

      expect(merged.single.displayDevice.deviceType, DeviceType.mobile);
    });

    test('LAN-side ip / port / fingerprint survive the cloud-side override', () {
      final lan = _lan(fingerprint: 'fp-1', ip: '10.0.0.42');
      final cloud = _cloud(
        deviceId: 'cloud-1',
        displayName: 'Laptop A',
        fingerprint: 'fp-1',
      );
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: [cloud],
        currentDeviceId: null,
      );

      final display = merged.single.displayDevice;
      expect(display.alias, 'Laptop A');
      expect(display.ip, '10.0.0.42', reason: 'LAN ip retained for actual transport');
      expect(display.port, 53317);
      expect(display.fingerprint, 'fp-1');
    });

    test('keeps a stock-LocalSend LAN peer (no cloud match) untouched', () {
      final lan = _lan(fingerprint: 'fp-stock', alias: 'Stock LocalSend');
      final merged = mergeNetworkDevices(lan: [lan], cloud: const [], currentDeviceId: null);
      expect(merged.single.cloud, isNull);
      expect(merged.single.isLanReachable, isTrue);
      expect(merged.single.isOnline, isTrue);
    });

    test('synthesizes a tile for a cloud-only device with a known fingerprint', () {
      final cloud = _cloud(
        deviceId: 'cloud-2',
        displayName: 'Pixel 8',
        icon: CloudDeviceIcon.phone,
        presence: CloudDevicePresence.offline,
        fingerprint: 'fp-2',
      );
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud], currentDeviceId: null);
      expect(merged, hasLength(1));
      final entry = merged.single;
      expect(entry.isLanReachable, isFalse);
      expect(entry.isOfflineCloud, isTrue);
      expect(entry.displayDevice.alias, 'Pixel 8');
      expect(entry.displayDevice.fingerprint, 'fp-2');
      expect(entry.displayDevice.deviceType, DeviceType.mobile);
      expect(entry.stableId, 'fp-2');
    });

    test('synthesized tile for a cloud-only device with no fingerprint uses deviceId as stable key', () {
      final cloud = _cloud(deviceId: 'cloud-legacy');
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.displayDevice.fingerprint, 'cloud-legacy');
      expect(merged.single.stableId, 'cloud-legacy');
    });

    test('LAN online + cloud presence offline reports the device as offline', () {
      // Cloud presence is authoritative for cloud-known peers. A LAN
      // announce can outrun the heartbeat (the peer is mid-shutdown),
      // so presence=offline wins on a same-fingerprint match.
      final lan = _lan(fingerprint: 'fp-3');
      final cloud = _cloud(deviceId: 'cloud-3', fingerprint: 'fp-3', presence: CloudDevicePresence.offline);
      final merged = mergeNetworkDevices(lan: [lan], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.isLanReachable, isTrue);
      expect(merged.single.isOnline, isFalse);
      expect(merged.single.isOfflineCloud, isFalse, reason: 'LAN entry exists, so the wake flow is not needed');
    });

    test('filters out the current device from the cloud list', () {
      final cloud = _cloud(deviceId: 'me');
      final other = _cloud(deviceId: 'other', displayName: 'Sibling');
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud, other], currentDeviceId: 'me');
      expect(merged.map((m) => m.cloud?.deviceId), ['other']);
    });

    test('skips LAN devices with empty fingerprint (defensive)', () {
      final lan = _lan(fingerprint: '');
      final merged = mergeNetworkDevices(lan: [lan], cloud: const [], currentDeviceId: null);
      expect(merged, isEmpty);
    });

    test('drops a LAN device whose fingerprint equals our own (Android-emulator loopback)', () {
      // Reproduces what the user reported: on the Android emulator,
      // multicast loopback lets the device's own announce reach itself.
      // The upstream multicast listener already filters this out, but
      // we keep a defensive filter at the merge layer so the Send tab
      // never lists the user themselves regardless of upstream behaviour.
      final selfLan = _lan(fingerprint: 'fp-self', alias: 'Solid Lemon');
      final peer = _lan(fingerprint: 'fp-peer', alias: 'Peer');
      final merged = mergeNetworkDevices(
        lan: [selfLan, peer],
        cloud: const [],
        currentDeviceId: null,
        ownFingerprint: 'fp-self',
      );
      expect(merged.map((m) => m.displayDevice.alias), ['Peer']);
    });

    test('drops a LAN device whose IP equals one of our local IPs', () {
      // Reproduces a stock-LocalSend instance running side-by-side
      // with MagicShare on the same host (or any other same-machine
      // setup): same IP as the sender, different fingerprint, and
      // the user can't actually transfer to itself.
      final samesie = _lan(
        fingerprint: 'fp-other',
        alias: 'Fine Mango',
        ip: '192.168.101.126',
      );
      final peer = _lan(
        fingerprint: 'fp-peer',
        alias: 'Peer',
        ip: '192.168.101.42',
      );
      final merged = mergeNetworkDevices(
        lan: [samesie, peer],
        cloud: const [],
        currentDeviceId: null,
        ownLocalIps: const ['192.168.101.126', 'fe80::1'],
      );
      expect(merged.map((m) => m.displayDevice.alias), ['Peer']);
    });

    test('null / empty ownLocalIps does not block any LAN device', () {
      final lan = _lan(fingerprint: 'fp-1');
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: const [],
        currentDeviceId: null,
      );
      expect(merged, hasLength(1));
    });

    test('treats null / empty ownFingerprint as no-self-filter', () {
      // Bootstrap may not have a stored security context yet on very
      // first launch. Falling through to the existing behaviour is
      // safer than dropping every LAN device because we couldn't
      // identify ourselves.
      final lan = _lan(fingerprint: 'fp-1');
      final mergedNull = mergeNetworkDevices(
        lan: [lan],
        cloud: const [],
        currentDeviceId: null,
      );
      final mergedEmpty = mergeNetworkDevices(
        lan: [lan],
        cloud: const [],
        currentDeviceId: null,
        ownFingerprint: '',
      );
      expect(mergedNull, hasLength(1));
      expect(mergedEmpty, hasLength(1));
    });
  });

  group('MergedDevice presence semantics', () {
    test('isOnline tracks cloud presence even when no LAN entry exists', () {
      // Android-emulator-from-macOS scenario: qemu user-mode NAT silently
      // drops the emulator's multicast announce on the way to the host,
      // so macOS never sees a LAN entry. The badge follows the heartbeat
      // — Online when presence=online, Offline when stale — and the
      // tap is still routed through the wake flow via [isOfflineCloud].
      final cloud = _cloud(deviceId: 'c', fingerprint: 'fp', presence: CloudDevicePresence.online);
      final mergedOnline = mergeNetworkDevices(lan: const [], cloud: [cloud], currentDeviceId: null);
      expect(mergedOnline.single.isOnline, isTrue);
      expect(mergedOnline.single.isOfflineCloud, isTrue, reason: 'tap still routes through wake flow');

      final stale = _cloud(deviceId: 'c', fingerprint: 'fp', presence: CloudDevicePresence.offline);
      final mergedOffline = mergeNetworkDevices(lan: const [], cloud: [stale], currentDeviceId: null);
      expect(mergedOffline.single.isOnline, isFalse);
    });

    test('isOnline is true for cloud-known + LAN-reachable + presence online', () {
      final lan = _lan(fingerprint: 'fp');
      final cloud = _cloud(deviceId: 'c', fingerprint: 'fp', presence: CloudDevicePresence.online);
      final merged = mergeNetworkDevices(lan: [lan], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.isOnline, isTrue);
    });
  });
}
