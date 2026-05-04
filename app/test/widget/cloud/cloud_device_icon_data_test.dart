import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_icon_data.dart';

void main() {
  test('every CloudDeviceIcon maps to a non-null Material icon', () {
    for (final icon in CloudDeviceIcon.values) {
      expect(iconDataFor(icon), isA<IconData>(), reason: 'missing mapping for $icon');
    }
  });

  test('icon mapping is stable per variant', () {
    expect(iconDataFor(CloudDeviceIcon.laptop), Icons.laptop_mac);
    expect(iconDataFor(CloudDeviceIcon.desktop), Icons.desktop_windows);
    expect(iconDataFor(CloudDeviceIcon.phone), Icons.smartphone);
    expect(iconDataFor(CloudDeviceIcon.tablet), Icons.tablet_mac);
    expect(iconDataFor(CloudDeviceIcon.server), Icons.dns_outlined);
    expect(iconDataFor(CloudDeviceIcon.headless), Icons.memory);
    expect(iconDataFor(CloudDeviceIcon.other), Icons.devices_other);
  });

  test('every variant maps to a distinct icon', () {
    final seen = <IconData>{};
    for (final icon in CloudDeviceIcon.values) {
      final mapped = iconDataFor(icon);
      expect(seen.add(mapped), isTrue, reason: 'duplicate mapping at $icon');
    }
  });
}
