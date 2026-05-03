import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';

part 'send_wake_result.mapper.dart';

/// Mirrors `SendWakeResult` in firebase/functions/src/notifications.ts.
@MappableClass()
class SendWakeResult with SendWakeResultMappable {
  final bool delivered;
  final DeliveryChannel channel;

  const SendWakeResult({
    required this.delivered,
    required this.channel,
  });

  static const fromJson = SendWakeResultMapper.fromJson;
}
