import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/config/cloud/firebase_init.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('returns disabledByUser when cloudSyncEnabled is false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final result = await initializeFirebase(cloudSyncEnabled: false);
    expect(result, FirebaseInitResult.disabledByUser);
  });

  test('returns unsupportedPlatform on Linux even when cloudSyncEnabled is true', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final result = await initializeFirebase(cloudSyncEnabled: true);
    expect(result, FirebaseInitResult.unsupportedPlatform);
  });

  test('cloudFunctionsRegion stays europe-west1 to match the deployed backend', () {
    expect(cloudFunctionsRegion, 'europe-west1');
  });

  test('useFirebaseEmulator defaults to false without --dart-define', () {
    expect(useFirebaseEmulator, isFalse);
  });

  test('firebaseEmulatorHost defaults to localhost', () {
    expect(firebaseEmulatorHost, 'localhost');
  });
}
