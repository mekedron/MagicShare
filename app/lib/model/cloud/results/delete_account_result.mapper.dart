// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'delete_account_result.dart';

class DeleteAccountResultMapper extends ClassMapperBase<DeleteAccountResult> {
  DeleteAccountResultMapper._();

  static DeleteAccountResultMapper? _instance;
  static DeleteAccountResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeleteAccountResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DeleteAccountResult';

  static bool _$deleted(DeleteAccountResult v) => v.deleted;
  static const Field<DeleteAccountResult, bool> _f$deleted = Field(
    'deleted',
    _$deleted,
  );

  @override
  final MappableFields<DeleteAccountResult> fields = const {
    #deleted: _f$deleted,
  };

  static DeleteAccountResult _instantiate(DecodingData data) {
    return DeleteAccountResult(deleted: data.dec(_f$deleted));
  }

  @override
  final Function instantiate = _instantiate;

  static DeleteAccountResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DeleteAccountResult>(map);
  }

  static DeleteAccountResult deserialize(String json) {
    return ensureInitialized().decodeJson<DeleteAccountResult>(json);
  }
}

mixin DeleteAccountResultMappable {
  String serialize() {
    return DeleteAccountResultMapper.ensureInitialized()
        .encodeJson<DeleteAccountResult>(this as DeleteAccountResult);
  }

  Map<String, dynamic> toJson() {
    return DeleteAccountResultMapper.ensureInitialized()
        .encodeMap<DeleteAccountResult>(this as DeleteAccountResult);
  }

  DeleteAccountResultCopyWith<
    DeleteAccountResult,
    DeleteAccountResult,
    DeleteAccountResult
  >
  get copyWith =>
      _DeleteAccountResultCopyWithImpl<
        DeleteAccountResult,
        DeleteAccountResult
      >(this as DeleteAccountResult, $identity, $identity);
  @override
  String toString() {
    return DeleteAccountResultMapper.ensureInitialized().stringifyValue(
      this as DeleteAccountResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return DeleteAccountResultMapper.ensureInitialized().equalsValue(
      this as DeleteAccountResult,
      other,
    );
  }

  @override
  int get hashCode {
    return DeleteAccountResultMapper.ensureInitialized().hashValue(
      this as DeleteAccountResult,
    );
  }
}

extension DeleteAccountResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DeleteAccountResult, $Out> {
  DeleteAccountResultCopyWith<$R, DeleteAccountResult, $Out>
  get $asDeleteAccountResult => $base.as(
    (v, t, t2) => _DeleteAccountResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DeleteAccountResultCopyWith<
  $R,
  $In extends DeleteAccountResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? deleted});
  DeleteAccountResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DeleteAccountResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DeleteAccountResult, $Out>
    implements DeleteAccountResultCopyWith<$R, DeleteAccountResult, $Out> {
  _DeleteAccountResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DeleteAccountResult> $mapper =
      DeleteAccountResultMapper.ensureInitialized();
  @override
  $R call({bool? deleted}) =>
      $apply(FieldCopyWithData({if (deleted != null) #deleted: deleted}));
  @override
  DeleteAccountResult $make(CopyWithData data) =>
      DeleteAccountResult(deleted: data.get(#deleted, or: $value.deleted));

  @override
  DeleteAccountResultCopyWith<$R2, DeleteAccountResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _DeleteAccountResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

