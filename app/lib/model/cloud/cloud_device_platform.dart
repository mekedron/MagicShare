import 'package:dart_mappable/dart_mappable.dart';

part 'cloud_device_platform.mapper.dart';

/// Mirrors `DEVICE_PLATFORMS` in firebase/functions/src/models.ts.
@MappableEnum()
enum CloudDevicePlatform {
  android,
  ios,
  macos,
  windows,
  linux,
}
