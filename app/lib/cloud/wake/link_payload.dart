import 'package:dart_mappable/dart_mappable.dart';

part 'link_payload.mapper.dart';

/// Plaintext shape of an encrypted link-notification payload before it
/// is encrypted with the device-group key and base64-encoded for
/// `sendLinkNotification` (encrypted mode).
///
/// On the wire this is the same envelope shape as the backend's
/// `PlaintextLinkPayload` (`url, title?`); the difference is solely
/// whether the cloud function sees it directly (plaintext mode) or
/// only an opaque ciphertext (encrypted mode).
@MappableClass(ignoreNull: true)
class LinkPayload with LinkPayloadMappable {
  final String url;
  final String? title;

  const LinkPayload({
    required this.url,
    this.title,
  });

  static const fromJson = LinkPayloadMapper.fromJson;
}
