import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/wake/wake_payload.dart';
import 'package:magicshare_app/cloud/wake/wake_payload_codec.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cross_file.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:magicshare_app/provider/network/send_provider.dart';
import 'package:magicshare_app/provider/security_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudWake');

/// Maximum time we wait for the target to appear on multicast after
/// firing `sendWake`. Mirrors the spec's "device did not respond"
/// ceiling (§5.3 *Send Flow*).
const Duration kWakeWaitTimeout = Duration(seconds: 60);

/// Per-target wake status. Idle = key absent in the orchestrator state.
sealed class WakeStatus {
  const WakeStatus();
}

/// `sendWake` request in flight.
class WakeStatusSending extends WakeStatus {
  const WakeStatusSending();
}

/// `sendWake` succeeded; we are now waiting for the target to appear in
/// the LAN multicast list within [kWakeWaitTimeout].
class WakeStatusWaiting extends WakeStatus {
  const WakeStatusWaiting({required this.deadlineMs});
  final int deadlineMs;
}

/// Wake flow ended in failure. The tile surfaces the [message] and
/// offers a Retry action.
class WakeStatusError extends WakeStatus {
  const WakeStatusError({required this.message, required this.timedOut});
  final String message;

  /// True when the failure was the 60-s ceiling (vs a cloud-side error
  /// such as `unauthenticated` or `resource-exhausted`). The UI uses
  /// the spec copy "Device did not respond. It might be offline." for
  /// the timed-out path and the raw cloud-error message otherwise.
  final bool timedOut;
}

class WakeOrchestratorDeps {
  WakeOrchestratorDeps({
    required this.accountStateReader,
    required this.groupKeyReader,
    required this.sourceFingerprintReader,
    required this.client,
    required this.nearbyDevicesStream,
    required this.startSession,
    DateTime Function()? clock,
    Duration timeoutDuration = kWakeWaitTimeout,
  }) : _clock = clock ?? DateTime.now,
       _timeout = timeoutDuration;

  final AccountState Function() accountStateReader;
  final Uint8List? Function() groupKeyReader;
  final String? Function() sourceFingerprintReader;
  final CloudFunctionsClient Function() client;
  final Stream<Iterable<Device>> Function() nearbyDevicesStream;
  final Future<void> Function({
    required Device target,
    required List<CrossFile> files,
    required String wakeSessionId,
    required bool background,
  })
  startSession;

  final DateTime Function() _clock;
  final Duration _timeout;

  DateTime now() => _clock();
  Duration get timeout => _timeout;
}

class WakeOrchestrator extends Notifier<Map<String, WakeStatus>> {
  WakeOrchestrator({required WakeOrchestratorDeps deps}) : _deps = deps;

  final WakeOrchestratorDeps _deps;
  final Map<String, _PendingWake> _pending = {};

  @override
  Map<String, WakeStatus> init() => const {};

  /// Kicks off a wake for [target] and, on the receiver coming online,
  /// hands the transfer to [sendProvider] with the same session nonce
  /// so the upload-request carries `wakeSessionId`. Safe to call again
  /// on the same target — any in-flight wake for that target is
  /// cancelled first.
  Future<void> start({
    required CloudDevice target,
    required List<CrossFile> files,
    bool background = false,
  }) async {
    await _cancel(target.deviceId);

    final accountState = _deps.accountStateReader();
    if (accountState is! AccountReady) {
      _setStatus(target.deviceId, const WakeStatusError(message: 'Cloud not ready', timedOut: false));
      return;
    }
    final groupKey = _deps.groupKeyReader();
    if (groupKey == null) {
      _logger.warning(
        'Wake aborted: group key missing on this device '
        '(target=${target.deviceId})',
      );
      _setStatus(
        target.deviceId,
        const WakeStatusError(
          message:
              'Group key missing on this device — open Settings → '
              'Device group → Delete this device group, then create or '
              'join a group again.',
          timedOut: false,
        ),
      );
      return;
    }
    final sourceFingerprint = _deps.sourceFingerprintReader();
    if (sourceFingerprint == null || sourceFingerprint.isEmpty) {
      _setStatus(target.deviceId, const WakeStatusError(message: 'Local fingerprint missing', timedOut: false));
      return;
    }
    final targetFingerprint = target.fingerprint;
    if (targetFingerprint == null || targetFingerprint.isEmpty) {
      _setStatus(target.deviceId, const WakeStatusError(message: 'Target has no fingerprint', timedOut: false));
      return;
    }

    final nonce = generateWakeSessionNonce();
    final payload = WakePayload(
      sessionNonce: nonce,
      sourceFingerprint: sourceFingerprint,
      initiatedAtMs: _deps.now().millisecondsSinceEpoch,
    );
    final encoded = encodeWakePayload(payload, groupKey);

    _setStatus(target.deviceId, const WakeStatusSending());

    try {
      await _deps.client().sendWake(
        sourceDeviceId: accountState.currentDeviceId,
        targetDeviceId: target.deviceId,
        payload: encoded,
      );
    } on CloudException catch (e, st) {
      _logger.warning(
        'sendWake failed: code=${e.code.name} message="${e.message}" details=${e.details}',
        e,
        st,
      );
      // Default Firebase Functions text for `internal` is "An internal
      // error has occurred…", which gives the user nothing to act on.
      // Tag the surface message with the code so the run log + on-screen
      // text both point at the same thing.
      final surface = e.code.name == 'internal' ? '${e.message} (code=${e.code.name})' : e.message;
      _setStatus(
        target.deviceId,
        WakeStatusError(message: surface, timedOut: false),
      );
      return;
    }

    final deadline = _deps.now().add(_deps.timeout);
    _setStatus(
      target.deviceId,
      WakeStatusWaiting(deadlineMs: deadline.millisecondsSinceEpoch),
    );

    final pending = _PendingWake(targetDeviceId: target.deviceId);
    _pending[target.deviceId] = pending;
    pending.timeoutTimer = Timer(_deps.timeout, () {
      _onTimeout(target.deviceId);
    });
    pending.subscription = _deps.nearbyDevicesStream().listen(
      (devices) {
        // Wake requires HTTP reachability — the receiver must be
        // serving on a LAN endpoint to accept the transfer. A
        // signaling-only match isn't enough. Cert-hash compare only:
        // signaling tokens live in a different value space.
        final match = devices.firstWhereOrNull(
          (d) => d.hasHttpEndpoint && d.certHashes.contains(targetFingerprint),
        );
        if (match != null) {
          _onLanMatch(
            targetDeviceId: target.deviceId,
            match: match,
            files: files,
            wakeSessionId: nonce,
            background: background,
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        _logger.warning('Nearby-devices stream errored', error, stack);
        _setStatus(
          target.deviceId,
          WakeStatusError(message: error.toString(), timedOut: false),
        );
        unawaited(_cancel(target.deviceId));
      },
    );
  }

  /// Cancels an in-flight wake for [targetDeviceId]. Idempotent. Used
  /// by the UI when the user navigates away from the Send tab.
  Future<void> cancel(String targetDeviceId) async {
    await _cancel(targetDeviceId);
    _clearStatus(targetDeviceId);
  }

  /// Clears a terminal (error) status without affecting any in-flight
  /// pending state. Called by the UI's "Retry" button so the tile drops
  /// back to its idle indicator before the next attempt fires.
  void clearError(String targetDeviceId) {
    final current = state[targetDeviceId];
    if (current is WakeStatusError) {
      _clearStatus(targetDeviceId);
    }
  }

  void _onLanMatch({
    required String targetDeviceId,
    required Device match,
    required List<CrossFile> files,
    required String wakeSessionId,
    required bool background,
  }) {
    final pending = _pending.remove(targetDeviceId);
    pending?.timeoutTimer.cancel();
    unawaited(pending?.subscription.cancel());
    _clearStatus(targetDeviceId);
    unawaited(
      _deps.startSession(
        target: match,
        files: files,
        wakeSessionId: wakeSessionId,
        background: background,
      ),
    );
  }

  void _onTimeout(String targetDeviceId) {
    final pending = _pending.remove(targetDeviceId);
    unawaited(pending?.subscription.cancel());
    _setStatus(
      targetDeviceId,
      const WakeStatusError(
        message: 'Device did not respond. It might be offline.',
        timedOut: true,
      ),
    );
  }

  Future<void> _cancel(String targetDeviceId) async {
    final pending = _pending.remove(targetDeviceId);
    if (pending == null) return;
    pending.timeoutTimer.cancel();
    await pending.subscription.cancel();
  }

  void _setStatus(String targetDeviceId, WakeStatus status) {
    state = {...state, targetDeviceId: status};
  }

  void _clearStatus(String targetDeviceId) {
    if (!state.containsKey(targetDeviceId)) return;
    final next = Map<String, WakeStatus>.from(state)..remove(targetDeviceId);
    state = next;
  }

  @override
  Future<void> dispose() async {
    for (final pending in _pending.values) {
      pending.timeoutTimer.cancel();
      await pending.subscription.cancel();
    }
    _pending.clear();
    super.dispose();
  }
}

class _PendingWake {
  _PendingWake({required this.targetDeviceId});
  final String targetDeviceId;
  late final Timer timeoutTimer;
  late final StreamSubscription<Iterable<Device>> subscription;
}

final wakeOrchestratorProvider = NotifierProvider<WakeOrchestrator, Map<String, WakeStatus>>((ref) {
  return WakeOrchestrator(
    deps: WakeOrchestratorDeps(
      accountStateReader: () => ref.read(accountRepositoryProvider),
      groupKeyReader: () {
        final keyState = ref.read(groupKeyProvider);
        return keyState is GroupKeyReady ? keyState.key : null;
      },
      sourceFingerprintReader: () => ref.read(securityProvider).certificateHash,
      client: () => ref.read(cloudFunctionsClientProvider),
      nearbyDevicesStream: () => ref.stream(nearbyDevicesProvider).map((event) => event.next.allDevices.values),
      startSession:
          ({
            required Device target,
            required List<CrossFile> files,
            required String wakeSessionId,
            required bool background,
          }) async {
            await ref
                .notifier(sendProvider)
                .startSession(
                  target: target,
                  files: files,
                  background: background,
                  wakeSessionId: wakeSessionId,
                );
          },
    ),
  );
});
