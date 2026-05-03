import 'package:dart_mappable/dart_mappable.dart';

part 'register_device_result.mapper.dart';

/// Mirrors `RegisterDeviceResult` in firebase/functions/src/devices.ts.
@MappableClass()
class RegisterDeviceResult with RegisterDeviceResultMappable {
  /// True when this device was newly registered; false if the document
  /// already existed and was updated in place.
  final bool created;

  const RegisterDeviceResult({
    required this.created,
  });

  static const fromJson = RegisterDeviceResultMapper.fromJson;
}
