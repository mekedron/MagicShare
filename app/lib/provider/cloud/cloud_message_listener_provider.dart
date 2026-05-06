import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/wake/cloud_message.dart';
import 'package:magicshare_app/cloud/wake/cloud_message_dispatcher.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_persistence.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_registry.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/provider/cloud/wake_nonce_registry_provider.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('CloudMessageListener');

/// Two minutes — matches the receiver-side expected-nonce window in
/// `cloud-sync-spec.md` §5.3. Used as a fallback when the wake payload
/// itself doesn't carry a sender timestamp.
const Duration wakeNonceTtl = Duration(minutes: 2);

/// Surface of [FirebaseMessaging] that [CloudMessageListenerService]
/// consumes. Modelled as a typedef bag so tests can inject controlled
/// streams without mocking the platform SDK directly.
class CloudMessageListenerGateway {
  CloudMessageListenerGateway({
    required this.onMessage,
    required this.onMessageOpenedApp,
    required this.getInitialMessage,
  });

  /// Stream of FCM messages delivered while the app is in the
  /// foreground.
  final Stream<RemoteMessage> Function() onMessage;

  /// Stream of taps on a backgrounded notification that brought the
  /// app forward.
  final Stream<RemoteMessage> Function() onMessageOpenedApp;

  /// Initial-message lookup for the cold-start tap case (the user tapped
  /// a notification while the app was killed, which launched it).
  final Future<RemoteMessage?> Function() getInitialMessage;

  factory CloudMessageListenerGateway.live() {
    final messaging = FirebaseMessaging.instance;
    return CloudMessageListenerGateway(
      onMessage: () => FirebaseMessaging.onMessage,
      onMessageOpenedApp: () => FirebaseMessaging.onMessageOpenedApp,
      getInitialMessage: () => messaging.getInitialMessage(),
    );
  }
}

/// Function the listener calls to open a URL. Defaults to
/// [launchUrl] from `url_launcher`; tests inject a recorder.
typedef LaunchUrlFn = Future<bool> Function(Uri uri);

Future<bool> _liveLaunchUrl(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Discriminated state for the listener — mostly informational, useful
/// in debug overlays.
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

/// Subscribes to foreground FCM messages and notification taps; routes
/// each one through [CloudMessageDispatcher] and acts on the result:
///
/// - [WakeMessage] → register the nonce in [WakeNonceRegistry] so the
///   receive controller's auto-accept hook short-circuits the matching
///   `prepareUpload`.
/// - [LinkMessage] → open the URL via `url_launcher`.
/// - [CloudMessageError] → log and drop.
///
/// Also drains [WakeNoncePersistence] into the registry on `init()`
/// (covers cold-start where the FCM background isolate or a previous
/// app run wrote nonces) and exposes [drainPersistence] so the
/// app-lifecycle watcher can call it on `resumed`.
class CloudMessageListenerService extends Notifier<CloudMessageListenerState> {
  CloudMessageListenerService({
    CloudMessageListenerGateway? gateway,
    CloudMessageDispatcher dispatcher = const CloudMessageDispatcher(),
    WakeNoncePersistence persistence = const WakeNoncePersistence(),
    LaunchUrlFn? launchUrl,
    bool? supportedOverride,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _dispatcher = dispatcher,
       _persistence = persistence,
       _launchUrl = launchUrl ?? _liveLaunchUrl,
       _supportedOverride = supportedOverride,
       _clock = clock ?? DateTime.now;

  final CloudMessageListenerGateway? _gateway;
  final CloudMessageDispatcher _dispatcher;
  final WakeNoncePersistence _persistence;
  final LaunchUrlFn _launchUrl;
  final bool? _supportedOverride;
  final DateTime Function() _clock;

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
    _onMessageSub = gateway.onMessage().listen(
      _handleRemoteMessage,
      onError: (Object error, StackTrace stack) => _logger.warning('onMessage stream errored', error, stack),
    );
    _onTapSub = gateway.onMessageOpenedApp().listen(
      _handleRemoteMessage,
      onError: (Object error, StackTrace stack) => _logger.warning('onMessageOpenedApp stream errored', error, stack),
    );
    unawaited(_handleInitialMessage(gateway));
    unawaited(drainPersistence());
    return const CloudMessageListenerRunning();
  }

  /// Drains the [WakeNoncePersistence] buffer into the in-memory
  /// [WakeNonceRegistry]. Called once from `init()` and again from the
  /// app-lifecycle watcher every time the app resumes — so a wake the
  /// background isolate wrote while the app was paused gets picked up
  /// the moment the user comes back.
  Future<void> drainPersistence() async {
    try {
      final entries = await _persistence.drain();
      if (entries.isEmpty) return;
      final registry = ref.read(wakeNonceRegistryProvider);
      for (final entry in entries) {
        registry.register(entry.nonce, entry.expiresAt);
      }
      _logger.info('Drained ${entries.length} pending wake nonces from persistence');
    } catch (e, st) {
      _logger.warning('Draining wake-nonce persistence failed', e, st);
    }
  }

  Future<void> _handleInitialMessage(CloudMessageListenerGateway gateway) async {
    try {
      final initial = await gateway.getInitialMessage();
      if (initial != null) {
        _handleRemoteMessage(initial);
      }
    } catch (e, st) {
      _logger.warning('getInitialMessage failed', e, st);
    }
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    _logger.info(
      'Foreground FCM event received (type=${data['type']}, '
      'hasPayload=${data['payload'] != null}, hasUrl=${data['url'] != null})',
    );
    final groupKey = _resolveGroupKey();
    if (groupKey == null) {
      _logger.info('No group key on this device — encrypted payloads will be dropped');
    }
    final result = _dispatcher.dispatch(data, groupKey: groupKey);
    switch (result) {
      case WakeMessage():
        _onWake(result);
      case LinkMessage():
        unawaited(_onLink(result));
      case CloudMessageError():
        _logger.warning('Dispatcher returned error: ${result.reason}');
    }
  }

  void _onWake(WakeMessage wake) {
    final registry = ref.read(wakeNonceRegistryProvider);
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(wake.initiatedAtMs).add(wakeNonceTtl);
    final now = _clock();
    // If the sender clock is way ahead of ours the entry would live
    // longer than 2 min; if it's way behind it could already be expired.
    // Cap at our local now + ttl as a safety net.
    final cap = now.add(wakeNonceTtl);
    final boundedExpiry = expiresAt.isAfter(cap) ? cap : expiresAt;
    registry.register(wake.nonce, boundedExpiry);
    _logger.info('Registered wake nonce (expires ${boundedExpiry.toIso8601String()})');
  }

  Future<void> _onLink(LinkMessage link) async {
    _logger.info('Link message: opening ${link.url}');
    Uri? uri;
    try {
      uri = Uri.parse(link.url);
    } catch (e) {
      _logger.warning('Link message carried unparseable URL: ${link.url}', e);
      return;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      _logger.warning('Link message carried non-http(s) URL: ${link.url}');
      return;
    }
    try {
      final ok = await _launchUrl(uri);
      if (!ok) {
        _logger.warning('launchUrl reported failure for ${link.url}');
      } else {
        _logger.info('launchUrl succeeded for ${link.url}');
      }
    } catch (e, st) {
      _logger.warning('launchUrl threw for ${link.url}', e, st);
    }
  }

  Uint8List? _resolveGroupKey() {
    final state = ref.read(groupKeyProvider);
    if (state is GroupKeyReady) {
      return state.key;
    }
    return null;
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
