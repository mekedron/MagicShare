import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';

void main() {
  group('NearbyDevicesState.allDevices', () {
    test(
      'merges LAN HttpEndpoint + signaling SignalingEndpoint for the same '
      'physical device when cert hash and server token differ but identity tuple matches',
      () {
        // The HttpEndpoint carries the HTTPS cert hash; the
        // SignalingEndpoint carries a token from the public signaling
        // server. Both identify the same iPhone but never match by
        // identifier value (different value spaces). The user-visible
        // identity (alias + deviceModel + deviceType) is identical
        // across both, so the merge must collapse them — and the
        // merged Device must carry BOTH endpoints losslessly.
        const lanCertHash = 'D82CAAA7211A76696E477DDE3338FAAF33CB91192C7C54559F03A8CD774BB370';
        const signalingToken = 'sha256.W2Hv8KFnciu8zzxBc1FlwPOvPemZ_re14ZgerAFgadE';

        final lanDevice = Device(
          version: '2.1',
          alias: 'Wise Mushroom',
          deviceModel: 'iPhone',
          deviceType: DeviceType.mobile,
          download: false,
          endpoints: {
            HttpEndpoint(
              ip: '192.168.101.109',
              port: 53317,
              https: true,
              certHash: lanCertHash,
            ),
          },
          discoveryMethods: {HttpDiscovery(ip: '192.168.101.109')},
        );
        final signalingDevice = Device(
          version: '2.1',
          alias: 'Wise Mushroom',
          deviceModel: 'iPhone',
          deviceType: DeviceType.mobile,
          download: false,
          endpoints: {
            SignalingEndpoint(
              signalingId: 'ea602544-df2e-4917-adca-2e88588a764d',
              signalingServer: 'wss://public.localsend.org/v1/ws',
              serverToken: signalingToken,
            ),
          },
          discoveryMethods: {
            SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
          },
        );

        final state = NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: const {},
          devices: {'192.168.101.109': lanDevice},
          signalingDevices: {
            signalingToken: {signalingDevice},
          },
        );

        expect(
          state.allDevices.length,
          1,
          reason: 'Same physical device must collapse to a single entry',
        );
        final merged = state.allDevices.values.single;
        expect(merged.alias, 'Wise Mushroom');
        // LAN-side reachability is preserved.
        expect(merged.firstHttpEndpoint?.ip, '192.168.101.109');
        expect(merged.firstHttpEndpoint?.certHash, lanCertHash);
        // Signaling-side identity is preserved — losslessly.
        expect(merged.firstSignalingEndpoint?.signalingId, 'ea602544-df2e-4917-adca-2e88588a764d');
        expect(merged.firstSignalingEndpoint?.serverToken, signalingToken);
        // Both endpoints survive the union.
        expect(merged.endpoints.length, 2);
        expect(merged.hasHttpEndpoint, isTrue);
        expect(merged.hasSignalingEndpoint, isTrue);
        // Discovery methods union — both transports are tracked.
        expect(merged.discoveryMethods, {
          const HttpDiscovery(ip: '192.168.101.109'),
          const SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
        });
      },
    );

    test('keeps two separate entries when alias differs', () {
      // Two genuinely different devices on the network — alias and
      // deviceModel disagree, so the merge must NOT collapse them.
      final iphone = Device(
        version: '2.1',
        alias: 'Wise Mushroom',
        deviceModel: 'iPhone',
        deviceType: DeviceType.mobile,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'fp-iphone'),
        },
        discoveryMethods: {HttpDiscovery(ip: '192.168.1.5')},
      );
      final pixel = Device(
        version: '2.1',
        alias: 'Funny Apple',
        deviceModel: 'Pixel 7',
        deviceType: DeviceType.mobile,
        download: false,
        endpoints: {
          SignalingEndpoint(
            signalingId: 'pixel-signaling-id',
            signalingServer: 'wss://public.localsend.org/v1/ws',
            serverToken: 'fp-pixel',
          ),
        },
        discoveryMethods: {
          SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
        },
      );

      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {'192.168.1.5': iphone},
        signalingDevices: {
          'fp-pixel': {pixel},
        },
      );

      expect(state.allDevices.length, 2);
    });

    test('collapses multi-homed LAN entries that share a cert hash', () {
      // A macOS device on WiFi (en0) AND Ethernet (en1) sends a
      // multicast announce from each interface. Each announce has a
      // different IP but the SAME cert hash (it's the same physical
      // device). `state.devices` is keyed by IP so both entries land
      // there. `allDevices` must collapse them by cert-hash match —
      // otherwise the Send tab on the receiving side renders the
      // same MacBook as two separate tiles.
      final wifi = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'shared-cert-hash'),
        },
        discoveryMethods: {HttpDiscovery(ip: '192.168.1.5')},
      );
      final ethernet = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '10.0.0.5', port: 53317, https: true, certHash: 'shared-cert-hash'),
        },
        discoveryMethods: {HttpDiscovery(ip: '10.0.0.5')},
      );

      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {
          '192.168.1.5': wifi,
          '10.0.0.5': ethernet,
        },
        signalingDevices: const {},
      );

      expect(state.allDevices.length, 1, reason: 'multi-homed must collapse by cert hash');
      final merged = state.allDevices.values.single;
      expect(merged.alias, 'Timetravels MacBook');
      expect(merged.httpEndpoints.length, 2);
      expect(merged.httpEndpoints.map((e) => e.ip), containsAll(['192.168.1.5', '10.0.0.5']));
    });

    test('collapses multi-homed LAN AND merges signaling on top', () {
      // Real-world reproduction of the duplicate-tile bug: multicast
      // announces from 2 interfaces + 1 signaling-server entry, all
      // for the same physical macOS device. Result must be ONE Device
      // with 2 HttpEndpoints and 1 SignalingEndpoint.
      final wifi = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'cert-X'),
        },
        discoveryMethods: {HttpDiscovery(ip: '192.168.1.5')},
      );
      final ethernet = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '10.0.0.5', port: 53317, https: true, certHash: 'cert-X'),
        },
        discoveryMethods: {HttpDiscovery(ip: '10.0.0.5')},
      );
      final signaling = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          SignalingEndpoint(
            signalingId: 'sig-uuid',
            signalingServer: 'wss://public.localsend.org/v1/ws',
            serverToken: 'token-Y',
          ),
        },
        discoveryMethods: {SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws')},
      );

      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {
          '192.168.1.5': wifi,
          '10.0.0.5': ethernet,
        },
        signalingDevices: {
          'token-Y': {signaling},
        },
      );

      expect(state.allDevices.length, 1, reason: 'multi-homed + signaling all collapse to one');
      final merged = state.allDevices.values.single;
      expect(merged.httpEndpoints.length, 2);
      expect(merged.signalingEndpoints.length, 1);
      expect(merged.transmissionMethods, {TransmissionMethod.http, TransmissionMethod.webrtc});
    });

    test('keeps two separate entries when LAN devices have different cert hashes', () {
      // Sanity check: distinct cert hashes = distinct physical
      // devices, even if other fields happen to match. Don't
      // over-merge.
      final a = Device(
        version: '2.1',
        alias: 'MacBook A',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'cert-A'),
        },
        discoveryMethods: {HttpDiscovery(ip: '192.168.1.5')},
      );
      final b = Device(
        version: '2.1',
        alias: 'MacBook B',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.6', port: 53317, https: true, certHash: 'cert-B'),
        },
        discoveryMethods: {HttpDiscovery(ip: '192.168.1.6')},
      );
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {'192.168.1.5': a, '192.168.1.6': b},
        signalingDevices: const {},
      );
      expect(state.allDevices.length, 2);
    });

    test('reproduction: macOS multi-homed (en0+awdl0) MacBook does not show twice', () {
      // The exact scenario from the iPhone screenshot bug report:
      // Timetravels MacBook is on the LAN announcing from BOTH en0
      // (WiFi) and awdl0 (AirDrop). Each interface produces a
      // separate multicast announce — same alias, same cert hash,
      // different source IP. Without cert-hash collapse, the iPhone
      // renders TWO "Timetravels MacBook" tiles (visible in the
      // screenshot).
      const certHash = 'D82CAAA7211A76696E477DDE3338FAAF33CB91192C7C54559F03A8CD774BB370';
      final wifi = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: certHash)},
        discoveryMethods: {const HttpDiscovery(ip: '192.168.1.5')},
      );
      final awdl = Device(
        version: '2.1',
        alias: 'Timetravels MacBook',
        deviceModel: 'macOS',
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {HttpEndpoint(ip: '169.254.123.45', port: 53317, https: true, certHash: certHash)},
        discoveryMethods: {const HttpDiscovery(ip: '169.254.123.45')},
      );
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {'192.168.1.5': wifi, '169.254.123.45': awdl},
        signalingDevices: const {},
      );
      expect(state.allDevices.length, 1, reason: 'one MacBook, one tile');
      final merged = state.allDevices.values.single;
      expect(merged.httpEndpoints.length, 2);
    });

    test('does not merge across devices whose alias is empty', () {
      // Identity-tuple fallback explicitly skips empty aliases so an
      // unannounced device doesn't fold into another unannounced one.
      final lanDevice = Device(
        version: '2.1',
        alias: '',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'fp-lan'),
        },
        discoveryMethods: {HttpDiscovery(ip: '192.168.1.5')},
      );
      final signalingDevice = Device(
        version: '2.1',
        alias: '',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          SignalingEndpoint(
            signalingId: 'sig',
            signalingServer: 'wss://public.localsend.org/v1/ws',
            serverToken: 'fp-signaling',
          ),
        },
        discoveryMethods: {
          SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
        },
      );

      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {'192.168.1.5': lanDevice},
        signalingDevices: {
          'fp-signaling': {signalingDevice},
        },
      );

      expect(state.allDevices.length, 2);
    });
  });
}
