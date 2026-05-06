import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/results/create_account_result.dart';
import 'package:magicshare_app/model/cloud/results/register_device_result.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/cloud_bootstrap_service.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';
import 'package:magicshare_app/provider/cloud/fcm_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _CallableSpy {
  bool createAccountFirstTime = true;
  CreateAccountResult Function()? createAccountResultBuilder;
  Object? registerDeviceThrows;

  int createAccountCalls = 0;
  int registerDeviceCalls = 0;
  final List<Map<String, dynamic>> registerCalls = [];

  HttpsCallableInvoker invoker() => (name, data) async {
    switch (name) {
      case 'createAccount':
        createAccountCalls++;
        final result = (createAccountResultBuilder ?? _defaultCreateResult)();
        return result.toJson();
      case 'registerDevice':
        registerDeviceCalls++;
        final body = (data as Map).cast<String, dynamic>();
        registerCalls.add(body);
        if (registerDeviceThrows != null) throw registerDeviceThrows!;
        return const RegisterDeviceResult(created: true).toJson();
      default:
        throw UnimplementedError('Unhandled callable in spy: $name');
    }
  };

  CreateAccountResult _defaultCreateResult() {
    final created = createAccountFirstTime;
    createAccountFirstTime = false;
    return CreateAccountResult(created: created, accountId: 'uid-1');
  }
}

class _DeviceIdentityFake extends DeviceIdentityService {
  _DeviceIdentityFake({String deviceId = 'device-A'})
    : super(
        storage: DeviceIdStorage(
          read: () => deviceId,
          write: (_) async {},
        ),
        aliasReader: () => 'fixture-alias',
        platformOverride: TargetPlatform.android,
        deviceIdGenerator: () => deviceId,
      );

  @override
  CloudDeviceIcon defaultIcon() => CloudDeviceIcon.phone;
  @override
  CloudDevicePlatform currentPlatform() => CloudDevicePlatform.android;
}

class _Streams {
  final auth = StreamController<CloudAuthState>.broadcast();
  final fcm = StreamController<FcmTokenSnapshot>.broadcast();

  Future<void> dispose() async {
    await auth.close();
    await fcm.close();
  }
}

CloudBootstrapDeps _deps({
  required _CallableSpy spy,
  required _Streams streams,
  required CloudAuthState authInitial,
  required FcmTokenSnapshot fcmInitial,
  required GroupKeyState Function() groupKeyReader,
  required Future<void> Function() ensureGroupKey,
  int peerDeviceCount = 0,
  bool cloudSyncEnabled = true,
  DeviceIdentityService? identity,
  String? Function()? fingerprintReader,
  Future<String?> Function(String uid, String fingerprint)? findExistingDeviceIdForFingerprint,
}) {
  return CloudBootstrapDeps(
    authStateReader: () => authInitial,
    authStateChanges: () => streams.auth.stream,
    deviceIdentity: () => identity ?? _DeviceIdentityFake(),
    client: () => CloudFunctionsClient(invoker: spy.invoker()),
    fcmTokenReader: () => fcmInitial,
    fcmTokenChanges: () => streams.fcm.stream,
    groupKeyReader: groupKeyReader,
    ensureGroupKey: ensureGroupKey,
    peerDeviceCountReader: () => peerDeviceCount,
    cloudSyncEnabledReader: () => cloudSyncEnabled,
    fingerprintReader: fingerprintReader ?? () => 'fixture-fingerprint',
    findExistingDeviceIdForFingerprint: findExistingDeviceIdForFingerprint ?? (_, __) async => null,
  );
}

void main() {
  group('CloudBootstrapService gates', () {
    test('returns Disabled when the master toggle is off', () {
      final spy = _CallableSpy();
      final streams = _Streams();
      final tester = Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
            cloudSyncEnabled: false,
          ),
          supportedOverride: true,
        ),
      );
      expect(tester.state, isA<BootstrapDisabled>());
      expect(spy.createAccountCalls, 0);
      expect(spy.registerDeviceCalls, 0);
    });

    test('returns Unsupported on platforms without Cloud Functions', () {
      final spy = _CallableSpy();
      final streams = _Streams();
      final tester = Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
          ),
          supportedOverride: false,
        ),
      );
      expect(tester.state, isA<BootstrapUnsupported>());
      expect(spy.createAccountCalls, 0);
      expect(spy.registerDeviceCalls, 0);
    });
  });

  group('CloudBootstrapService happy path', () {
    test('runs createAccount → ensureGroupKey → registerDevice when created: true', () async {
      final spy = _CallableSpy();
      final streams = _Streams();
      var groupKeyEnsures = 0;
      final tester = Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {
              groupKeyEnsures++;
            },
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();

      expect(spy.createAccountCalls, 1);
      expect(groupKeyEnsures, 1);
      expect(spy.registerDeviceCalls, 1);
      expect(spy.registerCalls.single['fcmToken'], isNull);
      expect(tester.state, isA<BootstrapDone>());
      expect((tester.state as BootstrapDone).accountId, 'uid-1');
      await streams.dispose();
    });

    test('adopts an existing cloud device row when local slot is empty and a fingerprint match exists', () async {
      // Reproduces the duplicate-device bug: SharedPreferences slot
      // is empty (e.g. after delete-group + rejoin or app reinstall),
      // and the cloud account already has a row whose `fingerprint`
      // matches this install. Bootstrap must adopt the existing row's
      // deviceId instead of minting a fresh one — otherwise the user
      // ends up with two device entries for the same physical device.
      final spy = _CallableSpy();
      final streams = _Streams();
      final storedSlot = <String?>[null];
      final identity = DeviceIdentityService(
        storage: DeviceIdStorage(
          read: () => storedSlot.first,
          write: (value) async {
            storedSlot[0] = value;
          },
        ),
        aliasReader: () => 'fixture-alias',
        platformOverride: TargetPlatform.android,
        deviceIdGenerator: () => 'fresh-id-should-not-be-used',
      );
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
            identity: identity,
            fingerprintReader: () => 'cert-hash-abc',
            findExistingDeviceIdForFingerprint: (uid, fp) async {
              expect(uid, 'uid-1');
              expect(fp, 'cert-hash-abc');
              return 'existing-cloud-id';
            },
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(spy.registerCalls.single['deviceId'], 'existing-cloud-id');
      expect(storedSlot.first, 'existing-cloud-id', reason: 'adopted id is persisted');
    });

    test('mints a fresh deviceId when no existing fingerprint match is found', () async {
      final spy = _CallableSpy();
      final streams = _Streams();
      final storedSlot = <String?>[null];
      final identity = DeviceIdentityService(
        storage: DeviceIdStorage(
          read: () => storedSlot.first,
          write: (value) async {
            storedSlot[0] = value;
          },
        ),
        aliasReader: () => 'fixture-alias',
        platformOverride: TargetPlatform.android,
        deviceIdGenerator: () => 'fresh-uuid',
      );
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
            identity: identity,
            fingerprintReader: () => 'cert-hash-abc',
            findExistingDeviceIdForFingerprint: (_, __) async => null,
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(spy.registerCalls.single['deviceId'], 'fresh-uuid');
      expect(storedSlot.first, 'fresh-uuid');
    });

    test('skips adoption when the local slot already has a deviceId', () async {
      // Existing well-behaved install: the slot is populated. We must
      // NOT issue a Firestore lookup or change the deviceId — the row
      // is already correct.
      final spy = _CallableSpy();
      final streams = _Streams();
      var lookupCalls = 0;
      final identity = DeviceIdentityService(
        storage: DeviceIdStorage(
          read: () => 'persisted-id',
          write: (_) async {},
        ),
        aliasReader: () => 'fixture-alias',
        platformOverride: TargetPlatform.android,
      );
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
            identity: identity,
            fingerprintReader: () => 'cert-hash-abc',
            findExistingDeviceIdForFingerprint: (_, __) async {
              lookupCalls++;
              return 'should-not-be-used';
            },
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(lookupCalls, 0, reason: 'no lookup when slot is populated');
      expect(spy.registerCalls.single['deviceId'], 'persisted-id');
    });

    test('falls through to fresh-id when adoption lookup throws', () async {
      // Network blip / Firestore permission denied — we must not block
      // bootstrap. Falls through to ensureDeviceId which mints a fresh
      // id. Same behaviour as before this fix.
      final spy = _CallableSpy();
      final streams = _Streams();
      final storedSlot = <String?>[null];
      final identity = DeviceIdentityService(
        storage: DeviceIdStorage(
          read: () => storedSlot.first,
          write: (value) async {
            storedSlot[0] = value;
          },
        ),
        aliasReader: () => 'fixture-alias',
        platformOverride: TargetPlatform.android,
        deviceIdGenerator: () => 'fallback-uuid',
      );
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
            identity: identity,
            fingerprintReader: () => 'cert-hash-abc',
            findExistingDeviceIdForFingerprint: (_, __) async {
              throw StateError('firestore unavailable');
            },
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(spy.registerCalls.single['deviceId'], 'fallback-uuid');
    });

    test('forwards the LocalSend fingerprint on registerDevice', () async {
      final spy = _CallableSpy();
      final streams = _Streams();
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
            fingerprintReader: () => 'cert-hash-abc',
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(spy.registerCalls.single['fingerprint'], 'cert-hash-abc');
      await streams.dispose();
    });

    test('uses an FCM token when fcmProvider is already Ready', () async {
      final spy = _CallableSpy();
      final streams = _Streams();
      final tester = Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAvailable('fcm-1'),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(spy.registerCalls.single['fcmToken'], 'fcm-1');
      expect(tester.state, isA<BootstrapDone>());
      await streams.dispose();
    });
  });

  group('CloudBootstrapService idempotency', () {
    test('account-already-exists path skips ensureGroupKey when peers exist', () async {
      final spy = _CallableSpy()..createAccountFirstTime = false;
      final streams = _Streams();
      var groupKeyEnsures = 0;
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => GroupKeyReady(Uint8List(32)),
            ensureGroupKey: () async {
              groupKeyEnsures++;
            },
            peerDeviceCount: 2,
          ),
          supportedOverride: true,
        ),
      );
      await pumpEventQueue();
      expect(groupKeyEnsures, 0);
    });

    test('crash-recovery: created false + key missing + zero peers regenerates the key', () async {
      final spy = _CallableSpy()..createAccountFirstTime = false;
      final streams = _Streams();
      var groupKeyEnsures = 0;
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {
              groupKeyEnsures++;
            },
            peerDeviceCount: 0,
          ),
          supportedOverride: true,
        ),
      );
      await pumpEventQueue();
      expect(groupKeyEnsures, 1);
    });
  });

  group('CloudBootstrapService FCM token refresh', () {
    test('re-runs registerDevice when token transitions from null to a value', () async {
      final spy = _CallableSpy();
      final streams = _Streams();
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
          ),
          supportedOverride: true,
        ),
      );
      await pumpEventQueue();
      expect(spy.registerDeviceCalls, 1);
      expect(spy.registerCalls.single['fcmToken'], isNull);

      streams.fcm.add(const FcmTokenAvailable('fcm-fresh'));
      await pumpEventQueue();

      expect(spy.registerDeviceCalls, 2);
      expect(spy.registerCalls.last['fcmToken'], 'fcm-fresh');
      await streams.dispose();
    });

    test('does not re-register when refresh emits the same token again', () async {
      final spy = _CallableSpy();
      final streams = _Streams();
      Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAvailable('fcm-stable'),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
          ),
          supportedOverride: true,
        ),
      );
      await pumpEventQueue();
      expect(spy.registerDeviceCalls, 1);

      streams.fcm.add(const FcmTokenAvailable('fcm-stable'));
      await pumpEventQueue();

      expect(spy.registerDeviceCalls, 1);
      await streams.dispose();
    });
  });

  group('CloudBootstrapService re-emit safety', () {
    test('does not re-run createAccount/registerDevice when auth re-emits the same UID', () async {
      // Regression: a second Authenticated emit for the same UID
      // (token refresh, hot reload, refena re-broadcast) used to slip
      // past the in-flight guard and re-run the cloud calls. With
      // ensureDeviceId's race, that produced two device docs under
      // one account on first launch.
      final spy = _CallableSpy();
      final streams = _Streams();
      final tester = Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
          ),
          supportedOverride: true,
        ),
      );

      await pumpEventQueue();
      expect(tester.state, isA<BootstrapDone>());
      expect(spy.createAccountCalls, 1);
      expect(spy.registerDeviceCalls, 1);

      // Re-emit the same Authenticated state — must be a no-op.
      streams.auth.add(const CloudAuthAuthenticated('uid-1'));
      await pumpEventQueue();

      expect(spy.createAccountCalls, 1);
      expect(spy.registerDeviceCalls, 1);
      await streams.dispose();
    });
  });

  group('CloudBootstrapService failure path', () {
    test('CloudException on registerDevice surfaces as BootstrapFailed', () async {
      final spy = _CallableSpy()
        ..registerDeviceThrows = const CloudException(
          code: CloudErrorCode.unknown,
          message: 'simulated',
        );
      final streams = _Streams();
      final tester = Notifier.test<CloudBootstrapService, BootstrapState>(
        notifier: CloudBootstrapService(
          deps: _deps(
            spy: spy,
            streams: streams,
            authInitial: const CloudAuthAuthenticated('uid-1'),
            fcmInitial: const FcmTokenAcquiring(),
            groupKeyReader: () => const GroupKeyMissing(),
            ensureGroupKey: () async {},
          ),
          supportedOverride: true,
        ),
      );
      await pumpEventQueue();
      expect(tester.state, isA<BootstrapFailed>());
      await streams.dispose();
    });
  });

  group('toBootstrapSnapshot', () {
    test('maps every FcmState branch', () {
      expect(toBootstrapSnapshot(const FcmIdle()), isA<FcmTokenAcquiring>());
      expect(toBootstrapSnapshot(const FcmAcquiring()), isA<FcmTokenAcquiring>());
      expect(toBootstrapSnapshot(const FcmReady('t')), isA<FcmTokenAvailable>());
      expect(toBootstrapSnapshot(const FcmUnsupported()), isA<FcmTokenUnsupported>());
      expect(
        toBootstrapSnapshot(const FcmFailed(message: 'x', error: 'e')),
        isA<FcmTokenAcquiring>(),
      );
    });
  });
}
