/// Integration test (Epic 13): drives the full wake → P2P-bridge
/// pipeline against the Firebase emulator.
///
/// 1. Sender mints a wake nonce, encrypts a [WakePayload] with the
///    group key, and calls `sendWake` against the emulator.
/// 2. Receiver (registered as Linux so the dispatch falls back to the
///    Firestore `inbox`) reads it back via `pollPendingWakes`.
/// 3. The inbox payload is fed through [CloudMessageDispatcher] to
///    obtain a [WakeMessage], registered in a [WakeNonceRegistry] —
///    matching exactly what the foreground listener does in
///    production.
/// 4. We assert single-use consume + that a non-matching wakeSessionId
///    falls back to the standard prompt path (`consume` returns false).
///
/// This proves the cloud → FCM-stub → decrypt → registry pipeline
/// works end-to-end. The receive controller's HTTP-server integration
/// is exercised by the manual smoke checklist (Epic 15) and the
/// existing receive_controller wake-session unit coverage from
/// commit 2.
///
/// Run with the emulator suite running on localhost:
///
/// ```
/// cd firebase/functions && npm run dev    # in another terminal
/// cd app && flutter test integration_test/cloud_wake_auto_accept_test.dart \
///     --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/wake/cloud_message.dart';
import 'package:magicshare_app/cloud/wake/cloud_message_dispatcher.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_registry.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';
import 'package:magicshare_app/config/cloud/firebase_init.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/inbox_item_type.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'sendWake → inbox → dispatcher → registry pipeline auto-accepts a matching nonce',
    (tester) async {
      await initializeFirebase(cloudSyncEnabled: true);
      await FirebaseAuth.instance.signOut();
      await _signInAnonymously();

      final client = CloudFunctionsClient();
      final senderId = const Uuid().v4();
      final receiverId = const Uuid().v4();

      await client.createAccount();
      await client.registerDevice(
        deviceId: senderId,
        displayName: 'Sender',
        icon: CloudDeviceIcon.laptop,
        platform: CloudDevicePlatform.macos,
        fcmToken: 'fcm-sender',
        fingerprint: 'fp-sender',
      );
      // Linux receiver: no fcmToken, so sendWake routes through the
      // `inbox` collection — pollPendingWakes is the playback channel.
      await client.registerDevice(
        deviceId: receiverId,
        displayName: 'Linux receiver',
        icon: CloudDeviceIcon.headless,
        platform: CloudDevicePlatform.linux,
        fcmToken: null,
        fingerprint: 'fp-receiver',
      );

      // Sender side: build the wake payload exactly as
      // `wake_orchestrator.start()` does in production.
      final groupKey = Uint8List.fromList(List<int>.generate(32, (i) => 0x33));
      final nonce = generateWakeSessionNonce();
      final payload = WakePayload(
        sessionNonce: nonce,
        sourceFingerprint: 'fp-sender',
        initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final wire = encodeWakePayload(payload, groupKey);

      // Cloud round-trip.
      final sendResult = await client.sendWake(
        sourceDeviceId: senderId,
        targetDeviceId: receiverId,
        payload: wire,
      );
      expect(sendResult.delivered, isTrue);

      // Receiver side: read the inbox item, dispatch, register.
      final pending = await client.pollPendingWakes(deviceId: receiverId);
      expect(pending.items, hasLength(1));
      final item = pending.items.single;
      expect(item.type, InboxItemType.wake);
      expect(item.encryptedPayload, isNotNull);

      const dispatcher = CloudMessageDispatcher();
      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': item.encryptedPayload!},
        groupKey: groupKey,
      );
      expect(result, isA<WakeMessage>());
      final wake = result as WakeMessage;
      expect(wake.nonce, nonce);

      // Mirror what the foreground listener does on a wake event.
      final registry = WakeNonceRegistry();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(wake.initiatedAtMs).add(const Duration(minutes: 2));
      registry.register(wake.nonce, expiresAt);

      // The receive controller's auto-accept hook calls consume() with
      // the upload-request's wakeSessionId. Matching → auto-accept.
      expect(
        registry.consume(nonce),
        isTrue,
        reason: 'wakeSessionId from prepareUpload matches the registered nonce',
      );
      // Single-use: a replay attempt finds nothing.
      expect(
        registry.consume(nonce),
        isFalse,
        reason: 'a peer that learns the nonce cannot replay it',
      );

      await client.deleteAccount();
      await FirebaseAuth.instance.signOut();
    },
  );

  testWidgets(
    'a prepareUpload without a matching wakeSessionId falls back to the standard prompt path',
    (tester) async {
      await initializeFirebase(cloudSyncEnabled: true);
      await FirebaseAuth.instance.signOut();
      await _signInAnonymously();

      final client = CloudFunctionsClient();
      final senderId = const Uuid().v4();
      final receiverId = const Uuid().v4();

      await client.createAccount();
      await client.registerDevice(
        deviceId: senderId,
        displayName: 'Sender',
        icon: CloudDeviceIcon.laptop,
        platform: CloudDevicePlatform.macos,
        fcmToken: 'fcm-sender-2',
        fingerprint: 'fp-sender-2',
      );
      await client.registerDevice(
        deviceId: receiverId,
        displayName: 'Linux receiver',
        icon: CloudDeviceIcon.headless,
        platform: CloudDevicePlatform.linux,
        fcmToken: null,
        fingerprint: 'fp-receiver-2',
      );

      final groupKey = Uint8List.fromList(List<int>.generate(32, (i) => 0x77));
      final nonce = generateWakeSessionNonce();
      final payload = WakePayload(
        sessionNonce: nonce,
        sourceFingerprint: 'fp-sender-2',
        initiatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final wire = encodeWakePayload(payload, groupKey);
      await client.sendWake(
        sourceDeviceId: senderId,
        targetDeviceId: receiverId,
        payload: wire,
      );

      final pending = await client.pollPendingWakes(deviceId: receiverId);
      const dispatcher = CloudMessageDispatcher();
      final result = dispatcher.dispatch(
        <String, dynamic>{'type': 'wake', 'payload': pending.items.single.encryptedPayload!},
        groupKey: groupKey,
      );
      final wake = result as WakeMessage;
      final registry = WakeNonceRegistry();
      registry.register(
        wake.nonce,
        DateTime.fromMillisecondsSinceEpoch(wake.initiatedAtMs).add(const Duration(minutes: 2)),
      );

      // Now simulate a stock-LocalSend prepareUpload (no wakeSessionId)
      // and a MagicShare prepareUpload with a *different* wakeSessionId.
      // Neither should consume the registered nonce.
      expect(registry.consume('not-a-match'), isFalse);
      expect(registry.consume('completely-unrelated'), isFalse);
      // The legitimate sender's prepareUpload still auto-accepts.
      expect(registry.consume(nonce), isTrue);

      await client.deleteAccount();
      await FirebaseAuth.instance.signOut();
    },
  );
}

Future<String> _signInAnonymously() async {
  final auth = FirebaseAuth.instance;
  final emit = auth.userChanges().where((u) => u != null).map((u) => u!.uid).first;
  unawaited(auth.signInAnonymously());
  return emit.timeout(const Duration(seconds: 5));
}
