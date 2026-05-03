import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('checkPlatformSupportsFirebase', () {
    test('returns true on Android, iOS, macOS, Windows', () {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(checkPlatformSupportsFirebase(), isTrue, reason: 'expected true for $platform');
      }
    });

    test('returns false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(checkPlatformSupportsFirebase(), isFalse);
    });
  });

  group('checkPlatformSupportsCloudFunctions', () {
    test('returns true on Android, iOS, macOS', () {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(checkPlatformSupportsCloudFunctions(), isTrue, reason: 'expected true for $platform');
      }
    });

    test('returns false on Windows and Linux', () {
      for (final platform in const [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(checkPlatformSupportsCloudFunctions(), isFalse, reason: 'expected false for $platform');
      }
    });
  });

  group('checkPlatformSupportsFcm', () {
    test('returns true on Android, iOS, macOS', () {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(checkPlatformSupportsFcm(), isTrue, reason: 'expected true for $platform');
      }
    });

    test('returns false on Windows and Linux', () {
      for (final platform in const [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(checkPlatformSupportsFcm(), isFalse, reason: 'expected false for $platform');
      }
    });
  });
}
