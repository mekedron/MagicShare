import 'package:magicshare_app/model/cloud/inbox_item_type.dart';
import 'package:magicshare_app/model/cloud/plaintext_link_payload.dart';

/// Mirrors `PollPendingWakesItem` in firebase/functions/src/notifications.ts.
///
/// `payload` is either a base64 ciphertext [String] (wake items, encrypted
/// link items) or a [PlaintextLinkPayload] (plaintext-mode link items).
/// Hand-written instead of generated because dart_mappable doesn't model
/// the union type cleanly enough to be worth the boilerplate.
class InboxItem {
  final String id;
  final InboxItemType type;
  final Object payload;
  final int createdAtMs;
  final int expiresAtMs;

  const InboxItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAtMs,
    required this.expiresAtMs,
  });

  /// Returns the encrypted ciphertext blob, or null when this item carries
  /// a plaintext link.
  String? get encryptedPayload => payload is String ? payload as String : null;

  /// Returns the plaintext link payload, or null for encrypted items.
  PlaintextLinkPayload? get plaintextPayload => payload is PlaintextLinkPayload ? payload as PlaintextLinkPayload : null;

  factory InboxItem.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    final type = InboxItemType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => throw ArgumentError('Unknown InboxItemType: $rawType'),
    );
    final rawPayload = map['payload'];
    final Object payload;
    if (rawPayload is String) {
      payload = rawPayload;
    } else if (rawPayload is Map) {
      payload = PlaintextLinkPayload.fromJson(
        rawPayload.cast<String, dynamic>(),
      );
    } else {
      throw ArgumentError(
        'InboxItem.payload must be a String (ciphertext) or PlaintextLinkPayload map',
      );
    }
    return InboxItem(
      id: map['id'] as String,
      type: type,
      payload: payload,
      createdAtMs: (map['createdAtMs'] as num).toInt(),
      expiresAtMs: (map['expiresAtMs'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final dynamic encodedPayload = payload is PlaintextLinkPayload ? (payload as PlaintextLinkPayload).toJson() : payload;
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'payload': encodedPayload,
      'createdAtMs': createdAtMs,
      'expiresAtMs': expiresAtMs,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxItem &&
          other.id == id &&
          other.type == type &&
          other.payload == payload &&
          other.createdAtMs == createdAtMs &&
          other.expiresAtMs == expiresAtMs;

  @override
  int get hashCode => Object.hash(id, type, payload, createdAtMs, expiresAtMs);
}
