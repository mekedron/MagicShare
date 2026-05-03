import 'package:flutter/foundation.dart';
import 'package:magicshare_app/util/native/platform_check.dart';

/// FlutterFire's `firebase_core`, `firebase_auth`, and `cloud_firestore`
/// ship native bindings on Android, iOS, macOS, and Windows. Linux has no
/// official Firebase support — all cloud calls there must go through the
/// REST fallback added in a follow-up epic.
bool checkPlatformSupportsFirebase({TargetPlatform? platform}) {
  return checkPlatform(
    const [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows],
  );
}

/// Cloud Functions has no native Windows plugin in the FlutterFire matrix
/// and Linux has no Firebase support at all. Mobile + macOS are covered by
/// the standard `cloud_functions` SDK; Windows + Linux fall back to the
/// REST client planned in the follow-up epic.
bool checkPlatformSupportsCloudFunctions() {
  return checkPlatform(
    const [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS],
  );
}

/// `firebase_messaging` only exposes native FCM bindings on the mobile
/// platforms and macOS. Windows and Linux receive wakes through the
/// `pollPendingWakes` callable instead.
bool checkPlatformSupportsFcm() {
  return checkPlatform(
    const [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS],
  );
}
