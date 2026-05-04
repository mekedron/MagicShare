// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'register_device_result.dart';

class RegisterDeviceResultMapper extends ClassMapperBase<RegisterDeviceResult> {
  RegisterDeviceResultMapper._();

  static RegisterDeviceResultMapper? _instance;
  static RegisterDeviceResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RegisterDeviceResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'RegisterDeviceResult';

  static bool _$created(RegisterDeviceResult v) => v.created;
  static const Field<RegisterDeviceResult, bool> _f$created = Field(
    'created',
    _$created,
  );

  @override
  final MappableFields<RegisterDeviceResult> fields = const {
    #created: _f$created,
  };

  static RegisterDeviceResult _instantiate(DecodingData data) {
    return RegisterDeviceResult(created: data.dec(_f$created));
  }

  @override
  final Function instantiate = _instantiate;

  static RegisterDeviceResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RegisterDeviceResult>(map);
  }

  static RegisterDeviceResult deserialize(String json) {
    return ensureInitialized().decodeJson<RegisterDeviceResult>(json);
  }
}

mixin RegisterDeviceResultMappable {
  String serialize() {
    return RegisterDeviceResultMapper.ensureInitialized()
        .encodeJson<RegisterDeviceResult>(this as RegisterDeviceResult);
  }

  Map<String, dynamic> toJson() {
    return RegisterDeviceResultMapper.ensureInitialized()
        .encodeMap<RegisterDeviceResult>(this as RegisterDeviceResult);
  }

  RegisterDeviceResultCopyWith<
    RegisterDeviceResult,
    RegisterDeviceResult,
    RegisterDeviceResult
  >
  get copyWith =>
      _RegisterDeviceResultCopyWithImpl<
        RegisterDeviceResult,
        RegisterDeviceResult
      >(this as RegisterDeviceResult, $identity, $identity);
  @override
  String toString() {
    return RegisterDeviceResultMapper.ensureInitialized().stringifyValue(
      this as RegisterDeviceResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return RegisterDeviceResultMapper.ensureInitialized().equalsValue(
      this as RegisterDeviceResult,
      other,
    );
  }

  @override
  int get hashCode {
    return RegisterDeviceResultMapper.ensureInitialized().hashValue(
      this as RegisterDeviceResult,
    );
  }
}

extension RegisterDeviceResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RegisterDeviceResult, $Out> {
  RegisterDeviceResultCopyWith<$R, RegisterDeviceResult, $Out>
  get $asRegisterDeviceResult => $base.as(
    (v, t, t2) => _RegisterDeviceResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class RegisterDeviceResultCopyWith<
  $R,
  $In extends RegisterDeviceResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? created});
  RegisterDeviceResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _RegisterDeviceResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RegisterDeviceResult, $Out>
    implements RegisterDeviceResultCopyWith<$R, RegisterDeviceResult, $Out> {
  _RegisterDeviceResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RegisterDeviceResult> $mapper =
      RegisterDeviceResultMapper.ensureInitialized();
  @override
  $R call({bool? created}) =>
      $apply(FieldCopyWithData({if (created != null) #created: created}));
  @override
  RegisterDeviceResult $make(CopyWithData data) =>
      RegisterDeviceResult(created: data.get(#created, or: $value.created));

  @override
  RegisterDeviceResultCopyWith<$R2, RegisterDeviceResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _RegisterDeviceResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

