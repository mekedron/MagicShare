// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'join_token_preview.dart';

class JoinTokenPreviewDeviceMapper
    extends ClassMapperBase<JoinTokenPreviewDevice> {
  JoinTokenPreviewDeviceMapper._();

  static JoinTokenPreviewDeviceMapper? _instance;
  static JoinTokenPreviewDeviceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JoinTokenPreviewDeviceMapper._());
      CloudDeviceIconMapper.ensureInitialized();
      CloudDevicePlatformMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JoinTokenPreviewDevice';

  static String _$deviceId(JoinTokenPreviewDevice v) => v.deviceId;
  static const Field<JoinTokenPreviewDevice, String> _f$deviceId = Field(
    'deviceId',
    _$deviceId,
  );
  static String _$displayName(JoinTokenPreviewDevice v) => v.displayName;
  static const Field<JoinTokenPreviewDevice, String> _f$displayName = Field(
    'displayName',
    _$displayName,
  );
  static CloudDeviceIcon _$icon(JoinTokenPreviewDevice v) => v.icon;
  static const Field<JoinTokenPreviewDevice, CloudDeviceIcon> _f$icon = Field(
    'icon',
    _$icon,
  );
  static CloudDevicePlatform _$platform(JoinTokenPreviewDevice v) => v.platform;
  static const Field<JoinTokenPreviewDevice, CloudDevicePlatform> _f$platform =
      Field('platform', _$platform);

  @override
  final MappableFields<JoinTokenPreviewDevice> fields = const {
    #deviceId: _f$deviceId,
    #displayName: _f$displayName,
    #icon: _f$icon,
    #platform: _f$platform,
  };

  static JoinTokenPreviewDevice _instantiate(DecodingData data) {
    return JoinTokenPreviewDevice(
      deviceId: data.dec(_f$deviceId),
      displayName: data.dec(_f$displayName),
      icon: data.dec(_f$icon),
      platform: data.dec(_f$platform),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JoinTokenPreviewDevice fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JoinTokenPreviewDevice>(map);
  }

  static JoinTokenPreviewDevice deserialize(String json) {
    return ensureInitialized().decodeJson<JoinTokenPreviewDevice>(json);
  }
}

mixin JoinTokenPreviewDeviceMappable {
  String serialize() {
    return JoinTokenPreviewDeviceMapper.ensureInitialized()
        .encodeJson<JoinTokenPreviewDevice>(this as JoinTokenPreviewDevice);
  }

  Map<String, dynamic> toJson() {
    return JoinTokenPreviewDeviceMapper.ensureInitialized()
        .encodeMap<JoinTokenPreviewDevice>(this as JoinTokenPreviewDevice);
  }

  JoinTokenPreviewDeviceCopyWith<
    JoinTokenPreviewDevice,
    JoinTokenPreviewDevice,
    JoinTokenPreviewDevice
  >
  get copyWith =>
      _JoinTokenPreviewDeviceCopyWithImpl<
        JoinTokenPreviewDevice,
        JoinTokenPreviewDevice
      >(this as JoinTokenPreviewDevice, $identity, $identity);
  @override
  String toString() {
    return JoinTokenPreviewDeviceMapper.ensureInitialized().stringifyValue(
      this as JoinTokenPreviewDevice,
    );
  }

  @override
  bool operator ==(Object other) {
    return JoinTokenPreviewDeviceMapper.ensureInitialized().equalsValue(
      this as JoinTokenPreviewDevice,
      other,
    );
  }

  @override
  int get hashCode {
    return JoinTokenPreviewDeviceMapper.ensureInitialized().hashValue(
      this as JoinTokenPreviewDevice,
    );
  }
}

extension JoinTokenPreviewDeviceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JoinTokenPreviewDevice, $Out> {
  JoinTokenPreviewDeviceCopyWith<$R, JoinTokenPreviewDevice, $Out>
  get $asJoinTokenPreviewDevice => $base.as(
    (v, t, t2) => _JoinTokenPreviewDeviceCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class JoinTokenPreviewDeviceCopyWith<
  $R,
  $In extends JoinTokenPreviewDevice,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? deviceId,
    String? displayName,
    CloudDeviceIcon? icon,
    CloudDevicePlatform? platform,
  });
  JoinTokenPreviewDeviceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JoinTokenPreviewDeviceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JoinTokenPreviewDevice, $Out>
    implements
        JoinTokenPreviewDeviceCopyWith<$R, JoinTokenPreviewDevice, $Out> {
  _JoinTokenPreviewDeviceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JoinTokenPreviewDevice> $mapper =
      JoinTokenPreviewDeviceMapper.ensureInitialized();
  @override
  $R call({
    String? deviceId,
    String? displayName,
    CloudDeviceIcon? icon,
    CloudDevicePlatform? platform,
  }) => $apply(
    FieldCopyWithData({
      if (deviceId != null) #deviceId: deviceId,
      if (displayName != null) #displayName: displayName,
      if (icon != null) #icon: icon,
      if (platform != null) #platform: platform,
    }),
  );
  @override
  JoinTokenPreviewDevice $make(CopyWithData data) => JoinTokenPreviewDevice(
    deviceId: data.get(#deviceId, or: $value.deviceId),
    displayName: data.get(#displayName, or: $value.displayName),
    icon: data.get(#icon, or: $value.icon),
    platform: data.get(#platform, or: $value.platform),
  );

  @override
  JoinTokenPreviewDeviceCopyWith<$R2, JoinTokenPreviewDevice, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _JoinTokenPreviewDeviceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class JoinTokenPreviewMapper extends ClassMapperBase<JoinTokenPreview> {
  JoinTokenPreviewMapper._();

  static JoinTokenPreviewMapper? _instance;
  static JoinTokenPreviewMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JoinTokenPreviewMapper._());
      JoinTokenPreviewDeviceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JoinTokenPreview';

  static String _$accountId(JoinTokenPreview v) => v.accountId;
  static const Field<JoinTokenPreview, String> _f$accountId = Field(
    'accountId',
    _$accountId,
  );
  static String _$issuingDeviceId(JoinTokenPreview v) => v.issuingDeviceId;
  static const Field<JoinTokenPreview, String> _f$issuingDeviceId = Field(
    'issuingDeviceId',
    _$issuingDeviceId,
  );
  static int _$expiresAtMs(JoinTokenPreview v) => v.expiresAtMs;
  static const Field<JoinTokenPreview, int> _f$expiresAtMs = Field(
    'expiresAtMs',
    _$expiresAtMs,
  );
  static List<JoinTokenPreviewDevice> _$devices(JoinTokenPreview v) =>
      v.devices;
  static const Field<JoinTokenPreview, List<JoinTokenPreviewDevice>>
  _f$devices = Field('devices', _$devices);

  @override
  final MappableFields<JoinTokenPreview> fields = const {
    #accountId: _f$accountId,
    #issuingDeviceId: _f$issuingDeviceId,
    #expiresAtMs: _f$expiresAtMs,
    #devices: _f$devices,
  };

  static JoinTokenPreview _instantiate(DecodingData data) {
    return JoinTokenPreview(
      accountId: data.dec(_f$accountId),
      issuingDeviceId: data.dec(_f$issuingDeviceId),
      expiresAtMs: data.dec(_f$expiresAtMs),
      devices: data.dec(_f$devices),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JoinTokenPreview fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JoinTokenPreview>(map);
  }

  static JoinTokenPreview deserialize(String json) {
    return ensureInitialized().decodeJson<JoinTokenPreview>(json);
  }
}

mixin JoinTokenPreviewMappable {
  String serialize() {
    return JoinTokenPreviewMapper.ensureInitialized()
        .encodeJson<JoinTokenPreview>(this as JoinTokenPreview);
  }

  Map<String, dynamic> toJson() {
    return JoinTokenPreviewMapper.ensureInitialized()
        .encodeMap<JoinTokenPreview>(this as JoinTokenPreview);
  }

  JoinTokenPreviewCopyWith<JoinTokenPreview, JoinTokenPreview, JoinTokenPreview>
  get copyWith =>
      _JoinTokenPreviewCopyWithImpl<JoinTokenPreview, JoinTokenPreview>(
        this as JoinTokenPreview,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return JoinTokenPreviewMapper.ensureInitialized().stringifyValue(
      this as JoinTokenPreview,
    );
  }

  @override
  bool operator ==(Object other) {
    return JoinTokenPreviewMapper.ensureInitialized().equalsValue(
      this as JoinTokenPreview,
      other,
    );
  }

  @override
  int get hashCode {
    return JoinTokenPreviewMapper.ensureInitialized().hashValue(
      this as JoinTokenPreview,
    );
  }
}

extension JoinTokenPreviewValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JoinTokenPreview, $Out> {
  JoinTokenPreviewCopyWith<$R, JoinTokenPreview, $Out>
  get $asJoinTokenPreview =>
      $base.as((v, t, t2) => _JoinTokenPreviewCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class JoinTokenPreviewCopyWith<$R, $In extends JoinTokenPreview, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    JoinTokenPreviewDevice,
    JoinTokenPreviewDeviceCopyWith<
      $R,
      JoinTokenPreviewDevice,
      JoinTokenPreviewDevice
    >
  >
  get devices;
  $R call({
    String? accountId,
    String? issuingDeviceId,
    int? expiresAtMs,
    List<JoinTokenPreviewDevice>? devices,
  });
  JoinTokenPreviewCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JoinTokenPreviewCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JoinTokenPreview, $Out>
    implements JoinTokenPreviewCopyWith<$R, JoinTokenPreview, $Out> {
  _JoinTokenPreviewCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JoinTokenPreview> $mapper =
      JoinTokenPreviewMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    JoinTokenPreviewDevice,
    JoinTokenPreviewDeviceCopyWith<
      $R,
      JoinTokenPreviewDevice,
      JoinTokenPreviewDevice
    >
  >
  get devices => ListCopyWith(
    $value.devices,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(devices: v),
  );
  @override
  $R call({
    String? accountId,
    String? issuingDeviceId,
    int? expiresAtMs,
    List<JoinTokenPreviewDevice>? devices,
  }) => $apply(
    FieldCopyWithData({
      if (accountId != null) #accountId: accountId,
      if (issuingDeviceId != null) #issuingDeviceId: issuingDeviceId,
      if (expiresAtMs != null) #expiresAtMs: expiresAtMs,
      if (devices != null) #devices: devices,
    }),
  );
  @override
  JoinTokenPreview $make(CopyWithData data) => JoinTokenPreview(
    accountId: data.get(#accountId, or: $value.accountId),
    issuingDeviceId: data.get(#issuingDeviceId, or: $value.issuingDeviceId),
    expiresAtMs: data.get(#expiresAtMs, or: $value.expiresAtMs),
    devices: data.get(#devices, or: $value.devices),
  );

  @override
  JoinTokenPreviewCopyWith<$R2, JoinTokenPreview, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _JoinTokenPreviewCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

