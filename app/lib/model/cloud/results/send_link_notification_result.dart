import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';

part 'send_link_notification_result.mapper.dart';

/// Mirrors `SendLinkNotificationResult` in firebase/functions/src/notifications.ts.
@MappableClass()
class SendLinkNotificationResult with SendLinkNotificationResultMappable {
  final bool delivered;
  final DeliveryChannel channel;

  const SendLinkNotificationResult({
    required this.delivered,
    required this.channel,
  });

  static const fromJson = SendLinkNotificationResultMapper.fromJson;
}
