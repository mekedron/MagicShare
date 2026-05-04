import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_list_tile.dart';

CloudDevice _device({
  String id = 'device-a',
  String name = 'Macbook',
  CloudDeviceIcon icon = CloudDeviceIcon.laptop,
  CloudDevicePresence presence = CloudDevicePresence.online,
}) {
  return CloudDevice(
    deviceId: id,
    displayName: name,
    icon: icon,
    fcmToken: null,
    platform: CloudDevicePlatform.macos,
    lastSeenAtMs: 0,
    presence: presence,
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
        device: _device(presence: CloudDevicePresence.online, name: 'Macbook Pro'),
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
        device: _device(presence: CloudDevicePresence.offline, name: 'iPad'),
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

  testWidgets('shows This-device badge when isCurrent is true', (tester) async {
    await _pump(
      tester,
      CloudDeviceListTile(
        device: _device(),
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
        device: _device(),
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
        device: _device(),
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
        device: _device(icon: CloudDeviceIcon.phone),
        isCurrent: false,
        thisDeviceLabel: 'This device',
        onlineLabel: 'Online',
        offlineLabel: 'Offline',
      ),
    );

    expect(find.byIcon(Icons.smartphone), findsOneWidget);
  });
}
