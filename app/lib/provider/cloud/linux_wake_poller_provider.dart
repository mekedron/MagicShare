import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('LinuxWakePoller');

/// Polling cadence pinned to 30 s per the cloud-sync spec §5.3 Notifications.
const Duration linuxWakePollInterval = Duration(seconds: 30);

/// Linux clients have no FlutterFire support, so they cannot call
/// `pollPendingWakes` through the typed [CloudFunctionsClient] yet. This
/// provider scaffolds the interface — start/stop, periodic fire — but
/// performs no network call until the follow-up epic ("Linux/Windows REST
/// cloud client") lands. Wiring the timer here keeps the rest of Epic 7
/// coherent: the Linux build compiles, lifecycle hooks already attach, and
/// the only missing piece is the REST transport.
class LinuxWakePollerService extends Notifier<LinuxWakePollState> {
  LinuxWakePollerService({
    Duration interval = linuxWakePollInterval,
    Future<void> Function()? pollOnce,
    @visibleForTesting bool requireLinuxPlatform = true,
  }) : _interval = interval,
       _pollOnce = pollOnce ?? _unimplementedPoll,
       _requireLinuxPlatform = requireLinuxPlatform;

  final Duration _interval;
  final Future<void> Function() _pollOnce;
  final bool _requireLinuxPlatform;
  Timer? _timer;
  int _pollAttempts = 0;

  @override
  LinuxWakePollState init() {
    if (_requireLinuxPlatform && defaultTargetPlatform != TargetPlatform.linux) {
      return const LinuxWakePollUnsupported();
    }
    return const LinuxWakePollIdle();
  }

  /// Starts the periodic poll. Idempotent — repeated calls are a no-op.
  void start() {
    if (state is LinuxWakePollUnsupported) return;
    if (_timer != null && _timer!.isActive) return;
    state = const LinuxWakePollRunning();
    _timer = Timer.periodic(_interval, (_) => unawaited(_safePoll()));
  }

  /// Stops the periodic poll. Safe to call when not running.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (state is LinuxWakePollRunning) {
      state = const LinuxWakePollIdle();
    }
  }

  @visibleForTesting
  int get pollAttempts => _pollAttempts;

  Future<void> _safePoll() async {
    _pollAttempts++;
    try {
      await _pollOnce();
    } catch (e, st) {
      _logger.warning('Linux wake poll attempt #$_pollAttempts failed', e, st);
    }
  }

  static Future<void> _unimplementedPoll() async {
    throw UnimplementedError(
      'Linux pollPendingWakes transport is deferred to the follow-up epic. '
      'See docs/development/desktop-push.md.',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Discriminated state for the Linux poller. [LinuxWakePollUnsupported] is
/// emitted on every non-Linux platform — the provider is a no-op there.
sealed class LinuxWakePollState {
  const LinuxWakePollState();
}

class LinuxWakePollIdle extends LinuxWakePollState {
  const LinuxWakePollIdle();
}

class LinuxWakePollRunning extends LinuxWakePollState {
  const LinuxWakePollRunning();
}

class LinuxWakePollUnsupported extends LinuxWakePollState {
  const LinuxWakePollUnsupported();
}

final linuxWakePollerProvider = NotifierProvider<LinuxWakePollerService, LinuxWakePollState>(
  (ref) => LinuxWakePollerService(),
);
