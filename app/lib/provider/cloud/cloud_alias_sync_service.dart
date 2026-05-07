import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/network/server/server_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudAliasSync');

/// Discriminated state — purely informational, useful for debug overlays.
sealed class CloudAliasSyncState {
  const CloudAliasSyncState();
}

class CloudAliasSyncIdle extends CloudAliasSyncState {
  const CloudAliasSyncIdle();
}

class CloudAliasSyncRunning extends CloudAliasSyncState {
  const CloudAliasSyncRunning();
}

/// Surface of the surrounding providers that [CloudAliasSyncService]
/// depends on. Pulled out as a typedef-bag so the notifier is testable
/// with `Notifier.test` without a `RefenaScope`.
class CloudAliasSyncDeps {
  CloudAliasSyncDeps({
    required this.accountStateReader,
    required this.accountStateChanges,
    required this.aliasReader,
    required this.setAlias,
    required this.restartServer,
  });

  /// Snapshot of the current account state at attach time.
  final AccountState Function() accountStateReader;

  /// Stream of subsequent account-state transitions.
  final Stream<AccountState> Function() accountStateChanges;

  /// Reads the current local LAN alias on every call.
  final String Function() aliasReader;

  /// Persists the new local alias and updates the in-memory settings
  /// state so other providers (server, signaling) see the change.
  final Future<void> Function(String alias) setAlias;

  /// Tears down and re-starts the LAN HTTP server, picking up the new
  /// alias for the multicast announce. No-op when the server is not
  /// currently running.
  final Future<void> Function() restartServer;
}

/// Pushes the current device row's cloud-managed `displayName` into the
/// local `settings.alias` whenever they differ. The local alias is what
/// gets broadcast on multicast and over the WebRTC signaling channel —
/// keeping it aligned with the cloud-managed name lets the receiver-side
/// merge in `mergeNetworkDevices` collapse the LAN tile and the cloud
/// tile via the alias-fallback the moment WebRTC discovery populates,
/// without waiting for the slower LAN HTTP discovery to fire fingerprint
/// matching.
///
/// The sync is one-directional (cloud → local). A user-initiated local
/// rename via the settings tab is preserved: once we've pushed a value
/// from cloud and the user changes it locally, we won't re-push the same
/// cloud value on top of it. The user is expected to rename via the
/// device-group settings UI when they want the change to propagate.
class CloudAliasSyncService extends Notifier<CloudAliasSyncState> {
  CloudAliasSyncService({required CloudAliasSyncDeps deps}) : _deps = deps;

  final CloudAliasSyncDeps _deps;
  StreamSubscription<AccountState>? _subscription;

  /// The last cloud `displayName` we successfully pushed into local
  /// settings. Used to suppress re-application of the same cloud value
  /// after the user has edited the local alias — without this, the next
  /// AccountReady emission (e.g. from an unrelated FCM-token refresh)
  /// would clobber the user's edit.
  String? _lastSyncedAlias;

  bool _started = false;

  @override
  CloudAliasSyncState init() {
    if (_started) return state;
    _started = true;
    _subscription = _deps.accountStateChanges().listen(
      (next) => unawaited(_onAccountStateChanged(next)),
      onError: (Object error, StackTrace stack) {
        _logger.warning('Account-state stream errored', error, stack);
      },
    );
    final initial = _deps.accountStateReader();
    unawaited(_onAccountStateChanged(initial));
    return const CloudAliasSyncRunning();
  }

  Future<void> _onAccountStateChanged(AccountState next) async {
    if (next is! AccountReady) return;
    final myDevice = next.devices.firstWhereOrNull(
      (d) => d.deviceId == next.currentDeviceId,
    );
    if (myDevice == null) return;
    final cloudName = myDevice.displayName.trim();
    if (cloudName.isEmpty) return;
    final localAlias = _deps.aliasReader();
    if (cloudName == localAlias) {
      // Already in sync — record the high-water mark so a subsequent
      // local edit isn't accidentally re-overwritten by a re-emit of
      // the same cloud value.
      _lastSyncedAlias = cloudName;
      return;
    }
    if (cloudName == _lastSyncedAlias) {
      // We've already pushed this cloud value once and the local alias
      // has since been edited (otherwise the equality check above would
      // have hit). Don't fight the user.
      return;
    }
    try {
      _logger.info(
        'Syncing cloud displayName "$cloudName" into local alias '
        '(was "$localAlias")',
      );
      await _deps.setAlias(cloudName);
      await _deps.restartServer();
      _lastSyncedAlias = cloudName;
    } catch (e, st) {
      _logger.warning('Alias sync failed', e, st);
    }
  }

  @override
  void dispose() {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }
}

final cloudAliasSyncProvider = NotifierProvider<CloudAliasSyncService, CloudAliasSyncState>((ref) {
  return CloudAliasSyncService(
    deps: CloudAliasSyncDeps(
      accountStateReader: () => ref.read(accountRepositoryProvider),
      accountStateChanges: () => ref.stream(accountRepositoryProvider).map((event) => event.next),
      aliasReader: () => ref.read(settingsProvider).alias,
      setAlias: (alias) => ref.notifier(settingsProvider).setAlias(alias),
      restartServer: () async {
        await ref.notifier(serverProvider).restartServerFromSettings();
      },
    ),
  );
});
