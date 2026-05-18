import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';

class _RecordingInvoker {
  final List<({String name, Object? data})> calls = [];
  Object? Function(String name, Object? data)? respond;
  Exception? throwing;

  Future<Object?> call(String name, Object? data) async {
    calls.add((name: name, data: data));
    if (throwing != null) throw throwing!;
    return respond?.call(name, data);
  }
}

CloudFunctionsClient _client(_RecordingInvoker inv) => CloudFunctionsClient(invoker: inv.call);

void main() {
  group('CloudFunctionsClient — request envelopes', () {
    test('health passes null data', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'ok': true, 'service': 'magicshare-functions', 'version': '0.0.1'};
      final c = _client(inv);

      final result = await c.health();

      expect(inv.calls.single, (name: 'health', data: null));
      expect(result.ok, isTrue);
      expect(result.service, 'magicshare-functions');
      expect(result.version, '0.0.1');
    });

    test('createAccount passes null data and decodes result', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'created': true, 'accountId': 'acct-1'};
      final c = _client(inv);

      final result = await c.createAccount();

      expect(inv.calls.single, (name: 'createAccount', data: null));
      expect(result.created, isTrue);
      expect(result.accountId, 'acct-1');
    });

    test('deleteAccount passes null data and decodes result', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'deleted': true};
      final c = _client(inv);

      final result = await c.deleteAccount();

      expect(inv.calls.single, (name: 'deleteAccount', data: null));
      expect(result.deleted, isTrue);
    });

    test('registerDevice passes the validated input shape', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'created': true};
      final c = _client(inv);

      await c.registerDevice(
        deviceId: 'd-1',
        displayName: 'Macbook Pro',
        icon: CloudDeviceIcon.laptop,
        platform: CloudDevicePlatform.macos,
        fcmToken: 'fcm-abc',
        fingerprint: 'cert-hash-abc',
      );

      expect(inv.calls.single.name, 'registerDevice');
      expect(inv.calls.single.data, {
        'deviceId': 'd-1',
        'displayName': 'Macbook Pro',
        'icon': 'laptop',
        'platform': 'macos',
        'fcmToken': 'fcm-abc',
        'fingerprint': 'cert-hash-abc',
      });
    });

    test('registerDevice includes null fcmToken (backend rejects undefined)', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'created': true};
      final c = _client(inv);

      await c.registerDevice(
        deviceId: 'd-2',
        displayName: 'Linux server',
        icon: CloudDeviceIcon.server,
        platform: CloudDevicePlatform.linux,
        fcmToken: null,
        fingerprint: null,
      );

      expect((inv.calls.single.data as Map)['fcmToken'], isNull);
      expect((inv.calls.single.data as Map).containsKey('fcmToken'), isTrue);
      expect((inv.calls.single.data as Map)['fingerprint'], isNull);
      expect((inv.calls.single.data as Map).containsKey('fingerprint'), isTrue);
    });

    test('renameDevice returns void and forwards args', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'ok': true};
      final c = _client(inv);

      await c.renameDevice(deviceId: 'd-1', displayName: 'New name');

      expect(inv.calls.single.data, {'deviceId': 'd-1', 'displayName': 'New name'});
    });

    test('setDeviceIcon returns void and forwards args', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'ok': true};
      final c = _client(inv);

      await c.setDeviceIcon(deviceId: 'd-1', icon: CloudDeviceIcon.phone);

      expect(inv.calls.single.data, {'deviceId': 'd-1', 'icon': 'phone'});
    });

    test('removeDevice forwards deviceId and decodes accountDeleted', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'accountDeleted': true};
      final c = _client(inv);

      final result = await c.removeDevice(deviceId: 'd-1');

      expect(inv.calls.single.data, {'deviceId': 'd-1'});
      expect(result.accountDeleted, isTrue);
    });

    test('createJoinToken forwards issuingDeviceId', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'tokenId': 'tok-1', 'expiresAtMs': 1};
      final c = _client(inv);

      final result = await c.createJoinToken(issuingDeviceId: 'd-1');

      expect(inv.calls.single.data, {'issuingDeviceId': 'd-1'});
      expect(result.tokenId, 'tok-1');
    });

    test('previewJoinToken decodes the device list', () async {
      final inv = _RecordingInvoker()
        ..respond = (_, __) => {
          'accountId': 'acct-1',
          'issuingDeviceId': 'd-1',
          'expiresAtMs': 100,
          'devices': [
            {
              'deviceId': 'd-1',
              'displayName': 'Mac',
              'icon': 'laptop',
              'platform': 'macos',
              'presence': 'online',
            },
          ],
        };
      final c = _client(inv);

      final result = await c.previewJoinToken(tokenId: 'tok-1');

      expect(inv.calls.single.data, {'tokenId': 'tok-1'});
      expect(result.devices.single.icon, CloudDeviceIcon.laptop);
    });

    test('joinNetwork forwards token and device, decodes oldAccountDeleted + customToken', () async {
      final inv = _RecordingInvoker()
        ..respond = (_, __) => {
          'accountId': 'acct-2',
          'oldAccountDeleted': true,
          'devices': <Map<String, dynamic>>[],
          'customToken': 'fixture-custom-token',
        };
      final c = _client(inv);

      final result = await c.joinNetwork(tokenId: 'tok-1', deviceId: 'd-1');

      expect(inv.calls.single.data, {'tokenId': 'tok-1', 'deviceId': 'd-1'});
      expect(result.oldAccountDeleted, isTrue);
      expect(result.accountId, 'acct-2');
      expect(result.customToken, 'fixture-custom-token');
    });

    test('joinNetwork forwards newDevice when supplied (welcome-card route)', () async {
      final inv = _RecordingInvoker()
        ..respond = (_, __) => {
          'accountId': 'acct-2',
          'oldAccountDeleted': false,
          'devices': <Map<String, dynamic>>[],
          'customToken': 'token',
        };
      final c = _client(inv);

      await c.joinNetwork(
        tokenId: 'tok-1',
        deviceId: 'd-1',
        newDevice: const JoinNetworkNewDevice(
          displayName: 'Pixel 8',
          icon: CloudDeviceIcon.phone,
          platform: CloudDevicePlatform.android,
          fcmToken: 'fcm-fresh',
        ),
      );

      expect(inv.calls.single.data, {
        'tokenId': 'tok-1',
        'deviceId': 'd-1',
        'newDevice': {
          'displayName': 'Pixel 8',
          'icon': 'phone',
          'platform': 'android',
          'fcmToken': 'fcm-fresh',
        },
      });
    });

    test('notifyTransferIntent forwards kind on the wire and decodes channel', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'delivered': true, 'channel': 'fcm'};
      final c = _client(inv);

      final result = await c.notifyTransferIntent(
        sourceDeviceId: 'src',
        targetDeviceId: 'tgt',
        kind: NotifyTransferKind.file,
      );

      expect(inv.calls.single.name, 'notifyTransferIntent');
      expect(inv.calls.single.data, {
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'kind': 'file',
      });
      expect(result.delivered, isTrue);
      expect(result.channel, DeliveryChannel.fcm);
    });

    test('notifyTransferIntent decodes channel=none when target has no fcmToken', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'delivered': false, 'channel': 'none'};
      final c = _client(inv);

      final result = await c.notifyTransferIntent(
        sourceDeviceId: 'src',
        targetDeviceId: 'linux-tgt',
        kind: NotifyTransferKind.url,
      );

      expect(result.delivered, isFalse);
      expect(result.channel, DeliveryChannel.none);
      expect((inv.calls.single.data as Map)['kind'], 'url');
    });
  });

  group('CloudFunctionsClient — error mapping', () {
    test('FirebaseFunctionsException becomes CloudException', () async {
      final inv = _RecordingInvoker()
        ..throwing = FirebaseFunctionsException(
          message: 'Caller must be signed in.',
          code: 'unauthenticated',
        );
      final c = _client(inv);

      await expectLater(
        () => c.createAccount(),
        throwsA(
          isA<CloudException>()
              .having((e) => e.code, 'code', CloudErrorCode.unauthenticated)
              .having((e) => e.message, 'message', 'Caller must be signed in.'),
        ),
      );
    });

    test('CloudException from invoker is rethrown unchanged', () async {
      final ex = const CloudException(
        code: CloudErrorCode.failedPrecondition,
        message: 'Token already consumed',
      );
      final inv = _RecordingInvoker()..throwing = ex;
      final c = _client(inv);

      await expectLater(() => c.previewJoinToken(tokenId: 'tok'), throwsA(same(ex)));
    });

    test('non-map response surfaces as CloudException(unknown)', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => 'not a map';
      final c = _client(inv);

      await expectLater(
        () => c.createAccount(),
        throwsA(isA<CloudException>().having((e) => e.code, 'code', CloudErrorCode.unknown)),
      );
    });
  });
}
