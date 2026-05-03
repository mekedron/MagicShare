import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/firebase_options.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';

/// Cloud Functions are deployed to this region (see firebase/functions/src/index.ts).
const cloudFunctionsRegion = 'europe-west1';

/// Set via `--dart-define=USE_FIREBASE_EMULATOR=true` for emulator-backed tests.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Override via `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2` when running
/// against the Android emulator on a physical device.
const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);

const int _emulatorAuthPort = 9099;
const int _emulatorFirestorePort = 8080;
const int _emulatorFunctionsPort = 5001;

final _logger = Logger('FirebaseInit');

/// Outcome of [initializeFirebase] — used by callers to decide whether to
/// register downstream cloud providers.
enum FirebaseInitResult {
  /// Firebase initialised successfully (or was already initialised).
  initialised,

  /// The user disabled cloud sync; Firebase was intentionally skipped.
  disabledByUser,

  /// The current platform isn't on the FlutterFire support matrix.
  unsupportedPlatform,
}

/// Brings up Firebase Core and (when [useFirebaseEmulator] is on) wires the
/// SDKs at the locally running emulator suite.
///
/// Safe to call multiple times — repeat calls re-use the existing default
/// app instance. Throws on real init failures so the bootstrap can decide how
/// to surface the error.
Future<FirebaseInitResult> initializeFirebase({required bool cloudSyncEnabled}) async {
  if (!cloudSyncEnabled) {
    _logger.info('Cloud sync disabled by user setting; skipping Firebase init.');
    return FirebaseInitResult.disabledByUser;
  }
  if (!checkPlatformSupportsFirebase()) {
    _logger.info('Platform does not support Firebase; skipping init.');
    return FirebaseInitResult.unsupportedPlatform;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  if (useFirebaseEmulator) {
    await _wireEmulators();
  }

  return FirebaseInitResult.initialised;
}

Future<void> _wireEmulators() async {
  _logger.info('USE_FIREBASE_EMULATOR=true; pointing clients at $firebaseEmulatorHost');

  await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, _emulatorAuthPort);
  FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, _emulatorFirestorePort);

  if (checkPlatformSupportsCloudFunctions()) {
    FirebaseFunctions.instanceFor(region: cloudFunctionsRegion).useFunctionsEmulator(firebaseEmulatorHost, _emulatorFunctionsPort);
  }
}
