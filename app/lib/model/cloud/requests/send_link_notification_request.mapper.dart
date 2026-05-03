// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'send_link_notification_request.dart';

class SendLinkNotificationRequestMapper
    extends ClassMapperBase<SendLinkNotificationRequest> {
  SendLinkNotificationRequestMapper._();

  static SendLinkNotificationRequestMapper? _instance;
  static SendLinkNotificationRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = SendLinkNotificationRequestMapper._(),
      );
      PlaintextLinkNotificationRequestMapper.ensureInitialized();
      EncryptedLinkNotificationRequestMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SendLinkNotificationRequest';

  static String _$sourceDeviceId(SendLinkNotificationRequest v) =>
      v.sourceDeviceId;
  static const Field<SendLinkNotificationRequest, String> _f$sourceDeviceId =
      Field('sourceDeviceId', _$sourceDeviceId);
  static String _$targetDeviceId(SendLinkNotificationRequest v) =>
      v.targetDeviceId;
  static const Field<SendLinkNotificationRequest, String> _f$targetDeviceId =
      Field('targetDeviceId', _$targetDeviceId);

  @override
  final MappableFields<SendLinkNotificationRequest> fields = const {
    #sourceDeviceId: _f$sourceDeviceId,
    #targetDeviceId: _f$targetDeviceId,
  };

  static SendLinkNotificationRequest _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'SendLinkNotificationRequest',
      'mode',
      '${data.value['mode']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SendLinkNotificationRequest fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SendLinkNotificationRequest>(map);
  }

  static SendLinkNotificationRequest deserialize(String json) {
    return ensureInitialized().decodeJson<SendLinkNotificationRequest>(json);
  }
}

mixin SendLinkNotificationRequestMappable {
  String serialize();
  Map<String, dynamic> toJson();
  SendLinkNotificationRequestCopyWith<
    SendLinkNotificationRequest,
    SendLinkNotificationRequest,
    SendLinkNotificationRequest
  >
  get copyWith;
}

abstract class SendLinkNotificationRequestCopyWith<
  $R,
  $In extends SendLinkNotificationRequest,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? sourceDeviceId, String? targetDeviceId});
  SendLinkNotificationRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class PlaintextLinkNotificationRequestMapper
    extends SubClassMapperBase<PlaintextLinkNotificationRequest> {
  PlaintextLinkNotificationRequestMapper._();

  static PlaintextLinkNotificationRequestMapper? _instance;
  static PlaintextLinkNotificationRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = PlaintextLinkNotificationRequestMapper._(),
      );
      SendLinkNotificationRequestMapper.ensureInitialized().addSubMapper(
        _instance!,
      );
    }
    return _instance!;
  }

  @override
  final String id = 'PlaintextLinkNotificationRequest';

  static String _$sourceDeviceId(PlaintextLinkNotificationRequest v) =>
      v.sourceDeviceId;
  static const Field<PlaintextLinkNotificationRequest, String>
  _f$sourceDeviceId = Field('sourceDeviceId', _$sourceDeviceId);
  static String _$targetDeviceId(PlaintextLinkNotificationRequest v) =>
      v.targetDeviceId;
  static const Field<PlaintextLinkNotificationRequest, String>
  _f$targetDeviceId = Field('targetDeviceId', _$targetDeviceId);
  static String _$url(PlaintextLinkNotificationRequest v) => v.url;
  static const Field<PlaintextLinkNotificationRequest, String> _f$url = Field(
    'url',
    _$url,
  );
  static String? _$title(PlaintextLinkNotificationRequest v) => v.title;
  static const Field<PlaintextLinkNotificationRequest, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );

  @override
  final MappableFields<PlaintextLinkNotificationRequest> fields = const {
    #sourceDeviceId: _f$sourceDeviceId,
    #targetDeviceId: _f$targetDeviceId,
    #url: _f$url,
    #title: _f$title,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'mode';
  @override
  final dynamic discriminatorValue = 'plaintext';
  @override
  late final ClassMapperBase superMapper =
      SendLinkNotificationRequestMapper.ensureInitialized();

  static PlaintextLinkNotificationRequest _instantiate(DecodingData data) {
    return PlaintextLinkNotificationRequest(
      sourceDeviceId: data.dec(_f$sourceDeviceId),
      targetDeviceId: data.dec(_f$targetDeviceId),
      url: data.dec(_f$url),
      title: data.dec(_f$title),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlaintextLinkNotificationRequest fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlaintextLinkNotificationRequest>(map);
  }

  static PlaintextLinkNotificationRequest deserialize(String json) {
    return ensureInitialized().decodeJson<PlaintextLinkNotificationRequest>(
      json,
    );
  }
}

mixin PlaintextLinkNotificationRequestMappable {
  String serialize() {
    return PlaintextLinkNotificationRequestMapper.ensureInitialized()
        .encodeJson<PlaintextLinkNotificationRequest>(
          this as PlaintextLinkNotificationRequest,
        );
  }

  Map<String, dynamic> toJson() {
    return PlaintextLinkNotificationRequestMapper.ensureInitialized()
        .encodeMap<PlaintextLinkNotificationRequest>(
          this as PlaintextLinkNotificationRequest,
        );
  }

  PlaintextLinkNotificationRequestCopyWith<
    PlaintextLinkNotificationRequest,
    PlaintextLinkNotificationRequest,
    PlaintextLinkNotificationRequest
  >
  get copyWith =>
      _PlaintextLinkNotificationRequestCopyWithImpl<
        PlaintextLinkNotificationRequest,
        PlaintextLinkNotificationRequest
      >(this as PlaintextLinkNotificationRequest, $identity, $identity);
  @override
  String toString() {
    return PlaintextLinkNotificationRequestMapper.ensureInitialized()
        .stringifyValue(this as PlaintextLinkNotificationRequest);
  }

  @override
  bool operator ==(Object other) {
    return PlaintextLinkNotificationRequestMapper.ensureInitialized()
        .equalsValue(this as PlaintextLinkNotificationRequest, other);
  }

  @override
  int get hashCode {
    return PlaintextLinkNotificationRequestMapper.ensureInitialized().hashValue(
      this as PlaintextLinkNotificationRequest,
    );
  }
}

extension PlaintextLinkNotificationRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PlaintextLinkNotificationRequest, $Out> {
  PlaintextLinkNotificationRequestCopyWith<
    $R,
    PlaintextLinkNotificationRequest,
    $Out
  >
  get $asPlaintextLinkNotificationRequest => $base.as(
    (v, t, t2) =>
        _PlaintextLinkNotificationRequestCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PlaintextLinkNotificationRequestCopyWith<
  $R,
  $In extends PlaintextLinkNotificationRequest,
  $Out
>
    implements SendLinkNotificationRequestCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? sourceDeviceId,
    String? targetDeviceId,
    String? url,
    String? title,
  });
  PlaintextLinkNotificationRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PlaintextLinkNotificationRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PlaintextLinkNotificationRequest, $Out>
    implements
        PlaintextLinkNotificationRequestCopyWith<
          $R,
          PlaintextLinkNotificationRequest,
          $Out
        > {
  _PlaintextLinkNotificationRequestCopyWithImpl(
    super.value,
    super.then,
    super.then2,
  );

  @override
  late final ClassMapperBase<PlaintextLinkNotificationRequest> $mapper =
      PlaintextLinkNotificationRequestMapper.ensureInitialized();
  @override
  $R call({
    String? sourceDeviceId,
    String? targetDeviceId,
    String? url,
    Object? title = $none,
  }) => $apply(
    FieldCopyWithData({
      if (sourceDeviceId != null) #sourceDeviceId: sourceDeviceId,
      if (targetDeviceId != null) #targetDeviceId: targetDeviceId,
      if (url != null) #url: url,
      if (title != $none) #title: title,
    }),
  );
  @override
  PlaintextLinkNotificationRequest $make(CopyWithData data) =>
      PlaintextLinkNotificationRequest(
        sourceDeviceId: data.get(#sourceDeviceId, or: $value.sourceDeviceId),
        targetDeviceId: data.get(#targetDeviceId, or: $value.targetDeviceId),
        url: data.get(#url, or: $value.url),
        title: data.get(#title, or: $value.title),
      );

  @override
  PlaintextLinkNotificationRequestCopyWith<
    $R2,
    PlaintextLinkNotificationRequest,
    $Out2
  >
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PlaintextLinkNotificationRequestCopyWithImpl<$R2, $Out2>(
        $value,
        $cast,
        t,
      );
}

class EncryptedLinkNotificationRequestMapper
    extends SubClassMapperBase<EncryptedLinkNotificationRequest> {
  EncryptedLinkNotificationRequestMapper._();

  static EncryptedLinkNotificationRequestMapper? _instance;
  static EncryptedLinkNotificationRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = EncryptedLinkNotificationRequestMapper._(),
      );
      SendLinkNotificationRequestMapper.ensureInitialized().addSubMapper(
        _instance!,
      );
    }
    return _instance!;
  }

  @override
  final String id = 'EncryptedLinkNotificationRequest';

  static String _$sourceDeviceId(EncryptedLinkNotificationRequest v) =>
      v.sourceDeviceId;
  static const Field<EncryptedLinkNotificationRequest, String>
  _f$sourceDeviceId = Field('sourceDeviceId', _$sourceDeviceId);
  static String _$targetDeviceId(EncryptedLinkNotificationRequest v) =>
      v.targetDeviceId;
  static const Field<EncryptedLinkNotificationRequest, String>
  _f$targetDeviceId = Field('targetDeviceId', _$targetDeviceId);
  static String _$payload(EncryptedLinkNotificationRequest v) => v.payload;
  static const Field<EncryptedLinkNotificationRequest, String> _f$payload =
      Field('payload', _$payload);

  @override
  final MappableFields<EncryptedLinkNotificationRequest> fields = const {
    #sourceDeviceId: _f$sourceDeviceId,
    #targetDeviceId: _f$targetDeviceId,
    #payload: _f$payload,
  };

  @override
  final String discriminatorKey = 'mode';
  @override
  final dynamic discriminatorValue = 'encrypted';
  @override
  late final ClassMapperBase superMapper =
      SendLinkNotificationRequestMapper.ensureInitialized();

  static EncryptedLinkNotificationRequest _instantiate(DecodingData data) {
    return EncryptedLinkNotificationRequest(
      sourceDeviceId: data.dec(_f$sourceDeviceId),
      targetDeviceId: data.dec(_f$targetDeviceId),
      payload: data.dec(_f$payload),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EncryptedLinkNotificationRequest fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EncryptedLinkNotificationRequest>(map);
  }

  static EncryptedLinkNotificationRequest deserialize(String json) {
    return ensureInitialized().decodeJson<EncryptedLinkNotificationRequest>(
      json,
    );
  }
}

mixin EncryptedLinkNotificationRequestMappable {
  String serialize() {
    return EncryptedLinkNotificationRequestMapper.ensureInitialized()
        .encodeJson<EncryptedLinkNotificationRequest>(
          this as EncryptedLinkNotificationRequest,
        );
  }

  Map<String, dynamic> toJson() {
    return EncryptedLinkNotificationRequestMapper.ensureInitialized()
        .encodeMap<EncryptedLinkNotificationRequest>(
          this as EncryptedLinkNotificationRequest,
        );
  }

  EncryptedLinkNotificationRequestCopyWith<
    EncryptedLinkNotificationRequest,
    EncryptedLinkNotificationRequest,
    EncryptedLinkNotificationRequest
  >
  get copyWith =>
      _EncryptedLinkNotificationRequestCopyWithImpl<
        EncryptedLinkNotificationRequest,
        EncryptedLinkNotificationRequest
      >(this as EncryptedLinkNotificationRequest, $identity, $identity);
  @override
  String toString() {
    return EncryptedLinkNotificationRequestMapper.ensureInitialized()
        .stringifyValue(this as EncryptedLinkNotificationRequest);
  }

  @override
  bool operator ==(Object other) {
    return EncryptedLinkNotificationRequestMapper.ensureInitialized()
        .equalsValue(this as EncryptedLinkNotificationRequest, other);
  }

  @override
  int get hashCode {
    return EncryptedLinkNotificationRequestMapper.ensureInitialized().hashValue(
      this as EncryptedLinkNotificationRequest,
    );
  }
}

extension EncryptedLinkNotificationRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EncryptedLinkNotificationRequest, $Out> {
  EncryptedLinkNotificationRequestCopyWith<
    $R,
    EncryptedLinkNotificationRequest,
    $Out
  >
  get $asEncryptedLinkNotificationRequest => $base.as(
    (v, t, t2) =>
        _EncryptedLinkNotificationRequestCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class EncryptedLinkNotificationRequestCopyWith<
  $R,
  $In extends EncryptedLinkNotificationRequest,
  $Out
>
    implements SendLinkNotificationRequestCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sourceDeviceId, String? targetDeviceId, String? payload});
  EncryptedLinkNotificationRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EncryptedLinkNotificationRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EncryptedLinkNotificationRequest, $Out>
    implements
        EncryptedLinkNotificationRequestCopyWith<
          $R,
          EncryptedLinkNotificationRequest,
          $Out
        > {
  _EncryptedLinkNotificationRequestCopyWithImpl(
    super.value,
    super.then,
    super.then2,
  );

  @override
  late final ClassMapperBase<EncryptedLinkNotificationRequest> $mapper =
      EncryptedLinkNotificationRequestMapper.ensureInitialized();
  @override
  $R call({String? sourceDeviceId, String? targetDeviceId, String? payload}) =>
      $apply(
        FieldCopyWithData({
          if (sourceDeviceId != null) #sourceDeviceId: sourceDeviceId,
          if (targetDeviceId != null) #targetDeviceId: targetDeviceId,
          if (payload != null) #payload: payload,
        }),
      );
  @override
  EncryptedLinkNotificationRequest $make(CopyWithData data) =>
      EncryptedLinkNotificationRequest(
        sourceDeviceId: data.get(#sourceDeviceId, or: $value.sourceDeviceId),
        targetDeviceId: data.get(#targetDeviceId, or: $value.targetDeviceId),
        payload: data.get(#payload, or: $value.payload),
      );

  @override
  EncryptedLinkNotificationRequestCopyWith<
    $R2,
    EncryptedLinkNotificationRequest,
    $Out2
  >
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _EncryptedLinkNotificationRequestCopyWithImpl<$R2, $Out2>(
        $value,
        $cast,
        t,
      );
}

