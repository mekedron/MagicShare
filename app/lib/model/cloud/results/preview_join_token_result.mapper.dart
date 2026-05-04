// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'preview_join_token_result.dart';

class PreviewJoinTokenResultMapper
    extends ClassMapperBase<PreviewJoinTokenResult> {
  PreviewJoinTokenResultMapper._();

  static PreviewJoinTokenResultMapper? _instance;
  static PreviewJoinTokenResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PreviewJoinTokenResultMapper._());
      JoinTokenPreviewDeviceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PreviewJoinTokenResult';

  static String _$accountId(PreviewJoinTokenResult v) => v.accountId;
  static const Field<PreviewJoinTokenResult, String> _f$accountId = Field(
    'accountId',
    _$accountId,
  );
  static String _$issuingDeviceId(PreviewJoinTokenResult v) =>
      v.issuingDeviceId;
  static const Field<PreviewJoinTokenResult, String> _f$issuingDeviceId = Field(
    'issuingDeviceId',
    _$issuingDeviceId,
  );
  static int _$expiresAtMs(PreviewJoinTokenResult v) => v.expiresAtMs;
  static const Field<PreviewJoinTokenResult, int> _f$expiresAtMs = Field(
    'expiresAtMs',
    _$expiresAtMs,
  );
  static List<JoinTokenPreviewDevice> _$devices(PreviewJoinTokenResult v) =>
      v.devices;
  static const Field<PreviewJoinTokenResult, List<JoinTokenPreviewDevice>>
  _f$devices = Field('devices', _$devices);

  @override
  final MappableFields<PreviewJoinTokenResult> fields = const {
    #accountId: _f$accountId,
    #issuingDeviceId: _f$issuingDeviceId,
    #expiresAtMs: _f$expiresAtMs,
    #devices: _f$devices,
  };

  static PreviewJoinTokenResult _instantiate(DecodingData data) {
    return PreviewJoinTokenResult(
      accountId: data.dec(_f$accountId),
      issuingDeviceId: data.dec(_f$issuingDeviceId),
      expiresAtMs: data.dec(_f$expiresAtMs),
      devices: data.dec(_f$devices),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PreviewJoinTokenResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PreviewJoinTokenResult>(map);
  }

  static PreviewJoinTokenResult deserialize(String json) {
    return ensureInitialized().decodeJson<PreviewJoinTokenResult>(json);
  }
}

mixin PreviewJoinTokenResultMappable {
  String serialize() {
    return PreviewJoinTokenResultMapper.ensureInitialized()
        .encodeJson<PreviewJoinTokenResult>(this as PreviewJoinTokenResult);
  }

  Map<String, dynamic> toJson() {
    return PreviewJoinTokenResultMapper.ensureInitialized()
        .encodeMap<PreviewJoinTokenResult>(this as PreviewJoinTokenResult);
  }

  PreviewJoinTokenResultCopyWith<
    PreviewJoinTokenResult,
    PreviewJoinTokenResult,
    PreviewJoinTokenResult
  >
  get copyWith =>
      _PreviewJoinTokenResultCopyWithImpl<
        PreviewJoinTokenResult,
        PreviewJoinTokenResult
      >(this as PreviewJoinTokenResult, $identity, $identity);
  @override
  String toString() {
    return PreviewJoinTokenResultMapper.ensureInitialized().stringifyValue(
      this as PreviewJoinTokenResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return PreviewJoinTokenResultMapper.ensureInitialized().equalsValue(
      this as PreviewJoinTokenResult,
      other,
    );
  }

  @override
  int get hashCode {
    return PreviewJoinTokenResultMapper.ensureInitialized().hashValue(
      this as PreviewJoinTokenResult,
    );
  }
}

extension PreviewJoinTokenResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PreviewJoinTokenResult, $Out> {
  PreviewJoinTokenResultCopyWith<$R, PreviewJoinTokenResult, $Out>
  get $asPreviewJoinTokenResult => $base.as(
    (v, t, t2) => _PreviewJoinTokenResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PreviewJoinTokenResultCopyWith<
  $R,
  $In extends PreviewJoinTokenResult,
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
    String? issuingDeviceId,
    int? expiresAtMs,
    List<JoinTokenPreviewDevice>? devices,
  });
  PreviewJoinTokenResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PreviewJoinTokenResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PreviewJoinTokenResult, $Out>
    implements
        PreviewJoinTokenResultCopyWith<$R, PreviewJoinTokenResult, $Out> {
  _PreviewJoinTokenResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PreviewJoinTokenResult> $mapper =
      PreviewJoinTokenResultMapper.ensureInitialized();
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
  PreviewJoinTokenResult $make(CopyWithData data) => PreviewJoinTokenResult(
    accountId: data.get(#accountId, or: $value.accountId),
    issuingDeviceId: data.get(#issuingDeviceId, or: $value.issuingDeviceId),
    expiresAtMs: data.get(#expiresAtMs, or: $value.expiresAtMs),
    devices: data.get(#devices, or: $value.devices),
  );

  @override
  PreviewJoinTokenResultCopyWith<$R2, PreviewJoinTokenResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PreviewJoinTokenResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

