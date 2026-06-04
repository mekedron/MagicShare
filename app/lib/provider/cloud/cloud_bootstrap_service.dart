import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';
import 'package:magicshare_app/provider/cloud/fcm_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/provider/security_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudBootstrap');

/// Discriminated bootstrap state.
sealed class BootstrapState {
  const BootstrapState();
}

class BootstrapIdle extends BootstrapState {
  const BootstrapIdle();
}

class BootstrapDisabled extends BootstrapState {
  const BootstrapDisabled();
}

class BootstrapUnsupported extends BootstrapState {
  const BootstrapUnsupported();
}

class BootstrapInFlight extends BootstrapState {
  const BootstrapInFlight();
}

class BootstrapDone extends BootstrapState {
  const BootstrapDone({required this.accountId, required this.deviceId});
  final String accountId;
  final String deviceId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BootstrapDone && other.accountId == accountId && other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(accountId, deviceId);
}

class BootstrapFailed extends BootstrapState {
  const BootstrapFailed({required this.message, required this.error});
  final String message;
  final Object error;
}

/// Snapshot of the FCM token state at the moment we want to register.
sealed class FcmTokenSnapshot {
  const FcmTokenSnapshot();
}

class FcmTokenAvailable extends FcmTokenSnapshot {
  const FcmTokenAvailable(this.token);
  final String token;
}

class FcmTokenAcquiring extends FcmTokenSnapshot {
  const FcmTokenAcquiring();
}

class FcmTokenUnsupported extends FcmTokenSnapshot {
  const FcmTokenUnsupported();
}

/// Bag of cross-provider readers / streams that [CloudBootstrapService]
/// needs. Same trick as [AccountRepositoryDeps] — keeps the notifier
/// independently testable with `Notifier.test`.
class CloudBootstrapDeps {
  CloudBootstrapDeps({
    required this.authStateReader,
    required this.authStateChanges,
    required this.deviceIdentity,
    required this.client,
    required this.fcmTokenReader,
    required this.fcmTokenChanges,
    required this.groupKeyReader,
    required this.ensureGroupKey,
    required this.peerDeviceCountReader,
    required this.cloudSyncEnabledReader,
    required this.fingerprintReader,
    required this.findExistingDeviceIdForFingerprint,
  });

  final CloudAuthState Function() authStateReader;
  final Stream<CloudAuthState> Function() authStateChanges;
  final DeviceIdentityService Function() deviceIdentity;
  final CloudFunctionsClient Function() client;
  final FcmTokenSnapshot Function() fcmTokenReader;
  final Stream<FcmTokenSnapshot> Function() fcmTokenChanges;
  final GroupKeyState Function() groupKeyReader;
  final Future<void> Function() ensureGroupKey;
  final int Function() peerDeviceCountReader;
  final bool Function() cloudSyncEnabledReader;

  /// Returns the LocalSend cert hash that this install announces over
  /// multicast — the join key the Send tab uses to dedup LAN devices
  /// against cloud devices. May be null if the security context hasn't
  /// been generated yet (extremely early in boot); the bootstrap simply
  /// forwards null and the next launch will refresh.
  final String? Function() fingerprintReader;

  /// One-shot lookup: given the current account [uid] and our
  /// [fingerprint], returns the deviceId of an existing cloud device
  /// row matching that fingerprint, or null when there isn't one.
  /// Used by the bootstrap adoption pass — see _runBootstrap — to
  /// reuse a stale-but-still-correct device row instead of creating
  /// a duplicate when our local device-id slot is empty.
  final Future<String?> Function(String uid, String fingerprint) findExistingDeviceIdForFingerprint;
}

/// Orchestrates first-launch (and post-restart) bootstrap of the cloud
/// device-group identity. After [BootstrapDone], the local Firestore
/// account doc and a child device row exist and the group key is
/// persisted (when this device created the group).
class CloudBootstrapService extends Notifier<BootstrapState> {
  CloudBootstrapService({
    required CloudBootstrapDeps deps,
    bool? supportedOverride,
  }) : _deps = deps,
       _supportedOverride = supportedOverride;

  final CloudBootstrapDeps _deps;
  final bool? _supportedOverride;
  StreamSubscription<CloudAuthState>? _authSubscription;
  StreamSubscription<FcmTokenSnapshot>? _fcmSubscription;
  String? _currentUid;
  String? _currentDeviceId;
  String? _lastUploadedFcmToken;
  Future<void>? _inFlight;
  bool _started = false;

  bool get _isSupported => _supportedOverride ?? checkPlatformSupportsCloudFunctions();

  @override
  BootstrapState init() {
    if (_started) return state;
    _started = true;
    if (!_isSupported) {
      return const BootstrapUnsupported();
    }
    if (!_deps.cloudSyncEnabledReader()) {
      return const BootstrapDisabled();
    }
    _authSubscription = _deps.authStateChanges().listen(
      (auth) {
        if (auth is CloudAuthAuthenticated) {
          unawaited(_runBootstrap(auth.uid));
        }
      },
      onError: (Object error, StackTrace stack) {
        _logger.warning('Auth stream errored during bootstrap', error, stack);
      },
    );
    _fcmSubscription = _deps.fcmTokenChanges().listen(
      (snapshot) {
        if (snapshot is FcmTokenAvailable) {
          unawaited(_maybeReuploadToken(snapshot.token));
        }
      },
      onError: (Object error, StackTrace stack) {
        _logger.warning('FCM stream errored during bootstrap', error, stack);
      },
    );
    final initial = _deps.authStateReader();
    if (initial is CloudAuthAuthenticated) {
      unawaited(_runBootstrap(initial.uid));
      return const BootstrapInFlight();
    }
    return const BootstrapIdle();
  }

  Future<void> _runBootstrap(String uid) async {
    // Already done for this UID — nothing to do. The auth-state stream
    // can re-emit the same Authenticated value (e.g. on a token refresh
    // or a hot reload), and without this guard each re-emit re-ran
    // createAccount + registerDevice, which under a race in
    // ensureDeviceId could leave us with duplicate device docs.
    if (_currentUid == uid && state is BootstrapDone) return;
    final inFlight = _inFlight;
    if (inFlight != null) {
      await inFlight;
      if (_currentUid == uid && state is BootstrapDone) return;
    }
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      state = const BootstrapInFlight();
      _currentUid = uid;
      _logger.info('Bootstrap: starting for uid=$uid');
      final identity = _deps.deviceIdentity();

      // Adoption pass: if our local device-id slot is empty AND the
      // cloud account already has a device row whose `fingerprint`
      // matches this install's cert hash, adopt that row's id instead
      // of minting a fresh one. Prevents the duplicate-device row that
      // surfaces after the SharedPreferences slot is wiped (delete-
      // group then rejoin, app reinstall during dev iteration, etc.).
      if (identity.peekDeviceId() == null) {
        final fp = _deps.fingerprintReader();
        if (fp != null && fp.isNotEmpty) {
          try {
            final existing = await _deps.findExistingDeviceIdForFingerprint(uid, fp);
            if (existing != null && existing.isNotEmpty) {
              _logger.info(
                'Adopting existing cloud device row for our fingerprint: $existing',
              );
              await identity.adoptDeviceId(existing);
            }
          } catch (e, st) {
            // Best-effort: if the lookup fails for any reason (network,
            // permissions, etc.), fall through to ensureDeviceId. The
            // worst case is we mint a fresh row — same behaviour as
            // before this fix.
            _logger.warning('Adoption lookup failed; minting a fresh id', e, st);
          }
        }
      }

      final deviceId = await identity.ensureDeviceId();
      _currentDeviceId = deviceId;
      _logger.info('Bootstrap: deviceId resolved → $deviceId');

      final client = _deps.client();
      _logger.info('Bootstrap: calling createAccount');
      final accountResult = await client.createAccount();
      _logger.info('Bootstrap: createAccount → created=${accountResult.created} accountId=${accountResult.accountId}');

      // Group-key path:
      //  - Always generate when createAccount returned `created: true`.
      //  - Crash-recovery: also generate when this device sees no peers
      //    AND the local key slot is empty (covers a crash between the
      //    first createAccount call and key persistence on the original
      //    install).
      final keyState = _deps.groupKeyReader();
      if (accountResult.created) {
        await _deps.ensureGroupKey();
      } else if (keyState is GroupKeyMissing && _deps.peerDeviceCountReader() == 0) {
        _logger.info(
          'Recovering group key: account exists, no peers visible, local key missing',
        );
        await _deps.ensureGroupKey();
      }

      final fcmSnapshot = _deps.fcmTokenReader();
      final fcmToken = switch (fcmSnapshot) {
        FcmTokenAvailable(:final token) => token,
        _ => null,
      };

      _logger.info('Bootstrap: calling registerDevice deviceId=$deviceId');
      await client.registerDevice(
        deviceId: deviceId,
        displayName: identity.defaultDisplayName(),
        icon: identity.defaultIcon(),
        platform: identity.currentPlatform(),
        fcmToken: fcmToken,
        fingerprint: _deps.fingerprintReader(),
      );
      _lastUploadedFcmToken = fcmToken;
      _logger.info('Bootstrap: DONE for uid=$uid deviceId=$deviceId');
      state = BootstrapDone(accountId: uid, deviceId: deviceId);
      // FCM is async on iOS (APNs handshake) so the token often arrives
      // *during* this bootstrap call. The FCM-change listener would
      // have early-returned because state was not yet BootstrapDone.
      // Re-check here so the late-arriving token still reaches Firestore.
      final lateFcm = _deps.fcmTokenReader();
      if (lateFcm is FcmTokenAvailable && lateFcm.token != _lastUploadedFcmToken) {
        unawaited(_maybeReuploadToken(lateFcm.token));
      }
    } on CloudException catch (e, st) {
      _logger.warning('Bootstrap failed (code=${e.code.name} message="${e.message}" details=${e.details})', e, st);
      state = BootstrapFailed(message: e.message, error: e);
    } catch (e, st) {
      _logger.warning('Bootstrap failed (non-CloudException): $e', e, st);
      state = BootstrapFailed(message: 'Bootstrap failed: $e', error: e);
    } finally {
      completer.complete();
      _inFlight = null;
    }
  }

  Future<void> _maybeReuploadToken(String token) async {
    final deviceId = _currentDeviceId;
    if (deviceId == null) return;
    if (state is! BootstrapDone) return;
    if (token == _lastUploadedFcmToken) return;
    final identity = _deps.deviceIdentity();
    try {
      await _deps.client().registerDevice(
        deviceId: deviceId,
        displayName: identity.defaultDisplayName(),
        icon: identity.defaultIcon(),
        platform: identity.currentPlatform(),
        fcmToken: token,
        fingerprint: _deps.fingerprintReader(),
      );
      _lastUploadedFcmToken = token;
    } on CloudException catch (e, st) {
      _logger.warning('FCM token re-upload failed (${e.code.name})', e, st);
    } catch (e, st) {
      _logger.warning('FCM token re-upload failed', e, st);
    }
  }

  @override
  Future<void> dispose() async {
    final authSub = _authSubscription;
    final fcmSub = _fcmSubscription;
    _authSubscription = null;
    _fcmSubscription = null;
    if (authSub != null) await authSub.cancel();
    if (fcmSub != null) await fcmSub.cancel();
    super.dispose();
  }
}

/// Translates the typed [FcmState] from `fcmProvider` into the bootstrap
/// snapshot enum.
FcmTokenSnapshot toBootstrapSnapshot(FcmState state) {
  return switch (state) {
    FcmReady(:final token) => FcmTokenAvailable(token),
    FcmAcquiring() || FcmIdle() => const FcmTokenAcquiring(),
    FcmUnsupported() => const FcmTokenUnsupported(),
    FcmFailed() => const FcmTokenAcquiring(),
  };
}

final cloudBootstrapProvider = NotifierProvider<CloudBootstrapService, BootstrapState>((ref) {
  return CloudBootstrapService(
    deps: CloudBootstrapDeps(
      authStateReader: () => ref.read(cloudAuthProvider),
      authStateChanges: () => ref.stream(cloudAuthProvider).map((event) => event.next),
      deviceIdentity: () => ref.read(deviceIdentityProvider),
      client: () => ref.read(cloudFunctionsClientProvider),
      fcmTokenReader: () => toBootstrapSnapshot(ref.read(fcmProvider)),
      fcmTokenChanges: () => ref.stream(fcmProvider).map((event) => toBootstrapSnapshot(event.next)),
      groupKeyReader: () => ref.read(groupKeyProvider),
      ensureGroupKey: () async {
        await ref.notifier(groupKeyProvider).ensureForNewAccount();
      },
      peerDeviceCountReader: () {
        final accountState = ref.read(accountRepositoryProvider);
        if (accountState is! AccountReady) return 0;
        final currentDeviceId = accountState.currentDeviceId;
        return accountState.devices.where((device) => device.deviceId != currentDeviceId).length;
      },
      cloudSyncEnabledReader: () => ref.read(settingsProvider).cloudSyncEnabled,
      fingerprintReader: () => ref.read(securityProvider).certificateHash,
      findExistingDeviceIdForFingerprint: (uid, fingerprint) async {
        final query = await FirebaseFirestore.instance
            .collection('accounts/$uid/devices')
            .where('fingerprint', isEqualTo: fingerprint)
            .limit(2)
            .get();
        if (query.docs.isEmpty) return null;
        // If multiple rows match (a previous bug already created a
        // duplicate), pick deterministically by lexicographically-first
        // deviceId. Stale row can be removed manually from the
        // device-group list.
        final ids = query.docs.map((d) => d.id).toList()..sort();
        return ids.first;
      },
    ),
  );
});
