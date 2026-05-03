import 'package:dart_mappable/dart_mappable.dart';

part 'send_link_notification_request.mapper.dart';

/// Mirrors `SendLinkNotificationInput` in firebase/functions/src/validation.ts.
/// The `mode` discriminator routes between the two Cloud Functions paths.
@MappableClass(discriminatorKey: 'mode')
sealed class SendLinkNotificationRequest with SendLinkNotificationRequestMappable {
  final String sourceDeviceId;
  final String targetDeviceId;

  const SendLinkNotificationRequest({
    required this.sourceDeviceId,
    required this.targetDeviceId,
  });
}

/// Visible FCM notification with a plaintext URL. The `url` must use the
/// `http` or `https` scheme (validated server-side). `title` is omitted from
/// the wire payload when null — the backend treats it as `string | undefined`.
@MappableClass(discriminatorValue: 'plaintext', ignoreNull: true)
class PlaintextLinkNotificationRequest extends SendLinkNotificationRequest with PlaintextLinkNotificationRequestMappable {
  final String url;
  final String? title;

  const PlaintextLinkNotificationRequest({
    required super.sourceDeviceId,
    required super.targetDeviceId,
    required this.url,
    this.title,
  });
}

/// Data-only FCM message carrying an encrypted URL payload.
@MappableClass(discriminatorValue: 'encrypted')
class EncryptedLinkNotificationRequest extends SendLinkNotificationRequest with EncryptedLinkNotificationRequestMappable {
  final String payload;

  const EncryptedLinkNotificationRequest({
    required super.sourceDeviceId,
    required super.targetDeviceId,
    required this.payload,
  });
}
