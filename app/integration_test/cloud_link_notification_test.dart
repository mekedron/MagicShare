/// Integration test (Epic 12, Subtask 3): URL fast-path against the
/// Firebase emulator. Drives both `sendLinkNotification` modes
/// (plaintext + encrypted) end-to-end and asserts the dispatch result
/// and inbox shape on the receiving side.
///
/// Run with the emulator suite running on localhost:
///
/// ```
/// cd firebase/functions && npm run dev    # in another terminal
/// cd app && flutter test integration_test/cloud_link_notification_test.dart \
///     --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/wake/link_payload.dart';
import 'package:magicshare_app/cloud/wake/link_payload_codec.dart';
import 'package:magicshare_app/config/cloud/firebase_init.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/inbox_item_type.dart';
import 'package:magicshare_app/model/cloud/requests/send_link_notification_request.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plaintext sendLinkNotification queues a Linux inbox item with url + title', (
    tester,
  ) async {
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
    // Receiver is registered as Linux: no fcmToken, so the dispatch path
    // falls back to the Firestore `inbox` and the Linux-poll callable
    // can read it back.
    await client.registerDevice(
      deviceId: receiverId,
      displayName: 'Linux receiver',
      icon: CloudDeviceIcon.headless,
      platform: CloudDevicePlatform.linux,
      fcmToken: null,
      fingerprint: 'fp-receiver',
    );

    final result = await client.sendLinkNotification(
      PlaintextLinkNotificationRequest(
        sourceDeviceId: senderId,
        targetDeviceId: receiverId,
        url: 'https://example.com/article',
        title: 'Example',
      ),
    );
    expect(result.delivered, isTrue);

    final pending = await client.pollPendingWakes(deviceId: receiverId);
    expect(pending.items, hasLength(1));
    final item = pending.items.single;
    expect(item.type, InboxItemType.link);
    expect(item.plaintextPayload?.url, 'https://example.com/article');
    expect(item.plaintextPayload?.title, 'Example');
    expect(item.encryptedPayload, isNull);

    await client.deleteAccount();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('encrypted sendLinkNotification round-trips the URL through AES-GCM', (
    tester,
  ) async {
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
      fingerprint: 'fp-sender-enc',
    );
    await client.registerDevice(
      deviceId: receiverId,
      displayName: 'Linux receiver',
      icon: CloudDeviceIcon.headless,
      platform: CloudDevicePlatform.linux,
      fcmToken: null,
      fingerprint: 'fp-receiver-enc',
    );

    final groupKey = Uint8List.fromList(List<int>.generate(32, (i) => 0x42));
    const payload = LinkPayload(url: 'https://example.com/encrypted', title: 'Secret link');
    final wire = encodeLinkPayload(payload, groupKey);

    final result = await client.sendLinkNotification(
      EncryptedLinkNotificationRequest(
        sourceDeviceId: senderId,
        targetDeviceId: receiverId,
        payload: wire,
      ),
    );
    expect(result.delivered, isTrue);

    final pending = await client.pollPendingWakes(deviceId: receiverId);
    expect(pending.items, hasLength(1));
    final item = pending.items.single;
    expect(item.type, InboxItemType.link);
    expect(item.plaintextPayload, isNull);
    expect(item.encryptedPayload, isNotNull);
    final decoded = decodeLinkPayload(item.encryptedPayload!, groupKey);
    expect(decoded.url, 'https://example.com/encrypted');
    expect(decoded.title, 'Secret link');

    await client.deleteAccount();
    await FirebaseAuth.instance.signOut();
  });
}

Future<String> _signInAnonymously() async {
  final auth = FirebaseAuth.instance;
  final emit = auth.userChanges().where((u) => u != null).map((u) => u!.uid).first;
  unawaited(auth.signInAnonymously());
  return emit.timeout(const Duration(seconds: 5));
}
