import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/model/permission_availability.dart';
import 'package:magicshare_app/provider/cloud/notification_permission_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('PermissionsStatus');

/// Holds the current OS-level authorization for the permissions that
/// the Settings → Permissions section surfaces.
class PermissionsStatusState {
  final PermissionAvailability camera;
  final PermissionAvailability notification;

  /// True while [RefreshPermissionsAction] is in flight. Used to disable
  /// the Refresh button and to make a re-entrant refresh call a no-op.
  final bool refreshing;

  /// True while a [RequestCameraAction] or [RequestNotificationAction] is
  /// in flight. Prevents stacked OS dialogs if the user double-taps.
  final bool requestInFlight;

  const PermissionsStatusState({
    this.camera = PermissionAvailability.unknown,
    this.notification = PermissionAvailability.unknown,
    this.refreshing = false,
    this.requestInFlight = false,
  });

  PermissionsStatusState copyWith({
    PermissionAvailability? camera,
    PermissionAvailability? notification,
    bool? refreshing,
    bool? requestInFlight,
  }) {
    return PermissionsStatusState(
      camera: camera ?? this.camera,
      notification: notification ?? this.notification,
      refreshing: refreshing ?? this.refreshing,
      requestInFlight: requestInFlight ?? this.requestInFlight,
    );
  }
}

/// Surface of the [permission_handler] camera APIs and the OS-settings
/// deep-link, modelled as a typedef bag so unit tests can drive the
/// service without mocking the platform plugin.
class PermissionsGateway {
  PermissionsGateway({
    required this.getCameraStatus,
    required this.requestCamera,
    required this.openSettings,
  });

  final Future<PermissionStatus> Function() getCameraStatus;
  final Future<PermissionStatus> Function() requestCamera;

  /// Deep-links to the OS Settings app. Returns immediately; the user's
  /// actual choice is observed on [AppLifecycleState.resumed].
  final Future<bool> Function() openSettings;

  factory PermissionsGateway.live() {
    return PermissionsGateway(
      getCameraStatus: () => Permission.camera.status,
      requestCamera: () => Permission.camera.request(),
      openSettings: () => openAppSettings(),
    );
  }
}

/// Maps a [permission_handler] [PermissionStatus] to our user-facing
/// [PermissionAvailability] domain enum.
PermissionAvailability mapPermissionStatus(PermissionStatus status) {
  if (status.isGranted || status.isLimited || status.isProvisional) {
    return PermissionAvailability.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionAvailability.permanentlyDenied;
  }
  if (status.isRestricted) {
    return PermissionAvailability.restricted;
  }
  return PermissionAvailability.denied;
}

/// True on platforms where [permission_handler] actually has a native
/// implementation for [Permission.camera] — Android and iOS.
/// permission_handler_apple ships an `ios/` folder only; macOS calls
/// raise [MissingPluginException]. Linux/Windows have no implementation.
/// On unsupported platforms we surface camera state as
/// [PermissionAvailability.unsupported] so the UI hides the row instead
/// of spinning forever.
bool _liveCameraSupported() {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Reads + updates OS permission state for the Settings → Permissions
/// section. All actions are idempotent and re-entrancy-safe.
class PermissionsStatusService extends ReduxNotifier<PermissionsStatusState> {
  PermissionsStatusService({
    required NotificationPermissionService notificationPermissionService,
    PermissionsGateway? gateway,
    bool Function()? cameraSupportedOverride,
  }) : _notification = notificationPermissionService,
       _gateway = gateway ?? PermissionsGateway.live(),
       _cameraSupported = cameraSupportedOverride ?? _liveCameraSupported;

  final NotificationPermissionService _notification;
  final PermissionsGateway _gateway;
  final bool Function() _cameraSupported;

  @override
  PermissionsStatusState init() => const PermissionsStatusState();

  @override
  get initialAction => RefreshPermissionsAction();
}

/// Reads camera + notification status without prompting. Idempotent —
/// concurrent calls collapse into one read. Each permission is read
/// independently so a failure on one (e.g. camera on macOS where the
/// plugin throws MissingPluginException) does not block the other.
class RefreshPermissionsAction extends AsyncReduxAction<PermissionsStatusService, PermissionsStatusState> {
  @override
  Future<PermissionsStatusState> reduce() async {
    if (state.refreshing) {
      return state;
    }
    dispatch(_SetRefreshingAction(true));
    final cameraResult = await _readCamera();
    final notificationResult = await _readNotification();
    _logger.info('Refreshed permissions: camera=$cameraResult, notification=$notificationResult');
    return state.copyWith(
      camera: cameraResult,
      notification: notificationResult,
      refreshing: false,
    );
  }

  Future<PermissionAvailability> _readCamera() async {
    if (!notifier._cameraSupported()) {
      return PermissionAvailability.unsupported;
    }
    try {
      final raw = await notifier._gateway.getCameraStatus();
      final mapped = mapPermissionStatus(raw);
      _logger.info('Camera status raw=$raw mapped=$mapped');
      return mapped;
    } catch (e, st) {
      _logger.warning('Camera status read failed', e, st);
      return PermissionAvailability.unsupported;
    }
  }

  Future<PermissionAvailability> _readNotification() async {
    try {
      return await notifier._notification.status();
    } catch (e, st) {
      _logger.warning('Notification status read failed', e, st);
      return PermissionAvailability.unsupported;
    }
  }
}

/// Requests camera permission. If permission is permanently denied or
/// restricted, opens OS Settings instead — that's the only path forward
/// once the OS has consumed the prompt. Auto-refresh on app resume
/// (wired by the Settings tab) picks up the user's choice.
class RequestCameraAction extends AsyncReduxAction<PermissionsStatusService, PermissionsStatusState> {
  @override
  Future<PermissionsStatusState> reduce() async {
    if (state.requestInFlight) {
      return state;
    }
    if (!notifier._cameraSupported()) {
      return state;
    }
    dispatch(_SetRequestInFlightAction(true));
    try {
      if (state.camera.needsSettings) {
        await notifier._gateway.openSettings();
        // Do not refresh inline: openAppSettings returns immediately
        // while the OS Settings app launches, so the read would be stale.
        // The Settings tab's LifeCycleWatcher re-runs RefreshPermissionsAction
        // on AppLifecycleState.resumed.
        return state.copyWith(requestInFlight: false);
      }
      final result = await notifier._gateway.requestCamera();
      return state.copyWith(
        camera: mapPermissionStatus(result),
        requestInFlight: false,
      );
    } catch (e, st) {
      _logger.warning('Camera permission request failed', e, st);
      return state.copyWith(requestInFlight: false);
    }
  }
}

/// Requests notification permission. Delegates to
/// [NotificationPermissionService.request], which already handles
/// iOS / macOS (FirebaseMessaging) vs Android (permission_handler)
/// branching. Re-reads status afterwards.
class RequestNotificationAction extends AsyncReduxAction<PermissionsStatusService, PermissionsStatusState> {
  @override
  Future<PermissionsStatusState> reduce() async {
    if (state.requestInFlight) {
      return state;
    }
    dispatch(_SetRequestInFlightAction(true));
    try {
      if (state.notification.needsSettings) {
        await notifier._gateway.openSettings();
        return state.copyWith(requestInFlight: false);
      }
      await notifier._notification.request();
      final fresh = await notifier._notification.status();
      return state.copyWith(
        notification: fresh,
        requestInFlight: false,
      );
    } catch (e, st) {
      _logger.warning('Notification permission request failed', e, st);
      return state.copyWith(requestInFlight: false);
    }
  }
}

class _SetRefreshingAction extends ReduxAction<PermissionsStatusService, PermissionsStatusState> {
  final bool value;

  _SetRefreshingAction(this.value);

  @override
  PermissionsStatusState reduce() => state.copyWith(refreshing: value);
}

class _SetRequestInFlightAction extends ReduxAction<PermissionsStatusService, PermissionsStatusState> {
  final bool value;

  _SetRequestInFlightAction(this.value);

  @override
  PermissionsStatusState reduce() => state.copyWith(requestInFlight: value);
}

final permissionsStatusProvider = ReduxProvider<PermissionsStatusService, PermissionsStatusState>(
  (ref) {
    return PermissionsStatusService(
      notificationPermissionService: ref.read(notificationPermissionProvider),
    );
  },
);
