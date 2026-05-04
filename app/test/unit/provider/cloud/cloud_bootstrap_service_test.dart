import 'dart:async';
import 'dart:typed_data';

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
import 'package:magicshare_app/util/native/secure_storage_service.dart';
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
        storage: SecureStorageService(
          gateway: SecureStorageGateway(
            read: (_) async => deviceId,
            write: (_, __) async {},
            delete: (_) async {},
          ),
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
