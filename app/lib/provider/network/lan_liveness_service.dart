import 'dart:async';

import 'package:common/isolate.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('LanLiveness');

/// How often the foregrounded app re-announces itself on the multicast
/// group. Three of these (60 s) fit inside [kLanDeviceTtl], so two
/// successive dropped UDP packets don't cause the device to flap
/// offline on peers.
const Duration kLanReannouncePeriod = Duration(seconds: 20);

/// How often the foregrounded app prunes its own nearby-devices list
/// against [kLanDeviceTtl]. A short period keeps the displayed dot
/// honest without burning meaningful CPU — pruning is a cheap pass
/// over an in-memory map.
const Duration kLanPrunePeriod = Duration(seconds: 10);

sealed class LanLivenessState {
  const LanLivenessState();
}

class LanLivenessIdle extends LanLivenessState {
  const LanLivenessIdle();
}

class LanLivenessRunning extends LanLivenessState {
  const LanLivenessRunning();
}

class LanLivenessStopped extends LanLivenessState {
  const LanLivenessStopped();
}

/// Cross-provider deps the liveness service needs. The provider factory
/// wires these to live `ref.notifier` / `ref.redux` calls; tests pass
/// fakes.
class LanLivenessDeps {
  LanLivenessDeps({
    required this.dispatchPrune,
    required this.dispatchAnnounce,
    required this.dispatchGoodbye,
  });

  final void Function() dispatchPrune;
  final void Function() dispatchAnnounce;
  final void Function() dispatchGoodbye;
}

/// Owns the LAN-side liveness loop: the periodic re-announce that
/// keeps remote peers' `lastSeenAt` fresh while we're foregrounded,
/// the periodic prune that ages out our own stale entries, and the
/// goodbye broadcast on backgrounding so peers drop us immediately.
///
/// Wired into `LifeCycleWatcher.onChangedState` in main.dart:
/// foreground transitions call [markForeground], background
/// transitions call [markBackground].
class LanLivenessService extends Notifier<LanLivenessState> {
  LanLivenessService({
    required LanLivenessDeps deps,
    Duration? reannouncePeriod,
    Duration? prunePeriod,
    Timer Function(Duration, void Function(Timer))? timerFactory,
  }) : _deps = deps,
       _reannouncePeriod = reannouncePeriod ?? kLanReannouncePeriod,
       _prunePeriod = prunePeriod ?? kLanPrunePeriod,
       _timerFactory = timerFactory ?? Timer.periodic;

  final LanLivenessDeps _deps;
  final Duration _reannouncePeriod;
  final Duration _prunePeriod;
  final Timer Function(Duration, void Function(Timer)) _timerFactory;
  Timer? _reannounceTimer;
  Timer? _pruneTimer;

  @override
  LanLivenessState init() => const LanLivenessIdle();

  /// Starts (or keeps running) the re-announce + prune loops.
  /// Idempotent — a second call while already running is a no-op so
  /// rapid foreground / inactive lifecycle flips don't stack timers.
  void markForeground() {
    if (_reannounceTimer != null && _reannounceTimer!.isActive) {
      _logger.fine('[presence:lan-foreground] already running, no-op');
      return;
    }
    _logger.info(
      '[presence:lan-foreground] starting reannouncePeriod=${_reannouncePeriod.inSeconds}s prunePeriod=${_prunePeriod.inSeconds}s',
    );
    _reannounceTimer = _timerFactory(_reannouncePeriod, (_) {
      _logger.info('[presence:lan-tick] re-announce');
      try {
        _deps.dispatchAnnounce();
      } catch (e, st) {
        _logger.warning('Periodic re-announce failed', e, st);
      }
    });
    _pruneTimer = _timerFactory(_prunePeriod, (_) {
      _logger.fine('[presence:lan-tick] prune');
      try {
        _deps.dispatchPrune();
      } catch (e, st) {
        _logger.warning('Periodic prune failed', e, st);
      }
    });
    state = const LanLivenessRunning();
  }

  /// Cancels the timers and best-effort broadcasts a goodbye so peers
  /// drop the entry immediately. The goodbye is fire-and-forget; if it
  /// doesn't make it through (slow socket teardown, mobile radio
  /// already half-gone) the receiving side falls back to the TTL prune
  /// within ~60 s.
  void markBackground() {
    _logger.info('[presence:lan-background] cancelling timers + broadcasting goodbye');
    final reannounce = _reannounceTimer;
    final prune = _pruneTimer;
    _reannounceTimer = null;
    _pruneTimer = null;
    reannounce?.cancel();
    prune?.cancel();
    try {
      _deps.dispatchGoodbye();
    } catch (e, st) {
      _logger.warning('Goodbye broadcast failed', e, st);
    }
    state = const LanLivenessStopped();
  }

  @override
  void dispose() {
    _reannounceTimer?.cancel();
    _pruneTimer?.cancel();
    _reannounceTimer = null;
    _pruneTimer = null;
    super.dispose();
  }
}

final lanLivenessProvider = NotifierProvider<LanLivenessService, LanLivenessState>((ref) {
  return LanLivenessService(
    deps: LanLivenessDeps(
      dispatchPrune: () => ref.redux(nearbyDevicesProvider).dispatch(PruneStaleDevicesAction()),
      dispatchAnnounce: () => ref.redux(parentIsolateProvider).dispatch(IsolateSendMulticastAnnouncementAction()),
      dispatchGoodbye: () => ref.redux(parentIsolateProvider).dispatch(IsolateSendMulticastGoodbyeAction()),
    ),
  );
});
