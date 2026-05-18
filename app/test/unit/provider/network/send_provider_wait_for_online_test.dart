import 'dart:async';

import 'package:common/model/device.dart';
import 'package:common/model/file_type.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_account.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/delivery_channel.dart';
import 'package:magicshare_app/model/cloud/results/notify_transfer_intent_result.dart';
import 'package:magicshare_app/model/cross_file.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';
import 'package:magicshare_app/provider/network/send_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Tracks every call to `notifyTransferIntent` so assertions can verify
/// the recipient, kind, and call count.
class _RecordingFunctionsClient extends CloudFunctionsClient {
  _RecordingFunctionsClient() : super(invoker: (_, __) async => null);

  final List<({String sourceDeviceId, String targetDeviceId, NotifyTransferKind kind})> calls = [];

  @override
  Future<NotifyTransferIntentResult> notifyTransferIntent({
    required String sourceDeviceId,
    required String targetDeviceId,
    required NotifyTransferKind kind,
  }) async {
    calls.add((sourceDeviceId: sourceDeviceId, targetDeviceId: targetDeviceId, kind: kind));
    return const NotifyTransferIntentResult(delivered: true, channel: DeliveryChannel.fcm);
  }
}

/// Fake AccountRepository returning a fixed [AccountReady] without
/// attaching to Firestore / Auth.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository(this._initial)
    : super(
        deps: AccountRepositoryDeps(
          authStateReader: () => throw UnimplementedError(),
          authStateChanges: () => const Stream.empty(),
          deviceIdResolver: () async => '',
          cloudSyncEnabledReader: () => true,
        ),
        supportedOverride: false,
      );

  final AccountState _initial;

  @override
  AccountState init() => _initial;
}

Device _synthesizeCloudOnly(String alias) => Device(
  version: '',
  alias: alias,
  deviceModel: null,
  deviceType: DeviceType.desktop,
  download: false,
  endpoints: const {},
  discoveryMethods: const {},
);

CloudDevice _cloud({
  required String deviceId,
  required String fingerprint,
  String displayName = 'Cloud target',
}) {
  return CloudDevice(
    deviceId: deviceId,
    displayName: displayName,
    icon: CloudDeviceIcon.laptop,
    fcmToken: 'fcm-target',
    platform: CloudDevicePlatform.macos,
    fingerprint: fingerprint,
  );
}

MergedDevice _offlineGroupEntry({
  required String deviceId,
  required String fingerprint,
  String displayName = 'Cloud target',
}) {
  final cloud = _cloud(deviceId: deviceId, fingerprint: fingerprint, displayName: displayName);
  return MergedDevice(
    displayDevice: _synthesizeCloudOnly(displayName),
    cloud: cloud,
    isLanReachable: false,
  );
}

CrossFile _sampleFile({String name = 'photo.jpg', FileType type = FileType.image}) {
  return CrossFile(
    name: name,
    fileType: type,
    size: 1234,
    path: '/tmp/$name',
    bytes: null,
    thumbnail: null,
    asset: null,
    lastModified: null,
    lastAccessed: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SendNotifier.startSession — wait-for-online', () {
    late _RecordingFunctionsClient client;
    late RefenaContainer container;
    const ownDeviceId = 'own-device';
    const targetDeviceId = 'cloud-target';
    const fingerprint = 'fp-target';

    setUp(() {
      client = _RecordingFunctionsClient();
      container = RefenaContainer(
        overrides: [
          cloudFunctionsClientProvider.overrideWithBuilder((_) => client),
          accountRepositoryProvider.overrideWithNotifier(
            (_) => _FakeAccountRepository(
              const AccountReady(
                accountId: 'acct',
                currentDeviceId: ownDeviceId,
                account: CloudAccount(
                  accountId: 'acct',
                  createdAtMs: 0,
                  lastActiveAtMs: 0,
                  deviceCount: 1,
                ),
                devices: <CloudDevice>[],
              ),
            ),
          ),
          mergedNetworkDevicesProvider.overrideWithBuilder(
            (_) => [
              _offlineGroupEntry(deviceId: targetDeviceId, fingerprint: fingerprint),
            ],
          ),
        ],
      );
    });

    test('cloud-only target enters waitingForDevice and fires notifyTransferIntent', () async {
      final notifier = container.notifier(sendProvider);
      final target = _synthesizeCloudOnly('Cloud target');

      await notifier.startSession(
        target: target,
        files: [_sampleFile()],
        background: true,
        stableTargetId: targetDeviceId,
      );
      // Let the fire-and-forget notify call complete.
      await Future<void>.delayed(Duration.zero);

      final sessions = container.read(sendProvider).values.toList();
      expect(sessions, hasLength(1));
      final session = sessions.single;
      expect(session.status, SessionStatus.waitingForDevice);
      expect(session.stableTargetId, targetDeviceId);
      expect(session.waitDeadlineMs, isNotNull);
      expect(session.target.alias, 'Cloud target');

      expect(client.calls, hasLength(1));
      expect(client.calls.single.sourceDeviceId, ownDeviceId);
      expect(client.calls.single.targetDeviceId, targetDeviceId);
      expect(client.calls.single.kind, NotifyTransferKind.file);

      notifier.cancelWaitingSession(session.sessionId);
    });

    test('cancelWaitingSession removes the session', () async {
      final notifier = container.notifier(sendProvider);
      await notifier.startSession(
        target: _synthesizeCloudOnly('Cloud target'),
        files: [_sampleFile()],
        background: true,
        stableTargetId: targetDeviceId,
      );
      await Future<void>.delayed(Duration.zero);
      final sessionId = container.read(sendProvider).keys.single;

      notifier.cancelWaitingSession(sessionId);

      expect(container.read(sendProvider), isEmpty);
    });

    test('retryWaitingSession resets the deadline and fires another notify', () async {
      final notifier = container.notifier(sendProvider);
      await notifier.startSession(
        target: _synthesizeCloudOnly('Cloud target'),
        files: [_sampleFile()],
        background: true,
        stableTargetId: targetDeviceId,
      );
      await Future<void>.delayed(Duration.zero);
      final sessionId = container.read(sendProvider).keys.single;

      // Simulate the timer flipping the session into the timed-out state.
      final firstDeadline = container.read(sendProvider)[sessionId]!.waitDeadlineMs!;

      // Direct retry from the waiting state should be a no-op on the
      // session map (status stays waitingForDevice) but should re-fire
      // the notification and bump the deadline forward.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      notifier.retryWaitingSession(sessionId);
      await Future<void>.delayed(Duration.zero);

      final session = container.read(sendProvider)[sessionId]!;
      expect(session.status, SessionStatus.waitingForDevice);
      expect(session.waitDeadlineMs, greaterThanOrEqualTo(firstDeadline));
      expect(client.calls.length, 2);

      notifier.cancelWaitingSession(sessionId);
    });

    test('fires notifyTransferIntent for an online group device too', () async {
      // Override merged provider with an already-online entry (LAN
      // endpoint present + cloud row attached). startSession should
      // still fire the push — the spec is "every time on a group
      // device", not just on the offline branch.
      final lan = Device(
        version: '2.1',
        alias: 'Cloud target',
        deviceModel: null,
        deviceType: DeviceType.mobile,
        download: false,
        endpoints: {
          HttpEndpoint(
            ip: '192.168.1.20',
            port: 53317,
            https: true,
            certHash: 'fp',
          ),
        },
        discoveryMethods: {const MulticastDiscovery()},
      );
      container = RefenaContainer(
        overrides: [
          cloudFunctionsClientProvider.overrideWithBuilder((_) => client),
          accountRepositoryProvider.overrideWithNotifier(
            (_) => _FakeAccountRepository(
              const AccountReady(
                accountId: 'acct',
                currentDeviceId: ownDeviceId,
                account: CloudAccount(
                  accountId: 'acct',
                  createdAtMs: 0,
                  lastActiveAtMs: 0,
                  deviceCount: 1,
                ),
                devices: <CloudDevice>[],
              ),
            ),
          ),
          mergedNetworkDevicesProvider.overrideWithBuilder(
            (_) => [
              MergedDevice(
                displayDevice: lan,
                cloud: _cloud(deviceId: targetDeviceId, fingerprint: fingerprint),
                isLanReachable: true,
              ),
            ],
          ),
        ],
      );
      final notifier = container.notifier(sendProvider);

      // The full upload pipeline will run; we don't await it (the
      // routerino context push throws in unit tests), so we let the
      // fire-and-forget notify call complete and assert on its
      // record.
      try {
        await notifier.startSession(
          target: lan,
          files: [_sampleFile()],
          background: true,
          stableTargetId: targetDeviceId,
        );
      } catch (_) {
        /* upload pipeline may fail in unit tests; we only care about the notify */
      }
      await Future<void>.delayed(Duration.zero);

      expect(client.calls, hasLength(1));
      expect(client.calls.single.targetDeviceId, targetDeviceId);
    });

    test('aborts with finishedWithErrors when stableTargetId is missing', () async {
      final notifier = container.notifier(sendProvider);

      await notifier.startSession(
        target: _synthesizeCloudOnly('Cloud target'),
        files: [_sampleFile()],
        background: true,
        // Deliberately leave stableTargetId null — the wait path cannot
        // resolve a target without it.
      );
      await Future<void>.delayed(Duration.zero);

      final session = container.read(sendProvider).values.single;
      expect(session.status, SessionStatus.finishedWithErrors);
      expect(session.errorMessage, contains('Cannot reach'));
      expect(client.calls, isEmpty);
    });

    test('skips notifyTransferIntent when no group account is ready', () async {
      // Rebuild container with AccountIdle.
      container = RefenaContainer(
        overrides: [
          cloudFunctionsClientProvider.overrideWithBuilder((_) => client),
          accountRepositoryProvider.overrideWithNotifier(
            (_) => _FakeAccountRepository(const AccountIdle()),
          ),
          mergedNetworkDevicesProvider.overrideWithBuilder(
            (_) => [
              _offlineGroupEntry(deviceId: targetDeviceId, fingerprint: fingerprint),
            ],
          ),
        ],
      );
      final notifier = container.notifier(sendProvider);

      await notifier.startSession(
        target: _synthesizeCloudOnly('Cloud target'),
        files: [_sampleFile()],
        background: true,
        stableTargetId: targetDeviceId,
      );
      await Future<void>.delayed(Duration.zero);

      // The session still enters waitingForDevice — only the push fails
      // silently. This is intentional: the receiver may still come
      // online via LAN multicast.
      final session = container.read(sendProvider).values.single;
      expect(session.status, SessionStatus.waitingForDevice);
      expect(client.calls, isEmpty);

      notifier.cancelWaitingSession(session.sessionId);
    });
  });
}
