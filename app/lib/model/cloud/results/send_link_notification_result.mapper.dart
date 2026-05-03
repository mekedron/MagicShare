// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'send_link_notification_result.dart';

class SendLinkNotificationResultMapper
    extends ClassMapperBase<SendLinkNotificationResult> {
  SendLinkNotificationResultMapper._();

  static SendLinkNotificationResultMapper? _instance;
  static SendLinkNotificationResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = SendLinkNotificationResultMapper._(),
      );
      DeliveryChannelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SendLinkNotificationResult';

  static bool _$delivered(SendLinkNotificationResult v) => v.delivered;
  static const Field<SendLinkNotificationResult, bool> _f$delivered = Field(
    'delivered',
    _$delivered,
  );
  static DeliveryChannel _$channel(SendLinkNotificationResult v) => v.channel;
  static const Field<SendLinkNotificationResult, DeliveryChannel> _f$channel =
      Field('channel', _$channel);

  @override
  final MappableFields<SendLinkNotificationResult> fields = const {
    #delivered: _f$delivered,
    #channel: _f$channel,
  };

  static SendLinkNotificationResult _instantiate(DecodingData data) {
    return SendLinkNotificationResult(
      delivered: data.dec(_f$delivered),
      channel: data.dec(_f$channel),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SendLinkNotificationResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SendLinkNotificationResult>(map);
  }

  static SendLinkNotificationResult deserialize(String json) {
    return ensureInitialized().decodeJson<SendLinkNotificationResult>(json);
  }
}

mixin SendLinkNotificationResultMappable {
  String serialize() {
    return SendLinkNotificationResultMapper.ensureInitialized()
        .encodeJson<SendLinkNotificationResult>(
          this as SendLinkNotificationResult,
        );
  }

  Map<String, dynamic> toJson() {
    return SendLinkNotificationResultMapper.ensureInitialized()
        .encodeMap<SendLinkNotificationResult>(
          this as SendLinkNotificationResult,
        );
  }

  SendLinkNotificationResultCopyWith<
    SendLinkNotificationResult,
    SendLinkNotificationResult,
    SendLinkNotificationResult
  >
  get copyWith =>
      _SendLinkNotificationResultCopyWithImpl<
        SendLinkNotificationResult,
        SendLinkNotificationResult
      >(this as SendLinkNotificationResult, $identity, $identity);
  @override
  String toString() {
    return SendLinkNotificationResultMapper.ensureInitialized().stringifyValue(
      this as SendLinkNotificationResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return SendLinkNotificationResultMapper.ensureInitialized().equalsValue(
      this as SendLinkNotificationResult,
      other,
    );
  }

  @override
  int get hashCode {
    return SendLinkNotificationResultMapper.ensureInitialized().hashValue(
      this as SendLinkNotificationResult,
    );
  }
}

extension SendLinkNotificationResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SendLinkNotificationResult, $Out> {
  SendLinkNotificationResultCopyWith<$R, SendLinkNotificationResult, $Out>
  get $asSendLinkNotificationResult => $base.as(
    (v, t, t2) => _SendLinkNotificationResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SendLinkNotificationResultCopyWith<
  $R,
  $In extends SendLinkNotificationResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? delivered, DeliveryChannel? channel});
  SendLinkNotificationResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SendLinkNotificationResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SendLinkNotificationResult, $Out>
    implements
        SendLinkNotificationResultCopyWith<
          $R,
          SendLinkNotificationResult,
          $Out
        > {
  _SendLinkNotificationResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SendLinkNotificationResult> $mapper =
      SendLinkNotificationResultMapper.ensureInitialized();
  @override
  $R call({bool? delivered, DeliveryChannel? channel}) => $apply(
    FieldCopyWithData({
      if (delivered != null) #delivered: delivered,
      if (channel != null) #channel: channel,
    }),
  );
  @override
  SendLinkNotificationResult $make(CopyWithData data) =>
      SendLinkNotificationResult(
        delivered: data.get(#delivered, or: $value.delivered),
        channel: data.get(#channel, or: $value.channel),
      );

  @override
  SendLinkNotificationResultCopyWith<$R2, SendLinkNotificationResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _SendLinkNotificationResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

