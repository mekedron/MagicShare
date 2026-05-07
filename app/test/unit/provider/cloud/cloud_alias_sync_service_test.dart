import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_alias_sync_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _AliasSlot {
  String value;

  _AliasSlot(this.value);
}

class _ServerSpy {
  int restartCalls = 0;

  Future<void> restart() async {
    restartCalls++;
  }
}

CloudDevice _device({
  required String id,
  required String name,
  String? fingerprint,
}) {
  return CloudDevice(
    deviceId: id,
    displayName: name,
    icon: CloudDeviceIcon.phone,
    fcmToken: null,
    platform: CloudDevicePlatform.ios,
    fingerprint: fingerprint,
  );
}

AccountReady _ready({
  required String currentDeviceId,
  required List<CloudDevice> devices,
}) {
  return AccountReady(
    accountId: 'uid-1',
    currentDeviceId: currentDeviceId,
    account: null,
    devices: devices,
  );
}

CloudAliasSyncDeps _deps({
  required _AliasSlot alias,
  required _ServerSpy server,
  required AccountState initial,
  required Stream<AccountState> changes,
}) {
  return CloudAliasSyncDeps(
    accountStateReader: () => initial,
    accountStateChanges: () => changes,
    aliasReader: () => alias.value,
    setAlias: (value) async {
      alias.value = value;
    },
    restartServer: server.restart,
  );
}

void main() {
  group('CloudAliasSyncService initial sync', () {
    test('does nothing when account is not ready', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: const AccountIdle(),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'Wise Mushroom');
      expect(server.restartCalls, 0);
      await controller.close();
    });

    test('pushes cloud displayName into local alias when they differ', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-A', name: 'iPhone')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'iPhone');
      expect(server.restartCalls, 1);
      await controller.close();
    });

    test('does nothing when cloud displayName already matches local alias', () async {
      final alias = _AliasSlot('iPhone');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-A', name: 'iPhone')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'iPhone');
      expect(server.restartCalls, 0);
      await controller.close();
    });

    test('skips sync when current device row is missing', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-OTHER', name: 'iPad')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'Wise Mushroom');
      expect(server.restartCalls, 0);
      await controller.close();
    });

    test('skips sync when cloud displayName is empty or whitespace', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-A', name: '  ')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'Wise Mushroom');
      expect(server.restartCalls, 0);
      await controller.close();
    });
  });

  group('CloudAliasSyncService stream updates', () {
    test('reacts to AccountReady emitted after initial idle state', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: const AccountIdle(),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();

      controller.add(
        _ready(
          currentDeviceId: 'device-A',
          devices: [_device(id: 'device-A', name: 'iPhone')],
        ),
      );
      await pumpEventQueue();

      expect(alias.value, 'iPhone');
      expect(server.restartCalls, 1);
      await controller.close();
    });

    test('does not re-sync when account stream re-emits the same value', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-A', name: 'iPhone')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'iPhone');
      expect(server.restartCalls, 1);

      // FCM token refresh / unrelated re-emission with the same name.
      controller.add(
        _ready(
          currentDeviceId: 'device-A',
          devices: [_device(id: 'device-A', name: 'iPhone', fingerprint: 'cert-x')],
        ),
      );
      await pumpEventQueue();

      expect(alias.value, 'iPhone');
      expect(server.restartCalls, 1);
      await controller.close();
    });

    test('does not clobber a local alias edit with the same cloud value', () async {
      // After the initial sync, the user changes their local alias via
      // the settings tab. A subsequent re-emission of the same cloud
      // displayName must not overwrite the user's edit.
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-A', name: 'iPhone')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'iPhone');

      // User edits local alias via the settings tab.
      alias.value = 'MyPhone';

      // Cloud stream re-emits the same displayName (e.g. on a stream
      // re-subscribe after a transient network blip).
      controller.add(
        _ready(
          currentDeviceId: 'device-A',
          devices: [_device(id: 'device-A', name: 'iPhone')],
        ),
      );
      await pumpEventQueue();

      expect(alias.value, 'MyPhone');
      expect(server.restartCalls, 1);
      await controller.close();
    });

    test('applies a fresh cloud rename even after a local edit', () async {
      final alias = _AliasSlot('Wise Mushroom');
      final server = _ServerSpy();
      final controller = StreamController<AccountState>.broadcast();
      Notifier.test<CloudAliasSyncService, CloudAliasSyncState>(
        notifier: CloudAliasSyncService(
          deps: _deps(
            alias: alias,
            server: server,
            initial: _ready(
              currentDeviceId: 'device-A',
              devices: [_device(id: 'device-A', name: 'iPhone')],
            ),
            changes: controller.stream,
          ),
        ),
      );
      await pumpEventQueue();
      expect(alias.value, 'iPhone');

      // User edits locally.
      alias.value = 'MyPhone';

      // User then renames again from the device-group settings on
      // another device — cloud now says "Foo".
      controller.add(
        _ready(
          currentDeviceId: 'device-A',
          devices: [_device(id: 'device-A', name: 'Foo')],
        ),
      );
      await pumpEventQueue();

      expect(alias.value, 'Foo');
      expect(server.restartCalls, 2);
      await controller.close();
    });
  });
}
