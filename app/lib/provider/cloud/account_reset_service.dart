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
    required this.clearGroupKey,
    required this.deleteAndResetAuth,
  });

  final Future<void> Function() deleteAccountOnCloud;
  final Future<void> Function() clearGroupKey;
  final Future<void> Function() deleteAndResetAuth;
}

/// Coordinates the destroy-this-device-group flow.
///
/// Sequence:
/// 1. `deleteAccount` on the cloud functions client — wipes the Firestore
///    account document and cascades to all child devices in one
///    transaction.
/// 2. `groupKeyService.clear()` — wipes the local group key and device id
///    so the next bootstrap registers a fresh device row.
/// 3. `cloudAuthService.deleteAndReset()` — deletes the Firebase Auth
///    user. The auth-state stream emits null, the auth service re-signs
///    in anonymously with a new UID, and the bootstrap service then
///    re-runs and creates a fresh account + device.
///
/// A failure in any step short-circuits and surfaces the original
/// exception. Steps 2 and 3 only run after step 1 succeeds — there is no
/// point wiping local state if the cloud-side wipe failed.
class AccountResetService {
  AccountResetService(this._deps);

  final AccountResetDeps _deps;

  Future<void> resetForGroupDeletion() async {
    _logger.info('Starting destroy-group flow');
    await _deps.deleteAccountOnCloud();
    await _deps.clearGroupKey();
    await _deps.deleteAndResetAuth();
    _logger.info('Destroy-group flow complete; awaiting bootstrap re-run');
  }
}

final accountResetServiceProvider = Provider<AccountResetService>((ref) {
  return AccountResetService(
    AccountResetDeps(
      deleteAccountOnCloud: () async {
        await ref.read(cloudFunctionsClientProvider).deleteAccount();
      },
      clearGroupKey: () => ref.notifier(groupKeyProvider).clear(),
      deleteAndResetAuth: () => ref.notifier(cloudAuthProvider).deleteAndReset(),
    ),
  );
});
