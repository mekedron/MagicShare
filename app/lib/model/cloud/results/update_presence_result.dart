import 'package:dart_mappable/dart_mappable.dart';

part 'update_presence_result.mapper.dart';

/// Mirrors `UpdatePresenceResult` in firebase/functions/src/devices.ts.
@MappableClass()
class UpdatePresenceResult with UpdatePresenceResultMappable {
  /// False when the call was rate-limited (the device was last updated
  /// less than the rate-limit window ago) and the write was skipped.
  final bool updated;

  const UpdatePresenceResult({
    required this.updated,
  });

  static const fromJson = UpdatePresenceResultMapper.fromJson;
}
