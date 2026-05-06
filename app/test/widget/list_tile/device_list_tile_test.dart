import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/widget/cloud/presence_dot.dart';
import 'package:magicshare_app/widget/device_bage.dart';
import 'package:magicshare_app/widget/list_tile/device_list_tile.dart';

Device _device({
  String fingerprint = 'fp',
  String alias = 'My Device',
  String? ip = '192.168.1.10',
}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: '2.0',
    port: 53317,
    https: true,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: {const MulticastDiscovery()},
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
