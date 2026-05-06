import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';
import 'package:magicshare_app/provider/favorites_provider.dart';
import 'package:magicshare_app/provider/logging/discovery_logs_provider.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _StubIsolateController extends Mock implements IsolateController {}

class _StubFavoritesService extends Mock implements FavoritesService {}

class _StubDiscoveryLogger extends Mock implements DiscoveryLogger {}

NearbyDevicesService _makeService() {
  return NearbyDevicesService(
    isolateController: _StubIsolateController(),
    favoriteService: _StubFavoritesService(),
    discoveryLogs: _StubDiscoveryLogger(),
  );
}

Device _device({required String fingerprint, String ip = '10.0.0.1'}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: '2.0',
    port: 53317,
    https: true,
    fingerprint: fingerprint,
    alias: 'Solid Lemon',
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: {const MulticastDiscovery()},
  );
}

void main() {
  group('PruneStaleDevicesAction', () {
    test('drops entries whose lastSeenAt is older than kLanDeviceTtl', () {
      final fresh = _device(fingerprint: 'fp-fresh', ip: '10.0.0.1');
      final stale = _device(fingerprint: 'fp-stale', ip: '10.0.0.2');
      final now = DateTime.now();
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: const {},
          devices: {fresh.ip!: fresh, stale.ip!: stale},
          lastSeenAt: {
            fresh.ip!: now.subtract(const Duration(seconds: 5)),
            stale.ip!: now.subtract(kLanDeviceTtl + const Duration(seconds: 5)),
          },
          signalingDevices: const {},
        ),
      );

      tester.dispatch(PruneStaleDevicesAction());

      expect(tester.state.devices.keys, equals({fresh.ip!}));
      expect(tester.state.lastSeenAt.keys, equals({fresh.ip!}));
    });

    test('is a no-op when nothing is stale', () {
      final fresh = _device(fingerprint: 'fp', ip: '10.0.0.1');
      final original = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {fresh.ip!: fresh},
        lastSeenAt: {fresh.ip!: DateTime.now()},
        signalingDevices: const {},
      );
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: original,
      );

      tester.dispatch(PruneStaleDevicesAction());

      expect(identical(tester.state, original), isTrue, reason: 'fast path returns the same state instance');
    });

    test('drops an entry that has no lastSeenAt timestamp at all', () {
      // Defensive: an IP-keyed entry with no matching lastSeenAt is
      // already inconsistent state — treat it as stale and clean up.
      final orphan = _device(fingerprint: 'fp', ip: '10.0.0.9');
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: const {},
          devices: {orphan.ip!: orphan},
          lastSeenAt: const {},
          signalingDevices: const {},
        ),
      );

      tester.dispatch(PruneStaleDevicesAction());

      expect(tester.state.devices, isEmpty);
      expect(tester.state.lastSeenAt, isEmpty);
    });
  });

  group('UnregisterDeviceAction', () {
    test('removes the matching fingerprint regardless of which IP it is keyed under', () {
      // Goodbye carries only the fingerprint; the IP it was last seen
      // under may have shifted (Android emulator hot-restart, network
      // interface change). Drop by fingerprint.
      final keep = _device(fingerprint: 'fp-keep', ip: '10.0.0.1');
      final go = _device(fingerprint: 'fp-go', ip: '10.0.0.2');
      final now = DateTime.now();
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: const {},
          devices: {keep.ip!: keep, go.ip!: go},
          lastSeenAt: {keep.ip!: now, go.ip!: now},
          signalingDevices: const {},
        ),
      );

      tester.dispatch(UnregisterDeviceAction('fp-go'));

      expect(tester.state.devices.keys, equals({keep.ip!}));
      expect(tester.state.lastSeenAt.keys, equals({keep.ip!}));
    });

    test('is a no-op when no entry has the given fingerprint', () {
      final keep = _device(fingerprint: 'fp-keep', ip: '10.0.0.1');
      final original = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {keep.ip!: keep},
        lastSeenAt: {keep.ip!: DateTime.now()},
        signalingDevices: const {},
      );
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: original,
      );

      tester.dispatch(UnregisterDeviceAction('fp-not-present'));

      expect(identical(tester.state, original), isTrue);
    });

    test('ignores empty fingerprints defensively', () {
      // An attacker-or-bug could spoof a goodbye for fingerprint=''
      // which on the LAN-side bookkeeping would otherwise drop the
      // empty-fingerprint entries (already filtered out in [allDevices]
      // but defence-in-depth never hurts).
      final keep = _device(fingerprint: 'fp-keep', ip: '10.0.0.1');
      final original = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {keep.ip!: keep},
        lastSeenAt: {keep.ip!: DateTime.now()},
        signalingDevices: const {},
      );
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: original,
      );

      tester.dispatch(UnregisterDeviceAction(''));

      expect(identical(tester.state, original), isTrue);
    });
  });

  group('ClearFoundDevicesAction', () {
    test('clears both devices and lastSeenAt', () {
      final dev = _device(fingerprint: 'fp', ip: '10.0.0.1');
      final tester = ReduxNotifier.test(
        redux: _makeService(),
        initialState: NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: const {},
          devices: {dev.ip!: dev},
          lastSeenAt: {dev.ip!: DateTime.now()},
          signalingDevices: const {},
        ),
      );

      tester.dispatch(ClearFoundDevicesAction());

      expect(tester.state.devices, isEmpty);
      expect(tester.state.lastSeenAt, isEmpty);
    });
  });
}
