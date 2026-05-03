import 'package:dart_mappable/dart_mappable.dart';

part 'cloud_device_icon.mapper.dart';

/// Mirrors `DEVICE_ICONS` in firebase/functions/src/models.ts.
/// Wire format is the lowercase enum name.
@MappableEnum(defaultValue: CloudDeviceIcon.other)
enum CloudDeviceIcon {
  laptop,
  desktop,
  phone,
  tablet,
  server,
  headless,
  other,
}
