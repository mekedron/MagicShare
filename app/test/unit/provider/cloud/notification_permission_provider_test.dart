import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/notification_permission_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class _RecordingGateway {
  AuthorizationStatus firebaseStatus = AuthorizationStatus.authorized;
  PermissionStatus androidStatus = PermissionStatus.granted;
  Object? firebaseThrows;
  Object? androidThrows;
  Object? firebaseGetThrows;
  Object? androidGetThrows;
  int firebaseCalls = 0;
  int androidCalls = 0;
  int firebaseGetCalls = 0;
  int androidGetCalls = 0;

  NotificationPermissionGateway gateway() => NotificationPermissionGateway(
    requestFirebase: () async {
      firebaseCalls++;
      if (firebaseThrows != null) throw firebaseThrows!;
      return firebaseStatus;
    },
    getFirebase: () async {
      firebaseGetCalls++;
      if (firebaseGetThrows != null) throw firebaseGetThrows!;
      return firebaseStatus;
    },
    requestAndroid: () async {
      androidCalls++;
      if (androidThrows != null) throw androidThrows!;
      return androidStatus;
    },
    getAndroid: () async {
      androidGetCalls++;
      if (androidGetThrows != null) throw androidGetThrows!;
      return androidStatus;
    },
  );
}

NotificationPermissionService _service({
  required _RecordingGateway gateway,
  bool platformSupportsFcm = true,
  bool isAndroid = false,
  bool isApple = false,
}) => NotificationPermissionService(
  gateway: gateway.gateway(),
  supportedOverride: platformSupportsFcm,
  isAndroidOverride: () => isAndroid,
  isApplePlatformOverride: () => isApple,
);

void main() {
  group('platform gating', () {
    test('returns unsupported when FCM platform support is off', () async {
      final gateway = _RecordingGateway();
      final service = _service(gateway: gateway, platformSupportsFcm: false);
      final outcome = await service.request();
      expect(outcome, NotificationPermissionOutcome.unsupported);
      expect(gateway.firebaseCalls, 0);
      expect(gateway.androidCalls, 0);
    });

    test('returns unsupported on a platform we do not gate (e.g. macOS web)', () async {
      final gateway = _RecordingGateway();
      final service = _service(gateway: gateway);
      final outcome = await service.request();
      expect(outcome, NotificationPermissionOutcome.unsupported);
    });
  });

  group('Apple platforms (iOS / macOS)', () {
    test('authorized maps to granted', () async {
      final gateway = _RecordingGateway()..firebaseStatus = AuthorizationStatus.authorized;
      final service = _service(gateway: gateway, isApple: true);
      expect(await service.request(), NotificationPermissionOutcome.granted);
      expect(gateway.firebaseCalls, 1);
    });

    test('provisional maps to granted', () async {
      final gateway = _RecordingGateway()..firebaseStatus = AuthorizationStatus.provisional;
      final service = _service(gateway: gateway, isApple: true);
      expect(await service.request(), NotificationPermissionOutcome.granted);
    });

    test('denied maps to denied', () async {
      final gateway = _RecordingGateway()..firebaseStatus = AuthorizationStatus.denied;
      final service = _service(gateway: gateway, isApple: true);
      expect(await service.request(), NotificationPermissionOutcome.denied);
    });

    test('notDetermined maps to denied (best-effort signalling)', () async {
      final gateway = _RecordingGateway()..firebaseStatus = AuthorizationStatus.notDetermined;
      final service = _service(gateway: gateway, isApple: true);
      expect(await service.request(), NotificationPermissionOutcome.denied);
    });

    test('plugin throw maps to failed and does not propagate', () async {
      final gateway = _RecordingGateway()..firebaseThrows = StateError('plugin unavailable');
      final service = _service(gateway: gateway, isApple: true);
      expect(await service.request(), NotificationPermissionOutcome.failed);
    });
  });

  group('Android', () {
    test('granted maps to granted', () async {
      final gateway = _RecordingGateway()..androidStatus = PermissionStatus.granted;
      final service = _service(gateway: gateway, isAndroid: true);
      expect(await service.request(), NotificationPermissionOutcome.granted);
      expect(gateway.androidCalls, 1);
    });

    test('limited / provisional map to granted', () async {
      final gateway = _RecordingGateway()..androidStatus = PermissionStatus.limited;
      final service = _service(gateway: gateway, isAndroid: true);
      expect(await service.request(), NotificationPermissionOutcome.granted);
    });

    test('denied maps to denied', () async {
      final gateway = _RecordingGateway()..androidStatus = PermissionStatus.denied;
      final service = _service(gateway: gateway, isAndroid: true);
      expect(await service.request(), NotificationPermissionOutcome.denied);
    });

    test('permanentlyDenied maps to denied', () async {
      final gateway = _RecordingGateway()..androidStatus = PermissionStatus.permanentlyDenied;
      final service = _service(gateway: gateway, isAndroid: true);
      expect(await service.request(), NotificationPermissionOutcome.denied);
    });

    test('plugin throw maps to failed and does not propagate', () async {
      final gateway = _RecordingGateway()..androidThrows = StateError('permission_handler down');
      final service = _service(gateway: gateway, isAndroid: true);
      expect(await service.request(), NotificationPermissionOutcome.failed);
    });
  });
}
