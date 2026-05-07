import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';

Device _lan({
  required String certHash,
  String alias = 'LAN device',
  String ip = '192.168.1.10',
}) {
  return Device(
    version: '2.0',
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    endpoints: {
      HttpEndpoint(
        ip: ip,
        port: 53317,
        https: true,
        certHash: certHash,
      ),
    },
    discoveryMethods: {const MulticastDiscovery()},
  );
}

Device _signalingOnly({
  required String serverToken,
  String alias = 'Signaling device',
  String signalingId = 'sig-uuid',
}) {
  return Device(
    version: '2.0',
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    endpoints: {
      SignalingEndpoint(
        signalingId: signalingId,
        signalingServer: 'wss://public.localsend.org/v1/ws',
        serverToken: serverToken,
      ),
    },
    discoveryMethods: {const SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws')},
  );
}

CloudDevice _cloud({
  required String deviceId,
  String displayName = 'Cloud device',
  CloudDeviceIcon icon = CloudDeviceIcon.laptop,
  String? fingerprint,
}) {
  return CloudDevice(
    deviceId: deviceId,
    displayName: displayName,
    icon: icon,
    fcmToken: null,
    platform: CloudDevicePlatform.macos,
    fingerprint: fingerprint,
  );
}

void main() {
  group('mergeNetworkDevices', () {
    test('dedups a LAN device against a cloud device by cert hash', () {
      final lan = _lan(certHash: 'fp-1', alias: 'Stock-LocalSend-default-name');
      final cloud = _cloud(
        deviceId: 'cloud-1',
        displayName: 'Living-room laptop',
        fingerprint: 'fp-1',
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
      final lan = _lan(certHash: 'fp-1');
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

    test('LAN-side ip / port / cert hash survive the cloud-side override', () {
      final lan = _lan(certHash: 'fp-1', ip: '10.0.0.42');
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
      final endpoint = display.firstHttpEndpoint!;
      expect(endpoint.ip, '10.0.0.42', reason: 'LAN ip retained for actual transport');
      expect(endpoint.port, 53317);
      expect(endpoint.certHash, 'fp-1');
    });

    test('keeps a stock-LocalSend LAN peer (no cloud match) untouched', () {
      final lan = _lan(certHash: 'fp-stock', alias: 'Stock LocalSend');
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
        fingerprint: 'fp-2',
      );
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud], currentDeviceId: null);
      expect(merged, hasLength(1));
      final entry = merged.single;
      expect(entry.isLanReachable, isFalse);
      expect(entry.isOfflineCloud, isTrue);
      expect(entry.displayDevice.alias, 'Pixel 8');
      // Synthesized cloud-only entry has no usable endpoint — that's
      // the signal that send_provider uses to gate sendWake.
      expect(entry.displayDevice.hasAnyEndpoint, isFalse);
      expect(entry.displayDevice.deviceType, DeviceType.mobile);
      // stableId falls back to cloud deviceId since there's no
      // endpoint to extract a cert hash from.
      expect(entry.stableId, 'cloud-2');
    });

    test('synthesized tile for a cloud-only device with no fingerprint uses deviceId as stable key', () {
      final cloud = _cloud(deviceId: 'cloud-legacy');
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.displayDevice.hasAnyEndpoint, isFalse);
      expect(merged.single.stableId, 'cloud-legacy');
    });

    test('folds a cloud row whose fingerprint drifted from the LAN cert hash by alias', () {
      // Real-world reproduction of the lingering hot-restart-duplicate
      // report. A previous install left a cloud device row whose
      // fingerprint no longer matches the current install's cert hash
      // (cert regeneration during dev iteration, app reinstall, etc.).
      // Without an alias fallback the merge produced both a LAN tile
      // and a synthesized cloud-only tile for the same physical device.
      final lan = _lan(certHash: 'fp-current-cert', alias: 'Solid Lemon');
      final staleCloud = _cloud(
        deviceId: 'cloud-stale',
        displayName: 'Solid Lemon',
        fingerprint: 'fp-from-old-install',
      );
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: [staleCloud],
        currentDeviceId: null,
      );
      expect(merged, hasLength(1));
      expect(merged.single.cloud, staleCloud);
      expect(merged.single.isLanReachable, isTrue);
      expect(merged.single.displayDevice.alias, 'Solid Lemon');
    });

    test('folds a cloud row with null fingerprint into a same-alias LAN entry', () {
      // Legacy cloud rows missing the `fingerprint` field — pre-dating
      // the field being populated — should still dedup against their
      // LAN twin instead of rendering as a separate cloud-only tile.
      final lan = _lan(certHash: 'fp-current', alias: 'Pixel 8');
      final legacyCloud = _cloud(deviceId: 'legacy', displayName: 'Pixel 8');
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: [legacyCloud],
        currentDeviceId: null,
      );
      expect(merged, hasLength(1));
      expect(merged.single.cloud, legacyCloud);
      expect(merged.single.isLanReachable, isTrue);
    });

    test('cloud rows with mismatched display names still surface as separate cloud-only tiles', () {
      // Negative case: if the user edits the cloud display name to
      // something that no LAN-announced alias resembles, we can't fold
      // confidently. Render as a cloud-only tile so the user can
      // still wake-then-send to it.
      final lan = _lan(certHash: 'fp-A', alias: 'Solid Lemon');
      final unrelated = _cloud(
        deviceId: 'cloud-other',
        displayName: 'Living-room laptop',
        fingerprint: 'fp-B',
      );
      final merged = mergeNetworkDevices(
        lan: [lan],
        cloud: [unrelated],
        currentDeviceId: null,
      );
      expect(merged, hasLength(2));
    });

    test('signaling-only LAN device whose serverToken equals a cloud cert hash must NOT false-merge', () {
      // Cert hashes and signaling tokens live in distinct value
      // spaces. If a string happens to be valid in both spaces by
      // coincidence (or by a future bug), the join must NOT collapse
      // them — the cloud doc's `fingerprint` field is unambiguously a
      // cert hash, not a server token. Cert-hash lookups go through
      // `device.certHashes` (HTTP endpoints only).
      final signaling = _signalingOnly(
        serverToken: 'cert-hash-X',
        alias: 'Sig-Only Device',
      );
      final cloud = _cloud(
        deviceId: 'cloud-different-device',
        displayName: 'Cloud Device A',
        fingerprint: 'cert-hash-X',
      );
      final merged = mergeNetworkDevices(
        lan: [signaling],
        cloud: [cloud],
        currentDeviceId: null,
      );
      // Two separate tiles: the signaling-only LAN entry and the
      // synthesized cloud-only entry (no LAN twin matching by cert).
      expect(merged, hasLength(2));
      final cloudEntry = merged.firstWhere((m) => m.cloud != null);
      expect(cloudEntry.isLanReachable, isFalse, reason: 'no cert-hash match → cloud tile is offline');
    });

    test('LAN-reachable cloud-known peer is online regardless of stale presence field', () {
      // After the presence subsystem was removed, online truth comes
      // exclusively from LAN reachability.
      final lan = _lan(certHash: 'fp-3');
      final cloud = _cloud(deviceId: 'cloud-3', fingerprint: 'fp-3');
      final merged = mergeNetworkDevices(lan: [lan], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.isLanReachable, isTrue);
      expect(merged.single.isOnline, isTrue);
      expect(merged.single.isOfflineCloud, isFalse, reason: 'LAN entry exists, so the wake flow is not needed');
    });

    test('filters out the current device from the cloud list', () {
      final cloud = _cloud(deviceId: 'me');
      final other = _cloud(deviceId: 'other', displayName: 'Sibling');
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud, other], currentDeviceId: 'me');
      expect(merged.map((m) => m.cloud?.deviceId), ['other']);
    });

    test('skips LAN devices with no endpoints (defensive)', () {
      final lan = Device(
        version: '2.0',
        alias: 'Empty',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: const {},
        discoveryMethods: const {},
      );
      final merged = mergeNetworkDevices(lan: [lan], cloud: const [], currentDeviceId: null);
      expect(merged, isEmpty);
    });

    test('drops a stale-self cloud row whose fingerprint matches our cert hash', () {
      // Reproduction of the user-reported bug: iPhone sees itself as
      // an "Offline / Wake" tile on the Send tab. Cause: the Firebase
      // emulator was restarted so the iPhone's bootstrap minted a
      // fresh deviceId for the new session, while the local cert
      // hash (securityContext.certificateHash) persisted across the
      // restart. The cloud now has two device rows for this iPhone:
      // the current one (filtered by deviceId match) AND an old one
      // from the previous session (different deviceId, SAME
      // fingerprint). Without a cert-hash filter, the old row
      // renders as a separate offline-self tile.
      final currentSelfRow = _cloud(
        deviceId: 'me-current',
        displayName: 'iPhone',
        fingerprint: 'cert-mine',
      );
      final staleSelfRow = _cloud(
        deviceId: 'me-old',
        displayName: 'iPhone',
        fingerprint: 'cert-mine',
      );
      final peer = _cloud(
        deviceId: 'mac-1',
        displayName: 'Timetravels MacBook',
        fingerprint: 'cert-mac',
      );
      final merged = mergeNetworkDevices(
        lan: const [],
        cloud: [currentSelfRow, staleSelfRow, peer],
        currentDeviceId: 'me-current',
        ownFingerprint: 'cert-mine',
      );
      // Only the peer should survive: `me-current` is filtered by
      // deviceId match, `me-old` is filtered by cert-hash match.
      expect(merged.map((m) => m.cloud?.deviceId), ['mac-1']);
    });

    test('drops a LAN device whose cert hash equals our own (Android-emulator loopback)', () {
      // Reproduces what the user reported: on the Android emulator,
      // multicast loopback lets the device's own announce reach itself.
      // The upstream multicast listener already filters this out, but
      // we keep a defensive filter at the merge layer so the Send tab
      // never lists the user themselves regardless of upstream behaviour.
      final selfLan = _lan(certHash: 'fp-self', alias: 'Solid Lemon');
      final peer = _lan(certHash: 'fp-peer', alias: 'Peer');
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
        certHash: 'fp-other',
        alias: 'Fine Mango',
        ip: '192.168.101.126',
      );
      final peer = _lan(
        certHash: 'fp-peer',
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
      final lan = _lan(certHash: 'fp-1');
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
      final lan = _lan(certHash: 'fp-1');
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

  group('mergeNetworkDevices multi-homed', () {
    test('two LAN entries with the same cert hash + cloud doc → ONE merged tile', () {
      // Reproduction of the visible duplicate-MacBook bug from the
      // user report: a MacBook on WiFi + Ethernet sends two multicast
      // announces (different IPs, same cert hash). The receiving
      // device's `state.devices` is keyed by IP so both land in the
      // map. `mergeNetworkDevices` must NOT render two cloud-bound
      // tiles for the same physical device — both LAN entries have
      // the same cert hash as the cloud doc, but only one of them
      // gets bound to `cloud`. The other should fold into it.
      //
      // The first-line defense is the LAN multi-homed collapse in
      // `nearbyDevicesState.allDevices`. This test simulates that
      // upstream collapse already happened: callers pass a SINGLE
      // multi-endpoint LAN Device into `mergeNetworkDevices`.
      final wifi = HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'fp-mac');
      final ethernet = HttpEndpoint(ip: '10.0.0.5', port: 53317, https: true, certHash: 'fp-mac');
      final multiHomed = Device(
        version: '2.0',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {wifi, ethernet},
        discoveryMethods: {const MulticastDiscovery()},
      );
      final cloud = _cloud(deviceId: 'cloud-mac', displayName: 'Timetravels MacBook', fingerprint: 'fp-mac');
      final merged = mergeNetworkDevices(
        lan: [multiHomed],
        cloud: [cloud],
        currentDeviceId: null,
      );
      expect(merged, hasLength(1));
      expect(merged.single.cloud, cloud);
      expect(merged.single.displayDevice.httpEndpoints.length, 2);
    });

    test('two unique cert hashes with same alias each get their own tile, both folded with cloud', () {
      // Negative case: two genuinely different MacBooks happen to
      // share an alias (e.g. both are "Timetravels MacBook" before
      // anyone renames them). Distinct cert hashes mean distinct
      // physical devices — DON'T over-merge. Each gets a tile; the
      // cloud doc with matching cert folds into the matching one.
      final macA = _lan(certHash: 'cert-A', alias: 'Timetravels MacBook', ip: '192.168.1.5');
      final macB = _lan(certHash: 'cert-B', alias: 'Timetravels MacBook', ip: '192.168.1.6');
      final cloudA = _cloud(deviceId: 'cloud-A', displayName: 'Timetravels MacBook', fingerprint: 'cert-A');
      final merged = mergeNetworkDevices(
        lan: [macA, macB],
        cloud: [cloudA],
        currentDeviceId: null,
      );
      expect(merged, hasLength(2));
      final cloudBound = merged.firstWhere((m) => m.cloud != null);
      final stockOnly = merged.firstWhere((m) => m.cloud == null);
      expect(cloudBound.displayDevice.firstHttpEndpoint?.certHash, 'cert-A');
      expect(stockOnly.displayDevice.firstHttpEndpoint?.certHash, 'cert-B');
    });

    test('multi-homed self-IP filter drops only when our own IP appears in the endpoint set', () {
      // Edge case: a multi-homed peer with one IP that happens to
      // match our own (loopback case). Drop the peer to avoid the
      // self-receive crash. Real-world this is the Android emulator
      // multicast-loopback scenario.
      final peer = Device(
        version: '2.0',
        alias: 'Peer',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'fp-peer'),
          HttpEndpoint(ip: '192.168.101.126', port: 53317, https: true, certHash: 'fp-peer'),
        },
        discoveryMethods: {const MulticastDiscovery()},
      );
      final merged = mergeNetworkDevices(
        lan: [peer],
        cloud: const [],
        currentDeviceId: null,
        ownLocalIps: const ['192.168.101.126'],
      );
      expect(merged, isEmpty, reason: 'any endpoint matching our IP filters the whole entry');
    });
  });

  group('MergedDevice online semantics', () {
    test('cloud-known peer with no LAN entry reports offline and routes through wake', () {
      final cloud = _cloud(deviceId: 'c', fingerprint: 'fp');
      final merged = mergeNetworkDevices(lan: const [], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.isOnline, isFalse);
      expect(merged.single.isOfflineCloud, isTrue, reason: 'tap routes through wake flow');
    });

    test('cloud-known peer with a LAN twin reports online and skips the wake flow', () {
      final lan = _lan(certHash: 'fp');
      final cloud = _cloud(deviceId: 'c', fingerprint: 'fp');
      final merged = mergeNetworkDevices(lan: [lan], cloud: [cloud], currentDeviceId: null);
      expect(merged.single.isOnline, isTrue);
      expect(merged.single.isOfflineCloud, isFalse);
    });
  });
}
