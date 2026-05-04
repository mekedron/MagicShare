import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/results/update_presence_result.dart';
import 'package:magicshare_app/provider/cloud/presence_heartbeat_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _PresenceSpy {
  Object? throws;
  int calls = 0;
  final List<CloudDevicePresence> presences = [];

  HttpsCallableInvoker invoker() => (name, data) async {
    expect(name, 'updateDevicePresence');
    calls++;
    final map = (data as Map).cast<String, dynamic>();
    presences.add(
      CloudDevicePresence.values.firstWhere((p) => p.name == map['presence']),
    );
    if (throws != null) throw throws!;
    return const UpdatePresenceResult(updated: true).toJson();
  };
}

PresenceHeartbeatDeps _deps({
  required _PresenceSpy spy,
  String? deviceId = 'device-A',
  bool cloudSyncEnabled = true,
}) {
  return PresenceHeartbeatDeps(
    client: () => CloudFunctionsClient(invoker: spy.invoker()),
    currentDeviceIdReader: () => deviceId,
    cloudSyncEnabledReader: () => cloudSyncEnabled,
  );
}

void main() {
  group('PresenceHeartbeatService gates', () {
    test('reports Unsupported on platforms without Cloud Functions', () {
      final spy = _PresenceSpy();
      final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
        notifier: PresenceHeartbeatService(
          deps: _deps(spy: spy),
          supportedOverride: false,
        ),
      );

      expect(tester.state, isA<HeartbeatUnsupported>());
      tester.notifier.markForeground();
      tester.notifier.markBackground();
      expect(spy.calls, 0);
    });

    test('reports Disabled when the master toggle is off', () {
      final spy = _PresenceSpy();
      final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
        notifier: PresenceHeartbeatService(
          deps: _deps(spy: spy, cloudSyncEnabled: false),
          supportedOverride: true,
        ),
      );

      expect(tester.state, isA<HeartbeatDisabled>());
      tester.notifier.markForeground();
      expect(spy.calls, 0);
    });
  });

  group('PresenceHeartbeatService periodic dispatch', () {
    test('foreground fires once immediately and then every 4 minutes', () {
      fakeAsync((async) {
        final spy = _PresenceSpy();
        final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
          notifier: PresenceHeartbeatService(
            deps: _deps(spy: spy),
            supportedOverride: true,
            period: heartbeatPeriod,
          ),
        );

        tester.notifier.markForeground();
        async.flushMicrotasks();
        expect(spy.calls, 1, reason: 'immediate online dispatch');

        async.elapse(heartbeatPeriod);
        async.flushMicrotasks();
        expect(spy.calls, 2);

        async.elapse(heartbeatPeriod);
        async.flushMicrotasks();
        expect(spy.calls, 3);

        expect(spy.presences, everyElement(CloudDevicePresence.online));
      });
    });

    test('two consecutive markForeground calls do not stack timers', () {
      fakeAsync((async) {
        final spy = _PresenceSpy();
        final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
          notifier: PresenceHeartbeatService(
            deps: _deps(spy: spy),
            supportedOverride: true,
            period: heartbeatPeriod,
          ),
        );

        tester.notifier.markForeground();
        tester.notifier.markForeground();
        async.flushMicrotasks();
        expect(spy.calls, 1, reason: 'second markForeground is a no-op');

        async.elapse(heartbeatPeriod);
        async.flushMicrotasks();
        expect(spy.calls, 2, reason: 'still one tick per 4 minutes');
      });
    });

    test('background cancels the timer and dispatches an offline mark', () {
      fakeAsync((async) {
        final spy = _PresenceSpy();
        final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
          notifier: PresenceHeartbeatService(
            deps: _deps(spy: spy),
            supportedOverride: true,
            period: heartbeatPeriod,
          ),
        );

        tester.notifier.markForeground();
        async.flushMicrotasks();
        expect(spy.calls, 1);

        tester.notifier.markBackground();
        async.flushMicrotasks();
        expect(spy.calls, 2);
        expect(spy.presences.last, CloudDevicePresence.offline);

        async.elapse(const Duration(minutes: 8));
        async.flushMicrotasks();
        expect(spy.calls, 2, reason: 'timer is cancelled — no further calls');
      });
    });
  });

  group('PresenceHeartbeatService bail-out conditions', () {
    test('skips the call when current device id is null (bootstrap not done)', () {
      fakeAsync((async) {
        final spy = _PresenceSpy();
        final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
          notifier: PresenceHeartbeatService(
            deps: _deps(spy: spy, deviceId: null),
            supportedOverride: true,
            period: heartbeatPeriod,
          ),
        );

        tester.notifier.markForeground();
        async.flushMicrotasks();
        expect(spy.calls, 0);
      });
    });

    test('rate-limit exception is swallowed silently', () async {
      final spy = _PresenceSpy()
        ..throws = const CloudException(
          code: CloudErrorCode.resourceExhausted,
          message: 'rate limited',
        );
      final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
        notifier: PresenceHeartbeatService(
          deps: _deps(spy: spy),
          supportedOverride: true,
        ),
      );

      tester.notifier.markBackground();
      // Wait for the unawaited send future to complete.
      await pumpEventQueue();
      expect(spy.calls, 1);
      // No exception should have escaped — the test would fail with an
      // uncaught error otherwise.
    });

    test('unrelated CloudException is also swallowed (not rethrown)', () async {
      final spy = _PresenceSpy()
        ..throws = const CloudException(
          code: CloudErrorCode.unknown,
          message: 'transient',
        );
      final tester = Notifier.test<PresenceHeartbeatService, HeartbeatState>(
        notifier: PresenceHeartbeatService(
          deps: _deps(spy: spy),
          supportedOverride: true,
        ),
      );

      tester.notifier.markBackground();
      await pumpEventQueue();
      expect(spy.calls, 1);
    });
  });
}
