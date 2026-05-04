/// Integration test (Epic 11): drives the cloud-side pairing flow
/// against the Firebase emulator. The LAN handshake half is covered
/// by the in-process unit tests at
/// `test/unit/cloud/pairing/pairing_lan_handshake_test.dart`; this
/// suite verifies the end-to-end Firestore + Auth orchestration that
/// the Flutter UI runs on top of.
///
/// Run:
///
/// ```
/// cd firebase/functions && npm run dev   # emulator suite in another shell
/// cd app && flutter test integration_test/cloud_pairing_test.dart \
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
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('end-to-end: issuer mints token, joiner consumes it, joiner re-auths to target accountId', (tester) async {
    final issuerCtx = await _bootstrapIssuer();

    // Issuer mints the token while signed in as itself — the
    // cloud function checks accounts/{auth.uid}/devices/{issuingDeviceId},
    // so the auth context must match the issuing device's owner.
    final tokenResult = await issuerCtx.client.createJoinToken(
      issuingDeviceId: issuerCtx.deviceId,
    );

    // Now switch to the joiner.
    await FirebaseAuth.instance.signOut();
    final joinerUid = await _signInAnonymously();
    expect(joinerUid, isNot(issuerCtx.uid));

    final joinerClient = CloudFunctionsClient();
    final joinerDeviceId = const Uuid().v4();

    // Joiner mints its own account + device first.
    await joinerClient.createAccount();
    await joinerClient.registerDevice(
      deviceId: joinerDeviceId,
      displayName: 'Joiner phone',
      icon: CloudDeviceIcon.phone,
      platform: CloudDevicePlatform.android,
      fcmToken: 'fcm-joiner',
    );

    // Joiner previews + joins.
    final preview = await joinerClient.previewJoinToken(tokenId: tokenResult.tokenId);
    expect(preview.accountId, issuerCtx.uid);
    expect(preview.devices.map((d) => d.deviceId), [issuerCtx.deviceId]);

    final joinResult = await joinerClient.joinNetwork(
      tokenId: tokenResult.tokenId,
      deviceId: joinerDeviceId,
    );
    expect(joinResult.accountId, issuerCtx.uid);
    // Joiner had only one device (its own); old account should be destroyed.
    expect(joinResult.oldAccountDeleted, isTrue);
    expect(joinResult.devices.map((d) => d.deviceId).toSet(), {
      issuerCtx.deviceId,
      joinerDeviceId,
    });
    expect(joinResult.customToken, isNotEmpty);

    // 3. Joiner re-auths with the custom token. auth.uid should now
    //    equal the issuer's accountId.
    await FirebaseAuth.instance.signInWithCustomToken(joinResult.customToken);
    expect(FirebaseAuth.instance.currentUser?.uid, issuerCtx.uid);

    // 4. Firestore reads under the new account path now succeed.
    final firestore = FirebaseFirestore.instance;
    final issuerAccountSnap = await firestore.doc('accounts/${issuerCtx.uid}').get();
    expect(issuerAccountSnap.exists, isTrue);
    expect(issuerAccountSnap.data()?['deviceCount'], 2);

    final movedDeviceSnap = await firestore.doc('accounts/${issuerCtx.uid}/devices/$joinerDeviceId').get();
    expect(movedDeviceSnap.exists, isTrue);
    expect(movedDeviceSnap.data()?['displayName'], 'Joiner phone');
    expect(movedDeviceSnap.data()?['presence'], 'offline');

    // 5. The cloud function's oldAccountDeleted flag is the
    //    authoritative signal — the joiner can't directly read
    //    accounts/$joinerUid anymore (rules require auth.uid match).
    expect(joinResult.oldAccountDeleted, isTrue, reason: 'asserted earlier; mirroring for clarity');

    // Cleanup: destroy the merged account.
    await joinerClient.deleteAccount();
    await FirebaseAuth.instance.currentUser?.delete();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('welcome-card path: joiner with no source account joins via newDevice', (tester) async {
    final issuerCtx = await _bootstrapIssuer();

    // Mint the token while still signed in as the issuer.
    final tokenResult = await issuerCtx.client.createJoinToken(
      issuingDeviceId: issuerCtx.deviceId,
    );

    // Joiner is a fresh install — anon sign-in only, no createAccount.
    await FirebaseAuth.instance.signOut();
    await _signInAnonymously();

    final joinerClient = CloudFunctionsClient();
    final joinerDeviceId = const Uuid().v4();

    // Confirm joiner has no source account doc on its own UID.
    final joinerAnonUid = FirebaseAuth.instance.currentUser!.uid;
    final preExistingAccount = await FirebaseFirestore.instance.doc('accounts/$joinerAnonUid').get();
    expect(preExistingAccount.exists, isFalse);

    final joinResult = await joinerClient.joinNetwork(
      tokenId: tokenResult.tokenId,
      deviceId: joinerDeviceId,
      newDevice: const JoinNetworkNewDevice(
        displayName: 'Welcome iPad',
        icon: CloudDeviceIcon.tablet,
        platform: CloudDevicePlatform.ios,
        fcmToken: null,
      ),
    );
    expect(joinResult.accountId, issuerCtx.uid);
    expect(joinResult.oldAccountDeleted, isFalse, reason: 'no source account existed for the joiner UID');
    expect(joinResult.customToken, isNotEmpty);

    await FirebaseAuth.instance.signInWithCustomToken(joinResult.customToken);
    expect(FirebaseAuth.instance.currentUser?.uid, issuerCtx.uid);

    final firestore = FirebaseFirestore.instance;
    final movedDeviceSnap = await firestore.doc('accounts/${issuerCtx.uid}/devices/$joinerDeviceId').get();
    expect(movedDeviceSnap.exists, isTrue);
    expect(movedDeviceSnap.data()?['displayName'], 'Welcome iPad');
    expect(movedDeviceSnap.data()?['icon'], 'tablet');
    expect(movedDeviceSnap.data()?['platform'], 'ios');

    // Cleanup.
    await joinerClient.deleteAccount();
    await FirebaseAuth.instance.currentUser?.delete();
    await FirebaseAuth.instance.signOut();
  });
}

class _IssuerCtx {
  _IssuerCtx({required this.uid, required this.deviceId, required this.client});
  final String uid;
  final String deviceId;
  final CloudFunctionsClient client;
}

Future<_IssuerCtx> _bootstrapIssuer() async {
  await initializeFirebase(cloudSyncEnabled: true);
  await FirebaseAuth.instance.signOut();
  final uid = await _signInAnonymously();
  final client = CloudFunctionsClient();
  final deviceId = const Uuid().v4();
  await client.createAccount();
  await client.registerDevice(
    deviceId: deviceId,
    displayName: 'Issuer Mac',
    icon: CloudDeviceIcon.laptop,
    platform: CloudDevicePlatform.macos,
    fcmToken: 'fcm-issuer',
  );
  return _IssuerCtx(uid: uid, deviceId: deviceId, client: client);
}

Future<String> _signInAnonymously() async {
  final auth = FirebaseAuth.instance;
  final emit = auth.userChanges().where((u) => u != null).map((u) => u!.uid).first;
  unawaited(auth.signInAnonymously());
  return emit.timeout(const Duration(seconds: 5));
}
