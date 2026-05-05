// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'wake_payload.dart';

class WakePayloadMapper extends ClassMapperBase<WakePayload> {
  WakePayloadMapper._();

  static WakePayloadMapper? _instance;
  static WakePayloadMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = WakePayloadMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'WakePayload';

  static String _$sessionNonce(WakePayload v) => v.sessionNonce;
  static const Field<WakePayload, String> _f$sessionNonce = Field(
    'sessionNonce',
    _$sessionNonce,
  );
  static String _$sourceFingerprint(WakePayload v) => v.sourceFingerprint;
  static const Field<WakePayload, String> _f$sourceFingerprint = Field(
    'sourceFingerprint',
    _$sourceFingerprint,
  );
  static int _$initiatedAtMs(WakePayload v) => v.initiatedAtMs;
  static const Field<WakePayload, int> _f$initiatedAtMs = Field(
    'initiatedAtMs',
    _$initiatedAtMs,
  );

  @override
  final MappableFields<WakePayload> fields = const {
    #sessionNonce: _f$sessionNonce,
    #sourceFingerprint: _f$sourceFingerprint,
    #initiatedAtMs: _f$initiatedAtMs,
  };

  static WakePayload _instantiate(DecodingData data) {
    return WakePayload(
      sessionNonce: data.dec(_f$sessionNonce),
      sourceFingerprint: data.dec(_f$sourceFingerprint),
      initiatedAtMs: data.dec(_f$initiatedAtMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static WakePayload fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<WakePayload>(map);
  }

  static WakePayload deserialize(String json) {
    return ensureInitialized().decodeJson<WakePayload>(json);
  }
}

mixin WakePayloadMappable {
  String serialize() {
    return WakePayloadMapper.ensureInitialized().encodeJson<WakePayload>(
      this as WakePayload,
    );
  }

  Map<String, dynamic> toJson() {
    return WakePayloadMapper.ensureInitialized().encodeMap<WakePayload>(
      this as WakePayload,
    );
  }

  WakePayloadCopyWith<WakePayload, WakePayload, WakePayload> get copyWith =>
      _WakePayloadCopyWithImpl<WakePayload, WakePayload>(
        this as WakePayload,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return WakePayloadMapper.ensureInitialized().stringifyValue(
      this as WakePayload,
    );
  }

  @override
  bool operator ==(Object other) {
    return WakePayloadMapper.ensureInitialized().equalsValue(
      this as WakePayload,
      other,
    );
  }

  @override
  int get hashCode {
    return WakePayloadMapper.ensureInitialized().hashValue(this as WakePayload);
  }
}

extension WakePayloadValueCopy<$R, $Out>
    on ObjectCopyWith<$R, WakePayload, $Out> {
  WakePayloadCopyWith<$R, WakePayload, $Out> get $asWakePayload =>
      $base.as((v, t, t2) => _WakePayloadCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class WakePayloadCopyWith<$R, $In extends WakePayload, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? sessionNonce,
    String? sourceFingerprint,
    int? initiatedAtMs,
  });
  WakePayloadCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _WakePayloadCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, WakePayload, $Out>
    implements WakePayloadCopyWith<$R, WakePayload, $Out> {
  _WakePayloadCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<WakePayload> $mapper =
      WakePayloadMapper.ensureInitialized();
  @override
  $R call({
    String? sessionNonce,
    String? sourceFingerprint,
    int? initiatedAtMs,
  }) => $apply(
    FieldCopyWithData({
      if (sessionNonce != null) #sessionNonce: sessionNonce,
      if (sourceFingerprint != null) #sourceFingerprint: sourceFingerprint,
      if (initiatedAtMs != null) #initiatedAtMs: initiatedAtMs,
    }),
  );
  @override
  WakePayload $make(CopyWithData data) => WakePayload(
    sessionNonce: data.get(#sessionNonce, or: $value.sessionNonce),
    sourceFingerprint: data.get(
      #sourceFingerprint,
      or: $value.sourceFingerprint,
    ),
    initiatedAtMs: data.get(#initiatedAtMs, or: $value.initiatedAtMs),
  );

  @override
  WakePayloadCopyWith<$R2, WakePayload, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _WakePayloadCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

