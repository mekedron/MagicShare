import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/model/permission_availability.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('NotificationPermission');

/// Outcome of [NotificationPermissionService.request].
enum NotificationPermissionOutcome {
  /// The user granted notification permission (or it was already granted,
  /// or the platform doesn't gate them).
  granted,

  /// The user denied notification permission. Cloud features still work,
  /// but the user won't see link / wake notifications.
  denied,

  /// The platform isn't on the FCM matrix or doesn't gate notification
  /// permissions (Linux, Windows in current scope). Treated as a no-op.
  unsupported,

  /// Permission could not be requested (plugin error, etc.). Logged but
  /// non-blocking — cloud features still work; the user just may not
  /// see notifications.
  failed,
}

/// Surface of the platform notification-permission APIs that
/// [NotificationPermissionService] consumes. Modelled as a typedef bag
/// so tests can inject a recorder without mocking the platform plugin.
class NotificationPermissionGateway {
  NotificationPermissionGateway({
    required this.requestFirebase,
    required this.getFirebase,
    required this.requestAndroid,
    required this.getAndroid,
  });

  /// Triggers the iOS / macOS notification-permission prompt via
  /// FirebaseMessaging. Returns the resulting authorization status.
  final Future<AuthorizationStatus> Function() requestFirebase;

  /// Reads the current iOS / macOS notification-permission status via
  /// FirebaseMessaging without prompting the user.
  final Future<AuthorizationStatus> Function() getFirebase;

  /// Triggers the Android 13+ POST_NOTIFICATIONS prompt via
  /// permission_handler.
  final Future<PermissionStatus> Function() requestAndroid;

  /// Reads the current Android POST_NOTIFICATIONS status without prompting.
  final Future<PermissionStatus> Function() getAndroid;

  factory NotificationPermissionGateway.live() {
    return NotificationPermissionGateway(
      requestFirebase: () async {
        final settings = await FirebaseMessaging.instance.requestPermission();
        return settings.authorizationStatus;
      },
      getFirebase: () async {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        return settings.authorizationStatus;
      },
      requestAndroid: () => Permission.notification.request(),
      getAndroid: () => Permission.notification.status,
    );
  }
}

/// Requests notification permission from the user at the moment they
/// explicitly opt into cloud features (welcome-card *Create a new
/// group* / *Join an existing group*). Non-blocking: a denial logs
/// and continues so the rest of the cloud-sync flow keeps working.
class NotificationPermissionService {
  NotificationPermissionService({
    NotificationPermissionGateway? gateway,
    bool? supportedOverride,
    bool Function()? isAndroidOverride,
    bool Function()? isApplePlatformOverride,
  }) : _gateway = gateway ?? NotificationPermissionGateway.live(),
       _supportedOverride = supportedOverride,
       _isAndroid = isAndroidOverride ?? _liveIsAndroid,
       _isApplePlatform = isApplePlatformOverride ?? _liveIsApple;

  final NotificationPermissionGateway _gateway;
  final bool? _supportedOverride;
  final bool Function() _isAndroid;
  final bool Function() _isApplePlatform;

  bool get _isSupported => _supportedOverride ?? checkPlatformSupportsFcm();

  /// Idempotent request. Safe to call from any cloud-onboarding entry
  /// point (welcome card *Create*, *Join*, settings flips). Returns
  /// the user's choice; never throws.
  Future<NotificationPermissionOutcome> request() async {
    if (!_isSupported) {
      return NotificationPermissionOutcome.unsupported;
    }
    if (_isApplePlatform()) {
      return _requestApple();
    }
    if (_isAndroid()) {
      return _requestAndroid();
    }
    // Other supported platforms (e.g. Windows web messaging) — nothing
    // to prompt for at this layer.
    return NotificationPermissionOutcome.unsupported;
  }

  Future<NotificationPermissionOutcome> _requestApple() async {
    try {
      final status = await _gateway.requestFirebase();
      switch (status) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return NotificationPermissionOutcome.granted;
        case AuthorizationStatus.denied:
          _logger.info('iOS / macOS notification permission denied');
          return NotificationPermissionOutcome.denied;
        case AuthorizationStatus.notDetermined:
          _logger.info('iOS / macOS notification permission notDetermined');
          return NotificationPermissionOutcome.denied;
      }
    } catch (e, st) {
      _logger.warning('iOS / macOS requestPermission failed', e, st);
      return NotificationPermissionOutcome.failed;
    }
  }

  Future<NotificationPermissionOutcome> _requestAndroid() async {
    try {
      final status = await _gateway.requestAndroid();
      if (status.isGranted || status.isLimited || status.isProvisional) {
        return NotificationPermissionOutcome.granted;
      }
      _logger.info('Android POST_NOTIFICATIONS denied: $status');
      return NotificationPermissionOutcome.denied;
    } catch (e, st) {
      _logger.warning('Android POST_NOTIFICATIONS request failed', e, st);
      return NotificationPermissionOutcome.failed;
    }
  }

  /// Reads the current authorization without triggering the OS prompt.
  /// Mirrors [request] platform branching but never surfaces UI.
  Future<PermissionAvailability> status() async {
    if (!_isSupported) {
      return PermissionAvailability.unsupported;
    }
    if (_isApplePlatform()) {
      return _statusApple();
    }
    if (_isAndroid()) {
      return _statusAndroid();
    }
    return PermissionAvailability.unsupported;
  }

  Future<PermissionAvailability> _statusApple() async {
    try {
      final status = await _gateway.getFirebase();
      switch (status) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return PermissionAvailability.granted;
        case AuthorizationStatus.denied:
          // Apple's notDetermined collapses into the .denied bucket from a
          // user's standpoint, but on iOS the OS will not re-prompt once
          // the user has tapped Don't Allow — only path is system Settings.
          return PermissionAvailability.permanentlyDenied;
        case AuthorizationStatus.notDetermined:
          return PermissionAvailability.denied;
      }
    } catch (e, st) {
      _logger.warning('iOS / macOS getNotificationSettings failed', e, st);
      return PermissionAvailability.denied;
    }
  }

  Future<PermissionAvailability> _statusAndroid() async {
    try {
      final status = await _gateway.getAndroid();
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
    } catch (e, st) {
      _logger.warning('Android POST_NOTIFICATIONS status read failed', e, st);
      return PermissionAvailability.denied;
    }
  }
}

bool _liveIsAndroid() {
  return !kIsWeb && Platform.isAndroid;
}

bool _liveIsApple() {
  return !kIsWeb && (Platform.isIOS || Platform.isMacOS);
}

final notificationPermissionProvider = Provider<NotificationPermissionService>((ref) {
  return NotificationPermissionService();
});
