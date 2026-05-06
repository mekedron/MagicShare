import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/cloud/local_notifications_provider.dart';

class _RecordingGateway {
  bool initializeCalled = false;
  void Function(NotificationResponse)? onResponse;
  final List<_ShownNotification> shown = <_ShownNotification>[];
  bool throwOnShow = false;
  bool throwOnInit = false;

  LocalNotificationsGateway gateway() => LocalNotificationsGateway(
    initialize:
        ({
          required InitializationSettings settings,
          DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
          DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
        }) async {
          if (throwOnInit) throw StateError('init blew up');
          initializeCalled = true;
          onResponse = onDidReceiveNotificationResponse;
          return true;
        },
    show:
        ({
          required int id,
          String? title,
          String? body,
          NotificationDetails? notificationDetails,
          String? payload,
        }) async {
          if (throwOnShow) throw StateError('show blew up');
          shown.add(
            _ShownNotification(id: id, title: title ?? '', body: body ?? '', payload: payload),
          );
        },
  );
}

class _ShownNotification {
  _ShownNotification({required this.id, required this.title, required this.body, this.payload});
  final int id;
  final String title;
  final String body;
  final String? payload;
}

class _LaunchRecorder {
  final List<Uri> calls = <Uri>[];
  Future<bool> launch(Uri uri) async {
    calls.add(uri);
    return true;
  }
}

void main() {
  group('LocalNotificationsService.initialize', () {
    test('calls the underlying initialize once', () async {
      final gateway = _RecordingGateway();
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.initialize();
      await service.initialize();
      expect(gateway.initializeCalled, isTrue);
    });

    test('swallows init failures without throwing', () async {
      final gateway = _RecordingGateway()..throwOnInit = true;
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.initialize(); // must not throw
    });
  });

  group('LocalNotificationsService.showLinkNotification', () {
    test('initialises lazily and surfaces a notification', () async {
      final gateway = _RecordingGateway();
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.showLinkNotification(url: 'https://example.com');
      expect(gateway.initializeCalled, isTrue);
      expect(gateway.shown, hasLength(1));
      final shown = gateway.shown.single;
      expect(shown.body, 'https://example.com');
      expect(shown.payload, isNotNull);
      expect(shown.payload, contains('https://example.com'));
    });

    test('uses provided title when given', () async {
      final gateway = _RecordingGateway();
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.showLinkNotification(
        url: 'https://example.com',
        title: 'Custom title',
      );
      expect(gateway.shown.single.title, 'Custom title');
    });

    test('falls back to a default title when none is given', () async {
      final gateway = _RecordingGateway();
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.showLinkNotification(url: 'https://example.com');
      expect(gateway.shown.single.title, isNotEmpty);
    });

    test('assigns distinct ids per notification', () async {
      final gateway = _RecordingGateway();
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.showLinkNotification(url: 'https://example.com/a');
      await service.showLinkNotification(url: 'https://example.com/b');
      expect(
        gateway.shown.map((e) => e.id).toSet().length,
        gateway.shown.length,
      );
    });

    test('swallows show failures without throwing', () async {
      final gateway = _RecordingGateway()..throwOnShow = true;
      final service = LocalNotificationsService(gateway: gateway.gateway());
      await service.showLinkNotification(url: 'https://example.com'); // must not throw
    });
  });

  group('tap response handling', () {
    test('valid http payload triggers url_launcher', () async {
      final gateway = _RecordingGateway();
      final launcher = _LaunchRecorder();
      final service = LocalNotificationsService(
        gateway: gateway.gateway(),
        launchUrl: launcher.launch,
      );
      await service.initialize();
      await service.showLinkNotification(url: 'https://example.com/news');

      // Simulate a tap.
      gateway.onResponse!(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: gateway.shown.single.payload,
        ),
      );
      // The launch is unawaited; let microtasks settle.
      await pumpEventQueue();
      expect(launcher.calls, [Uri.parse('https://example.com/news')]);
    });

    test('null payload is ignored', () async {
      final gateway = _RecordingGateway();
      final launcher = _LaunchRecorder();
      final service = LocalNotificationsService(
        gateway: gateway.gateway(),
        launchUrl: launcher.launch,
      );
      await service.initialize();
      gateway.onResponse!(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: null,
        ),
      );
      await pumpEventQueue();
      expect(launcher.calls, isEmpty);
    });

    test('non-http(s) URL is rejected', () async {
      final gateway = _RecordingGateway();
      final launcher = _LaunchRecorder();
      final service = LocalNotificationsService(
        gateway: gateway.gateway(),
        launchUrl: launcher.launch,
      );
      await service.initialize();
      gateway.onResponse!(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: '{"kind":"link","url":"javascript:alert(1)"}',
        ),
      );
      await pumpEventQueue();
      expect(launcher.calls, isEmpty);
    });

    test('malformed payload is ignored', () async {
      final gateway = _RecordingGateway();
      final launcher = _LaunchRecorder();
      final service = LocalNotificationsService(
        gateway: gateway.gateway(),
        launchUrl: launcher.launch,
      );
      await service.initialize();
      gateway.onResponse!(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: 'not-json{',
        ),
      );
      await pumpEventQueue();
      expect(launcher.calls, isEmpty);
    });
  });
}
