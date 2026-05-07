import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_account.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _FakeAuthBackend {
  CloudAuthState current = const CloudAuthIdle();
  final StreamController<CloudAuthState> _controller = StreamController<CloudAuthState>.broadcast();

  void emit(CloudAuthState next) {
    current = next;
    _controller.add(next);
  }

  Future<void> dispose() => _controller.close();
}

class _FakeFirestore {
  final Map<String, StreamController<CloudAccount?>> _accountControllers = {};
  final Map<String, StreamController<List<CloudDevice>>> _deviceControllers = {};
  final List<String> _attachedAccounts = [];
  int accountCancelCount = 0;
  int devicesCancelCount = 0;

  AccountFirestoreGateway gateway() => AccountFirestoreGateway(
    accountSnapshots: (accountId) {
      _attachedAccounts.add(accountId);
      final controller = StreamController<CloudAccount?>.broadcast(
        onCancel: () => accountCancelCount++,
      );
      _accountControllers[accountId] = controller;
      return controller.stream;
    },
    deviceSnapshots: (accountId) {
      final controller = StreamController<List<CloudDevice>>.broadcast(
        onCancel: () => devicesCancelCount++,
      );
      _deviceControllers[accountId] = controller;
      return controller.stream;
    },
  );

  void emitAccount(String accountId, CloudAccount? account) {
    _accountControllers[accountId]!.add(account);
  }

  void emitDevices(String accountId, List<CloudDevice> devices) {
    _deviceControllers[accountId]!.add(devices);
  }

  Future<void> dispose() async {
    for (final c in _accountControllers.values) {
      await c.close();
    }
    for (final c in _deviceControllers.values) {
      await c.close();
    }
  }

  List<String> get attachedAccounts => List.unmodifiable(_attachedAccounts);
}

AccountRepository _build({
  required _FakeAuthBackend auth,
  required _FakeFirestore firestore,
  bool cloudSyncEnabled = true,
  bool supported = true,
  String deviceId = 'device-A',
}) {
  return AccountRepository(
    deps: AccountRepositoryDeps(
      authStateReader: () => auth.current,
      authStateChanges: () => auth._controller.stream,
      deviceIdResolver: () async => deviceId,
      cloudSyncEnabledReader: () => cloudSyncEnabled,
    ),
    gateway: firestore.gateway(),
    supportedOverride: supported,
  );
}

void main() {
  group('AccountRepository init gates', () {
    test('reports Unsupported on platforms without Firestore', () {
      final auth = _FakeAuthBackend();
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore, supported: false),
      );

      expect(tester.state, isA<AccountUnsupported>());
    });

    test('reports Idle when the master toggle is off', () {
      final auth = _FakeAuthBackend()..current = const CloudAuthAuthenticated('uid-1');
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore, cloudSyncEnabled: false),
      );

      expect(tester.state, isA<AccountIdle>());
      // No Firestore listeners attached when disabled.
      expect(firestore.attachedAccounts, isEmpty);
    });
  });

  group('AccountRepository auth-driven attachment', () {
    test('attaches and emits Loading then Ready when already authenticated at init', () async {
      final auth = _FakeAuthBackend()..current = const CloudAuthAuthenticated('uid-A');
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore),
      );

      expect(tester.state, isA<AccountLoading>());
      // Yield once so the async _attachToAccount can run and populate
      // currentDeviceId.
      await pumpEventQueue();
      expect(firestore.attachedAccounts, ['uid-A']);

      firestore.emitAccount(
        'uid-A',
        const CloudAccount(
          accountId: 'uid-A',
          createdAtMs: 0,
          lastActiveAtMs: 0,
          deviceCount: 1,
        ),
      );
      firestore.emitDevices('uid-A', [_fakeDevice('device-A')]);
      await pumpEventQueue();

      final ready = tester.state as AccountReady;
      expect(ready.accountId, 'uid-A');
      expect(ready.currentDeviceId, 'device-A');
      expect(ready.devices, hasLength(1));
      expect(ready.devices.single.deviceId, 'device-A');
      await firestore.dispose();
      await auth.dispose();
    });

    test('attaches when auth transitions from Idle to Authenticated mid-session', () async {
      final auth = _FakeAuthBackend();
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore),
      );
      expect(tester.state, isA<AccountIdle>());

      auth.emit(const CloudAuthAuthenticated('uid-B'));
      await pumpEventQueue();
      expect(firestore.attachedAccounts, ['uid-B']);

      firestore.emitDevices('uid-B', [_fakeDevice('device-A')]);
      await pumpEventQueue();
      expect(tester.state, isA<AccountReady>());
      await firestore.dispose();
      await auth.dispose();
    });

    test('UID rotation cancels prior listeners and re-attaches under the new UID', () async {
      final auth = _FakeAuthBackend()..current = const CloudAuthAuthenticated('uid-1');
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore),
      );
      await pumpEventQueue();
      expect(firestore.attachedAccounts, ['uid-1']);

      auth.emit(const CloudAuthAuthenticated('uid-2'));
      await pumpEventQueue();

      expect(firestore.attachedAccounts, ['uid-1', 'uid-2']);
      expect(firestore.accountCancelCount, 1);
      expect(firestore.devicesCancelCount, 1);

      firestore.emitDevices('uid-2', [_fakeDevice('device-A')]);
      await pumpEventQueue();
      expect((tester.state as AccountReady).accountId, 'uid-2');
      await firestore.dispose();
      await auth.dispose();
    });

    test('sign-out tears listeners down and resets to Idle', () async {
      final auth = _FakeAuthBackend()..current = const CloudAuthAuthenticated('uid-1');
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore),
      );
      await pumpEventQueue();

      auth.emit(const CloudAuthIdle());
      await pumpEventQueue();
      expect(tester.state, isA<AccountIdle>());
      expect(firestore.accountCancelCount, 1);
      expect(firestore.devicesCancelCount, 1);
      await firestore.dispose();
      await auth.dispose();
    });
  });

  group('AccountRepository data flow', () {
    test('device-list updates flow into AccountReady.devices', () async {
      final auth = _FakeAuthBackend()..current = const CloudAuthAuthenticated('uid-A');
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore),
      );
      await pumpEventQueue();

      firestore.emitDevices('uid-A', [_fakeDevice('device-A')]);
      await pumpEventQueue();
      expect((tester.state as AccountReady).devices, hasLength(1));

      firestore.emitDevices('uid-A', [_fakeDevice('device-A'), _fakeDevice('device-B')]);
      await pumpEventQueue();
      expect((tester.state as AccountReady).devices, hasLength(2));
      await firestore.dispose();
      await auth.dispose();
    });

    test('account-doc errors transition to AccountFailed', () async {
      final auth = _FakeAuthBackend()..current = const CloudAuthAuthenticated('uid-A');
      final firestore = _FakeFirestore();
      final tester = Notifier.test<AccountRepository, AccountState>(
        notifier: _build(auth: auth, firestore: firestore),
      );
      await pumpEventQueue();

      firestore._accountControllers['uid-A']!.addError(StateError('firestore down'));
      await pumpEventQueue();
      expect(tester.state, isA<AccountFailed>());
      await firestore.dispose();
      await auth.dispose();
    });
  });
}

CloudDevice _fakeDevice(String id) => CloudDevice(
  deviceId: id,
  displayName: id,
  icon: CloudDeviceIcon.phone,
  fcmToken: null,
  platform: CloudDevicePlatform.android,
);
