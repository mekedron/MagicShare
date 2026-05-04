import 'package:flutter/foundation.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/provider/cloud/secure_storage_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

/// Knows everything device-shaped about *this* installation: a stable
/// per-install device id, a default human display name (sourced from the
/// existing user-editable LAN alias so cloud and LAN identities match),
/// and platform-derived defaults for the icon and platform enums sent on
/// `registerDevice`.
class DeviceIdentityService {
  DeviceIdentityService({
    required SecureStorageService storage,
    required this.aliasReader,
    TargetPlatform? platformOverride,
    String Function()? deviceIdGenerator,
  }) : _storage = storage,
       _platformOverride = platformOverride,
       _generateDeviceId = deviceIdGenerator ?? _defaultDeviceIdGenerator;

  final SecureStorageService _storage;

  /// Resolves the current LAN alias on every call. Held as a function
  /// rather than a captured snapshot so the value follows live edits in
  /// settings without DeviceIdentityService having to listen.
  final String Function() aliasReader;

  final TargetPlatform? _platformOverride;
  final String Function() _generateDeviceId;

  String? _cached;

  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  /// Reads the persisted device id from secure storage; if absent, generates
  /// a UUIDv4, persists it, and returns it. Subsequent calls in the same
  /// process serve from an in-memory cache so the secure-storage backend is
  /// hit at most once per launch.
  Future<String> ensureDeviceId() async {
    final cached = _cached;
    if (cached != null) return cached;
    final stored = await _storage.read(cloudDeviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return stored;
    }
    final fresh = _generateDeviceId();
    await _storage.write(cloudDeviceIdKey, fresh);
    _cached = fresh;
    return fresh;
  }

  /// Forgets the in-memory cache. After the storage entry is wiped (e.g. by
  /// `GroupKeyService.clear()` on `deleteAccount`), the next `ensureDeviceId`
  /// call will see the empty slot and mint a fresh id.
  void invalidate() {
    _cached = null;
  }

  /// User-visible display name for `registerDevice`. We piggy-back on the
  /// existing LAN alias so a user who has personalised their LocalSend alias
  /// sees that name on the cloud side too. Subsequent renames go through
  /// the dedicated `renameDevice` callable (Epic 10).
  String defaultDisplayName() => aliasReader();

  /// Mobile platforms map to `phone`; desktops map to `desktop`. Tablets
  /// would be ideal on iPadOS but `defaultTargetPlatform` returns iOS for
  /// both — the user can change the icon from the settings tab in Epic 10.
  CloudDeviceIcon defaultIcon() {
    switch (_platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return CloudDeviceIcon.phone;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return CloudDeviceIcon.desktop;
      case TargetPlatform.fuchsia:
        return CloudDeviceIcon.other;
    }
  }

  CloudDevicePlatform currentPlatform() {
    switch (_platform) {
      case TargetPlatform.android:
        return CloudDevicePlatform.android;
      case TargetPlatform.iOS:
        return CloudDevicePlatform.ios;
      case TargetPlatform.macOS:
        return CloudDevicePlatform.macos;
      case TargetPlatform.windows:
        return CloudDevicePlatform.windows;
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return CloudDevicePlatform.linux;
    }
  }
}

String _defaultDeviceIdGenerator() => const Uuid().v4();

final deviceIdentityProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService(
    storage: ref.read(secureStorageProvider),
    aliasReader: () => ref.read(settingsProvider).alias,
  );
});
