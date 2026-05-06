import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';

class _InMemoryStorage {
  String? _value;

  DeviceIdStorage gateway() => DeviceIdStorage(
    read: () => _value,
    write: (value) async => _value = value,
  );

  String? get(Object _) => _value;
  void put(Object _, String value) => _value = value;
}

const cloudDeviceIdKey = Object();

void main() {
  group('DeviceIdentityService.ensureDeviceId', () {
    test('generates and persists a fresh id on first call', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => 'minted-${++calls}',
      );

      final id = await service.ensureDeviceId();
      expect(id, 'minted-1');
      expect(storage.get(cloudDeviceIdKey), 'minted-1');
    });

    test('returns the persisted id on subsequent calls without re-generating', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => 'minted-${++calls}',
      );

      final first = await service.ensureDeviceId();
      final second = await service.ensureDeviceId();

      expect(second, first);
      expect(calls, 1);
    });

    test('honours an id already present in secure storage', () async {
      final storage = _InMemoryStorage()..put(cloudDeviceIdKey, 'pre-existing');
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => fail('should not be called when storage is populated'),
      );

      expect(await service.ensureDeviceId(), 'pre-existing');
    });

    test('invalidate clears the in-memory cache so the next call re-reads storage', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => 'minted-${++calls}',
      );

      await service.ensureDeviceId();
      // External state-change: storage wiped (e.g. by deleteAccount cleanup).
      storage._value = null;
      service.invalidate();

      final second = await service.ensureDeviceId();
      expect(second, 'minted-2');
    });

    test('concurrent callers on an empty store share one minted id', () async {
      // Regression: AccountRepository._attachToAccount and
      // CloudBootstrapService._runBootstrap both call ensureDeviceId on
      // the same auth transition. Without single-flight protection each
      // caller used to mint a fresh UUID and write its own — registering
      // two devices under one account on the very first post-destroy
      // bootstrap.
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => 'minted-${++calls}',
      );

      final results = await Future.wait([
        service.ensureDeviceId(),
        service.ensureDeviceId(),
        service.ensureDeviceId(),
      ]);

      expect(results.toSet(), hasLength(1));
      expect(calls, 1);
      expect(storage.get(cloudDeviceIdKey), results.first);
    });
  });

  group('DeviceIdentityService defaults', () {
    test('display name reads through to the alias function', () {
      var alias = 'first';
      final service = DeviceIdentityService(
        storage: _InMemoryStorage().gateway(),
        aliasReader: () => alias,
      );

      expect(service.defaultDisplayName(), 'first');
      alias = 'renamed';
      expect(service.defaultDisplayName(), 'renamed');
    });

    test('icon defaults to phone on mobile platforms', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final service = _build(platform: platform);
        expect(service.defaultIcon(), CloudDeviceIcon.phone, reason: '$platform');
      }
    });

    test('icon defaults to desktop on desktop platforms', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        final service = _build(platform: platform);
        expect(service.defaultIcon(), CloudDeviceIcon.desktop, reason: '$platform');
      }
    });

    test('icon falls back to other on fuchsia', () {
      expect(
        _build(platform: TargetPlatform.fuchsia).defaultIcon(),
        CloudDeviceIcon.other,
      );
    });

    test('peekDeviceId returns null when storage is empty and does not mint', () {
      final storage = _InMemoryStorage();
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => fail('peek must not call the generator'),
      );
      expect(service.peekDeviceId(), isNull);
      expect(storage.get(cloudDeviceIdKey), isNull, reason: 'peek must not write');
    });

    test('peekDeviceId returns the stored value without minting', () {
      final storage = _InMemoryStorage()..put(cloudDeviceIdKey, 'persisted-id');
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => fail('peek must not call the generator'),
      );
      expect(service.peekDeviceId(), 'persisted-id');
    });

    test('adoptDeviceId persists the supplied id and serves it from cache', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.gateway(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => 'minted-${++calls}',
      );

      await service.adoptDeviceId('adopted-id');
      expect(storage.get(cloudDeviceIdKey), 'adopted-id');
      expect(await service.ensureDeviceId(), 'adopted-id', reason: 'no minting after adoption');
      expect(calls, 0);
    });

    test('adoptDeviceId rejects an empty id', () async {
      final service = DeviceIdentityService(
        storage: _InMemoryStorage().gateway(),
        aliasReader: () => 'fixture',
      );
      await expectLater(service.adoptDeviceId(''), throwsArgumentError);
    });

    test('platform enum is mapped 1:1 for supported platforms', () {
      final cases = <TargetPlatform, CloudDevicePlatform>{
        TargetPlatform.android: CloudDevicePlatform.android,
        TargetPlatform.iOS: CloudDevicePlatform.ios,
        TargetPlatform.macOS: CloudDevicePlatform.macos,
        TargetPlatform.windows: CloudDevicePlatform.windows,
        TargetPlatform.linux: CloudDevicePlatform.linux,
        // Unsupported but plausible — bucketed under linux as the closest fit.
        TargetPlatform.fuchsia: CloudDevicePlatform.linux,
      };
      for (final entry in cases.entries) {
        expect(
          _build(platform: entry.key).currentPlatform(),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });
  });
}

DeviceIdentityService _build({required TargetPlatform platform}) {
  return DeviceIdentityService(
    storage: _InMemoryStorage().gateway(),
    aliasReader: () => 'fixture',
    platformOverride: platform,
  );
}
