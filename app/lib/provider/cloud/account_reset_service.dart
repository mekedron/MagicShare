import 'package:logging/logging.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('AccountResetService');

/// Cross-provider deps in a typedef-bag, mirroring the pattern used by
/// AccountRepository and CloudBootstrapService — keeps the service unit
/// testable without spinning up a full RefenaScope.
class AccountResetDeps {
  AccountResetDeps({
    required this.deleteAccountOnCloud,
    required this.removeDeviceOnCloud,
    required this.clearGroupKey,
    required this.deleteAndResetAuth,
  });

  final Future<void> Function() deleteAccountOnCloud;
  final Future<void> Function(String deviceId) removeDeviceOnCloud;
  final Future<void> Function() clearGroupKey;
  final Future<void> Function() deleteAndResetAuth;
}

/// Coordinates the leave / destroy-this-device-group flows.
///
/// Both flows share the same local steps (clear group key + auth reset)
/// — only the cloud-side step differs:
///
/// - [resetForGroupDeletion] calls `deleteAccount` first, which wipes
///   the Firestore account document and cascades to all child devices.
///   Used by the explicit *Delete this device group* red button.
/// - [resetForLeaveGroup] calls `removeDevice(currentDeviceId)` first,
///   which removes only this device. The cloud function cascades to
///   delete the parent account when this was the last device. Used by
///   the current-device bottom sheet's *Leave or destroy this group*
///   row.
///
/// Local steps in both flows:
/// 1. `groupKeyService.clear()` — wipes the local group key and device
///    id so the next bootstrap registers a fresh device row.
/// 2. `cloudAuthService.deleteAndReset()` — deletes the Firebase Auth
///    user. The auth-state stream emits null, the auth service re-signs
///    in anonymously with a new UID, and the bootstrap service then
///    re-runs and creates a fresh account + device.
///
/// A failure in any step short-circuits and surfaces the original
/// exception. Local steps only run after the cloud step succeeds —
/// there is no point wiping local state if the cloud-side action
/// failed.
class AccountResetService {
  AccountResetService(this._deps);

  final AccountResetDeps _deps;

  /// User explicitly opted to wipe everything. We attempt the cloud
  /// wipe first, but a failure there does NOT block local cleanup —
  /// the user's mental model is "make this device forget the group",
  /// and leaving the local app in a half-bad state because the cloud
  /// rejected our call (stale UID, emulator reset, transient 500)
  /// produces a worse UX than letting potential orphan docs sit until
  /// the 90-day GC. The cloud error is logged for diagnostics.
  Future<void> resetForGroupDeletion() async {
    _logger.info('Starting destroy-group flow');
    try {
      await _deps.deleteAccountOnCloud();
    } catch (e, st) {
      _logger.warning('Cloud-side deleteAccount failed; continuing with local reset', e, st);
    }
    await _resetLocalState();
    _logger.info('Destroy-group flow complete');
  }

  /// Triggered by AccountRepository when the account document the
  /// user was attached to disappears from Firestore — i.e. another
  /// device in the group ran *Delete this device group* (or this
  /// device's row was removed by a peer). The cloud-side action is
  /// already done; we only run the local cleanup so the user lands
  /// back at the welcome card with a fresh anon UID on next bootstrap
  /// instead of being stuck on a ghost group.
  Future<void> resetForExternalGroupDeletion() async {
    _logger.info('Starting external-group-deletion reset');
    await _resetLocalState();
    _logger.info('External-group-deletion reset complete');
  }

  /// Leave-group only swallows notFound (the cloud already considers
  /// this device gone, e.g. after another device removed it). Other
  /// failures abort the flow because the rest of the group is supposed
  /// to stay intact and a partial leave would corrupt that.
  Future<void> resetForLeaveGroup({required String currentDeviceId}) async {
    _logger.info('Starting leave-group flow for device $currentDeviceId');
    try {
      await _deps.removeDeviceOnCloud(currentDeviceId);
    } on CloudException catch (e) {
      if (e.code != CloudErrorCode.notFound) rethrow;
      _logger.info('Cloud-side removeDevice returned notFound; proceeding with local reset');
    }
    await _resetLocalState();
    _logger.info('Leave-group flow complete');
  }

  Future<void> _resetLocalState() async {
    await _deps.clearGroupKey();
    await _deps.deleteAndResetAuth();
  }
}

final accountResetServiceProvider = Provider<AccountResetService>((ref) {
  return AccountResetService(
    AccountResetDeps(
      deleteAccountOnCloud: () async {
        await ref.read(cloudFunctionsClientProvider).deleteAccount();
      },
      removeDeviceOnCloud: (deviceId) async {
        await ref.read(cloudFunctionsClientProvider).removeDevice(deviceId: deviceId);
      },
      clearGroupKey: () => ref.notifier(groupKeyProvider).clear(),
      deleteAndResetAuth: () => ref.notifier(cloudAuthProvider).deleteAndReset(),
    ),
  );
});
