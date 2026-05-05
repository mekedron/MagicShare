// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'link_payload.dart';

class LinkPayloadMapper extends ClassMapperBase<LinkPayload> {
  LinkPayloadMapper._();

  static LinkPayloadMapper? _instance;
  static LinkPayloadMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LinkPayloadMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LinkPayload';

  static String _$url(LinkPayload v) => v.url;
  static const Field<LinkPayload, String> _f$url = Field('url', _$url);
  static String? _$title(LinkPayload v) => v.title;
  static const Field<LinkPayload, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );

  @override
  final MappableFields<LinkPayload> fields = const {
    #url: _f$url,
    #title: _f$title,
  };
  @override
  final bool ignoreNull = true;

  static LinkPayload _instantiate(DecodingData data) {
    return LinkPayload(url: data.dec(_f$url), title: data.dec(_f$title));
  }

  @override
  final Function instantiate = _instantiate;

  static LinkPayload fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LinkPayload>(map);
  }

  static LinkPayload deserialize(String json) {
    return ensureInitialized().decodeJson<LinkPayload>(json);
  }
}

mixin LinkPayloadMappable {
  String serialize() {
    return LinkPayloadMapper.ensureInitialized().encodeJson<LinkPayload>(
      this as LinkPayload,
    );
  }

  Map<String, dynamic> toJson() {
    return LinkPayloadMapper.ensureInitialized().encodeMap<LinkPayload>(
      this as LinkPayload,
    );
  }

  LinkPayloadCopyWith<LinkPayload, LinkPayload, LinkPayload> get copyWith =>
      _LinkPayloadCopyWithImpl<LinkPayload, LinkPayload>(
        this as LinkPayload,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LinkPayloadMapper.ensureInitialized().stringifyValue(
      this as LinkPayload,
    );
  }

  @override
  bool operator ==(Object other) {
    return LinkPayloadMapper.ensureInitialized().equalsValue(
      this as LinkPayload,
      other,
    );
  }

  @override
  int get hashCode {
    return LinkPayloadMapper.ensureInitialized().hashValue(this as LinkPayload);
  }
}

extension LinkPayloadValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LinkPayload, $Out> {
  LinkPayloadCopyWith<$R, LinkPayload, $Out> get $asLinkPayload =>
      $base.as((v, t, t2) => _LinkPayloadCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LinkPayloadCopyWith<$R, $In extends LinkPayload, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? url, String? title});
  LinkPayloadCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LinkPayloadCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LinkPayload, $Out>
    implements LinkPayloadCopyWith<$R, LinkPayload, $Out> {
  _LinkPayloadCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LinkPayload> $mapper =
      LinkPayloadMapper.ensureInitialized();
  @override
  $R call({String? url, Object? title = $none}) => $apply(
    FieldCopyWithData({
      if (url != null) #url: url,
      if (title != $none) #title: title,
    }),
  );
  @override
  LinkPayload $make(CopyWithData data) => LinkPayload(
    url: data.get(#url, or: $value.url),
    title: data.get(#title, or: $value.title),
  );

  @override
  LinkPayloadCopyWith<$R2, LinkPayload, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LinkPayloadCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

