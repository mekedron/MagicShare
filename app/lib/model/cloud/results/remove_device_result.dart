import 'package:dart_mappable/dart_mappable.dart';

part 'remove_device_result.mapper.dart';

/// Mirrors `RemoveDeviceResult` in firebase/functions/src/devices.ts.
@MappableClass()
class RemoveDeviceResult with RemoveDeviceResultMappable {
  /// True when removing the device emptied the parent account, which
  /// causes the backend to delete the account document in the same
  /// transaction.
  final bool accountDeleted;

  const RemoveDeviceResult({
    required this.accountDeleted,
  });

  static const fromJson = RemoveDeviceResultMapper.fromJson;
}
