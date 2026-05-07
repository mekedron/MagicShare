import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';
import 'package:magicshare_app/cloud/pairing/pairing_join_service.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_client.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/join_token_preview.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:magicshare_app/model/cloud/results/join_network_result.dart';
import 'package:magicshare_app/model/cloud/results/preview_join_token_result.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';
import 'package:pointycastle/ecc/api.dart' show ECPrivateKey, ECPublicKey;
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  late _StubCloudFunctionsClient client;
  late _FakeAuthGateway authGateway;
  late GroupKeyService groupKeyService;
  late DeviceIdentityService deviceIdentityService;
  late _StubLanClient lanClient;
  late _ProbeRecorder probe;

  late RefenaContainer container;

  setUp(() {
    client = _StubCloudFunctionsClient();
    authGateway = _FakeAuthGateway();
    final groupKeyProviderForTest = NotifierProvider<GroupKeyService, GroupKeyState>((ref) {
      return GroupKeyService(
        storage: SecureStorageService(gateway: _inMemoryStorageGateway()),
        clearDeviceId: () async {},
      );
    });
    container = RefenaContainer();
    groupKeyService = container.notifier(groupKeyProviderForTest);
    deviceIdentityService = DeviceIdentityService(
      storage: DeviceIdStorage(
        read: () => 'fake-device-id',
        write: (_) async {},
      ),
      aliasReader: () => 'Test alias',
      deviceIdGenerator: () => 'fake-device-id',
    );
    lanClient = _StubLanClient();
    probe = _ProbeRecorder();
  });

  // RefenaContainer cleans up on GC; explicit teardown is unnecessary
  // and the per-provider `dispose(provider)` API isn't a fit here.

  PairingJoinService buildService() {
    return PairingJoinService(
      cloudFunctionsClient: client,
      authGateway: authGateway.gateway,
      groupKeyService: groupKeyService,
      deviceIdentityService: deviceIdentityService,
      lanClient: lanClient,
      lanReachabilityProbe: probe.probe,
    );
  }

  PairingPayload samplePayload({
    List<String> addresses = const ['192.168.1.10'],
  }) {
    return PairingPayload(
      tokenId: 'fixture-token',
      issuerLanAddresses: addresses,
      issuerLanPort: 50001,
      issuerPubKeyCompressed: compressPublicKey(generatePairingKeyPair().publicKey),
    );
  }

  group('previewPairing', () {
    test('returns LanUnreachable when probe finds no reachable host', () async {
      probe.reachableHosts = const {};

      final outcome = await buildService().previewPairing(payload: samplePayload());

      expect(outcome, isA<PairingPreviewLanUnreachable>());
      expect(client.previewCalls, isEmpty);
    });

    test('returns Success with the winning host when reachable', () async {
      probe.reachableHosts = {'192.168.1.10'};
      client.previewResponse = PreviewJoinTokenResult(
        accountId: 'target-acct',
        issuingDeviceId: 'issuer-device',
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60_000,
        devices: const [],
      );

      final outcome = await buildService().previewPairing(payload: samplePayload());

      expect(outcome, isA<PairingPreviewSuccess>());
      final success = outcome as PairingPreviewSuccess;
      expect(success.preview.accountId, 'target-acct');
      expect(success.reachableHost, '192.168.1.10');
      expect(client.previewCalls.single, 'fixture-token');
    });

    test('races multi-address payload and returns the reachable one', () async {
      // Simulate the run-dev.sh setup: macOS issuer advertises both
      // 127.0.0.1 (for an Android-emulator joiner via adb reverse)
      // and the real LAN IP (for a physical-device joiner). The
      // physical iPhone joiner can only reach the LAN IP.
      probe.reachableHosts = {'192.168.101.129'};
      client.previewResponse = PreviewJoinTokenResult(
        accountId: 'target-acct',
        issuingDeviceId: 'issuer-device',
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60_000,
        devices: const [],
      );

      final outcome = await buildService().previewPairing(
        payload: samplePayload(addresses: const ['127.0.0.1', '192.168.101.129']),
      );

      expect(outcome, isA<PairingPreviewSuccess>());
      expect((outcome as PairingPreviewSuccess).reachableHost, '192.168.101.129');
    });

    test('classifies notFound from previewJoinToken', () async {
      probe.reachableHosts = {'192.168.1.10'};
      client.previewThrows = CloudException(
        code: CloudErrorCode.notFound,
        message: 'gone',
      );

      final outcome = await buildService().previewPairing(payload: samplePayload());

      expect(
        outcome,
        isA<PairingPreviewCloudFailure>().having(
          (o) => o.reason,
          'reason',
          PairingCloudFailureReason.notFound,
        ),
      );
    });
  });

  group('completePairing', () {
    test('happy path: signs in if needed, joins, exchanges key, replaces, re-auths', () async {
      authGateway.startsSignedIn = false;
      probe.reachableHosts = {'192.168.1.10'};
      client.joinResponse = JoinNetworkResult(
        accountId: 'target-acct',
        oldAccountDeleted: false,
        devices: const [],
        customToken: 'fake-custom-token',
      );
      lanClient.exchangeResponse = generateGroupKey();

      final outcome = await buildService().completePairing(
        payload: samplePayload(),
        reachableHost: '192.168.1.10',
        newDeviceIdentity: const JoinNetworkNewDevice(
          displayName: 'Test',
          icon: CloudDeviceIcon.laptop,
          platform: CloudDevicePlatform.macos,
          fcmToken: null,
        ),
      );

      expect(outcome, isA<PairingCompleteSuccess>());
      expect((outcome as PairingCompleteSuccess).newAccountId, 'target-acct');

      expect(authGateway.signInAnonymouslyCalls, 1);
      expect(client.joinCalls.single.tokenId, 'fixture-token');
      expect(client.joinCalls.single.deviceId, 'fake-device-id');
      expect(client.joinCalls.single.newDevice?.displayName, 'Test');
      expect(lanClient.exchangeCalls, hasLength(1));
      expect(lanClient.exchangeCalls.single.issuerHost, '192.168.1.10');
      expect(authGateway.signInWithCustomTokenCalls.single, 'fake-custom-token');
      // Group key landed in storage.
      final keyState = groupKeyService.state;
      expect(keyState, isA<GroupKeyReady>());
      expect((keyState as GroupKeyReady).key, lanClient.exchangeResponse);
    });

    test('uses the preview-time winner for the handshake (not the first listed address)', () async {
      // The QR carries [127.0.0.1, 192.168.101.129]. Preview already
      // determined 192.168.101.129 was the reachable one. complete
      // must hit that exact host — never blindly pick the first.
      authGateway.startsSignedIn = true;
      probe.reachableHosts = {'192.168.101.129'};
      client.joinResponse = JoinNetworkResult(
        accountId: 'target-acct',
        oldAccountDeleted: false,
        devices: const [],
        customToken: 'fake-custom-token',
      );
      lanClient.exchangeResponse = generateGroupKey();

      await buildService().completePairing(
        payload: samplePayload(addresses: const ['127.0.0.1', '192.168.101.129']),
        reachableHost: '192.168.101.129',
      );

      expect(lanClient.exchangeCalls.single.issuerHost, '192.168.101.129');
    });

    test('re-races the addresses when reachableHost is omitted', () async {
      authGateway.startsSignedIn = true;
      probe.reachableHosts = {'192.168.101.129'};
      client.joinResponse = JoinNetworkResult(
        accountId: 'target-acct',
        oldAccountDeleted: false,
        devices: const [],
        customToken: 'fake-custom-token',
      );
      lanClient.exchangeResponse = generateGroupKey();

      final outcome = await buildService().completePairing(
        payload: samplePayload(addresses: const ['127.0.0.1', '192.168.101.129']),
      );

      expect(outcome, isA<PairingCompleteSuccess>());
      expect(lanClient.exchangeCalls.single.issuerHost, '192.168.101.129');
    });

    test('returns LanHandshakeFailure(transport) when no address is reachable on complete', () async {
      authGateway.startsSignedIn = true;
      probe.reachableHosts = const {};

      final outcome = await buildService().completePairing(
        payload: samplePayload(addresses: const ['127.0.0.1']),
      );

      expect(
        outcome,
        isA<PairingCompleteLanHandshakeFailure>().having(
          (o) => o.error,
          'error',
          PairingLanClientError.transport,
        ),
      );
      expect(client.joinCalls, isEmpty);
    });

    test('returns CloudFailure on joinNetwork error', () async {
      authGateway.startsSignedIn = true;
      probe.reachableHosts = {'192.168.1.10'};
      client.joinThrows = CloudException(
        code: CloudErrorCode.failedPrecondition,
        message: 'expired',
      );

      final outcome = await buildService().completePairing(
        payload: samplePayload(),
        reachableHost: '192.168.1.10',
      );

      expect(
        outcome,
        isA<PairingCompleteCloudFailure>().having(
          (o) => o.reason,
          'reason',
          PairingCloudFailureReason.expiredOrConsumed,
        ),
      );
      expect(lanClient.exchangeCalls, isEmpty);
      expect(authGateway.signInWithCustomTokenCalls, isEmpty);
    });

    test('returns LanHandshakeFailure when LAN client throws', () async {
      authGateway.startsSignedIn = true;
      probe.reachableHosts = {'192.168.1.10'};
      client.joinResponse = JoinNetworkResult(
        accountId: 'target-acct',
        oldAccountDeleted: false,
        devices: const [],
        customToken: 'fake-custom-token',
      );
      lanClient.exchangeThrows = PairingLanClientException(
        PairingLanClientError.cryptoAuth,
        'tag mismatch',
      );

      final outcome = await buildService().completePairing(
        payload: samplePayload(),
        reachableHost: '192.168.1.10',
      );

      expect(
        outcome,
        isA<PairingCompleteLanHandshakeFailure>().having(
          (o) => o.error,
          'error',
          PairingLanClientError.cryptoAuth,
        ),
      );
      // Crucially: the group key must NOT be installed and re-auth
      // must NOT happen if the handshake failed.
      expect(groupKeyService.state, isA<GroupKeyMissing>());
      expect(authGateway.signInWithCustomTokenCalls, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _StubCloudFunctionsClient extends CloudFunctionsClient {
  _StubCloudFunctionsClient() : super(invoker: _alwaysThrows);

  PreviewJoinTokenResult? previewResponse;
  CloudException? previewThrows;
  JoinNetworkResult? joinResponse;
  CloudException? joinThrows;

  final List<String> previewCalls = [];
  final List<({String tokenId, String deviceId, JoinNetworkNewDevice? newDevice})> joinCalls = [];

  @override
  Future<PreviewJoinTokenResult> previewJoinToken({required String tokenId}) async {
    previewCalls.add(tokenId);
    if (previewThrows != null) throw previewThrows!;
    return previewResponse ??
        PreviewJoinTokenResult(
          accountId: 'default',
          issuingDeviceId: 'default',
          expiresAtMs: 0,
          devices: const <JoinTokenPreviewDevice>[],
        );
  }

  @override
  Future<JoinNetworkResult> joinNetwork({
    required String tokenId,
    required String deviceId,
    JoinNetworkNewDevice? newDevice,
  }) async {
    joinCalls.add((tokenId: tokenId, deviceId: deviceId, newDevice: newDevice));
    if (joinThrows != null) throw joinThrows!;
    return joinResponse ??
        JoinNetworkResult(
          accountId: 'default',
          oldAccountDeleted: false,
          devices: const <JoinTokenPreviewDevice>[],
          customToken: 'default-token',
        );
  }

  static Future<Object?> _alwaysThrows(String name, Object? data) async {
    throw StateError('fake invoker not used in this test');
  }
}

class _FakeAuthGateway {
  bool startsSignedIn = false;
  String currentUid = 'pre-pair-uid';
  int signInAnonymouslyCalls = 0;
  int deleteCallCount = 0;
  final List<String> signInWithCustomTokenCalls = [];

  late final CloudAuthGateway gateway = CloudAuthGateway(
    userIdChanges: () => const Stream<String?>.empty(),
    signInAnonymously: () async {
      signInAnonymouslyCalls++;
      currentUid = 'anon-uid-after-signin';
      startsSignedIn = true;
      return currentUid;
    },
    currentUserId: () => startsSignedIn ? currentUid : null,
    deleteCurrentUser: () async {
      deleteCallCount++;
    },
    signOut: () async {},
    signInWithCustomToken: (token) async {
      signInWithCustomTokenCalls.add(token);
      return 'post-pair-uid';
    },
  );
}

class _StubLanClient extends PairingLanClient {
  _StubLanClient();

  Uint8List? exchangeResponse;
  PairingLanClientException? exchangeThrows;
  final List<({String issuerHost, int issuerPort, String tokenId})> exchangeCalls = [];

  @override
  Future<Uint8List> exchangeKey({
    required String issuerHost,
    required int issuerPort,
    required String tokenId,
    required ECPrivateKey joinerPrivateKey,
    required ECPublicKey joinerPublicKey,
    required ECPublicKey issuerPublicKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    exchangeCalls.add((issuerHost: issuerHost, issuerPort: issuerPort, tokenId: tokenId));
    if (exchangeThrows != null) throw exchangeThrows!;
    return exchangeResponse ?? generateGroupKey();
  }
}

class _ProbeRecorder {
  /// Hosts the probe should report as reachable. The first entry of
  /// the requested `hosts` iterable that's in this set wins. An
  /// empty set means "no host is reachable".
  Set<String> reachableHosts = const {};

  Future<String?> probe({
    required Iterable<String> hosts,
    required int port,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    for (final host in hosts) {
      if (reachableHosts.contains(host)) return host;
    }
    return null;
  }
}

SecureStorageGateway _inMemoryStorageGateway() {
  final memory = <String, String>{};
  return SecureStorageGateway(
    read: (key) async => memory[key],
    write: (key, value) async => memory[key] = value,
    delete: (key) async => memory.remove(key),
  );
}
