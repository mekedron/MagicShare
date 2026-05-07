import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/permission_availability.dart';
import 'package:magicshare_app/provider/cloud/notification_permission_provider.dart';
import 'package:magicshare_app/provider/permissions_status_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _CameraSpy {
  PermissionStatus status = PermissionStatus.denied;
  PermissionStatus requestResult = PermissionStatus.granted;
  int statusCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  PermissionsGateway gateway() => PermissionsGateway(
    getCameraStatus: () async {
      statusCalls++;
      return status;
    },
    requestCamera: () async {
      requestCalls++;
      return requestResult;
    },
    openSettings: () async {
      openSettingsCalls++;
      return true;
    },
  );
}

class _NotifGatewaySpy {
  AuthorizationStatus firebaseStatus = AuthorizationStatus.notDetermined;
  PermissionStatus androidStatus = PermissionStatus.denied;
  int requestCalls = 0;
  int statusCalls = 0;

  NotificationPermissionGateway gateway() => NotificationPermissionGateway(
    requestFirebase: () async {
      requestCalls++;
      return firebaseStatus;
    },
    getFirebase: () async {
      statusCalls++;
      return firebaseStatus;
    },
    requestAndroid: () async {
      requestCalls++;
      return androidStatus;
    },
    getAndroid: () async {
      statusCalls++;
      return androidStatus;
    },
  );
}

NotificationPermissionService _notificationService(_NotifGatewaySpy spy, {bool isAndroid = true}) {
  return NotificationPermissionService(
    gateway: spy.gateway(),
    supportedOverride: true,
    isAndroidOverride: () => isAndroid,
    isApplePlatformOverride: () => !isAndroid,
  );
}

PermissionsStatusService _service({
  required _CameraSpy camera,
  required _NotifGatewaySpy notif,
  bool isAndroid = true,
  bool cameraSupported = true,
}) {
  return PermissionsStatusService(
    notificationPermissionService: _notificationService(notif, isAndroid: isAndroid),
    gateway: camera.gateway(),
    cameraSupportedOverride: () => cameraSupported,
  );
}

void main() {
  group('RefreshPermissionsAction', () {
    test('reads camera + notification status into state', () async {
      final camera = _CameraSpy()..status = PermissionStatus.granted;
      final notif = _NotifGatewaySpy()..androidStatus = PermissionStatus.granted;
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
      );

      await service.dispatchAsync(RefreshPermissionsAction());

      expect(service.state.camera, PermissionAvailability.granted);
      expect(service.state.notification, PermissionAvailability.granted);
      expect(service.state.refreshing, isFalse);
      expect(camera.statusCalls, 1);
      expect(notif.statusCalls, 1);
    });

    test('maps permanentlyDenied camera state', () async {
      final camera = _CameraSpy()..status = PermissionStatus.permanentlyDenied;
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
      );

      await service.dispatchAsync(RefreshPermissionsAction());

      expect(service.state.camera, PermissionAvailability.permanentlyDenied);
    });

    test('Apple denied notification maps to permanentlyDenied (OS will not re-prompt)', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy()..firebaseStatus = AuthorizationStatus.denied;
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif, isAndroid: false),
      );

      await service.dispatchAsync(RefreshPermissionsAction());

      expect(service.state.notification, PermissionAvailability.permanentlyDenied);
    });

    test('is a no-op when already refreshing (re-entrancy guard)', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(refreshing: true),
      );

      await service.dispatchAsync(RefreshPermissionsAction());

      expect(camera.statusCalls, 0);
      expect(notif.statusCalls, 0);
    });

    test('skips camera read on platforms without camera support and still reads notification', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy()..androidStatus = PermissionStatus.granted;
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif, cameraSupported: false),
      );

      await service.dispatchAsync(RefreshPermissionsAction());

      expect(camera.statusCalls, 0);
      expect(service.state.camera, PermissionAvailability.unsupported);
      expect(notif.statusCalls, 1);
      expect(service.state.notification, PermissionAvailability.granted);
    });

    test('camera read failure does not block notification read', () async {
      // Simulates the macOS case where Permission.camera.status throws
      // MissingPluginException because permission_handler_apple has no
      // macOS implementation.
      final throwingGateway = PermissionsGateway(
        getCameraStatus: () async => throw StateError('plugin missing'),
        requestCamera: () async => PermissionStatus.denied,
        openSettings: () async => true,
      );
      final notif = _NotifGatewaySpy()..androidStatus = PermissionStatus.granted;
      final service = ReduxNotifier.test(
        redux: PermissionsStatusService(
          notificationPermissionService: _notificationService(notif, isAndroid: true),
          gateway: throwingGateway,
          cameraSupportedOverride: () => true,
        ),
      );

      await service.dispatchAsync(RefreshPermissionsAction());

      expect(service.state.camera, PermissionAvailability.unsupported);
      expect(service.state.notification, PermissionAvailability.granted);
      expect(service.state.refreshing, isFalse);
    });
  });

  group('RequestCameraAction', () {
    test('calls request when status is denied', () async {
      final camera = _CameraSpy()
        ..status = PermissionStatus.granted
        ..requestResult = PermissionStatus.granted;
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(camera: PermissionAvailability.denied),
      );

      await service.dispatchAsync(RequestCameraAction());

      expect(camera.requestCalls, 1);
      expect(camera.openSettingsCalls, 0);
      expect(service.state.camera, PermissionAvailability.granted);
      expect(service.state.requestInFlight, isFalse);
    });

    test('opens OS settings when status is permanentlyDenied (does not re-prompt)', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(camera: PermissionAvailability.permanentlyDenied),
      );

      await service.dispatchAsync(RequestCameraAction());

      expect(camera.openSettingsCalls, 1);
      expect(camera.requestCalls, 0);
      // No inline refresh — state stays as-is until lifecycle-resumed re-reads.
      expect(service.state.camera, PermissionAvailability.permanentlyDenied);
      expect(service.state.requestInFlight, isFalse);
    });

    test('opens OS settings when status is restricted', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(camera: PermissionAvailability.restricted),
      );

      await service.dispatchAsync(RequestCameraAction());

      expect(camera.openSettingsCalls, 1);
      expect(camera.requestCalls, 0);
    });

    test('is a no-op when a request is already in flight', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(
          camera: PermissionAvailability.denied,
          requestInFlight: true,
        ),
      );

      await service.dispatchAsync(RequestCameraAction());

      expect(camera.requestCalls, 0);
      expect(camera.openSettingsCalls, 0);
    });
  });

  group('RequestNotificationAction', () {
    test('delegates to notification request and re-reads status afterwards', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy()..androidStatus = PermissionStatus.granted;
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(notification: PermissionAvailability.denied),
      );

      await service.dispatchAsync(RequestNotificationAction());

      expect(notif.requestCalls, 1);
      expect(notif.statusCalls, 1);
      expect(service.state.notification, PermissionAvailability.granted);
      expect(service.state.requestInFlight, isFalse);
    });

    test('opens OS settings when notification is permanentlyDenied', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(notification: PermissionAvailability.permanentlyDenied),
      );

      await service.dispatchAsync(RequestNotificationAction());

      expect(camera.openSettingsCalls, 1);
      expect(notif.requestCalls, 0);
      expect(service.state.notification, PermissionAvailability.permanentlyDenied);
    });

    test('is a no-op when a request is already in flight', () async {
      final camera = _CameraSpy();
      final notif = _NotifGatewaySpy();
      final service = ReduxNotifier.test(
        redux: _service(camera: camera, notif: notif),
        initialState: const PermissionsStatusState(
          notification: PermissionAvailability.denied,
          requestInFlight: true,
        ),
      );

      await service.dispatchAsync(RequestNotificationAction());

      expect(notif.requestCalls, 0);
    });
  });

  group('PermissionAvailability helpers', () {
    test('isGranted is true only for granted', () {
      expect(PermissionAvailability.granted.isGranted, isTrue);
      expect(PermissionAvailability.denied.isGranted, isFalse);
      expect(PermissionAvailability.permanentlyDenied.isGranted, isFalse);
      expect(PermissionAvailability.restricted.isGranted, isFalse);
      expect(PermissionAvailability.unsupported.isGranted, isFalse);
      expect(PermissionAvailability.unknown.isGranted, isFalse);
    });

    test('needsSettings is true for permanentlyDenied and restricted', () {
      expect(PermissionAvailability.permanentlyDenied.needsSettings, isTrue);
      expect(PermissionAvailability.restricted.needsSettings, isTrue);
      expect(PermissionAvailability.denied.needsSettings, isFalse);
      expect(PermissionAvailability.granted.needsSettings, isFalse);
    });
  });

  group('mapPermissionStatus', () {
    test('granted variants collapse to granted', () {
      expect(mapPermissionStatus(PermissionStatus.granted), PermissionAvailability.granted);
      expect(mapPermissionStatus(PermissionStatus.limited), PermissionAvailability.granted);
      expect(mapPermissionStatus(PermissionStatus.provisional), PermissionAvailability.granted);
    });

    test('permanentlyDenied is preserved', () {
      expect(mapPermissionStatus(PermissionStatus.permanentlyDenied), PermissionAvailability.permanentlyDenied);
    });

    test('restricted is preserved', () {
      expect(mapPermissionStatus(PermissionStatus.restricted), PermissionAvailability.restricted);
    });

    test('plain denied falls through to denied', () {
      expect(mapPermissionStatus(PermissionStatus.denied), PermissionAvailability.denied);
    });
  });
}
