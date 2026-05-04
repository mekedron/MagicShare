import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_account.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';
import 'package:magicshare_app/model/cloud/inbox_item.dart';
import 'package:magicshare_app/model/cloud/inbox_item_type.dart';
import 'package:magicshare_app/model/cloud/join_token_preview.dart';
import 'package:magicshare_app/model/cloud/plaintext_link_payload.dart';
import 'package:magicshare_app/model/cloud/requests/send_link_notification_request.dart';
import 'package:magicshare_app/model/cloud/results/create_account_result.dart';
import 'package:magicshare_app/model/cloud/results/create_join_token_result.dart';
import 'package:magicshare_app/model/cloud/results/delete_account_result.dart';
import 'package:magicshare_app/model/cloud/results/join_network_result.dart';
import 'package:magicshare_app/model/cloud/results/poll_pending_wakes_result.dart';
import 'package:magicshare_app/model/cloud/results/preview_join_token_result.dart';
import 'package:magicshare_app/model/cloud/results/register_device_result.dart';
import 'package:magicshare_app/model/cloud/results/remove_device_result.dart';
import 'package:magicshare_app/model/cloud/results/send_link_notification_result.dart';
import 'package:magicshare_app/model/cloud/results/send_wake_result.dart';
import 'package:magicshare_app/model/cloud/results/update_presence_result.dart';

void main() {
  group('Enums encode to lowercase strings matching firebase/functions', () {
    test('CloudDeviceIcon.values match DEVICE_ICONS', () {
      expect(
        CloudDeviceIcon.values.map((e) => e.name).toList(),
        const ['laptop', 'desktop', 'phone', 'tablet', 'server', 'headless', 'other'],
      );
    });

    test('CloudDevicePlatform.values match DEVICE_PLATFORMS', () {
      expect(
        CloudDevicePlatform.values.map((e) => e.name).toList(),
        const ['android', 'ios', 'macos', 'windows', 'linux'],
      );
    });

    test('CloudDevicePresence values', () {
      expect(
        CloudDevicePresence.values.map((e) => e.name).toList(),
        const ['online', 'offline'],
      );
    });

    test('InboxItemType values', () {
      expect(
        InboxItemType.values.map((e) => e.name).toList(),
        const ['wake', 'link'],
      );
    });

    test('DeliveryChannel values', () {
      expect(
        DeliveryChannel.values.map((e) => e.name).toList(),
        const ['fcm', 'inbox', 'none'],
      );
    });
  });

  group('PlaintextLinkPayload round-trip', () {
    test('with title', () {
      const fixture = {
        'url': 'https://example.com/article',
        'title': 'Example article',
      };
      final decoded = PlaintextLinkPayload.fromJson(fixture);
      expect(decoded.url, 'https://example.com/article');
      expect(decoded.title, 'Example article');
      expect(decoded.toJson(), fixture);
    });

    test('without title', () {
      const fixture = {'url': 'https://example.com'};
      final decoded = PlaintextLinkPayload.fromJson(fixture);
      expect(decoded.url, 'https://example.com');
      expect(decoded.title, isNull);
      // dart_mappable elides nulls by default
      expect(decoded.toJson(), {'url': 'https://example.com'});
    });
  });

  group('CloudAccount round-trip', () {
    test('preserves all fields', () {
      const fixture = {
        'accountId': 'acct-1',
        'createdAtMs': 1714780800000,
        'lastActiveAtMs': 1714867200000,
        'deviceCount': 3,
      };
      final decoded = CloudAccount.fromJson(fixture);
      expect(decoded.accountId, 'acct-1');
      expect(decoded.createdAtMs, 1714780800000);
      expect(decoded.lastActiveAtMs, 1714867200000);
      expect(decoded.deviceCount, 3);
      expect(decoded.toJson(), fixture);
    });
  });

  group('CloudDevice round-trip', () {
    test('with fcmToken', () {
      const fixture = {
        'deviceId': 'device-1',
        'displayName': 'Macbook Pro',
        'icon': 'laptop',
        'fcmToken': 'fcm-abc',
        'platform': 'macos',
        'lastSeenAtMs': 1714780800000,
        'presence': 'online',
      };
      final decoded = CloudDevice.fromJson(fixture);
      expect(decoded.icon, CloudDeviceIcon.laptop);
      expect(decoded.platform, CloudDevicePlatform.macos);
      expect(decoded.presence, CloudDevicePresence.online);
      expect(decoded.toJson(), fixture);
    });

    test('with null fcmToken', () {
      const fixture = {
        'deviceId': 'device-2',
        'displayName': 'Headless server',
        'icon': 'server',
        'fcmToken': null,
        'platform': 'linux',
        'lastSeenAtMs': 1714780800000,
        'presence': 'offline',
      };
      final decoded = CloudDevice.fromJson(fixture);
      expect(decoded.fcmToken, isNull);
      expect(decoded.icon, CloudDeviceIcon.server);
      expect(decoded.platform, CloudDevicePlatform.linux);
      expect(decoded.presence, CloudDevicePresence.offline);
    });

    test('unknown icon falls back to other', () {
      final decoded = CloudDevice.fromJson({
        'deviceId': 'd',
        'displayName': 'D',
        'icon': 'spaceship',
        'fcmToken': null,
        'platform': 'ios',
        'lastSeenAtMs': 0,
        'presence': 'offline',
      });
      expect(decoded.icon, CloudDeviceIcon.other);
    });
  });

  group('JoinTokenPreview round-trip', () {
    test('with two devices', () {
      const fixture = {
        'accountId': 'acct-1',
        'issuingDeviceId': 'device-1',
        'expiresAtMs': 1714780800000,
        'devices': [
          {
            'deviceId': 'device-1',
            'displayName': 'Macbook Pro',
            'icon': 'laptop',
            'platform': 'macos',
            'presence': 'online',
          },
          {
            'deviceId': 'device-2',
            'displayName': 'Pixel 8',
            'icon': 'phone',
            'platform': 'android',
            'presence': 'offline',
          },
        ],
      };
      final decoded = JoinTokenPreview.fromJson(fixture);
      expect(decoded.devices, hasLength(2));
      expect(decoded.devices.first.icon, CloudDeviceIcon.laptop);
      expect(decoded.devices.last.platform, CloudDevicePlatform.android);
      expect(decoded.toJson(), fixture);
    });
  });

  group('Result types round-trip', () {
    test('CreateAccountResult', () {
      const fixture = {'created': true, 'accountId': 'acct-1'};
      expect(CreateAccountResult.fromJson(fixture).toJson(), fixture);
    });

    test('DeleteAccountResult', () {
      const fixture = {'deleted': true};
      expect(DeleteAccountResult.fromJson(fixture).toJson(), fixture);
    });

    test('RegisterDeviceResult', () {
      const fixture = {'created': true};
      expect(RegisterDeviceResult.fromJson(fixture).toJson(), fixture);
    });

    test('UpdatePresenceResult', () {
      const fixture = {'updated': false};
      expect(UpdatePresenceResult.fromJson(fixture).toJson(), fixture);
    });

    test('RemoveDeviceResult', () {
      const fixture = {'accountDeleted': true};
      expect(RemoveDeviceResult.fromJson(fixture).toJson(), fixture);
    });

    test('CreateJoinTokenResult', () {
      const fixture = {'tokenId': 'tok-1', 'expiresAtMs': 1714780800000};
      expect(CreateJoinTokenResult.fromJson(fixture).toJson(), fixture);
    });

    test('PreviewJoinTokenResult', () {
      const fixture = {
        'accountId': 'acct-1',
        'issuingDeviceId': 'device-1',
        'expiresAtMs': 1714780800000,
        'devices': [
          {
            'deviceId': 'device-1',
            'displayName': 'Mac',
            'icon': 'laptop',
            'platform': 'macos',
            'presence': 'online',
          },
        ],
      };
      expect(PreviewJoinTokenResult.fromJson(fixture).toJson(), fixture);
    });

    test('JoinNetworkResult', () {
      const fixture = {
        'accountId': 'acct-2',
        'oldAccountDeleted': true,
        'devices': [
          {
            'deviceId': 'device-1',
            'displayName': 'Pixel',
            'icon': 'phone',
            'platform': 'android',
            'presence': 'online',
          },
        ],
        'customToken': 'eyJhbGciOiJSUzI1NiJ9.fixturePayload.fixtureSig',
      };
      expect(JoinNetworkResult.fromJson(fixture).toJson(), fixture);
    });

    test('SendWakeResult fcm channel', () {
      const fixture = {'delivered': true, 'channel': 'fcm'};
      final decoded = SendWakeResult.fromJson(fixture);
      expect(decoded.channel, DeliveryChannel.fcm);
      expect(decoded.toJson(), fixture);
    });

    test('SendLinkNotificationResult inbox channel', () {
      const fixture = {'delivered': true, 'channel': 'inbox'};
      final decoded = SendLinkNotificationResult.fromJson(fixture);
      expect(decoded.channel, DeliveryChannel.inbox);
      expect(decoded.toJson(), fixture);
    });

    test('SendWakeResult unknown channel falls back to none', () {
      final decoded = SendWakeResult.fromJson({'delivered': false, 'channel': 'unknown'});
      expect(decoded.channel, DeliveryChannel.none);
    });
  });

  group('SendLinkNotificationRequest discriminator', () {
    test('plaintext encodes mode field', () {
      const req = PlaintextLinkNotificationRequest(
        sourceDeviceId: 'src',
        targetDeviceId: 'tgt',
        url: 'https://example.com',
        title: 'Hi',
      );
      expect(req.toJson(), {
        'mode': 'plaintext',
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'url': 'https://example.com',
        'title': 'Hi',
      });
    });

    test('encrypted encodes mode field', () {
      const req = EncryptedLinkNotificationRequest(
        sourceDeviceId: 'src',
        targetDeviceId: 'tgt',
        payload: 'ciphertext',
      );
      expect(req.toJson(), {
        'mode': 'encrypted',
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'payload': 'ciphertext',
      });
    });

    test('round-trip dispatches to the correct subclass', () {
      const fixture = {
        'mode': 'plaintext',
        'sourceDeviceId': 'src',
        'targetDeviceId': 'tgt',
        'url': 'https://example.com',
      };
      final decoded = SendLinkNotificationRequestMapper.fromJson(fixture);
      expect(decoded, isA<PlaintextLinkNotificationRequest>());
      expect((decoded as PlaintextLinkNotificationRequest).url, 'https://example.com');
      expect(decoded.title, isNull);
    });
  });

  group('InboxItem (hand-rolled) round-trip', () {
    test('encrypted wake payload', () {
      const fixture = {
        'id': 'item-1',
        'type': 'wake',
        'payload': 'ciphertext-base64',
        'createdAtMs': 1000,
        'expiresAtMs': 2000,
      };
      final decoded = InboxItem.fromMap(fixture);
      expect(decoded.type, InboxItemType.wake);
      expect(decoded.encryptedPayload, 'ciphertext-base64');
      expect(decoded.plaintextPayload, isNull);
      expect(decoded.toMap(), fixture);
    });

    test('plaintext link payload', () {
      const fixture = {
        'id': 'item-2',
        'type': 'link',
        'payload': {'url': 'https://example.com', 'title': 'Hi'},
        'createdAtMs': 1000,
        'expiresAtMs': 2000,
      };
      final decoded = InboxItem.fromMap(fixture);
      expect(decoded.type, InboxItemType.link);
      expect(decoded.encryptedPayload, isNull);
      expect(decoded.plaintextPayload?.url, 'https://example.com');
      expect(decoded.plaintextPayload?.title, 'Hi');
      expect(decoded.toMap(), fixture);
    });

    test('rejects unknown payload shape', () {
      expect(
        () => InboxItem.fromMap(const {
          'id': 'item-3',
          'type': 'wake',
          'payload': 42,
          'createdAtMs': 1,
          'expiresAtMs': 2,
        }),
        throwsArgumentError,
      );
    });
  });

  group('PollPendingWakesResult round-trip', () {
    test('mixed encrypted and plaintext items', () {
      const fixture = {
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
      final decoded = PollPendingWakesResult.fromMap(fixture);
      expect(decoded.items, hasLength(2));
      expect(decoded.items.first.encryptedPayload, 'ct-1');
      expect(decoded.items.last.plaintextPayload?.url, 'https://example.com');
      expect(decoded.toMap(), fixture);
    });

    test('empty items list', () {
      const fixture = {'items': <Map<String, dynamic>>[]};
      final decoded = PollPendingWakesResult.fromMap(fixture);
      expect(decoded.items, isEmpty);
      expect(decoded.toMap(), fixture);
    });
  });
}
