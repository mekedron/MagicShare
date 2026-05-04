import 'package:flutter/material.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';

/// Material icon used to render a [CloudDeviceIcon] in the UI. The wire enum
/// is intentionally decoupled from the icon glyph: the wire format is shared
/// with the Cloud Functions backend, but the visual representation is a
/// purely client-side concern.
IconData iconDataFor(CloudDeviceIcon icon) {
  return switch (icon) {
    CloudDeviceIcon.laptop => Icons.laptop_mac,
    CloudDeviceIcon.desktop => Icons.desktop_windows,
    CloudDeviceIcon.phone => Icons.smartphone,
    CloudDeviceIcon.tablet => Icons.tablet_mac,
    CloudDeviceIcon.server => Icons.dns_outlined,
    CloudDeviceIcon.headless => Icons.memory,
    CloudDeviceIcon.other => Icons.devices_other,
  };
}
