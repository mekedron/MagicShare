import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';

class _InMemoryStorage {
  final Map<String, String> _store = <String, String>{};

  SecureStorageService service() => SecureStorageService(
    gateway: SecureStorageGateway(
      read: (key) async => _store[key],
      write: (key, value) async => _store[key] = value,
      delete: (key) async => _store.remove(key),
    ),
  );

  String? get(String key) => _store[key];
  void put(String key, String value) => _store[key] = value;
}

void main() {
  group('DeviceIdentityService.ensureDeviceId', () {
    test('generates and persists a fresh id on first call', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.service(),
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
        storage: storage.service(),
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
        storage: storage.service(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => fail('should not be called when storage is populated'),
      );

      expect(await service.ensureDeviceId(), 'pre-existing');
    });

    test('invalidate clears the in-memory cache so the next call re-reads storage', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final service = DeviceIdentityService(
        storage: storage.service(),
        aliasReader: () => 'fixture',
        deviceIdGenerator: () => 'minted-${++calls}',
      );

      await service.ensureDeviceId();
      // External state-change: storage wiped (e.g. by deleteAccount cleanup).
      storage._store.remove(cloudDeviceIdKey);
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
        storage: storage.service(),
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
        storage: _InMemoryStorage().service(),
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
    storage: _InMemoryStorage().service(),
    aliasReader: () => 'fixture',
    platformOverride: platform,
  );
}
