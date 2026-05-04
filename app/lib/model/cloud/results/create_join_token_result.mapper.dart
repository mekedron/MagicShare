// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'create_join_token_result.dart';

class CreateJoinTokenResultMapper
    extends ClassMapperBase<CreateJoinTokenResult> {
  CreateJoinTokenResultMapper._();

  static CreateJoinTokenResultMapper? _instance;
  static CreateJoinTokenResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreateJoinTokenResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CreateJoinTokenResult';

  static String _$tokenId(CreateJoinTokenResult v) => v.tokenId;
  static const Field<CreateJoinTokenResult, String> _f$tokenId = Field(
    'tokenId',
    _$tokenId,
  );
  static int _$expiresAtMs(CreateJoinTokenResult v) => v.expiresAtMs;
  static const Field<CreateJoinTokenResult, int> _f$expiresAtMs = Field(
    'expiresAtMs',
    _$expiresAtMs,
  );

  @override
  final MappableFields<CreateJoinTokenResult> fields = const {
    #tokenId: _f$tokenId,
    #expiresAtMs: _f$expiresAtMs,
  };

  static CreateJoinTokenResult _instantiate(DecodingData data) {
    return CreateJoinTokenResult(
      tokenId: data.dec(_f$tokenId),
      expiresAtMs: data.dec(_f$expiresAtMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreateJoinTokenResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreateJoinTokenResult>(map);
  }

  static CreateJoinTokenResult deserialize(String json) {
    return ensureInitialized().decodeJson<CreateJoinTokenResult>(json);
  }
}

mixin CreateJoinTokenResultMappable {
  String serialize() {
    return CreateJoinTokenResultMapper.ensureInitialized()
        .encodeJson<CreateJoinTokenResult>(this as CreateJoinTokenResult);
  }

  Map<String, dynamic> toJson() {
    return CreateJoinTokenResultMapper.ensureInitialized()
        .encodeMap<CreateJoinTokenResult>(this as CreateJoinTokenResult);
  }

  CreateJoinTokenResultCopyWith<
    CreateJoinTokenResult,
    CreateJoinTokenResult,
    CreateJoinTokenResult
  >
  get copyWith =>
      _CreateJoinTokenResultCopyWithImpl<
        CreateJoinTokenResult,
        CreateJoinTokenResult
      >(this as CreateJoinTokenResult, $identity, $identity);
  @override
  String toString() {
    return CreateJoinTokenResultMapper.ensureInitialized().stringifyValue(
      this as CreateJoinTokenResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreateJoinTokenResultMapper.ensureInitialized().equalsValue(
      this as CreateJoinTokenResult,
      other,
    );
  }

  @override
  int get hashCode {
    return CreateJoinTokenResultMapper.ensureInitialized().hashValue(
      this as CreateJoinTokenResult,
    );
  }
}

extension CreateJoinTokenResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreateJoinTokenResult, $Out> {
  CreateJoinTokenResultCopyWith<$R, CreateJoinTokenResult, $Out>
  get $asCreateJoinTokenResult => $base.as(
    (v, t, t2) => _CreateJoinTokenResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CreateJoinTokenResultCopyWith<
  $R,
  $In extends CreateJoinTokenResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? tokenId, int? expiresAtMs});
  CreateJoinTokenResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreateJoinTokenResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreateJoinTokenResult, $Out>
    implements CreateJoinTokenResultCopyWith<$R, CreateJoinTokenResult, $Out> {
  _CreateJoinTokenResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreateJoinTokenResult> $mapper =
      CreateJoinTokenResultMapper.ensureInitialized();
  @override
  $R call({String? tokenId, int? expiresAtMs}) => $apply(
    FieldCopyWithData({
      if (tokenId != null) #tokenId: tokenId,
      if (expiresAtMs != null) #expiresAtMs: expiresAtMs,
    }),
  );
  @override
  CreateJoinTokenResult $make(CopyWithData data) => CreateJoinTokenResult(
    tokenId: data.get(#tokenId, or: $value.tokenId),
    expiresAtMs: data.get(#expiresAtMs, or: $value.expiresAtMs),
  );

  @override
  CreateJoinTokenResultCopyWith<$R2, CreateJoinTokenResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _CreateJoinTokenResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

