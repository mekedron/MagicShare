import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';

part 'join_network_new_device.mapper.dart';

/// Optional `joinNetwork.newDevice` field for the welcome-card pairing
/// route — the joining device has no source account doc on its UID
/// (anon sign-in happened only to authenticate the call) and therefore
/// the backend has no source-side device doc to copy from. Mirrors the
/// `newDevice` block in
/// `firebase/functions/src/validation.ts:JoinNetworkInput`.
@MappableClass()
class JoinNetworkNewDevice with JoinNetworkNewDeviceMappable {
  final String displayName;
  final CloudDeviceIcon icon;
  final CloudDevicePlatform platform;
  final String? fcmToken;

  const JoinNetworkNewDevice({
    required this.displayName,
    required this.icon,
    required this.platform,
    required this.fcmToken,
  });

  static const fromJson = JoinNetworkNewDeviceMapper.fromJson;
}
