import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/model/cloud/cloud_account.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudAccountRepository');

/// Discriminated state of the on-device cloud account view.
sealed class AccountState {
  const AccountState();
}

/// Either Firebase has not finished signing the user in yet, or the user
/// has disabled cloud sync entirely.
class AccountIdle extends AccountState {
  const AccountIdle();
}

/// Cloud sync is on but Firebase Firestore isn't supported on this
/// platform (currently Linux). Bootstrap and presence will also bail out;
/// see [accountRepositoryProvider] for the gating decision.
class AccountUnsupported extends AccountState {
  const AccountUnsupported();
}

/// Listening to Firestore but no data has arrived yet (or auth just
/// flipped, attaching new listeners).
class AccountLoading extends AccountState {
  const AccountLoading({required this.accountId, required this.currentDeviceId});
  final String accountId;
  final String currentDeviceId;
}

/// Live view of the cloud account.
///
/// [devices] includes the current device. Consumers (Settings device-group
/// section in Epic 10, Send tab merge in Epic 12) filter by
/// [currentDeviceId] as appropriate.
class AccountReady extends AccountState {
  const AccountReady({
    required this.accountId,
    required this.currentDeviceId,
    required this.account,
    required this.devices,
  });
  final String accountId;
  final String currentDeviceId;
  final CloudAccount? account;
  final List<CloudDevice> devices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountReady &&
          other.accountId == accountId &&
          other.currentDeviceId == currentDeviceId &&
          other.account == account &&
          _listEqual(other.devices, devices);

  @override
  int get hashCode => Object.hash(accountId, currentDeviceId, account, Object.hashAll(devices));
}

class AccountFailed extends AccountState {
  const AccountFailed({required this.message, required this.error});
  final String message;
  final Object error;
}

/// Surface of `cloud_firestore` that [AccountRepository] consumes. Kept as
/// a typedef-bag so unit tests can drive both streams without a Firebase
/// emulator.
class AccountFirestoreGateway {
  AccountFirestoreGateway({
    required this.accountSnapshots,
    required this.deviceSnapshots,
  });

  /// Live stream of the account doc; emits `null` when the doc does not
  /// (yet) exist.
  final Stream<CloudAccount?> Function(String accountId) accountSnapshots;

  /// Live stream of the devices subcollection.
  final Stream<List<CloudDevice>> Function(String accountId) deviceSnapshots;

  factory AccountFirestoreGateway.live() {
    final db = FirebaseFirestore.instance;
    return AccountFirestoreGateway(
      accountSnapshots: (accountId) {
        return db.doc('accounts/$accountId').snapshots().map(_decodeAccount);
      },
      deviceSnapshots: (accountId) {
        return db
            .collection('accounts/$accountId/devices')
            .snapshots()
            .map(
              (snap) => snap.docs.map((doc) => _decodeDevice(doc.id, doc.data())).toList(growable: false),
            );
      },
    );
  }
}

/// Bag of cross-provider readers that [AccountRepository] needs but cannot
/// safely call inside `init()` when the notifier is constructed without a
/// real RefenaScope (e.g. in unit tests). The provider factory below wires
/// these to live `ref.read` / `ref.stream` calls; tests pass fakes.
class AccountRepositoryDeps {
  AccountRepositoryDeps({
    required this.authStateReader,
    required this.authStateChanges,
    required this.deviceIdResolver,
    required this.cloudSyncEnabledReader,
  });

  /// Snapshot of the current cloud auth state at attach time.
  final CloudAuthState Function() authStateReader;

  /// Stream of subsequent auth-state transitions.
  final Stream<CloudAuthState> Function() authStateChanges;

  /// Reads (and persists if needed) the stable per-install device id.
  final Future<String> Function() deviceIdResolver;

  /// Honours the user's master toggle. Read once at startup; we do not
  /// react to live flips (that's Epic 14).
  final bool Function() cloudSyncEnabledReader;
}

/// Live view of the current device group. Subscribes to Firestore as soon
/// as Firebase auth reports an authenticated user, and tears the
/// subscription down on sign-out / UID rotation.
class AccountRepository extends Notifier<AccountState> {
  AccountRepository({
    required AccountRepositoryDeps deps,
    AccountFirestoreGateway? gateway,
    bool? supportedOverride,
  }) : _deps = deps,
       _gatewayOverride = gateway,
       _supportedOverride = supportedOverride;

  final AccountRepositoryDeps _deps;
  final AccountFirestoreGateway? _gatewayOverride;
  final bool? _supportedOverride;
  StreamSubscription<CloudAuthState>? _authSubscription;
  StreamSubscription<CloudAccount?>? _accountSubscription;
  StreamSubscription<List<CloudDevice>>? _devicesSubscription;
  String? _currentAccountId;
  String? _currentDeviceId;
  CloudAccount? _latestAccount;
  List<CloudDevice> _latestDevices = const <CloudDevice>[];
  bool _started = false;

  AccountFirestoreGateway get _gateway => _gatewayOverride ?? AccountFirestoreGateway.live();

  bool get _isSupported => _supportedOverride ?? checkPlatformSupportsFirebase();

  @override
  AccountState init() {
    if (_started) {
      return _stateOrIdle();
    }
    _started = true;
    if (!_isSupported) {
      return const AccountUnsupported();
    }
    if (!_deps.cloudSyncEnabledReader()) {
      return const AccountIdle();
    }
    _authSubscription = _deps.authStateChanges().listen(
      (state) => unawaited(_onAuthStateChanged(state)),
      onError: (Object error, StackTrace stack) {
        _logger.warning('Auth-state stream errored', error, stack);
      },
    );
    final initial = _deps.authStateReader();
    if (initial is CloudAuthAuthenticated) {
      // Best-effort: kick off the first attach asynchronously so init()
      // returns synchronously. The Loading state below is overwritten
      // when the Firestore listener emits.
      unawaited(_attachToAccount(initial.uid));
      return AccountLoading(accountId: initial.uid, currentDeviceId: '');
    }
    return const AccountIdle();
  }

  AccountState _stateOrIdle() => state;

  /// Tear down the active Firestore listeners and re-attach to the same
  /// account. Useful for a "refresh" affordance in the UI: the live
  /// stream already auto-updates, but a manual re-attach forces a fresh
  /// fetch and a transient AccountLoading → AccountReady transition the
  /// user can see. No-op if there's no current account.
  Future<void> refresh() async {
    final accountId = _currentAccountId;
    if (accountId == null) return;
    await _attachToAccount(accountId);
  }

  Future<void> _onAuthStateChanged(CloudAuthState authState) async {
    if (authState is CloudAuthAuthenticated) {
      if (_currentAccountId == authState.uid) return;
      await _attachToAccount(authState.uid);
      return;
    }
    // Idle / SigningIn / Failed: drop any active listeners and reset.
    await _detach();
    state = const AccountIdle();
  }

  Future<void> _attachToAccount(String accountId) async {
    await _detach();
    final deviceId = await _deps.deviceIdResolver();
    _currentAccountId = accountId;
    _currentDeviceId = deviceId;
    _latestAccount = null;
    _latestDevices = const <CloudDevice>[];
    state = AccountLoading(accountId: accountId, currentDeviceId: deviceId);

    _accountSubscription = _gateway
        .accountSnapshots(accountId)
        .listen(
          (snap) {
            _latestAccount = snap;
            _emitReady();
          },
          onError: (Object error, StackTrace stack) {
            _logger.warning('Firestore account-doc stream errored', error, stack);
            state = AccountFailed(message: 'Account stream error', error: error);
          },
        );
    _devicesSubscription = _gateway
        .deviceSnapshots(accountId)
        .listen(
          (devices) {
            _latestDevices = List.unmodifiable(devices);
            _emitReady();
          },
          onError: (Object error, StackTrace stack) {
            _logger.warning('Firestore devices-stream errored', error, stack);
            state = AccountFailed(message: 'Devices stream error', error: error);
          },
        );
  }

  void _emitReady() {
    final accountId = _currentAccountId;
    final deviceId = _currentDeviceId;
    if (accountId == null || deviceId == null) return;
    state = AccountReady(
      accountId: accountId,
      currentDeviceId: deviceId,
      account: _latestAccount,
      devices: _latestDevices,
    );
  }

  Future<void> _detach() async {
    final accountSub = _accountSubscription;
    final devicesSub = _devicesSubscription;
    _accountSubscription = null;
    _devicesSubscription = null;
    _currentAccountId = null;
    _currentDeviceId = null;
    _latestAccount = null;
    _latestDevices = const <CloudDevice>[];
    if (accountSub != null) await accountSub.cancel();
    if (devicesSub != null) await devicesSub.cancel();
  }

  @override
  Future<void> dispose() async {
    final authSub = _authSubscription;
    _authSubscription = null;
    if (authSub != null) await authSub.cancel();
    await _detach();
    super.dispose();
  }
}

bool _listEqual<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

CloudAccount? _decodeAccount(DocumentSnapshot<Map<String, dynamic>> snap) {
  final data = snap.data();
  if (data == null) return null;
  return CloudAccount(
    accountId: snap.id,
    createdAtMs: _timestampMs(data['createdAt']) ?? 0,
    lastActiveAtMs: _timestampMs(data['lastActiveAt']) ?? 0,
    deviceCount: (data['deviceCount'] as num?)?.toInt() ?? 0,
  );
}

CloudDevice _decodeDevice(String deviceId, Map<String, dynamic>? data) {
  final raw = data ?? const <String, dynamic>{};
  return CloudDevice(
    deviceId: deviceId,
    displayName: (raw['displayName'] as String?) ?? '',
    icon: CloudDeviceIconMapper.fromValue(raw['icon'] as String? ?? CloudDeviceIcon.other.name),
    fcmToken: raw['fcmToken'] as String?,
    platform: CloudDevicePlatformMapper.fromValue(
      raw['platform'] as String? ?? CloudDevicePlatform.linux.name,
    ),
    lastSeenAtMs: _timestampMs(raw['lastSeenAt']) ?? 0,
    presence: CloudDevicePresenceMapper.fromValue(
      raw['presence'] as String? ?? CloudDevicePresence.offline.name,
    ),
  );
}

int? _timestampMs(Object? raw) {
  if (raw is Timestamp) return raw.millisecondsSinceEpoch;
  if (raw is int) return raw;
  return null;
}

final accountRepositoryProvider = NotifierProvider<AccountRepository, AccountState>((ref) {
  return AccountRepository(
    deps: AccountRepositoryDeps(
      authStateReader: () => ref.read(cloudAuthProvider),
      authStateChanges: () => ref.stream(cloudAuthProvider).map((event) => event.next),
      deviceIdResolver: () => ref.read(deviceIdentityProvider).ensureDeviceId(),
      cloudSyncEnabledReader: () => ref.read(settingsProvider).cloudSyncEnabled,
    ),
  );
});
