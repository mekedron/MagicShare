import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';

part 'join_token_preview.mapper.dart';

/// Mirrors `JoinTokenPreviewDevice` in firebase/functions/src/pairing.ts.
/// Public-safe subset of [CloudDevice] returned by `previewJoinToken`.
@MappableClass()
class JoinTokenPreviewDevice with JoinTokenPreviewDeviceMappable {
  final String deviceId;
  final String displayName;
  final CloudDeviceIcon icon;
  final CloudDevicePlatform platform;
  final CloudDevicePresence presence;

  const JoinTokenPreviewDevice({
    required this.deviceId,
    required this.displayName,
    required this.icon,
    required this.platform,
    required this.presence,
  });

  static const fromJson = JoinTokenPreviewDeviceMapper.fromJson;
}

/// Mirrors `PreviewJoinTokenResult` shape in firebase/functions/src/pairing.ts.
@MappableClass()
class JoinTokenPreview with JoinTokenPreviewMappable {
  final String accountId;
  final String issuingDeviceId;
  final int expiresAtMs;
  final List<JoinTokenPreviewDevice> devices;

  const JoinTokenPreview({
    required this.accountId,
    required this.issuingDeviceId,
    required this.expiresAtMs,
    required this.devices,
  });

  static const fromJson = JoinTokenPreviewMapper.fromJson;
}
