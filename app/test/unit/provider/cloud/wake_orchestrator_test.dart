import 'dart:async';
import 'dart:typed_data';

import 'package:common/model/device.dart';
import 'package:common/model/file_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cross_file.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/wake_orchestrator.dart';
import 'package:refena_flutter/refena_flutter.dart';

const _kFingerprint = 'target-fp';
const _kSourceFingerprint = 'source-fp';
const _kTargetDeviceId = 'target-device';
const _kCurrentDeviceId = 'me';

CloudDevice _target({CloudDevicePresence presence = CloudDevicePresence.offline}) {
  return CloudDevice(
    deviceId: _kTargetDeviceId,
    displayName: 'Pixel',
    icon: CloudDeviceIcon.phone,
    fcmToken: null,
    platform: CloudDevicePlatform.android,
    lastSeenAtMs: 0,
    presence: presence,
    fingerprint: _kFingerprint,
  );
}

Device _lanMatch() {
  return Device(
    signalingId: null,
    ip: '192.168.1.10',
    version: '2.0',
    port: 53317,
    https: true,
    fingerprint: _kFingerprint,
    alias: 'Pixel (LAN)',
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: {const MulticastDiscovery()},
  );
}

class _FakeClient {
  Future<Map<String, dynamic>> Function(String, String, String)? sendWakeImpl;
  final List<Map<String, String>> sendWakeCalls = [];

  CloudFunctionsClient build() {
    return CloudFunctionsClient(
      invoker: (name, data) async {
        if (name == 'sendWake') {
          final map = (data as Map).cast<String, dynamic>();
          sendWakeCalls.add({
            'sourceDeviceId': map['sourceDeviceId'] as String,
            'targetDeviceId': map['targetDeviceId'] as String,
            'payload': map['payload'] as String,
          });
          if (sendWakeImpl != null) {
            return await sendWakeImpl!(
              map['sourceDeviceId'] as String,
              map['targetDeviceId'] as String,
              map['payload'] as String,
            );
          }
          return {'delivered': true, 'channel': 'fcm'};
        }
        throw UnimplementedError('Unhandled callable in spy: $name');
      },
    );
  }
}

class _StartSessionSpy {
  final List<({Device target, List<CrossFile> files, String wakeSessionId, bool background})> calls = [];
  Completer<void>? gate;

  Future<void> call({
    required Device target,
    required List<CrossFile> files,
    required String wakeSessionId,
    required bool background,
  }) async {
    calls.add((target: target, files: files, wakeSessionId: wakeSessionId, background: background));
    if (gate != null) {
      await gate!.future;
    }
  }
}

const Object _kUnsetSentinel = Object();

WakeOrchestrator _orchestrator({
  required _FakeClient client,
  required Stream<Iterable<Device>> stream,
  required _StartSessionSpy spy,
  AccountState? account,
  Object? groupKey = _kUnsetSentinel,
  String? sourceFingerprint = _kSourceFingerprint,
  Duration? timeoutDuration,
  DateTime Function()? clock,
}) {
  final accountState =
      account ??
      const AccountReady(
        accountId: 'acct',
        currentDeviceId: _kCurrentDeviceId,
        account: null,
        devices: [],
      );
  final resolvedKey = identical(groupKey, _kUnsetSentinel) ? Uint8List.fromList(List<int>.generate(32, (i) => i)) : groupKey as Uint8List?;
  return WakeOrchestrator(
    deps: WakeOrchestratorDeps(
      accountStateReader: () => accountState,
      groupKeyReader: () => resolvedKey,
      sourceFingerprintReader: () => sourceFingerprint,
      client: client.build,
      nearbyDevicesStream: () => stream,
      startSession: spy.call,
      clock: clock,
      timeoutDuration: timeoutDuration ?? const Duration(seconds: 60),
    ),
  );
}

CrossFile _file() {
  return CrossFile(
    name: 'note.txt',
    fileType: FileType.text,
    size: 4,
    bytes: Uint8List.fromList([0x68, 0x69, 0x21, 0x0a]),
    asset: null,
    path: null,
    thumbnail: null,
    lastModified: null,
    lastAccessed: null,
  );
}

void main() {
  group('WakeOrchestrator happy path', () {
    test('fires sendWake, waits for LAN match, then hands off to startSession', () async {
      final client = _FakeClient();
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(client: client, stream: controller.stream, spy: spy),
      );

      final startFuture = tester.notifier.start(target: _target(), files: [_file()]);
      await pumpEventQueue();

      expect(client.sendWakeCalls, hasLength(1));
      expect(client.sendWakeCalls.single['sourceDeviceId'], _kCurrentDeviceId);
      expect(client.sendWakeCalls.single['targetDeviceId'], _kTargetDeviceId);
      expect(client.sendWakeCalls.single['payload'], isNotEmpty);
      expect(tester.state[_kTargetDeviceId], isA<WakeStatusWaiting>());

      controller.add([_lanMatch()]);
      await startFuture;
      await pumpEventQueue();

      expect(tester.state.containsKey(_kTargetDeviceId), isFalse, reason: 'cleared after handoff');
      expect(spy.calls, hasLength(1));
      expect(spy.calls.single.target.fingerprint, _kFingerprint);
      expect(spy.calls.single.wakeSessionId, isNotEmpty);
      expect(spy.calls.single.background, isFalse);
      await controller.close();
    });
  });

  group('WakeOrchestrator timeout', () {
    test('emits a timed-out WakeStatusError when LAN never appears', () async {
      final client = _FakeClient();
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(
          client: client,
          stream: controller.stream,
          spy: spy,
          timeoutDuration: const Duration(milliseconds: 50),
        ),
      );

      await tester.notifier.start(target: _target(), files: [_file()]);
      // Let the timeout fire.
      await Future.delayed(const Duration(milliseconds: 120));

      final status = tester.state[_kTargetDeviceId];
      expect(status, isA<WakeStatusError>());
      expect((status! as WakeStatusError).timedOut, isTrue);
      expect((status as WakeStatusError).message, isNotEmpty);
      expect(spy.calls, isEmpty);
      await controller.close();
    });
  });

  group('WakeOrchestrator failure paths', () {
    test('CloudException from sendWake surfaces as WakeStatusError(timedOut=false)', () async {
      final client = _FakeClient()
        ..sendWakeImpl = (s, t, p) async {
          throw const CloudException(
            code: CloudErrorCode.resourceExhausted,
            message: 'Rate limit exceeded',
          );
        };
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(client: client, stream: controller.stream, spy: spy),
      );

      await tester.notifier.start(target: _target(), files: [_file()]);
      await pumpEventQueue();

      final status = tester.state[_kTargetDeviceId];
      expect(status, isA<WakeStatusError>());
      expect((status! as WakeStatusError).timedOut, isFalse);
      expect((status as WakeStatusError).message, contains('Rate limit'));
      await controller.close();
    });

    test('rejects when group key is missing', () async {
      final client = _FakeClient();
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(
          client: client,
          stream: controller.stream,
          spy: spy,
          groupKey: null,
        ),
      );

      await tester.notifier.start(target: _target(), files: [_file()]);

      expect(client.sendWakeCalls, isEmpty);
      expect(tester.state[_kTargetDeviceId], isA<WakeStatusError>());
      await controller.close();
    });

    test('rejects when target has no fingerprint', () async {
      final client = _FakeClient();
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(client: client, stream: controller.stream, spy: spy),
      );
      final fingerprintless = CloudDevice(
        deviceId: _kTargetDeviceId,
        displayName: 'Legacy',
        icon: CloudDeviceIcon.laptop,
        fcmToken: null,
        platform: CloudDevicePlatform.macos,
        lastSeenAtMs: 0,
        presence: CloudDevicePresence.offline,
        fingerprint: null,
      );

      await tester.notifier.start(target: fingerprintless, files: [_file()]);

      expect(client.sendWakeCalls, isEmpty);
      expect(tester.state[_kTargetDeviceId], isA<WakeStatusError>());
      await controller.close();
    });
  });

  group('WakeOrchestrator state utilities', () {
    test('clearError drops only error states', () async {
      final client = _FakeClient()
        ..sendWakeImpl = (s, t, p) async {
          throw const CloudException(code: CloudErrorCode.unknown, message: 'boom');
        };
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(client: client, stream: controller.stream, spy: spy),
      );

      await tester.notifier.start(target: _target(), files: [_file()]);
      await pumpEventQueue();
      expect(tester.state[_kTargetDeviceId], isA<WakeStatusError>());

      tester.notifier.clearError(_kTargetDeviceId);
      expect(tester.state.containsKey(_kTargetDeviceId), isFalse);
      await controller.close();
    });

    test('cancel removes pending state and stops the timeout', () async {
      final client = _FakeClient();
      final controller = StreamController<Iterable<Device>>.broadcast();
      final spy = _StartSessionSpy();
      final tester = Notifier.test<WakeOrchestrator, Map<String, WakeStatus>>(
        notifier: _orchestrator(
          client: client,
          stream: controller.stream,
          spy: spy,
          timeoutDuration: const Duration(milliseconds: 50),
        ),
      );

      await tester.notifier.start(target: _target(), files: [_file()]);
      await tester.notifier.cancel(_kTargetDeviceId);

      // Wait past the original timeout deadline; no error must appear.
      await Future.delayed(const Duration(milliseconds: 120));
      expect(tester.state.containsKey(_kTargetDeviceId), isFalse);
      await controller.close();
    });
  });
}
