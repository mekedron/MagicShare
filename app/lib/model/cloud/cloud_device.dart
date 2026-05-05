import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';

part 'cloud_device.mapper.dart';

/// Mirrors `DeviceDoc` in firebase/functions/src/models.ts plus the document
/// id. Timestamp fields are encoded as integer milliseconds since the Unix
/// epoch — see plan note in `app/lib/model/cloud/cloud_account.dart`.
@MappableClass()
class CloudDevice with CloudDeviceMappable {
  final String deviceId;
  final String displayName;
  final CloudDeviceIcon icon;
  final String? fcmToken;
  final CloudDevicePlatform platform;
  final int lastSeenAtMs;
  final CloudDevicePresence presence;

  /// LocalSend cert hash announced by this device on multicast. Mirrors
  /// `DeviceDoc.fingerprint` in firebase/functions/src/models.ts. Lets
  /// the Send tab dedup LAN-discovered devices against the cloud device
  /// list. Null for devices that haven't re-registered since the field
  /// was introduced.
  final String? fingerprint;

  const CloudDevice({
    required this.deviceId,
    required this.displayName,
    required this.icon,
    required this.fcmToken,
    required this.platform,
    required this.lastSeenAtMs,
    required this.presence,
    this.fingerprint,
  });

  static const fromJson = CloudDeviceMapper.fromJson;
}
