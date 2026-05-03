import 'package:dart_mappable/dart_mappable.dart';

part 'cloud_account.mapper.dart';

/// Mirrors `AccountDoc` in firebase/functions/src/models.ts. Timestamp fields
/// are encoded as integer milliseconds since the Unix epoch on the wire.
@MappableClass()
class CloudAccount with CloudAccountMappable {
  final String accountId;
  final int createdAtMs;
  final int lastActiveAtMs;
  final int deviceCount;

  const CloudAccount({
    required this.accountId,
    required this.createdAtMs,
    required this.lastActiveAtMs,
    required this.deviceCount,
  });

  static const fromJson = CloudAccountMapper.fromJson;
}
