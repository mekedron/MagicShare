import 'package:dart_mappable/dart_mappable.dart';

part 'cloud_device_presence.mapper.dart';

/// Mirrors `DevicePresence` in firebase/functions/src/models.ts.
@MappableEnum(defaultValue: CloudDevicePresence.offline)
enum CloudDevicePresence {
  online,
  offline,
}
