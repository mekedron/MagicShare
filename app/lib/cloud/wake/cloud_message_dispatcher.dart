import 'dart:typed_data';

import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/wake/cloud_message.dart';
import 'package:magicshare_app/cloud/wake/link_payload_codec.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';

/// Stateless decoder for the FCM data maps produced by `sendWake` and
/// `sendLinkNotification`. Mirrors the wire shape defined in
/// `firebase/functions/src/notifications.ts buildWakeFcmMessage` /
/// `buildLinkFcmMessage`.
///
/// Returns a [CloudMessage] subclass; never throws. Callers (foreground
/// listener, background handler, Linux poller in Epic 16) inspect the
/// result and act on it.
class CloudMessageDispatcher {
  const CloudMessageDispatcher();

  /// Decodes [data] using [groupKey] for any encrypted ciphertext.
  /// [groupKey] may be null when the only thing in flight is a
  /// plaintext-mode link notification — in that case wake / encrypted
  /// link items return a [CloudMessageError].
  CloudMessage dispatch(Map<String, dynamic> data, {Uint8List? groupKey}) {
    final type = data['type'];
    if (type is! String) {
      return const CloudMessageError('missing or non-string `type` field');
    }
    switch (type) {
      case 'wake':
        return _dispatchWake(data, groupKey);
      case 'link':
        return _dispatchLink(data, groupKey);
      default:
        return CloudMessageError('unknown message type: $type');
    }
  }

  CloudMessage _dispatchWake(Map<String, dynamic> data, Uint8List? groupKey) {
    final payload = data['payload'];
    if (payload is! String || payload.isEmpty) {
      return const CloudMessageError('wake message missing string `payload`');
    }
    if (groupKey == null) {
      return const CloudMessageError('wake message arrived but no group key on this device');
    }
    try {
      final decoded = decodeWakePayload(payload, groupKey);
      return WakeMessage(
        nonce: decoded.sessionNonce,
        sourceFingerprint: decoded.sourceFingerprint,
        initiatedAtMs: decoded.initiatedAtMs,
      );
    } on GroupKeyAuthFailure catch (e) {
      return CloudMessageError('wake payload failed authentication tag', cause: e);
    } catch (e) {
      return CloudMessageError('wake payload could not be decoded', cause: e);
    }
  }

  CloudMessage _dispatchLink(Map<String, dynamic> data, Uint8List? groupKey) {
    // Encrypted mode: opaque base64 ciphertext under `payload`.
    final encrypted = data['payload'];
    if (encrypted is String && encrypted.isNotEmpty) {
      if (groupKey == null) {
        return const CloudMessageError('encrypted link message arrived but no group key on this device');
      }
      try {
        final decoded = decodeLinkPayload(encrypted, groupKey);
        return LinkMessage(url: decoded.url, title: decoded.title);
      } on GroupKeyAuthFailure catch (e) {
        return CloudMessageError('encrypted link payload failed authentication tag', cause: e);
      } catch (e) {
        return CloudMessageError('encrypted link payload could not be decoded', cause: e);
      }
    }

    // Plaintext mode: `url` (and optional `title`) live directly in the
    // FCM data map. Mirrors `PlaintextLinkPayload` on the backend.
    final url = data['url'];
    if (url is! String || url.isEmpty) {
      return const CloudMessageError('link message missing both `payload` and `url`');
    }
    final title = data['title'];
    return LinkMessage(url: url, title: title is String ? title : null);
  }
}
