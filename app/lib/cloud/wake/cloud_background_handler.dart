import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/wake/cloud_message.dart';
import 'package:magicshare_app/cloud/wake/cloud_message_dispatcher.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_persistence.dart';
import 'package:magicshare_app/firebase_options.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';

final _logger = Logger('CloudBackgroundHandler');

/// Two minutes — matches the receiver-side expected-nonce window in
/// `cloud-sync-spec.md` §5.3.
const Duration _wakeNonceTtl = Duration(minutes: 2);

/// Top-level entry point for FCM background messages.
///
/// **Must** be a top-level function annotated `@pragma('vm:entry-point')`
/// — release-mode tree-shaking eats it otherwise. Registered via
/// `FirebaseMessaging.onBackgroundMessage(cloudBackgroundMessageHandler)`
/// in `main.dart` before `runApp`.
///
/// Runs in a separate isolate, so it cannot reach the refena container,
/// the in-memory [WakeNonceRegistry], or any UI. It decrypts the
/// payload using the secure-storage-backed group key and persists the
/// resulting wake nonce in [WakeNoncePersistence] so the main isolate
/// picks it up on next foreground / app start.
@pragma('vm:entry-point')
Future<void> cloudBackgroundMessageHandler(RemoteMessage message) async {
  await _ensureFirebase();
  await handleCloudBackgroundMessage(
    message,
    readGroupKey: _readGroupKeyFromSecureStorage,
  );
}

/// Pure (no platform-channel coupling) implementation. Exposed for unit
/// tests; real callers go through [cloudBackgroundMessageHandler].
@visibleForTesting
Future<void> handleCloudBackgroundMessage(
  RemoteMessage message, {
  required Future<Uint8List?> Function() readGroupKey,
  WakeNoncePersistence persistence = const WakeNoncePersistence(),
  CloudMessageDispatcher dispatcher = const CloudMessageDispatcher(),
  DateTime Function() now = DateTime.now,
}) async {
  Uint8List? groupKey;
  try {
    groupKey = await readGroupKey();
  } catch (e, st) {
    _logger.warning('Reading group key in background isolate failed', e, st);
    return;
  }

  final data = Map<String, dynamic>.from(message.data);
  final result = dispatcher.dispatch(data, groupKey: groupKey);

  switch (result) {
    case WakeMessage():
      try {
        final senderExpiry = DateTime.fromMillisecondsSinceEpoch(result.initiatedAtMs).add(_wakeNonceTtl);
        final cap = now().add(_wakeNonceTtl);
        final boundedExpiry = senderExpiry.isAfter(cap) ? cap : senderExpiry;
        if (!boundedExpiry.isAfter(now())) {
          _logger.info('Background wake nonce already expired, dropping');
          return;
        }
        await persistence.append(result.nonce, boundedExpiry);
        _logger.info(
          'Background isolate persisted wake nonce (expires '
          '${boundedExpiry.toIso8601String()})',
        );
      } catch (e, st) {
        _logger.warning('Persisting background wake nonce failed', e, st);
      }
    case LinkMessage():
      // The encrypted-link tap surface (a local notification whose tap
      // opens the URL) lands in the next commit, alongside the
      // flutter_local_notifications dep. Plaintext-mode links arrive
      // with an FCM `notification` field, which the OS surfaces
      // directly; the foreground listener picks up the tap via
      // onMessageOpenedApp / getInitialMessage.
      _logger.fine('Background link message received; deferring to UI');
    case CloudMessageError():
      _logger.fine('Background dispatcher error: ${result.reason}');
  }
}

Future<void> _ensureFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

Future<Uint8List?> _readGroupKeyFromSecureStorage() async {
  final storage = SecureStorageService();
  final stored = await storage.read(cloudGroupKeyKey);
  if (stored == null || stored.isEmpty) return null;
  final bytes = Uint8List.fromList(base64Decode(stored));
  if (bytes.length != groupKeyLengthBytes) return null;
  return bytes;
}
