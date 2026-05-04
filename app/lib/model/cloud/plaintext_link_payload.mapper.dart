// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'plaintext_link_payload.dart';

class PlaintextLinkPayloadMapper extends ClassMapperBase<PlaintextLinkPayload> {
  PlaintextLinkPayloadMapper._();

  static PlaintextLinkPayloadMapper? _instance;
  static PlaintextLinkPayloadMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PlaintextLinkPayloadMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PlaintextLinkPayload';

  static String _$url(PlaintextLinkPayload v) => v.url;
  static const Field<PlaintextLinkPayload, String> _f$url = Field('url', _$url);
  static String? _$title(PlaintextLinkPayload v) => v.title;
  static const Field<PlaintextLinkPayload, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );

  @override
  final MappableFields<PlaintextLinkPayload> fields = const {
    #url: _f$url,
    #title: _f$title,
  };
  @override
  final bool ignoreNull = true;

  static PlaintextLinkPayload _instantiate(DecodingData data) {
    return PlaintextLinkPayload(
      url: data.dec(_f$url),
      title: data.dec(_f$title),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlaintextLinkPayload fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlaintextLinkPayload>(map);
  }

  static PlaintextLinkPayload deserialize(String json) {
    return ensureInitialized().decodeJson<PlaintextLinkPayload>(json);
  }
}

mixin PlaintextLinkPayloadMappable {
  String serialize() {
    return PlaintextLinkPayloadMapper.ensureInitialized()
        .encodeJson<PlaintextLinkPayload>(this as PlaintextLinkPayload);
  }

  Map<String, dynamic> toJson() {
    return PlaintextLinkPayloadMapper.ensureInitialized()
        .encodeMap<PlaintextLinkPayload>(this as PlaintextLinkPayload);
  }

  PlaintextLinkPayloadCopyWith<
    PlaintextLinkPayload,
    PlaintextLinkPayload,
    PlaintextLinkPayload
  >
  get copyWith =>
      _PlaintextLinkPayloadCopyWithImpl<
        PlaintextLinkPayload,
        PlaintextLinkPayload
      >(this as PlaintextLinkPayload, $identity, $identity);
  @override
  String toString() {
    return PlaintextLinkPayloadMapper.ensureInitialized().stringifyValue(
      this as PlaintextLinkPayload,
    );
  }

  @override
  bool operator ==(Object other) {
    return PlaintextLinkPayloadMapper.ensureInitialized().equalsValue(
      this as PlaintextLinkPayload,
      other,
    );
  }

  @override
  int get hashCode {
    return PlaintextLinkPayloadMapper.ensureInitialized().hashValue(
      this as PlaintextLinkPayload,
    );
  }
}

extension PlaintextLinkPayloadValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PlaintextLinkPayload, $Out> {
  PlaintextLinkPayloadCopyWith<$R, PlaintextLinkPayload, $Out>
  get $asPlaintextLinkPayload => $base.as(
    (v, t, t2) => _PlaintextLinkPayloadCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PlaintextLinkPayloadCopyWith<
  $R,
  $In extends PlaintextLinkPayload,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? title});
  PlaintextLinkPayloadCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PlaintextLinkPayloadCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PlaintextLinkPayload, $Out>
    implements PlaintextLinkPayloadCopyWith<$R, PlaintextLinkPayload, $Out> {
  _PlaintextLinkPayloadCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PlaintextLinkPayload> $mapper =
      PlaintextLinkPayloadMapper.ensureInitialized();
  @override
  $R call({String? url, Object? title = $none}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (title != $none) #title: title,
    }),
  );
  @override
  PlaintextLinkPayload $make(CopyWithData data) => PlaintextLinkPayload(
    url: data.get(#url, or: $value.url),
    title: data.get(#title, or: $value.title),
  );

  @override
  PlaintextLinkPayloadCopyWith<$R2, PlaintextLinkPayload, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PlaintextLinkPayloadCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

