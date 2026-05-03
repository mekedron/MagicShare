import 'package:dart_mappable/dart_mappable.dart';

part 'delete_account_result.mapper.dart';

/// Mirrors `DeleteAccountResult` in firebase/functions/src/accounts.ts.
@MappableClass()
class DeleteAccountResult with DeleteAccountResultMappable {
  final bool deleted;

  const DeleteAccountResult({
    required this.deleted,
  });

  static const fromJson = DeleteAccountResultMapper.fromJson;
}
