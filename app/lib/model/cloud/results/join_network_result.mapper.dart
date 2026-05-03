// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'join_network_result.dart';

class JoinNetworkResultMapper extends ClassMapperBase<JoinNetworkResult> {
  JoinNetworkResultMapper._();

  static JoinNetworkResultMapper? _instance;
  static JoinNetworkResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JoinNetworkResultMapper._());
      JoinTokenPreviewDeviceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JoinNetworkResult';

  static String _$accountId(JoinNetworkResult v) => v.accountId;
  static const Field<JoinNetworkResult, String> _f$accountId = Field(
    'accountId',
    _$accountId,
  );
  static bool _$oldAccountDeleted(JoinNetworkResult v) => v.oldAccountDeleted;
  static const Field<JoinNetworkResult, bool> _f$oldAccountDeleted = Field(
    'oldAccountDeleted',
    _$oldAccountDeleted,
  );
  static List<JoinTokenPreviewDevice> _$devices(JoinNetworkResult v) =>
      v.devices;
  static const Field<JoinNetworkResult, List<JoinTokenPreviewDevice>>
  _f$devices = Field('devices', _$devices);

  @override
  final MappableFields<JoinNetworkResult> fields = const {
    #accountId: _f$accountId,
    #oldAccountDeleted: _f$oldAccountDeleted,
    #devices: _f$devices,
  };

  static JoinNetworkResult _instantiate(DecodingData data) {
    return JoinNetworkResult(
      accountId: data.dec(_f$accountId),
      oldAccountDeleted: data.dec(_f$oldAccountDeleted),
      devices: data.dec(_f$devices),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JoinNetworkResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JoinNetworkResult>(map);
  }

  static JoinNetworkResult deserialize(String json) {
    return ensureInitialized().decodeJson<JoinNetworkResult>(json);
  }
}

mixin JoinNetworkResultMappable {
  String serialize() {
    return JoinNetworkResultMapper.ensureInitialized()
        .encodeJson<JoinNetworkResult>(this as JoinNetworkResult);
  }

  Map<String, dynamic> toJson() {
    return JoinNetworkResultMapper.ensureInitialized()
        .encodeMap<JoinNetworkResult>(this as JoinNetworkResult);
  }

  JoinNetworkResultCopyWith<
    JoinNetworkResult,
    JoinNetworkResult,
    JoinNetworkResult
  >
  get copyWith =>
      _JoinNetworkResultCopyWithImpl<JoinNetworkResult, JoinNetworkResult>(
        this as JoinNetworkResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return JoinNetworkResultMapper.ensureInitialized().stringifyValue(
      this as JoinNetworkResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return JoinNetworkResultMapper.ensureInitialized().equalsValue(
      this as JoinNetworkResult,
      other,
    );
  }

  @override
  int get hashCode {
    return JoinNetworkResultMapper.ensureInitialized().hashValue(
      this as JoinNetworkResult,
    );
  }
}

extension JoinNetworkResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JoinNetworkResult, $Out> {
  JoinNetworkResultCopyWith<$R, JoinNetworkResult, $Out>
  get $asJoinNetworkResult => $base.as(
    (v, t, t2) => _JoinNetworkResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class JoinNetworkResultCopyWith<
  $R,
  $In extends JoinNetworkResult,
  $Out
>
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
    bool? oldAccountDeleted,
    List<JoinTokenPreviewDevice>? devices,
  });
  JoinNetworkResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JoinNetworkResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JoinNetworkResult, $Out>
    implements JoinNetworkResultCopyWith<$R, JoinNetworkResult, $Out> {
  _JoinNetworkResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JoinNetworkResult> $mapper =
      JoinNetworkResultMapper.ensureInitialized();
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
    bool? oldAccountDeleted,
    List<JoinTokenPreviewDevice>? devices,
  }) => $apply(
    FieldCopyWithData({
      if (accountId != null) #accountId: accountId,
      if (oldAccountDeleted != null) #oldAccountDeleted: oldAccountDeleted,
      if (devices != null) #devices: devices,
    }),
  );
  @override
  JoinNetworkResult $make(CopyWithData data) => JoinNetworkResult(
    accountId: data.get(#accountId, or: $value.accountId),
    oldAccountDeleted: data.get(
      #oldAccountDeleted,
      or: $value.oldAccountDeleted,
    ),
    devices: data.get(#devices, or: $value.devices),
  );

  @override
  JoinNetworkResultCopyWith<$R2, JoinNetworkResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _JoinNetworkResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

