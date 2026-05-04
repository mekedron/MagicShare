/// Integration test (Epic 10): drives the device-group flows end-to-end
/// against the Firebase emulator.
///
/// The widget-level paths (section + dialogs) are covered by widget
/// tests; this suite exercises the cloud-side machinery they call —
/// renameDevice, setDeviceIcon, removeDevice, deleteAccount — plus the
/// destroy-then-rebootstrap chain (deleteAccount → auth.delete →
/// fresh anon sign-in → fresh account/device row under a new UID).
///
/// Run:
///
/// ```
/// cd firebase/functions && npm run dev   # emulator suite in another shell
/// cd app && flutter test integration_test/cloud_device_group_test.dart \
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

  testWidgets('renameDevice updates the device document', (tester) async {
    final ctx = await _registerOneDevice();

    await ctx.client.renameDevice(
      deviceId: ctx.deviceId,
      displayName: 'Renamed Macbook',
    );

    final snap = await FirebaseFirestore.instance.doc('accounts/${ctx.uid}/devices/${ctx.deviceId}').get();
    expect(snap.data()?['displayName'], 'Renamed Macbook');

    await ctx.cleanup();
  });

  testWidgets('setDeviceIcon updates the icon field', (tester) async {
    final ctx = await _registerOneDevice();

    await ctx.client.setDeviceIcon(
      deviceId: ctx.deviceId,
      icon: CloudDeviceIcon.tablet,
    );

    final snap = await FirebaseFirestore.instance.doc('accounts/${ctx.uid}/devices/${ctx.deviceId}').get();
    expect(snap.data()?['icon'], CloudDeviceIcon.tablet.name);

    await ctx.cleanup();
  });

  testWidgets('removeDevice deletes only the targeted device', (tester) async {
    await initializeFirebase(cloudSyncEnabled: true);
    await FirebaseAuth.instance.signOut();
    final uid = await _signInAnonymously();

    final client = CloudFunctionsClient();
    final deviceA = const Uuid().v4();
    final deviceB = const Uuid().v4();
    await client.createAccount();
    await client.registerDevice(
      deviceId: deviceA,
      displayName: 'Device A',
      icon: CloudDeviceIcon.laptop,
      platform: CloudDevicePlatform.macos,
      fcmToken: null,
    );
    await client.registerDevice(
      deviceId: deviceB,
      displayName: 'Device B',
      icon: CloudDeviceIcon.phone,
      platform: CloudDevicePlatform.android,
      fcmToken: null,
    );

    await client.removeDevice(deviceId: deviceB);

    final firestore = FirebaseFirestore.instance;
    final snapA = await firestore.doc('accounts/$uid/devices/$deviceA').get();
    final snapB = await firestore.doc('accounts/$uid/devices/$deviceB').get();
    expect(snapA.exists, isTrue, reason: 'untouched device must remain');
    expect(snapB.exists, isFalse, reason: 'removed device doc must vanish');

    final accountSnap = await firestore.doc('accounts/$uid').get();
    expect(accountSnap.exists, isTrue, reason: 'account survives — still has device A');

    await client.deleteAccount();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('removing the last device cascades to delete the account', (tester) async {
    final ctx = await _registerOneDevice();

    final result = await ctx.client.removeDevice(deviceId: ctx.deviceId);
    expect(result.accountDeleted, isTrue);

    final firestore = FirebaseFirestore.instance;
    final accountSnap = await firestore.doc('accounts/${ctx.uid}').get();
    expect(accountSnap.exists, isFalse, reason: 'cascading account delete on last device');

    await FirebaseAuth.instance.signOut();
  });

  testWidgets('destroy-then-rebootstrap gives a fresh UID + single device row', (tester) async {
    await initializeFirebase(cloudSyncEnabled: true);
    await FirebaseAuth.instance.signOut();
    final originalUid = await _signInAnonymously();

    final client = CloudFunctionsClient();
    final originalDeviceId = const Uuid().v4();
    await client.createAccount();
    await client.registerDevice(
      deviceId: originalDeviceId,
      displayName: 'Original',
      icon: CloudDeviceIcon.laptop,
      platform: CloudDevicePlatform.macos,
      fcmToken: null,
    );

    // Mirror what the destroy-group UI flow does: cloud wipe → auth user
    // deletion → fresh anon sign-in → fresh account/device under the new UID.
    await client.deleteAccount();
    await FirebaseAuth.instance.currentUser?.delete();

    final newUid = await _signInAnonymously();
    expect(newUid, isNot(originalUid), reason: 'fresh anon sign-in must yield a new UID');

    final newDeviceId = const Uuid().v4();
    final newCreate = await client.createAccount();
    expect(newCreate.created, isTrue);
    expect(newCreate.accountId, newUid);
    await client.registerDevice(
      deviceId: newDeviceId,
      displayName: 'Fresh',
      icon: CloudDeviceIcon.desktop,
      platform: CloudDevicePlatform.macos,
      fcmToken: null,
    );

    final firestore = FirebaseFirestore.instance;
    // Old account is gone.
    final oldAccountSnap = await firestore.doc('accounts/$originalUid').get();
    expect(oldAccountSnap.exists, isFalse, reason: 'old account must be wiped');

    // New account has exactly one device, and it's the new one.
    final newAccountSnap = await firestore.doc('accounts/$newUid').get();
    expect(newAccountSnap.exists, isTrue);
    expect(newAccountSnap.data()?['deviceCount'], 1);
    final newDevices = await firestore.collection('accounts/$newUid/devices').get();
    expect(newDevices.docs.map((d) => d.id), [newDeviceId]);

    await client.deleteAccount();
    await FirebaseAuth.instance.currentUser?.delete();
    await FirebaseAuth.instance.signOut();
  });
}

class _Ctx {
  _Ctx({required this.uid, required this.deviceId, required this.client});
  final String uid;
  final String deviceId;
  final CloudFunctionsClient client;

  Future<void> cleanup() async {
    try {
      await client.deleteAccount();
    } catch (_) {
      // Account may already be gone — best-effort cleanup.
    }
    await FirebaseAuth.instance.signOut();
  }
}

Future<_Ctx> _registerOneDevice() async {
  await initializeFirebase(cloudSyncEnabled: true);
  await FirebaseAuth.instance.signOut();
  final uid = await _signInAnonymously();
  final client = CloudFunctionsClient();
  final deviceId = const Uuid().v4();
  await client.createAccount();
  await client.registerDevice(
    deviceId: deviceId,
    displayName: 'Macbook',
    icon: CloudDeviceIcon.laptop,
    platform: CloudDevicePlatform.macos,
    fcmToken: null,
  );
  return _Ctx(uid: uid, deviceId: deviceId, client: client);
}

Future<String> _signInAnonymously() async {
  final auth = FirebaseAuth.instance;
  final emit = auth.userChanges().where((u) => u != null).map((u) => u!.uid).first;
  unawaited(auth.signInAnonymously());
  return emit.timeout(const Duration(seconds: 5));
}
