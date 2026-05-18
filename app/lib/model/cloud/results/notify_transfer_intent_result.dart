import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';

part 'notify_transfer_intent_result.mapper.dart';

/// Mirrors `NotifyTransferIntentResult` in firebase/functions/src/transfer-notify.ts.
@MappableClass()
class NotifyTransferIntentResult with NotifyTransferIntentResultMappable {
  final bool delivered;
  final DeliveryChannel channel;

  const NotifyTransferIntentResult({
    required this.delivered,
    required this.channel,
  });

  static const fromJson = NotifyTransferIntentResultMapper.fromJson;
}
