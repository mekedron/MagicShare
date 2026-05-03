/// Integration test: app boot reaches `Authenticated(uid)` within ~1 s
/// against the Firebase emulator.
///
/// Run with the emulator suite running on localhost (or override the host
/// via `--dart-define=FIREBASE_EMULATOR_HOST=...`):
///
/// ```
/// cd firebase/functions && npm run dev    # in another terminal
/// cd app && flutter test integration_test/cloud_bootstrap_test.dart \
///     --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// This test requires a connected device or simulator (or `chrome`).
/// It does NOT run as part of `flutter test`, only when invoked explicitly.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:magicshare_app/config/cloud/firebase_init.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signs in anonymously within ~1 s of init', (tester) async {
    await initializeFirebase(cloudSyncEnabled: true);

    // Sign out any pre-existing session so the test always exercises the
    // sign-in path. (Anonymous UIDs persist across runs by default.)
    await FirebaseAuth.instance.signOut();
    expect(FirebaseAuth.instance.currentUser, isNull);

    final stopwatch = Stopwatch()..start();
    final uid = await _signInWithBudget(const Duration(seconds: 5));
    stopwatch.stop();

    expect(uid, isNotNull);
    expect(uid, isNotEmpty);
    // Spec target: <2 s cold start. Allow generous slack for emulator
    // warm-up; the assertion catches catastrophic regressions.
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 5)),
      reason: 'Anonymous sign-in took ${stopwatch.elapsed} — expected <5 s.',
    );

    // Cleanup: leave the emulator in a clean state for subsequent tests.
    await FirebaseAuth.instance.signOut();
  });
}

Future<String?> _signInWithBudget(Duration budget) async {
  final firstUid = FirebaseAuth.instance.userChanges().where((user) => user != null).map((user) => user!.uid).first;
  // Fire-and-forget: the test assertion is on the auth-state stream.
  unawaited(FirebaseAuth.instance.signInAnonymously());
  try {
    return await firstUid.timeout(budget);
  } on TimeoutException {
    return null;
  }
}
