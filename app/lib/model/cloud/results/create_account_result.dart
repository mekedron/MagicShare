import 'package:dart_mappable/dart_mappable.dart';

part 'create_account_result.mapper.dart';

/// Mirrors `CreateAccountResult` in firebase/functions/src/accounts.ts.
@MappableClass()
class CreateAccountResult with CreateAccountResultMappable {
  /// True when the account document was newly created on this call;
  /// false if it already existed (the callable is idempotent).
  final bool created;
  final String accountId;

  const CreateAccountResult({
    required this.created,
    required this.accountId,
  });

  static const fromJson = CreateAccountResultMapper.fromJson;
}
