import 'package:logging/logging.dart';
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

  Future<void> resetForGroupDeletion() async {
    _logger.info('Starting destroy-group flow');
    await _deps.deleteAccountOnCloud();
    await _resetLocalState();
    _logger.info('Destroy-group flow complete; awaiting bootstrap re-run');
  }

  Future<void> resetForLeaveGroup({required String currentDeviceId}) async {
    _logger.info('Starting leave-group flow for device $currentDeviceId');
    await _deps.removeDeviceOnCloud(currentDeviceId);
    await _resetLocalState();
    _logger.info('Leave-group flow complete; awaiting bootstrap re-run');
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
