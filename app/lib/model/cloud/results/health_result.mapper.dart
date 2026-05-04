// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'health_result.dart';

class HealthResultMapper extends ClassMapperBase<HealthResult> {
  HealthResultMapper._();

  static HealthResultMapper? _instance;
  static HealthResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HealthResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'HealthResult';

  static bool _$ok(HealthResult v) => v.ok;
  static const Field<HealthResult, bool> _f$ok = Field('ok', _$ok);
  static String _$service(HealthResult v) => v.service;
  static const Field<HealthResult, String> _f$service = Field(
    'service',
    _$service,
  );
  static String _$version(HealthResult v) => v.version;
  static const Field<HealthResult, String> _f$version = Field(
    'version',
    _$version,
  );

  @override
  final MappableFields<HealthResult> fields = const {
    #ok: _f$ok,
    #service: _f$service,
    #version: _f$version,
  };

  static HealthResult _instantiate(DecodingData data) {
    return HealthResult(
      ok: data.dec(_f$ok),
      service: data.dec(_f$service),
      version: data.dec(_f$version),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HealthResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HealthResult>(map);
  }

  static HealthResult deserialize(String json) {
    return ensureInitialized().decodeJson<HealthResult>(json);
  }
}

mixin HealthResultMappable {
  String serialize() {
    return HealthResultMapper.ensureInitialized().encodeJson<HealthResult>(
      this as HealthResult,
    );
  }

  Map<String, dynamic> toJson() {
    return HealthResultMapper.ensureInitialized().encodeMap<HealthResult>(
      this as HealthResult,
    );
  }

  HealthResultCopyWith<HealthResult, HealthResult, HealthResult> get copyWith =>
      _HealthResultCopyWithImpl<HealthResult, HealthResult>(
        this as HealthResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HealthResultMapper.ensureInitialized().stringifyValue(
      this as HealthResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return HealthResultMapper.ensureInitialized().equalsValue(
      this as HealthResult,
      other,
    );
  }

  @override
  int get hashCode {
    return HealthResultMapper.ensureInitialized().hashValue(
      this as HealthResult,
    );
  }
}

extension HealthResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, HealthResult, $Out> {
  HealthResultCopyWith<$R, HealthResult, $Out> get $asHealthResult =>
      $base.as((v, t, t2) => _HealthResultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HealthResultCopyWith<$R, $In extends HealthResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? ok, String? service, String? version});
  HealthResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HealthResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, HealthResult, $Out>
    implements HealthResultCopyWith<$R, HealthResult, $Out> {
  _HealthResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HealthResult> $mapper =
      HealthResultMapper.ensureInitialized();
  @override
  $R call({bool? ok, String? service, String? version}) => $apply(
    FieldCopyWithData({
      if (ok != null) #ok: ok,
      if (service != null) #service: service,
      if (version != null) #version: version,
    }),
  );
  @override
  HealthResult $make(CopyWithData data) => HealthResult(
    ok: data.get(#ok, or: $value.ok),
    service: data.get(#service, or: $value.service),
    version: data.get(#version, or: $value.version),
  );

  @override
  HealthResultCopyWith<$R2, HealthResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _HealthResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

