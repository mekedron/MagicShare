import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';
import 'package:magicshare_app/model/cloud/inbox_item_type.dart';
import 'package:magicshare_app/model/cloud/requests/send_link_notification_request.dart';

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
      );

      expect(inv.calls.single.name, 'registerDevice');
      expect(inv.calls.single.data, {
        'deviceId': 'd-1',
        'displayName': 'Macbook Pro',
        'icon': 'laptop',
        'platform': 'macos',
        'fcmToken': 'fcm-abc',
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
      );

      expect((inv.calls.single.data as Map)['fcmToken'], isNull);
      expect((inv.calls.single.data as Map).containsKey('fcmToken'), isTrue);
    });

    test('updateDevicePresence encodes presence as enum.name', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'updated': true};
      final c = _client(inv);

      await c.updateDevicePresence(
        deviceId: 'd-1',
        presence: CloudDevicePresence.online,
      );

      expect(inv.calls.single.data, {'deviceId': 'd-1', 'presence': 'online'});
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

    test('joinNetwork forwards token and device, decodes oldAccountDeleted', () async {
      final inv = _RecordingInvoker()
        ..respond = (_, __) => {
          'accountId': 'acct-2',
          'oldAccountDeleted': true,
          'devices': <Map<String, dynamic>>[],
        };
      final c = _client(inv);

      final result = await c.joinNetwork(tokenId: 'tok-1', deviceId: 'd-1');

      expect(inv.calls.single.data, {'tokenId': 'tok-1', 'deviceId': 'd-1'});
      expect(result.oldAccountDeleted, isTrue);
      expect(result.accountId, 'acct-2');
    });

    test('sendWake forwards opaque payload and decodes channel', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'delivered': true, 'channel': 'fcm'};
      final c = _client(inv);

      final result = await c.sendWake(
        sourceDeviceId: 'src',
        targetDeviceId: 'tgt',
        payload: 'ciphertext-base64',
      );

      expect(inv.calls.single.name, 'sendWake');
      expect(inv.calls.single.data, {
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'payload': 'ciphertext-base64',
      });
      expect(result.channel, DeliveryChannel.fcm);
    });

    test('sendLinkNotification serialises plaintext request with mode field', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'delivered': true, 'channel': 'inbox'};
      final c = _client(inv);

      await c.sendLinkNotification(
        const PlaintextLinkNotificationRequest(
          sourceDeviceId: 'src',
          targetDeviceId: 'tgt',
          url: 'https://example.com',
          title: 'Hi',
        ),
      );

      expect(inv.calls.single.name, 'sendLinkNotification');
      expect(inv.calls.single.data, {
        'mode': 'plaintext',
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'url': 'https://example.com',
        'title': 'Hi',
      });
    });

    test('sendLinkNotification serialises encrypted request with mode field', () async {
      final inv = _RecordingInvoker()..respond = (_, __) => {'delivered': true, 'channel': 'fcm'};
      final c = _client(inv);

      await c.sendLinkNotification(
        const EncryptedLinkNotificationRequest(
          sourceDeviceId: 'src',
          targetDeviceId: 'tgt',
          payload: 'ciphertext',
        ),
      );

      expect(inv.calls.single.data, {
        'mode': 'encrypted',
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'payload': 'ciphertext',
      });
    });

    test('pollPendingWakes decodes mixed payload union', () async {
      final inv = _RecordingInvoker()
        ..respond = (_, __) => {
          'items': [
            {
              'id': 'item-1',
              'type': 'wake',
              'payload': 'ct-1',
              'createdAtMs': 1,
              'expiresAtMs': 2,
            },
            {
              'id': 'item-2',
              'type': 'link',
              'payload': {'url': 'https://example.com'},
              'createdAtMs': 3,
              'expiresAtMs': 4,
            },
          ],
        };
      final c = _client(inv);

      final result = await c.pollPendingWakes(deviceId: 'd-1');

      expect(inv.calls.single.data, {'deviceId': 'd-1'});
      expect(result.items, hasLength(2));
      expect(result.items.first.type, InboxItemType.wake);
      expect(result.items.first.encryptedPayload, 'ct-1');
      expect(result.items.last.plaintextPayload?.url, 'https://example.com');
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
