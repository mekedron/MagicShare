import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudFcm');

/// iOS does not assign an APNS token immediately on launch — the system
/// needs to talk to APNs first. `getToken()` returns null until the APNS
/// token is in place. We poll for at most this long before giving up and
/// surfacing a transient null token; `onTokenRefresh` will deliver the
/// real token a moment later.
const Duration _apnsWaitTimeout = Duration(seconds: 5);
const Duration _apnsPollInterval = Duration(milliseconds: 250);

/// Surface of [FirebaseMessaging] that [FcmService] consumes. Modelled as
/// a typedef-bag so tests can supply fakes without mocking the platform
/// SDK directly.
class FcmGateway {
  FcmGateway({
    required this.getToken,
    required this.onTokenRefresh,
    required this.getApnsToken,
  });

  /// Returns the current FCM registration token, or null when one hasn't
  /// been issued yet (iOS APNS race).
  final Future<String?> Function() getToken;

  /// Stream of new FCM tokens issued by the SDK.
  final Stream<String> Function() onTokenRefresh;

  /// Returns the iOS APNS token (or null on Android / non-Apple platforms).
  /// Used to detect the iOS race window before [getToken] returns a value.
  final Future<String?> Function() getApnsToken;

  factory FcmGateway.live() {
    final messaging = FirebaseMessaging.instance;
    return FcmGateway(
      getToken: () => messaging.getToken(),
      onTokenRefresh: () => messaging.onTokenRefresh,
      getApnsToken: () => messaging.getAPNSToken(),
    );
  }
}

/// Discriminated FCM token state.
sealed class FcmState {
  const FcmState();
}

class FcmIdle extends FcmState {
  const FcmIdle();
}

class FcmUnsupported extends FcmState {
  const FcmUnsupported();
}

class FcmAcquiring extends FcmState {
  const FcmAcquiring();
}

class FcmReady extends FcmState {
  final String token;
  const FcmReady(this.token);

  @override
  bool operator ==(Object other) => identical(this, other) || other is FcmReady && other.token == token;

  @override
  int get hashCode => token.hashCode;
}

class FcmFailed extends FcmState {
  final String message;
  final Object error;
  const FcmFailed({required this.message, required this.error});
}

/// Pulls the current FCM token at startup (waiting briefly for the iOS
/// APNS token if needed) and tracks subsequent refreshes.
class FcmService extends Notifier<FcmState> {
  FcmService({FcmGateway? gateway, bool? supportedOverride}) : _gateway = gateway, _supportedOverride = supportedOverride;

  final FcmGateway? _gateway;
  final bool? _supportedOverride;
  StreamSubscription<String>? _refreshSubscription;
  bool _started = false;

  bool get _isSupported => _supportedOverride ?? checkPlatformSupportsFcm();

  FcmGateway get _resolvedGateway => _gateway ?? FcmGateway.live();

  @override
  FcmState init() {
    if (!_isSupported) {
      return const FcmUnsupported();
    }
    if (!_started) {
      _started = true;
      unawaited(_acquireToken());
      _refreshSubscription = _resolvedGateway.onTokenRefresh().listen(
        (token) {
          state = FcmReady(token);
        },
        onError: (Object error, StackTrace stack) {
          _logger.warning('FCM token refresh stream errored', error, stack);
          state = FcmFailed(message: 'Token refresh error', error: error);
        },
      );
    }
    return const FcmAcquiring();
  }

  Future<void> _acquireToken() async {
    try {
      // Wait for the iOS APNS token before requesting an FCM token.
      // Returns immediately on platforms where getApnsToken always returns null.
      await _waitForApnsToken();
      final token = await _resolvedGateway.getToken();
      if (token == null) {
        _logger.info('FCM token not yet available — waiting for refresh');
        // Stay in Acquiring; onTokenRefresh will surface the eventual token.
        return;
      }
      state = FcmReady(token);
    } catch (e, st) {
      _logger.warning('Acquiring FCM token failed', e, st);
      state = FcmFailed(message: 'getToken failed: $e', error: e);
    }
  }

  Future<void> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    final deadline = DateTime.now().add(_apnsWaitTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final apns = await _resolvedGateway.getApnsToken();
      if (apns != null) return;
      await Future<void>.delayed(_apnsPollInterval);
    }
    // Timed out — getToken() will likely return null and the refresh
    // subscription will catch up later.
  }

  @override
  void dispose() {
    final sub = _refreshSubscription;
    _refreshSubscription = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}

final fcmProvider = NotifierProvider<FcmService, FcmState>((ref) {
  return FcmService();
});
