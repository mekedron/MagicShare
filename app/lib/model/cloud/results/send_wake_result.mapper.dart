// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'send_wake_result.dart';

class SendWakeResultMapper extends ClassMapperBase<SendWakeResult> {
  SendWakeResultMapper._();

  static SendWakeResultMapper? _instance;
  static SendWakeResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SendWakeResultMapper._());
      DeliveryChannelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SendWakeResult';

  static bool _$delivered(SendWakeResult v) => v.delivered;
  static const Field<SendWakeResult, bool> _f$delivered = Field(
    'delivered',
    _$delivered,
  );
  static DeliveryChannel _$channel(SendWakeResult v) => v.channel;
  static const Field<SendWakeResult, DeliveryChannel> _f$channel = Field(
    'channel',
    _$channel,
  );

  @override
  final MappableFields<SendWakeResult> fields = const {
    #delivered: _f$delivered,
    #channel: _f$channel,
  };

  static SendWakeResult _instantiate(DecodingData data) {
    return SendWakeResult(
      delivered: data.dec(_f$delivered),
      channel: data.dec(_f$channel),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SendWakeResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SendWakeResult>(map);
  }

  static SendWakeResult deserialize(String json) {
    return ensureInitialized().decodeJson<SendWakeResult>(json);
  }
}

mixin SendWakeResultMappable {
  String serialize() {
    return SendWakeResultMapper.ensureInitialized().encodeJson<SendWakeResult>(
      this as SendWakeResult,
    );
  }

  Map<String, dynamic> toJson() {
    return SendWakeResultMapper.ensureInitialized().encodeMap<SendWakeResult>(
      this as SendWakeResult,
    );
  }

  SendWakeResultCopyWith<SendWakeResult, SendWakeResult, SendWakeResult>
  get copyWith => _SendWakeResultCopyWithImpl<SendWakeResult, SendWakeResult>(
    this as SendWakeResult,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SendWakeResultMapper.ensureInitialized().stringifyValue(
      this as SendWakeResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return SendWakeResultMapper.ensureInitialized().equalsValue(
      this as SendWakeResult,
      other,
    );
  }

  @override
  int get hashCode {
    return SendWakeResultMapper.ensureInitialized().hashValue(
      this as SendWakeResult,
    );
  }
}

extension SendWakeResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SendWakeResult, $Out> {
  SendWakeResultCopyWith<$R, SendWakeResult, $Out> get $asSendWakeResult =>
      $base.as((v, t, t2) => _SendWakeResultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SendWakeResultCopyWith<$R, $In extends SendWakeResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? delivered, DeliveryChannel? channel});
  SendWakeResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SendWakeResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SendWakeResult, $Out>
    implements SendWakeResultCopyWith<$R, SendWakeResult, $Out> {
  _SendWakeResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SendWakeResult> $mapper =
      SendWakeResultMapper.ensureInitialized();
  @override
  $R call({bool? delivered, DeliveryChannel? channel}) => $apply(
    FieldCopyWithData({
      if (delivered != null) #delivered: delivered,
      if (channel != null) #channel: channel,
    }),
  );
  @override
  SendWakeResult $make(CopyWithData data) => SendWakeResult(
    delivered: data.get(#delivered, or: $value.delivered),
    channel: data.get(#channel, or: $value.channel),
  );

  @override
  SendWakeResultCopyWith<$R2, SendWakeResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SendWakeResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

