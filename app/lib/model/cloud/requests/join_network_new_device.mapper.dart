// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'join_network_new_device.dart';

class JoinNetworkNewDeviceMapper extends ClassMapperBase<JoinNetworkNewDevice> {
  JoinNetworkNewDeviceMapper._();

  static JoinNetworkNewDeviceMapper? _instance;
  static JoinNetworkNewDeviceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JoinNetworkNewDeviceMapper._());
      CloudDeviceIconMapper.ensureInitialized();
      CloudDevicePlatformMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JoinNetworkNewDevice';

  static String _$displayName(JoinNetworkNewDevice v) => v.displayName;
  static const Field<JoinNetworkNewDevice, String> _f$displayName = Field(
    'displayName',
    _$displayName,
  );
  static CloudDeviceIcon _$icon(JoinNetworkNewDevice v) => v.icon;
  static const Field<JoinNetworkNewDevice, CloudDeviceIcon> _f$icon = Field(
    'icon',
    _$icon,
  );
  static CloudDevicePlatform _$platform(JoinNetworkNewDevice v) => v.platform;
  static const Field<JoinNetworkNewDevice, CloudDevicePlatform> _f$platform =
      Field('platform', _$platform);
  static String? _$fcmToken(JoinNetworkNewDevice v) => v.fcmToken;
  static const Field<JoinNetworkNewDevice, String> _f$fcmToken = Field(
    'fcmToken',
    _$fcmToken,
  );

  @override
  final MappableFields<JoinNetworkNewDevice> fields = const {
    #displayName: _f$displayName,
    #icon: _f$icon,
    #platform: _f$platform,
    #fcmToken: _f$fcmToken,
  };

  static JoinNetworkNewDevice _instantiate(DecodingData data) {
    return JoinNetworkNewDevice(
      displayName: data.dec(_f$displayName),
      icon: data.dec(_f$icon),
      platform: data.dec(_f$platform),
      fcmToken: data.dec(_f$fcmToken),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JoinNetworkNewDevice fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JoinNetworkNewDevice>(map);
  }

  static JoinNetworkNewDevice deserialize(String json) {
    return ensureInitialized().decodeJson<JoinNetworkNewDevice>(json);
  }
}

mixin JoinNetworkNewDeviceMappable {
  String serialize() {
    return JoinNetworkNewDeviceMapper.ensureInitialized()
        .encodeJson<JoinNetworkNewDevice>(this as JoinNetworkNewDevice);
  }

  Map<String, dynamic> toJson() {
    return JoinNetworkNewDeviceMapper.ensureInitialized()
        .encodeMap<JoinNetworkNewDevice>(this as JoinNetworkNewDevice);
  }

  JoinNetworkNewDeviceCopyWith<
    JoinNetworkNewDevice,
    JoinNetworkNewDevice,
    JoinNetworkNewDevice
  >
  get copyWith =>
      _JoinNetworkNewDeviceCopyWithImpl<
        JoinNetworkNewDevice,
        JoinNetworkNewDevice
      >(this as JoinNetworkNewDevice, $identity, $identity);
  @override
  String toString() {
    return JoinNetworkNewDeviceMapper.ensureInitialized().stringifyValue(
      this as JoinNetworkNewDevice,
    );
  }

  @override
  bool operator ==(Object other) {
    return JoinNetworkNewDeviceMapper.ensureInitialized().equalsValue(
      this as JoinNetworkNewDevice,
      other,
    );
  }

  @override
  int get hashCode {
    return JoinNetworkNewDeviceMapper.ensureInitialized().hashValue(
      this as JoinNetworkNewDevice,
    );
  }
}

extension JoinNetworkNewDeviceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JoinNetworkNewDevice, $Out> {
  JoinNetworkNewDeviceCopyWith<$R, JoinNetworkNewDevice, $Out>
  get $asJoinNetworkNewDevice => $base.as(
    (v, t, t2) => _JoinNetworkNewDeviceCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class JoinNetworkNewDeviceCopyWith<
  $R,
  $In extends JoinNetworkNewDevice,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? displayName,
    CloudDeviceIcon? icon,
    CloudDevicePlatform? platform,
    String? fcmToken,
  });
  JoinNetworkNewDeviceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JoinNetworkNewDeviceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JoinNetworkNewDevice, $Out>
    implements JoinNetworkNewDeviceCopyWith<$R, JoinNetworkNewDevice, $Out> {
  _JoinNetworkNewDeviceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JoinNetworkNewDevice> $mapper =
      JoinNetworkNewDeviceMapper.ensureInitialized();
  @override
  $R call({
    String? displayName,
    CloudDeviceIcon? icon,
    CloudDevicePlatform? platform,
    Object? fcmToken = $none,
  }) => $apply(
    FieldCopyWithData({
      if (displayName != null) #displayName: displayName,
      if (icon != null) #icon: icon,
      if (platform != null) #platform: platform,
      if (fcmToken != $none) #fcmToken: fcmToken,
    }),
  );
  @override
  JoinNetworkNewDevice $make(CopyWithData data) => JoinNetworkNewDevice(
    displayName: data.get(#displayName, or: $value.displayName),
    icon: data.get(#icon, or: $value.icon),
    platform: data.get(#platform, or: $value.platform),
    fcmToken: data.get(#fcmToken, or: $value.fcmToken),
  );

  @override
  JoinNetworkNewDeviceCopyWith<$R2, JoinNetworkNewDevice, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _JoinNetworkNewDeviceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

