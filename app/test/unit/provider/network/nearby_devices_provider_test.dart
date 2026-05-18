import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../../mocks.mocks.dart';

void main() {
  group('RegisterSignalingDeviceAction', () {
    const signalingServer = 'wss://public.localsend.org/v1/ws';
    const remoteToken = 'sha256.i6yGOOf8jT2aQHUavrHFlp4FWrcZzPStAnPJmg86kQI';
    const remoteSignalingId = '238fcb2b-1c21-4b5c-9238-96710718ff25';
    const ownToken = 'sha256.6zBrAfmjGdLc2QQkiIDM0DzbMMYR28e0xLHD25r6QS4';
    const ownSignalingId = '588ffd01-7ee5-402d-b409-e027d0358204';

    NearbyDevicesService buildService() => NearbyDevicesService(
      isolateController: MockIsolateController(),
      favoriteService: MockFavoritesService(),
      discoveryLogs: MockDiscoveryLogger(),
      httpsReader: () => true,
      activeIpsReader: () => const <String>{},
    );

    Device buildSignalingDevice({
      required String alias,
      required String signalingId,
      required String serverToken,
    }) {
      return Device(
        version: '2.1',
        alias: alias,
        deviceModel: alias,
        deviceType: DeviceType.mobile,
        download: false,
        endpoints: {
          SignalingEndpoint(
            signalingId: signalingId,
            signalingServer: signalingServer,
            serverToken: serverToken,
          ),
        },
        discoveryMethods: {
          SignalingDiscovery(signalingServer: signalingServer),
        },
      );
    }

    test('Registers a remote signaling device when localIdentities is empty', () {
      final service = ReduxNotifier.test(redux: buildService());

      service.dispatch(
        RegisterSignalingDeviceAction(
          buildSignalingDevice(
            alias: 'iPhone',
            signalingId: remoteSignalingId,
            serverToken: remoteToken,
          ),
        ),
      );

      expect(service.state.signalingDevices.keys, contains(remoteToken));
      expect(
        service.state.signalingDevices[remoteToken]?.single.alias,
        'iPhone',
      );
    });

    test('Drops a device whose serverToken matches a local identity', () {
      // Mirrors the bug: a second connection's hello echoes the new
      // ClientInfo (id=ownSignalingId, token=ownToken) back as a peer,
      // and we must not register it as a remote device.
      final service = ReduxNotifier.test(redux: buildService());

      service.dispatch(
        RegisterSignalingDeviceAction(
          buildSignalingDevice(
            alias: 'Timetravels MacBook',
            signalingId: ownSignalingId,
            serverToken: ownToken,
          ),
          localIdentities: const {ownSignalingId, ownToken},
        ),
      );

      expect(service.state.signalingDevices, isEmpty);
    });

    test('Drops a device whose signalingId matches a local identity even if token differs', () {
      // Defense-in-depth: same signalingId on a different token (rare
      // but possible mid-rotation) should still be filtered.
      final service = ReduxNotifier.test(redux: buildService());

      service.dispatch(
        RegisterSignalingDeviceAction(
          buildSignalingDevice(
            alias: 'Timetravels MacBook',
            signalingId: ownSignalingId,
            serverToken: 'sha256.totally-different-token',
          ),
          localIdentities: const {ownSignalingId},
        ),
      );

      expect(service.state.signalingDevices, isEmpty);
    });

    test('Still registers remote devices when local identities are tracked', () {
      // Filter must be precise: only drop matching entries, not the whole batch.
      final service = ReduxNotifier.test(redux: buildService());

      service.dispatch(
        RegisterSignalingDeviceAction(
          buildSignalingDevice(
            alias: 'Timetravels MacBook',
            signalingId: ownSignalingId,
            serverToken: ownToken,
          ),
          localIdentities: const {ownSignalingId, ownToken},
        ),
      );
      service.dispatch(
        RegisterSignalingDeviceAction(
          buildSignalingDevice(
            alias: 'iPhone',
            signalingId: remoteSignalingId,
            serverToken: remoteToken,
          ),
          localIdentities: const {ownSignalingId, ownToken},
        ),
      );

      expect(service.state.signalingDevices.keys, [remoteToken]);
      expect(
        service.state.signalingDevices[remoteToken]?.single.alias,
        'iPhone',
      );
    });
  });
}
