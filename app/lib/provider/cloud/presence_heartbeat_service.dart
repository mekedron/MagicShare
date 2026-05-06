import 'dart:async';

import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudPresence');

/// Cadence for the foreground presence heartbeat. The backend rate-limits
/// `updateDevicePresence` to one accepted call per device per 60 s — any
/// dispatch landing inside that window throws `resource-exhausted` and is
/// quietly swallowed by [_send]. We pick 70 s so a normal heartbeat is
/// always outside the window even when timer drift accumulates, while
/// still tightening the recovery window from the previous 4 minutes:
/// the cloud-side stale-presence sweep flips devices to offline after
/// 10 minutes of no `lastSeenAt` advance, so a device that drops a
/// heartbeat now recovers within ~70 s instead of risking the 10-min
/// offline window.
const Duration heartbeatPeriod = Duration(seconds: 70);

/// Discriminated state for the heartbeat lifecycle.
sealed class HeartbeatState {
  const HeartbeatState();
}

class HeartbeatIdle extends HeartbeatState {
  const HeartbeatIdle();
}

class HeartbeatDisabled extends HeartbeatState {
  const HeartbeatDisabled();
}

class HeartbeatUnsupported extends HeartbeatState {
  const HeartbeatUnsupported();
}

class HeartbeatRunning extends HeartbeatState {
  const HeartbeatRunning();
}

class HeartbeatStopped extends HeartbeatState {
  const HeartbeatStopped();
}

/// Cross-provider deps the heartbeat service needs. The provider factory
/// wires these to live `ref.read` calls; tests pass fakes.
class PresenceHeartbeatDeps {
  PresenceHeartbeatDeps({
    required this.client,
    required this.currentDeviceIdReader,
    required this.cloudSyncEnabledReader,
  });

  final CloudFunctionsClient Function() client;

  /// Returns the device id the heartbeat should report on, or null when
  /// the bootstrap hasn't yet finished and no device row exists.
  final String? Function() currentDeviceIdReader;

  final bool Function() cloudSyncEnabledReader;
}

/// Owns the foreground/background presence dispatch loop. Wired into
/// `LifeCycleWatcher.onChangedState` in main.dart: foreground transitions
/// call [markForeground], background transitions call [markBackground].
class PresenceHeartbeatService extends Notifier<HeartbeatState> {
  PresenceHeartbeatService({
    required PresenceHeartbeatDeps deps,
    Duration? period,
    bool? supportedOverride,
    Timer Function(Duration, void Function(Timer))? timerFactory,
  }) : _deps = deps,
       _period = period ?? heartbeatPeriod,
       _supportedOverride = supportedOverride,
       _timerFactory = timerFactory ?? Timer.periodic;

  final PresenceHeartbeatDeps _deps;
  final Duration _period;
  final bool? _supportedOverride;
  final Timer Function(Duration, void Function(Timer)) _timerFactory;
  Timer? _timer;
  bool _started = false;

  bool get _isSupported => _supportedOverride ?? checkPlatformSupportsCloudFunctions();
  bool get _isEnabled => _deps.cloudSyncEnabledReader();

  @override
  HeartbeatState init() {
    if (_started) return state;
    _started = true;
    if (!_isSupported) return const HeartbeatUnsupported();
    if (!_isEnabled) return const HeartbeatDisabled();
    return const HeartbeatIdle();
  }

  /// Marks the device online and starts the periodic loop. Idempotent: a
  /// second call while already running is a no-op (no stacked timers).
  void markForeground() {
    if (!_isSupported || !_isEnabled) return;
    if (_timer != null && _timer!.isActive) return;
    _timer = _timerFactory(_period, (_) {
      unawaited(_send(CloudDevicePresence.online));
    });
    state = const HeartbeatRunning();
    unawaited(_send(CloudDevicePresence.online));
  }

  /// Marks the device offline (best-effort) and cancels the timer.
  void markBackground() {
    if (!_isSupported || !_isEnabled) return;
    final timer = _timer;
    _timer = null;
    timer?.cancel();
    state = const HeartbeatStopped();
    unawaited(_send(CloudDevicePresence.offline));
  }

  Future<void> _send(CloudDevicePresence presence) async {
    final deviceId = _deps.currentDeviceIdReader();
    if (deviceId == null) {
      // Bootstrap hasn't reached a registered device yet — silently skip;
      // the next heartbeat tick (or the next foreground / background
      // transition) will catch up.
      return;
    }
    try {
      await _deps.client().updateDevicePresence(
        deviceId: deviceId,
        presence: presence,
      );
    } on CloudException catch (e) {
      // Rate-limit (1 call/min/device) is expected when foreground +
      // background flap quickly. Quietly swallow at debug level.
      if (e.code == CloudErrorCode.resourceExhausted) {
        _logger.fine('Presence dispatch rate-limited: ${e.message}');
        return;
      }
      _logger.warning('Presence dispatch failed (${e.code.name})', e);
    } catch (e, st) {
      _logger.warning('Presence dispatch failed', e, st);
    }
  }

  @override
  void dispose() {
    final timer = _timer;
    _timer = null;
    timer?.cancel();
    super.dispose();
  }
}

final presenceHeartbeatProvider = NotifierProvider<PresenceHeartbeatService, HeartbeatState>((ref) {
  return PresenceHeartbeatService(
    deps: PresenceHeartbeatDeps(
      client: () => ref.read(cloudFunctionsClientProvider),
      currentDeviceIdReader: () {
        final account = ref.read(accountRepositoryProvider);
        return account is AccountReady ? account.currentDeviceId : null;
      },
      cloudSyncEnabledReader: () => ref.read(settingsProvider).cloudSyncEnabled,
    ),
  );
});
