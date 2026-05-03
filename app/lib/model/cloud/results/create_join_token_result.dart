import 'package:dart_mappable/dart_mappable.dart';

part 'create_join_token_result.mapper.dart';

/// Mirrors `CreateJoinTokenResult` in firebase/functions/src/pairing.ts.
@MappableClass()
class CreateJoinTokenResult with CreateJoinTokenResultMappable {
  final String tokenId;
  final int expiresAtMs;

  const CreateJoinTokenResult({
    required this.tokenId,
    required this.expiresAtMs,
  });

  static const fromJson = CreateJoinTokenResultMapper.fromJson;
}
