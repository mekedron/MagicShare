import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/join_token_preview.dart';

part 'preview_join_token_result.mapper.dart';

/// Mirrors `PreviewJoinTokenResult` in firebase/functions/src/pairing.ts.
@MappableClass()
class PreviewJoinTokenResult with PreviewJoinTokenResultMappable {
  final String accountId;
  final String issuingDeviceId;
  final int expiresAtMs;
  final List<JoinTokenPreviewDevice> devices;

  const PreviewJoinTokenResult({
    required this.accountId,
    required this.issuingDeviceId,
    required this.expiresAtMs,
    required this.devices,
  });

  static const fromJson = PreviewJoinTokenResultMapper.fromJson;
}
