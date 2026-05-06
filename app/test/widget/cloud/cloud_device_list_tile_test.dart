import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_list_tile.dart';

CloudDevice _device({
  String id = 'device-a',
  String name = 'Macbook',
  CloudDeviceIcon icon = CloudDeviceIcon.laptop,
  CloudDevicePresence presence = CloudDevicePresence.online,
  int? lastSeenAtMs,
}) {
  return CloudDevice(
    deviceId: id,
    displayName: name,
    icon: icon,
    fcmToken: null,
    platform: CloudDevicePlatform.macos,
    // Default to "just heartbeated" so the freshness check passes for
    // tests that don't override it. Tests that exercise staleness
    // pass an explicit older timestamp.
    lastSeenAtMs: lastSeenAtMs ?? DateTime.now().millisecondsSinceEpoch,
    presence: presence,
  );
}

MergedDevice _merged(
  CloudDevice cloud, {
  bool isLanReachable = false,
}) {
  return MergedDevice(
    displayDevice: Device(
      signalingId: null,
      ip: isLanReachable ? '192.168.0.1' : null,
      version: '2.1',
      port: 53317,
      https: true,
      fingerprint: cloud.fingerprint ?? cloud.deviceId,
      alias: cloud.displayName,
      deviceModel: null,
      deviceType: DeviceType.desktop,
      download: false,
      discoveryMethods: const {},
    ),
    cloud: cloud,
    isLanReachable: isLanReachable,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('renders display name + online label and presence dot', (tester) async {
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(presence: CloudDevicePresence.online, name: 'Macbook Pro'), isLanReachable: true),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.text('Macbook Pro'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('renders offline label when device is offline', (tester) async {
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(presence: CloudDevicePresence.offline, name: 'iPad'), isLanReachable: false),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.text('iPad'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('renders Offline when cloud presence online but not LAN reachable', (tester) async {
    // The conjunction-aware predicate: dot reflects "transferable
    // right now", not just "device alive somewhere". A cloud peer on
    // a different network (or backgrounded with a stale heartbeat)
    // should not show as Online on the settings page either.
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(
          _device(presence: CloudDevicePresence.online, name: 'Phone (different network)'),
          isLanReachable: false,
        ),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.text('Phone (different network)'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('shows Online for the current-device row even without a LAN entry', (tester) async {
    // We never see our own multicast announce in our own LAN list,
    // so the current device's `isLanReachable` is always false. Show
    // Online based on cloud heartbeat freshness alone — we trust our
    // own process.
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(presence: CloudDevicePresence.online), isLanReachable: false),
        isCurrent: true,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('shows This-device badge when isCurrent is true', (tester) async {
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(), isLanReachable: false),
        isCurrent: true,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.text('This device'), findsOneWidget);
  });

  testWidgets('omits This-device badge when isCurrent is false', (tester) async {
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(), isLanReachable: true),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.text('This device'), findsNothing);
  });

  testWidgets('invokes onTap when tile is tapped', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(), isLanReachable: true),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
        onTap: () => taps++,
      ),
    );

    await tester.tap(find.text('Macbook'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('renders the mapped Material icon for the device-icon enum', (tester) async {
    await _pump(
      tester,
      CloudDeviceListTile(
        merged: _merged(_device(icon: CloudDeviceIcon.phone), isLanReachable: true),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.byIcon(Icons.smartphone), findsOneWidget);
  });
}
