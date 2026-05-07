// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'cloud_device.dart';

class CloudDeviceMapper extends ClassMapperBase<CloudDevice> {
  CloudDeviceMapper._();

  static CloudDeviceMapper? _instance;
  static CloudDeviceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudDeviceMapper._());
      CloudDeviceIconMapper.ensureInitialized();
      CloudDevicePlatformMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CloudDevice';

  static String _$deviceId(CloudDevice v) => v.deviceId;
  static const Field<CloudDevice, String> _f$deviceId = Field(
    'deviceId',
    _$deviceId,
  );
  static String _$displayName(CloudDevice v) => v.displayName;
  static const Field<CloudDevice, String> _f$displayName = Field(
    'displayName',
    _$displayName,
  );
  static CloudDeviceIcon _$icon(CloudDevice v) => v.icon;
  static const Field<CloudDevice, CloudDeviceIcon> _f$icon = Field(
    'icon',
    _$icon,
  );
  static String? _$fcmToken(CloudDevice v) => v.fcmToken;
  static const Field<CloudDevice, String> _f$fcmToken = Field(
    'fcmToken',
    _$fcmToken,
  );
  static CloudDevicePlatform _$platform(CloudDevice v) => v.platform;
  static const Field<CloudDevice, CloudDevicePlatform> _f$platform = Field(
    'platform',
    _$platform,
  );
  static String? _$fingerprint(CloudDevice v) => v.fingerprint;
  static const Field<CloudDevice, String> _f$fingerprint = Field(
    'fingerprint',
    _$fingerprint,
    opt: true,
  );

  @override
  final MappableFields<CloudDevice> fields = const {
    #deviceId: _f$deviceId,
    #displayName: _f$displayName,
    #icon: _f$icon,
    #fcmToken: _f$fcmToken,
    #platform: _f$platform,
    #fingerprint: _f$fingerprint,
  };

  static CloudDevice _instantiate(DecodingData data) {
    return CloudDevice(
      deviceId: data.dec(_f$deviceId),
      displayName: data.dec(_f$displayName),
      icon: data.dec(_f$icon),
      fcmToken: data.dec(_f$fcmToken),
      platform: data.dec(_f$platform),
      fingerprint: data.dec(_f$fingerprint),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CloudDevice fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CloudDevice>(map);
  }

  static CloudDevice deserialize(String json) {
    return ensureInitialized().decodeJson<CloudDevice>(json);
  }
}

mixin CloudDeviceMappable {
  String serialize() {
    return CloudDeviceMapper.ensureInitialized().encodeJson<CloudDevice>(
      this as CloudDevice,
    );
  }

  Map<String, dynamic> toJson() {
    return CloudDeviceMapper.ensureInitialized().encodeMap<CloudDevice>(
      this as CloudDevice,
    );
  }

  CloudDeviceCopyWith<CloudDevice, CloudDevice, CloudDevice> get copyWith =>
      _CloudDeviceCopyWithImpl<CloudDevice, CloudDevice>(
        this as CloudDevice,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CloudDeviceMapper.ensureInitialized().stringifyValue(
      this as CloudDevice,
    );
  }

  @override
  bool operator ==(Object other) {
    return CloudDeviceMapper.ensureInitialized().equalsValue(
      this as CloudDevice,
      other,
    );
  }

  @override
  int get hashCode {
    return CloudDeviceMapper.ensureInitialized().hashValue(this as CloudDevice);
  }
}

extension CloudDeviceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CloudDevice, $Out> {
  CloudDeviceCopyWith<$R, CloudDevice, $Out> get $asCloudDevice =>
      $base.as((v, t, t2) => _CloudDeviceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CloudDeviceCopyWith<$R, $In extends CloudDevice, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? deviceId,
    String? displayName,
    CloudDeviceIcon? icon,
    String? fcmToken,
    CloudDevicePlatform? platform,
    String? fingerprint,
  });
  CloudDeviceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CloudDeviceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CloudDevice, $Out>
    implements CloudDeviceCopyWith<$R, CloudDevice, $Out> {
  _CloudDeviceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CloudDevice> $mapper =
      CloudDeviceMapper.ensureInitialized();
  @override
  $R call({
    String? deviceId,
    String? displayName,
    CloudDeviceIcon? icon,
    Object? fcmToken = $none,
    CloudDevicePlatform? platform,
    Object? fingerprint = $none,
  }) => $apply(
    FieldCopyWithData({
      if (deviceId != null) #deviceId: deviceId,
      if (displayName != null) #displayName: displayName,
      if (icon != null) #icon: icon,
      if (fcmToken != $none) #fcmToken: fcmToken,
      if (platform != null) #platform: platform,
      if (fingerprint != $none) #fingerprint: fingerprint,
    }),
  );
  @override
  CloudDevice $make(CopyWithData data) => CloudDevice(
    deviceId: data.get(#deviceId, or: $value.deviceId),
    displayName: data.get(#displayName, or: $value.displayName),
    icon: data.get(#icon, or: $value.icon),
    fcmToken: data.get(#fcmToken, or: $value.fcmToken),
    platform: data.get(#platform, or: $value.platform),
    fingerprint: data.get(#fingerprint, or: $value.fingerprint),
  );

  @override
  CloudDeviceCopyWith<$R2, CloudDevice, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CloudDeviceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

