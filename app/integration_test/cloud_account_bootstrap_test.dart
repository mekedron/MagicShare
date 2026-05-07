/// Integration test (Epic 8): bootstrap flow against the Firebase emulator.
/// Drives `createAccount` → `registerDevice` end-to-end and asserts both
/// Firestore docs exist. Re-runs the same flow and asserts idempotency.
///
/// Run with the emulator suite running on localhost:
///
/// ```
/// cd firebase/functions && npm run dev    # in another terminal
/// cd app && flutter test integration_test/cloud_account_bootstrap_test.dart \
///     --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/config/cloud/firebase_init.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('createAccount + registerDevice produce both Firestore docs within ~3 s', (
    tester,
  ) async {
    await initializeFirebase(cloudSyncEnabled: true);
    await FirebaseAuth.instance.signOut();

    final uid = await _signInAnonymously();
    expect(uid, isNotEmpty);

    final client = CloudFunctionsClient();
    final deviceId = const Uuid().v4();

    final stopwatch = Stopwatch()..start();
    final created = await client.createAccount();
    expect(created.created, isTrue);
    expect(created.accountId, uid);

    final reg = await client.registerDevice(
      deviceId: deviceId,
      displayName: 'integration-test-device',
      icon: CloudDeviceIcon.phone,
      platform: CloudDevicePlatform.android,
      fcmToken: null,
      fingerprint: null,
    );
    expect(reg.created, isTrue);
    stopwatch.stop();

    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 3)),
      reason: 'Bootstrap callables took ${stopwatch.elapsed} — expected <3 s.',
    );

    final firestore = FirebaseFirestore.instance;
    final accountDoc = await firestore.doc('accounts/$uid').get();
    expect(accountDoc.exists, isTrue);
    expect(accountDoc.data()?['deviceCount'], 1);

    final deviceDoc = await firestore.doc('accounts/$uid/devices/$deviceId').get();
    expect(deviceDoc.exists, isTrue);
    expect(deviceDoc.data()?['displayName'], 'integration-test-device');
    expect(deviceDoc.data()?['platform'], CloudDevicePlatform.android.name);

    // Cleanup so re-running the suite from scratch is a clean slate.
    await client.deleteAccount();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('re-running bootstrap against an existing account is idempotent', (tester) async {
    await initializeFirebase(cloudSyncEnabled: true);
    await FirebaseAuth.instance.signOut();
    final uid = await _signInAnonymously();

    final client = CloudFunctionsClient();
    final deviceId = const Uuid().v4();

    final firstCreate = await client.createAccount();
    expect(firstCreate.created, isTrue);
    await client.registerDevice(
      deviceId: deviceId,
      displayName: 'first-run',
      icon: CloudDeviceIcon.desktop,
      platform: CloudDevicePlatform.macos,
      fcmToken: 'fcm-1',
      fingerprint: null,
    );

    // Snapshot the first registration timestamp to gate the second
    // registration's idempotency check.
    final firstSnap = await FirebaseFirestore.instance.doc('accounts/$uid/devices/$deviceId').get();
    expect(firstSnap.exists, isTrue, reason: 'first register must persist a device doc');

    // Simulate the next launch: same UID, same deviceId, fresh callable round.
    final secondCreate = await client.createAccount();
    expect(secondCreate.created, isFalse, reason: 'createAccount must be idempotent');

    await client.registerDevice(
      deviceId: deviceId,
      displayName: 'first-run',
      icon: CloudDeviceIcon.desktop,
      platform: CloudDevicePlatform.macos,
      fcmToken: 'fcm-1',
      fingerprint: null,
    );

    final accountSnap = await FirebaseFirestore.instance.doc('accounts/$uid').get();
    expect(accountSnap.data()?['deviceCount'], 1, reason: 'no double-counting');

    final secondSnap = await FirebaseFirestore.instance.doc('accounts/$uid/devices/$deviceId').get();
    expect(secondSnap.exists, isTrue, reason: 'second register must keep the device doc alive');

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
