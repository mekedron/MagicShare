import 'package:dart_mappable/dart_mappable.dart';

part 'plaintext_link_payload.mapper.dart';

/// Mirrors `PlaintextLinkPayload` in firebase/functions/src/models.ts.
/// Backend treats `title` as `string | undefined` — null must be omitted on
/// the wire, hence ignoreNull.
@MappableClass(ignoreNull: true)
class PlaintextLinkPayload with PlaintextLinkPayloadMappable {
  final String url;
  final String? title;

  const PlaintextLinkPayload({
    required this.url,
    this.title,
  });

  static const fromJson = PlaintextLinkPayloadMapper.fromJson;
}
