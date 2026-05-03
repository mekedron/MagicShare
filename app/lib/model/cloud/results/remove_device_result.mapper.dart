// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'remove_device_result.dart';

class RemoveDeviceResultMapper extends ClassMapperBase<RemoveDeviceResult> {
  RemoveDeviceResultMapper._();

  static RemoveDeviceResultMapper? _instance;
  static RemoveDeviceResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RemoveDeviceResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'RemoveDeviceResult';

  static bool _$accountDeleted(RemoveDeviceResult v) => v.accountDeleted;
  static const Field<RemoveDeviceResult, bool> _f$accountDeleted = Field(
    'accountDeleted',
    _$accountDeleted,
  );

  @override
  final MappableFields<RemoveDeviceResult> fields = const {
    #accountDeleted: _f$accountDeleted,
  };

  static RemoveDeviceResult _instantiate(DecodingData data) {
    return RemoveDeviceResult(accountDeleted: data.dec(_f$accountDeleted));
  }

  @override
  final Function instantiate = _instantiate;

  static RemoveDeviceResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RemoveDeviceResult>(map);
  }

  static RemoveDeviceResult deserialize(String json) {
    return ensureInitialized().decodeJson<RemoveDeviceResult>(json);
  }
}

mixin RemoveDeviceResultMappable {
  String serialize() {
    return RemoveDeviceResultMapper.ensureInitialized()
        .encodeJson<RemoveDeviceResult>(this as RemoveDeviceResult);
  }

  Map<String, dynamic> toJson() {
    return RemoveDeviceResultMapper.ensureInitialized()
        .encodeMap<RemoveDeviceResult>(this as RemoveDeviceResult);
  }

  RemoveDeviceResultCopyWith<
    RemoveDeviceResult,
    RemoveDeviceResult,
    RemoveDeviceResult
  >
  get copyWith =>
      _RemoveDeviceResultCopyWithImpl<RemoveDeviceResult, RemoveDeviceResult>(
        this as RemoveDeviceResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RemoveDeviceResultMapper.ensureInitialized().stringifyValue(
      this as RemoveDeviceResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return RemoveDeviceResultMapper.ensureInitialized().equalsValue(
      this as RemoveDeviceResult,
      other,
    );
  }

  @override
  int get hashCode {
    return RemoveDeviceResultMapper.ensureInitialized().hashValue(
      this as RemoveDeviceResult,
    );
  }
}

extension RemoveDeviceResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RemoveDeviceResult, $Out> {
  RemoveDeviceResultCopyWith<$R, RemoveDeviceResult, $Out>
  get $asRemoveDeviceResult => $base.as(
    (v, t, t2) => _RemoveDeviceResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class RemoveDeviceResultCopyWith<
  $R,
  $In extends RemoveDeviceResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? accountDeleted});
  RemoveDeviceResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _RemoveDeviceResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RemoveDeviceResult, $Out>
    implements RemoveDeviceResultCopyWith<$R, RemoveDeviceResult, $Out> {
  _RemoveDeviceResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RemoveDeviceResult> $mapper =
      RemoveDeviceResultMapper.ensureInitialized();
  @override
  $R call({bool? accountDeleted}) => $apply(
    FieldCopyWithData({
      if (accountDeleted != null) #accountDeleted: accountDeleted,
    }),
  );
  @override
  RemoveDeviceResult $make(CopyWithData data) => RemoveDeviceResult(
    accountDeleted: data.get(#accountDeleted, or: $value.accountDeleted),
  );

  @override
  RemoveDeviceResultCopyWith<$R2, RemoveDeviceResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RemoveDeviceResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

