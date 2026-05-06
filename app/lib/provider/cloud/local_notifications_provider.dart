import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('LocalNotifications');

/// Channel id reused from the Android manifest meta-data declared in
/// Epic 7. New channel ids would require a manifest tweak.
const String localNotificationsChannelId = 'magicshare_cloud_sync';

/// Localised channel name. Kept in code (not slang) because the channel
/// is created on first init from any isolate, including the FCM
/// background isolate where we don't have the slang container.
const String localNotificationsChannelName = 'Cloud sync';

/// Notification payload key used to route a tap to the right handler.
/// `link:<url>` — open URL in system browser.
String encodeLinkNotificationPayload(String url) => jsonEncode(<String, String>{
  'kind': 'link',
  'url': url,
});

/// Minimal surface of [FlutterLocalNotificationsPlugin] that
/// [LocalNotificationsService] consumes. Modelled as a typedef bag so
/// tests can inject a recorder without mocking the platform plugin.
class LocalNotificationsGateway {
  LocalNotificationsGateway({
    required this.initialize,
    required this.show,
  });

  final Future<bool?> Function({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  })
  initialize;

  final Future<void> Function({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  })
  show;

  factory LocalNotificationsGateway.live() {
    final plugin = FlutterLocalNotificationsPlugin();
    return LocalNotificationsGateway(
      initialize:
          ({
            required InitializationSettings settings,
            DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
            DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
          }) => plugin.initialize(
            settings: settings,
            onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
            onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
          ),
      show:
          ({
            required int id,
            String? title,
            String? body,
            NotificationDetails? notificationDetails,
            String? payload,
          }) => plugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: notificationDetails,
            payload: payload,
          ),
    );
  }
}

/// Function called when the user taps a link notification produced by
/// [LocalNotificationsService.showLinkNotification]. Defaults to
/// [launchUrl]; tests inject a recorder.
typedef LaunchUrlFn = Future<bool> Function(Uri uri);

Future<bool> _liveLaunchUrl(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Owns the platform-side local-notification surface used by the
/// encrypted-link path in the FCM background handler and (in a follow-up
/// epic) the Linux poller. Plaintext-mode link notifications still
/// arrive as FCM `notification` payloads — the OS surfaces them
/// directly without going through this service.
class LocalNotificationsService {
  LocalNotificationsService({
    LocalNotificationsGateway? gateway,
    LaunchUrlFn? launchUrl,
  }) : _gateway = gateway ?? LocalNotificationsGateway.live(),
       _launchUrl = launchUrl ?? _liveLaunchUrl;

  final LocalNotificationsGateway _gateway;
  final LaunchUrlFn _launchUrl;
  bool _initialized = false;
  int _idCounter = 0;

  /// One-time initialise. Subsequent calls are no-ops. Call from
  /// `postInit` (foreground) and from the background handler so taps
  /// are wired both ways.
  Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
    );
    try {
      await _gateway.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _initialized = true;
    } catch (e, st) {
      _logger.warning('Initialising local notifications failed', e, st);
    }
  }

  /// Surfaces a tappable notification whose tap action opens [url] in
  /// the system browser. Used for encrypted-mode link FCM payloads
  /// arriving while the app is paused / killed (FCM data-only carries
  /// no `notification` field, so the OS surfaces nothing on its own).
  Future<void> showLinkNotification({
    required String url,
    String? title,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    final id = _idCounter++;
    const androidDetails = AndroidNotificationDetails(
      localNotificationsChannelId,
      localNotificationsChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
    try {
      await _gateway.show(
        id: id,
        title: title ?? 'Open link',
        body: url,
        notificationDetails: details,
        payload: encodeLinkNotificationPayload(url),
      );
    } catch (e, st) {
      _logger.warning('Showing link notification failed', e, st);
    }
  }

  void _handleResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final kind = decoded['kind'];
      final url = decoded['url'];
      if (kind != 'link' || url is! String || url.isEmpty) return;
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        _logger.warning('Notification carried invalid URL: $url');
        return;
      }
      unawaited(_launchUrl(uri));
    } catch (e, st) {
      _logger.warning('Handling notification response failed', e, st);
    }
  }
}

final localNotificationsProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});
