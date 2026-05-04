// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'create_account_result.dart';

class CreateAccountResultMapper extends ClassMapperBase<CreateAccountResult> {
  CreateAccountResultMapper._();

  static CreateAccountResultMapper? _instance;
  static CreateAccountResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreateAccountResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CreateAccountResult';

  static bool _$created(CreateAccountResult v) => v.created;
  static const Field<CreateAccountResult, bool> _f$created = Field(
    'created',
    _$created,
  );
  static String _$accountId(CreateAccountResult v) => v.accountId;
  static const Field<CreateAccountResult, String> _f$accountId = Field(
    'accountId',
    _$accountId,
  );

  @override
  final MappableFields<CreateAccountResult> fields = const {
    #created: _f$created,
    #accountId: _f$accountId,
  };

  static CreateAccountResult _instantiate(DecodingData data) {
    return CreateAccountResult(
      created: data.dec(_f$created),
      accountId: data.dec(_f$accountId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreateAccountResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreateAccountResult>(map);
  }

  static CreateAccountResult deserialize(String json) {
    return ensureInitialized().decodeJson<CreateAccountResult>(json);
  }
}

mixin CreateAccountResultMappable {
  String serialize() {
    return CreateAccountResultMapper.ensureInitialized()
        .encodeJson<CreateAccountResult>(this as CreateAccountResult);
  }

  Map<String, dynamic> toJson() {
    return CreateAccountResultMapper.ensureInitialized()
        .encodeMap<CreateAccountResult>(this as CreateAccountResult);
  }

  CreateAccountResultCopyWith<
    CreateAccountResult,
    CreateAccountResult,
    CreateAccountResult
  >
  get copyWith =>
      _CreateAccountResultCopyWithImpl<
        CreateAccountResult,
        CreateAccountResult
      >(this as CreateAccountResult, $identity, $identity);
  @override
  String toString() {
    return CreateAccountResultMapper.ensureInitialized().stringifyValue(
      this as CreateAccountResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreateAccountResultMapper.ensureInitialized().equalsValue(
      this as CreateAccountResult,
      other,
    );
  }

  @override
  int get hashCode {
    return CreateAccountResultMapper.ensureInitialized().hashValue(
      this as CreateAccountResult,
    );
  }
}

extension CreateAccountResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreateAccountResult, $Out> {
  CreateAccountResultCopyWith<$R, CreateAccountResult, $Out>
  get $asCreateAccountResult => $base.as(
    (v, t, t2) => _CreateAccountResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CreateAccountResultCopyWith<
  $R,
  $In extends CreateAccountResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? created, String? accountId});
  CreateAccountResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreateAccountResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreateAccountResult, $Out>
    implements CreateAccountResultCopyWith<$R, CreateAccountResult, $Out> {
  _CreateAccountResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreateAccountResult> $mapper =
      CreateAccountResultMapper.ensureInitialized();
  @override
  $R call({bool? created, String? accountId}) => $apply(
    FieldCopyWithData({
      if (created != null) #created: created,
      if (accountId != null) #accountId: accountId,
    }),
  );
  @override
  CreateAccountResult $make(CopyWithData data) => CreateAccountResult(
    created: data.get(#created, or: $value.created),
    accountId: data.get(#accountId, or: $value.accountId),
  );

  @override
  CreateAccountResultCopyWith<$R2, CreateAccountResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _CreateAccountResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

