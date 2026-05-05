import 'dart:convert';
import 'dart:typed_data';

import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/wake/link_payload.dart';

/// Encrypts [payload] with [groupKey] and returns the base64 wire form
/// expected by `sendLinkNotification.payload` in encrypted mode.
String encodeLinkPayload(LinkPayload payload, Uint8List groupKey) {
  final plaintext = utf8.encode(jsonEncode(payload.toJson()));
  final encrypted = encryptWithGroupKey(groupKey, Uint8List.fromList(plaintext));
  return base64Encode(encrypted);
}

/// Decrypts the wire form produced by [encodeLinkPayload]. Throws
/// [GroupKeyAuthFailure] on tag mismatch.
LinkPayload decodeLinkPayload(String wire, Uint8List groupKey) {
  final blob = Uint8List.fromList(base64Decode(wire));
  final plaintext = decryptWithGroupKey(groupKey, blob);
  final decoded = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
  return LinkPayload.fromJson(decoded);
}
