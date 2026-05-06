import 'package:common/model/device.dart';

/// Discriminated payload for one packet observed by the multicast
/// listener. Most multicast traffic is a peer announcing or responding
/// — that flows through [MulticastDiscovered]. A peer that is
/// gracefully going offline (mobile lifecycle paused / hidden) sends a
/// `goodbye: true` packet which surfaces here as [MulticastGoodbye] so
/// the consumer can drop the entry immediately instead of waiting for
/// the LAN-side TTL to age it out.
sealed class MulticastEvent {
  const MulticastEvent();
}

class MulticastDiscovered extends MulticastEvent {
  final Device device;
  const MulticastDiscovered(this.device);
}

class MulticastGoodbye extends MulticastEvent {
  final String fingerprint;
  const MulticastGoodbye(this.fingerprint);
}
