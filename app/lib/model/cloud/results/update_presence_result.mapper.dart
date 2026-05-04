// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'update_presence_result.dart';

class UpdatePresenceResultMapper extends ClassMapperBase<UpdatePresenceResult> {
  UpdatePresenceResultMapper._();

  static UpdatePresenceResultMapper? _instance;
  static UpdatePresenceResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UpdatePresenceResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'UpdatePresenceResult';

  static bool _$updated(UpdatePresenceResult v) => v.updated;
  static const Field<UpdatePresenceResult, bool> _f$updated = Field(
    'updated',
    _$updated,
  );

  @override
  final MappableFields<UpdatePresenceResult> fields = const {
    #updated: _f$updated,
  };

  static UpdatePresenceResult _instantiate(DecodingData data) {
    return UpdatePresenceResult(updated: data.dec(_f$updated));
  }

  @override
  final Function instantiate = _instantiate;

  static UpdatePresenceResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<UpdatePresenceResult>(map);
  }

  static UpdatePresenceResult deserialize(String json) {
    return ensureInitialized().decodeJson<UpdatePresenceResult>(json);
  }
}

mixin UpdatePresenceResultMappable {
  String serialize() {
    return UpdatePresenceResultMapper.ensureInitialized()
        .encodeJson<UpdatePresenceResult>(this as UpdatePresenceResult);
  }

  Map<String, dynamic> toJson() {
    return UpdatePresenceResultMapper.ensureInitialized()
        .encodeMap<UpdatePresenceResult>(this as UpdatePresenceResult);
  }

  UpdatePresenceResultCopyWith<
    UpdatePresenceResult,
    UpdatePresenceResult,
    UpdatePresenceResult
  >
  get copyWith =>
      _UpdatePresenceResultCopyWithImpl<
        UpdatePresenceResult,
        UpdatePresenceResult
      >(this as UpdatePresenceResult, $identity, $identity);
  @override
  String toString() {
    return UpdatePresenceResultMapper.ensureInitialized().stringifyValue(
      this as UpdatePresenceResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return UpdatePresenceResultMapper.ensureInitialized().equalsValue(
      this as UpdatePresenceResult,
      other,
    );
  }

  @override
  int get hashCode {
    return UpdatePresenceResultMapper.ensureInitialized().hashValue(
      this as UpdatePresenceResult,
    );
  }
}

extension UpdatePresenceResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, UpdatePresenceResult, $Out> {
  UpdatePresenceResultCopyWith<$R, UpdatePresenceResult, $Out>
  get $asUpdatePresenceResult => $base.as(
    (v, t, t2) => _UpdatePresenceResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class UpdatePresenceResultCopyWith<
  $R,
  $In extends UpdatePresenceResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? updated});
  UpdatePresenceResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _UpdatePresenceResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, UpdatePresenceResult, $Out>
    implements UpdatePresenceResultCopyWith<$R, UpdatePresenceResult, $Out> {
  _UpdatePresenceResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<UpdatePresenceResult> $mapper =
      UpdatePresenceResultMapper.ensureInitialized();
  @override
  $R call({bool? updated}) =>
      $apply(FieldCopyWithData({if (updated != null) #updated: updated}));
  @override
  UpdatePresenceResult $make(CopyWithData data) =>
      UpdatePresenceResult(updated: data.get(#updated, or: $value.updated));

  @override
  UpdatePresenceResultCopyWith<$R2, UpdatePresenceResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _UpdatePresenceResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

