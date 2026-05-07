import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';

part 'cloud_device.mapper.dart';

/// Mirrors `DeviceDoc` in firebase/functions/src/models.ts plus the document
/// id. The doc is a pure registry of group membership — no online-status
/// fields. Online truth is derived from LAN multicast / HTTP `/info` and
/// WebRTC signaling, not from the cloud.
@MappableClass()
class CloudDevice with CloudDeviceMappable {
  final String deviceId;
  final String displayName;
  final CloudDeviceIcon icon;
  final String? fcmToken;
  final CloudDevicePlatform platform;

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
    this.fingerprint,
  });

  static const fromJson = CloudDeviceMapper.fromJson;
}
