import 'package:dart_mappable/dart_mappable.dart';

part 'delivery_channel.mapper.dart';

/// Mirrors the `channel` field returned by `notifyTransferIntent`.
///
/// `fcm` — visible notification published via FCM.
/// `none` — target has no FCM token registered (Linux, or stale install).
@MappableEnum(defaultValue: DeliveryChannel.none)
enum DeliveryChannel {
  fcm,
  none,
}
