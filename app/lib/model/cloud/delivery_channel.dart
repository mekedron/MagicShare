import 'package:dart_mappable/dart_mappable.dart';

part 'delivery_channel.mapper.dart';

/// Mirrors the `channel` field returned by `sendWake` / `sendLinkNotification`.
/// `fcm`: dispatched via FCM data message.
/// `inbox`: written to Firestore inbox for the Linux polling fallback.
/// `none`: target was reachable by neither route.
@MappableEnum(defaultValue: DeliveryChannel.none)
enum DeliveryChannel {
  fcm,
  inbox,
  none,
}
