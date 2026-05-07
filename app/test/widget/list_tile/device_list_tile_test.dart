import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/widget/cloud/presence_dot.dart';
import 'package:magicshare_app/widget/device_bage.dart';
import 'package:magicshare_app/widget/list_tile/device_list_tile.dart';

Device _device({
  String certHash = 'fp',
  String alias = 'My Device',
  String? ip = '192.168.1.10',
}) {
  return Device(
    version: '2.0',
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    endpoints: ip == null
        ? const {}
        : {
            HttpEndpoint(
              ip: ip,
              port: 53317,
              https: true,
              certHash: certHash,
            ),
          },
    discoveryMethods: {const MulticastDiscovery()},
  );
}

Device _bothEndpoints({
  String certHash = 'fp-cert',
  String serverToken = 'fp-token',
  String alias = 'Both',
  String ip = '192.168.1.10',
}) {
  return Device(
    version: '2.0',
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    endpoints: {
      HttpEndpoint(ip: ip, port: 53317, https: true, certHash: certHash),
      SignalingEndpoint(
        signalingId: 'sig-uuid',
        signalingServer: 'wss://public.localsend.org/v1/ws',
        serverToken: serverToken,
      ),
    },
    discoveryMethods: {
      const MulticastDiscovery(),
      const SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
    },
  );
}

Future<void> _pumpTile(WidgetTester tester, DeviceListTile tile) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: tile)));
}

void main() {
  group('DeviceListTile', () {
    testWidgets('renders the device alias', (tester) async {
      await _pumpTile(tester, DeviceListTile(device: _device(alias: 'Living-room laptop')));
      expect(find.text('Living-room laptop'), findsOneWidget);
    });

    testWidgets('without networkPresence: no PresenceDot, original LAN badge', (tester) async {
      await _pumpTile(tester, DeviceListTile(device: _device()));
      expect(find.byType(PresenceDot), findsNothing);
      expect(find.text('LAN • HTTP'), findsOneWidget);
    });

    testWidgets('online networkPresence: PresenceDot + status label, no Wake', (tester) async {
      await _pumpTile(
        tester,
        DeviceListTile(
          device: _device(),
          networkPresence: const NetworkPresenceInfo(
            isOnline: true,
            statusLabel: 'Online',
            wakeLabel: 'Wake',
          ),
        ),
      );
      expect(find.byType(PresenceDot), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      // wakeLabel only shows when offline
      expect(
        find.descendant(of: find.byType(DeviceBadge), matching: find.text('Wake')),
        findsNothing,
      );
    });

    testWidgets('offline networkPresence on a cloud-only tile: PresenceDot + Wake badge, no LAN badge', (
      tester,
    ) async {
      await _pumpTile(
        tester,
        DeviceListTile(
          device: _device(ip: null),
          networkPresence: const NetworkPresenceInfo(
            isOnline: false,
            statusLabel: 'Offline',
            wakeLabel: 'Wake',
          ),
        ),
      );
      expect(find.byType(PresenceDot), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      // Wake pill is present...
      expect(
        find.descendant(of: find.byType(DeviceBadge), matching: find.text('Wake')),
        findsOneWidget,
      );
      // ...and the legacy WebRTC fallback is not (presence info supersedes it).
      expect(find.text('LAN • HTTP'), findsNothing);
      expect(find.text('WebRTC'), findsNothing);
    });

    testWidgets('device with both endpoint types renders BOTH "LAN • HTTP" and "WebRTC" badges', (tester) async {
      // After a merge collapses an HTTP-discovered device with a
      // signaling-discovered device, the resulting Device carries
      // BOTH endpoint types. The tile must surface both — losing
      // either badge after merge is the bug this refactor fixes.
      await _pumpTile(tester, DeviceListTile(device: _bothEndpoints()));
      expect(find.text('LAN • HTTP'), findsOneWidget);
      expect(find.text('WebRTC'), findsOneWidget);
    });

    testWidgets('cloud-group device renders the "Group" badge', (tester) async {
      // Devices that are part of the user's cloud device group get a
      // small "Group" pill so the user can spot their own devices in
      // the nearby-devices list at a glance.
      await _pumpTile(
        tester,
        DeviceListTile(
          device: _device(),
          networkPresence: const NetworkPresenceInfo(
            isOnline: true,
            statusLabel: 'Online',
            groupLabel: 'Group',
          ),
        ),
      );
      expect(
        find.descendant(of: find.byType(DeviceBadge), matching: find.text('Group')),
        findsOneWidget,
      );
    });

    testWidgets('non-group device renders no "Group" badge', (tester) async {
      // Stock-LocalSend peers (cloud == null in the merge) must NOT
      // get the Group pill — that pill specifically marks the user's
      // own cloud-registered devices.
      await _pumpTile(
        tester,
        DeviceListTile(
          device: _device(),
          networkPresence: const NetworkPresenceInfo(
            isOnline: true,
            statusLabel: 'Online',
          ),
        ),
      );
      expect(find.text('Group'), findsNothing);
    });

    testWidgets('signaling-only device renders just "WebRTC"', (tester) async {
      final signalingOnly = Device(
        version: '2.0',
        alias: 'Signaling-only',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        endpoints: {
          const SignalingEndpoint(
            signalingId: 'sig',
            signalingServer: 'wss://public.localsend.org/v1/ws',
            serverToken: 'tok',
          ),
        },
        discoveryMethods: {
          const SignalingDiscovery(signalingServer: 'wss://public.localsend.org/v1/ws'),
        },
      );
      await _pumpTile(tester, DeviceListTile(device: signalingOnly));
      expect(find.text('LAN • HTTP'), findsNothing);
      expect(find.text('WebRTC'), findsOneWidget);
    });

    testWidgets('disables tap when onTap is null (offline-cloud during Subtask 1)', (tester) async {
      await _pumpTile(
        tester,
        DeviceListTile(
          device: _device(ip: null),
          networkPresence: const NetworkPresenceInfo(
            isOnline: false,
            statusLabel: 'Offline',
            wakeLabel: 'Wake',
          ),
        ),
      );
      // Verifies no exception when onTap is null — InkWell still renders
      // but tapping the tile does nothing.
      await tester.tap(find.byType(DeviceListTile));
      await tester.pump();
    });
  });
}
