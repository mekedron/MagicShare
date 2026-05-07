import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';

Device _http({
  String alias = 'Pixel',
  String ip = '192.168.1.5',
  String certHash = 'cert-hash-A',
}) {
  return Device(
    version: '2.0',
    alias: alias,
    deviceModel: 'Pixel',
    deviceType: DeviceType.mobile,
    download: false,
    endpoints: {
      HttpEndpoint(ip: ip, port: 53317, https: true, certHash: certHash),
    },
    discoveryMethods: {const MulticastDiscovery()},
  );
}

Device _signaling({
  String alias = 'Pixel',
  String signalingId = 'uuid-A',
  String serverToken = 'token-A',
  String server = 'wss://public.localsend.org/v1/ws',
}) {
  return Device(
    version: '2.0',
    alias: alias,
    deviceModel: 'Pixel',
    deviceType: DeviceType.mobile,
    download: false,
    endpoints: {
      SignalingEndpoint(
        signalingId: signalingId,
        signalingServer: server,
        serverToken: serverToken,
      ),
    },
    discoveryMethods: {SignalingDiscovery(signalingServer: server)},
  );
}

void main() {
  group('Device endpoint helpers', () {
    test('certHashes contains every HttpEndpoint cert hash, not signaling tokens', () {
      final device = Device(
        version: '2.0',
        alias: 'Multi',
        deviceModel: null,
        deviceType: DeviceType.mobile,
        download: false,
        endpoints: {
          HttpEndpoint(ip: '192.168.1.5', port: 53317, https: true, certHash: 'cert-A'),
          HttpEndpoint(ip: '10.0.0.5', port: 53317, https: true, certHash: 'cert-B'),
          SignalingEndpoint(
            signalingId: 'uuid',
            signalingServer: 'wss://public.localsend.org/v1/ws',
            serverToken: 'tok-X',
          ),
        },
        discoveryMethods: const {},
      );
      expect(device.certHashes, {'cert-A', 'cert-B'});
      expect(device.certHashes.contains('tok-X'), isFalse, reason: 'serverToken must NOT appear in certHashes');
    });

    test('hasHttpEndpoint / hasSignalingEndpoint reflect endpoint presence', () {
      expect(_http().hasHttpEndpoint, isTrue);
      expect(_http().hasSignalingEndpoint, isFalse);
      expect(_signaling().hasHttpEndpoint, isFalse);
      expect(_signaling().hasSignalingEndpoint, isTrue);
    });

    test('transmissionMethods reflects active channels', () {
      expect(_http().transmissionMethods, {TransmissionMethod.http});
      expect(_signaling().transmissionMethods, {TransmissionMethod.webrtc});
      // Multi-endpoint device — both methods reported.
      final both = _http().merge(_signaling());
      expect(both.transmissionMethods, {TransmissionMethod.http, TransmissionMethod.webrtc});
    });

    test('Device.empty has no endpoints and no transmission methods', () {
      expect(Device.empty.hasAnyEndpoint, isFalse);
      expect(Device.empty.transmissionMethods, isEmpty);
      expect(Device.empty.certHashes, isEmpty);
    });
  });

  group('Device.merge losslessness', () {
    test('HTTP first, signaling second: result carries both endpoints', () {
      final merged = _http(certHash: 'cert-X').merge(_signaling(serverToken: 'tok-X'));
      expect(merged.endpoints.length, 2);
      expect(merged.firstHttpEndpoint?.certHash, 'cert-X');
      expect(merged.firstSignalingEndpoint?.serverToken, 'tok-X');
    });

    test('signaling first, HTTP second: result carries both endpoints (order independent)', () {
      final merged = _signaling(serverToken: 'tok-X').merge(_http(certHash: 'cert-X'));
      expect(merged.endpoints.length, 2);
      expect(merged.firstHttpEndpoint?.certHash, 'cert-X');
      expect(merged.firstSignalingEndpoint?.serverToken, 'tok-X');
    });

    test('merge unions discoveryMethods', () {
      final merged = _http().merge(_signaling());
      expect(
        merged.discoveryMethods,
        containsAll([
          const MulticastDiscovery(),
          const SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
        ]),
      );
    });

    test('merge of two HTTP devices on different IPs preserves both endpoints', () {
      // Multi-homed scenario (laptop with WiFi + Ethernet).
      final wifi = _http(ip: '192.168.1.5', certHash: 'cert-shared');
      final eth = _http(ip: '10.0.0.5', certHash: 'cert-shared');
      final merged = wifi.merge(eth);
      // Both endpoints kept — the Set is keyed on equality, and the
      // two HttpEndpoints differ in `ip` so they're distinct elements.
      expect(merged.endpoints.length, 2);
      expect(merged.httpEndpoints.map((e) => e.ip), containsAll(['192.168.1.5', '10.0.0.5']));
    });

    test('idempotent: merging the same device twice does not double endpoints', () {
      // HttpEndpoint equality is value-based via dart_mappable, so the
      // second copy of an identical endpoint should fold away.
      final device = _http(ip: '192.168.1.5', certHash: 'cert-X');
      final merged = device.merge(device);
      expect(merged.endpoints.length, 1);
    });
  });
}
