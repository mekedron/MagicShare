import 'package:common/model/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';

Device _multicastPeer({
  required String fingerprint,
  String alias = 'Solid Lemon',
  String ip = '10.0.2.16',
  int port = 53317,
}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: '2.0',
    port: port,
    https: true,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: {const MulticastDiscovery()},
  );
}

Device _signalingPeer({
  required String fingerprint,
  String alias = 'Solid Lemon',
  String signalingId = 'sig-1',
  String signalingServer = 'wss://example.invalid',
}) {
  return Device(
    signalingId: signalingId,
    ip: null,
    version: '2.0',
    port: -1,
    https: false,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: {SignalingDiscovery(signalingServer: signalingServer)},
  );
}

void main() {
  group('NearbyDevicesState.allDevices', () {
    test('dedups a device discovered via multicast and signaling into a single entry', () {
      // Reproduction of the hot-restart duplicate-tile bug. Pre-fix
      // the getter `addAll`-ed the IP-keyed multicast map then wrote
      // the signaling entry under a fingerprint key, so iterating
      // `.values` returned the same physical device twice.
      final lan = _multicastPeer(fingerprint: 'fp-shared');
      final signaling = _signalingPeer(fingerprint: 'fp-shared');
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {lan.ip!: lan},
        signalingDevices: {
          'fp-shared': {signaling},
        },
      );
      final all = state.allDevices.values.toList();
      expect(all, hasLength(1));
      // The LAN-side ip+port survive the merge so the transport layer
      // can still hand the file over directly.
      expect(all.single.ip, '10.0.2.16');
      expect(all.single.port, 53317);
      expect(all.single.signalingId, 'sig-1', reason: 'signaling metadata is folded in');
      expect(
        all.single.discoveryMethods.map((m) => m.runtimeType).toSet(),
        containsAll(<Type>[MulticastDiscovery, SignalingDiscovery]),
      );
    });

    test('keys output by fingerprint, not by IP', () {
      final lan = _multicastPeer(fingerprint: 'fp-1');
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {lan.ip!: lan},
        signalingDevices: const {},
      );
      expect(state.allDevices.keys.toList(), ['fp-1']);
    });

    test('drops multicast entries with empty fingerprint defensively', () {
      final lan = _multicastPeer(fingerprint: '');
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {lan.ip!: lan},
        signalingDevices: const {},
      );
      expect(state.allDevices, isEmpty);
    });

    test('keeps the LAN entry when alias mismatches on the same fingerprint', () {
      // Defensive: same fingerprint, different alias. The LAN side has
      // the actual ip+port, so prefer it over the signaling record
      // rather than blindly overwriting like the old getter did.
      final lan = _multicastPeer(fingerprint: 'fp-1', alias: 'Solid Lemon');
      final signaling = _signalingPeer(fingerprint: 'fp-1', alias: 'Wildly different alias');
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {lan.ip!: lan},
        signalingDevices: {
          'fp-1': {signaling},
        },
      );
      final entry = state.allDevices.values.single;
      expect(entry.alias, 'Solid Lemon');
      expect(entry.ip, '10.0.2.16');
    });

    test('signaling-only device still surfaces when no LAN entry exists', () {
      final signaling = _signalingPeer(fingerprint: 'fp-only-signaling');
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: const {},
        signalingDevices: {
          'fp-only-signaling': {signaling},
        },
      );
      expect(state.allDevices.values.single.fingerprint, 'fp-only-signaling');
    });

    test('folds a signaling entry whose fingerprint drifts from the LAN cert hash by alias', () {
      // Real bug from the hot-restart report. The WebRTC signaling
      // handshake generates a fresh keypair on every connection, so
      // the `token` the signaling server hands us as the peer's
      // fingerprint differs from the LocalSend cert hash carried by
      // the multicast announce. After the peer hot-restarts the new
      // signaling token also differs from the OLD signaling token,
      // and until the server's Left message lands we hold both — none
      // of which share a fingerprint with the multicast entry. The
      // alias is the only stable identifier we can pivot on.
      final lan = _multicastPeer(fingerprint: 'fp-lan-cert-hash', alias: 'Solid Lemon');
      final freshSignaling = _signalingPeer(
        fingerprint: 'fp-fresh-signaling-token',
        alias: 'Solid Lemon',
        signalingId: 'sig-new',
      );
      final staleSignaling = _signalingPeer(
        fingerprint: 'fp-stale-signaling-token',
        alias: 'Solid Lemon',
        signalingId: 'sig-old',
      );
      final state = NearbyDevicesState(
        runningFavoriteScan: false,
        runningIps: const {},
        devices: {lan.ip!: lan},
        signalingDevices: {
          'fp-fresh-signaling-token': {freshSignaling},
          'fp-stale-signaling-token': {staleSignaling},
        },
      );
      final all = state.allDevices.values.toList();
      expect(all, hasLength(1), reason: 'duplicate-tile bug from cross-channel fingerprint drift');
      expect(all.single.alias, 'Solid Lemon');
      expect(all.single.ip, '10.0.2.16', reason: 'LAN ip preserved');
      expect(all.single.port, 53317);
    });
  });
}
