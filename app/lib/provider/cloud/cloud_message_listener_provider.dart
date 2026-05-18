import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudMessageListener');

/// Surface of [FirebaseMessaging] that [CloudMessageListenerService]
/// consumes. Modelled as a typedef bag so tests can inject controlled
/// streams without mocking the platform SDK directly.
class CloudMessageListenerGateway {
  CloudMessageListenerGateway({
    required this.onMessage,
    required this.onMessageOpenedApp,
    required this.getInitialMessage,
    this.enableForegroundPresentation,
  });

  final Stream<RemoteMessage> Function() onMessage;
  final Stream<RemoteMessage> Function() onMessageOpenedApp;
  final Future<RemoteMessage?> Function() getInitialMessage;

  /// Opts iOS into showing the FCM banner while the app is foregrounded.
  /// Null in tests; lazy in production so a missing Firebase init in
  /// startup error paths doesn't crash this listener.
  final Future<void> Function()? enableForegroundPresentation;

  factory CloudMessageListenerGateway.live() {
    final messaging = FirebaseMessaging.instance;
    return CloudMessageListenerGateway(
      onMessage: () => FirebaseMessaging.onMessage,
      onMessageOpenedApp: () => FirebaseMessaging.onMessageOpenedApp,
      getInitialMessage: () => messaging.getInitialMessage(),
      enableForegroundPresentation: () => messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      ),
    );
  }
}

sealed class CloudMessageListenerState {
  const CloudMessageListenerState();
}

class CloudMessageListenerIdle extends CloudMessageListenerState {
  const CloudMessageListenerIdle();
}

class CloudMessageListenerUnsupported extends CloudMessageListenerState {
  const CloudMessageListenerUnsupported();
}

class CloudMessageListenerRunning extends CloudMessageListenerState {
  const CloudMessageListenerRunning();
}

/// Listens for foreground FCM messages and notification taps purely to
/// log them. The new transfer-intent notification flow is fully visible:
/// the OS displays the notification in background/killed state, and a
/// notification tap brings the app forward via the usual cold-start /
/// resume path — no Dart routing required. Foreground messages also
/// reach this listener but produce no UI, because the sender's actual
/// LAN transfer will surface the receive Accept dialog moments later.
class CloudMessageListenerService extends Notifier<CloudMessageListenerState> {
  CloudMessageListenerService({
    CloudMessageListenerGateway? gateway,
    bool? supportedOverride,
  }) : _gateway = gateway,
       _supportedOverride = supportedOverride;

  final CloudMessageListenerGateway? _gateway;
  final bool? _supportedOverride;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onTapSub;
  bool _started = false;

  bool get _isSupported => _supportedOverride ?? checkPlatformSupportsFcm();

  CloudMessageListenerGateway get _resolvedGateway => _gateway ?? CloudMessageListenerGateway.live();

  @override
  CloudMessageListenerState init() {
    if (!_isSupported) {
      return const CloudMessageListenerUnsupported();
    }
    if (_started) {
      return const CloudMessageListenerRunning();
    }
    _started = true;
    final gateway = _resolvedGateway;
    // iOS hides FCM notifications when the app is foregrounded unless
    // we explicitly opt in. The new transfer-intent push must always
    // be visible — including when the receiver is sitting in the app
    // when the sender taps a group device.
    final enableForeground = gateway.enableForegroundPresentation;
    if (enableForeground != null) {
      unawaited(
        Future(() async {
          try {
            await enableForeground();
          } catch (e, st) {
            _logger.warning('setForegroundNotificationPresentationOptions failed', e, st);
          }
        }),
      );
    }
    _onMessageSub = gateway.onMessage().listen(
      _logForeground,
      onError: (Object error, StackTrace stack) => _logger.warning('onMessage stream errored', error, stack),
    );
    _onTapSub = gateway.onMessageOpenedApp().listen(
      _logTapped,
      onError: (Object error, StackTrace stack) => _logger.warning('onMessageOpenedApp stream errored', error, stack),
    );
    unawaited(_handleInitialMessage(gateway));
    return const CloudMessageListenerRunning();
  }

  Future<void> _handleInitialMessage(CloudMessageListenerGateway gateway) async {
    try {
      final initial = await gateway.getInitialMessage();
      if (initial != null) {
        _logTapped(initial);
      }
    } catch (e, st) {
      _logger.warning('getInitialMessage failed', e, st);
    }
  }

  void _logForeground(RemoteMessage message) {
    final data = message.data;
    _logger.info('Foreground FCM message (type=${data['type']}, kind=${data['kind']})');
  }

  void _logTapped(RemoteMessage message) {
    final data = message.data;
    _logger.info('Notification tap (type=${data['type']}, kind=${data['kind']})');
  }

  @override
  void dispose() {
    final m = _onMessageSub;
    final t = _onTapSub;
    _onMessageSub = null;
    _onTapSub = null;
    if (m != null) unawaited(m.cancel());
    if (t != null) unawaited(t.cancel());
    super.dispose();
  }
}

final cloudMessageListenerProvider = NotifierProvider<CloudMessageListenerService, CloudMessageListenerState>((ref) {
  return CloudMessageListenerService();
});
