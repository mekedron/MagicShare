// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'notify_transfer_intent_result.dart';

class NotifyTransferIntentResultMapper
    extends ClassMapperBase<NotifyTransferIntentResult> {
  NotifyTransferIntentResultMapper._();

  static NotifyTransferIntentResultMapper? _instance;
  static NotifyTransferIntentResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = NotifyTransferIntentResultMapper._(),
      );
      DeliveryChannelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'NotifyTransferIntentResult';

  static bool _$delivered(NotifyTransferIntentResult v) => v.delivered;
  static const Field<NotifyTransferIntentResult, bool> _f$delivered = Field(
    'delivered',
    _$delivered,
  );
  static DeliveryChannel _$channel(NotifyTransferIntentResult v) => v.channel;
  static const Field<NotifyTransferIntentResult, DeliveryChannel> _f$channel =
      Field('channel', _$channel);

  @override
  final MappableFields<NotifyTransferIntentResult> fields = const {
    #delivered: _f$delivered,
    #channel: _f$channel,
  };

  static NotifyTransferIntentResult _instantiate(DecodingData data) {
    return NotifyTransferIntentResult(
      delivered: data.dec(_f$delivered),
      channel: data.dec(_f$channel),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NotifyTransferIntentResult fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NotifyTransferIntentResult>(map);
  }

  static NotifyTransferIntentResult deserialize(String json) {
    return ensureInitialized().decodeJson<NotifyTransferIntentResult>(json);
  }
}

mixin NotifyTransferIntentResultMappable {
  String serialize() {
    return NotifyTransferIntentResultMapper.ensureInitialized()
        .encodeJson<NotifyTransferIntentResult>(
          this as NotifyTransferIntentResult,
        );
  }

  Map<String, dynamic> toJson() {
    return NotifyTransferIntentResultMapper.ensureInitialized()
        .encodeMap<NotifyTransferIntentResult>(
          this as NotifyTransferIntentResult,
        );
  }

  NotifyTransferIntentResultCopyWith<
    NotifyTransferIntentResult,
    NotifyTransferIntentResult,
    NotifyTransferIntentResult
  >
  get copyWith =>
      _NotifyTransferIntentResultCopyWithImpl<
        NotifyTransferIntentResult,
        NotifyTransferIntentResult
      >(this as NotifyTransferIntentResult, $identity, $identity);
  @override
  String toString() {
    return NotifyTransferIntentResultMapper.ensureInitialized().stringifyValue(
      this as NotifyTransferIntentResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return NotifyTransferIntentResultMapper.ensureInitialized().equalsValue(
      this as NotifyTransferIntentResult,
      other,
    );
  }

  @override
  int get hashCode {
    return NotifyTransferIntentResultMapper.ensureInitialized().hashValue(
      this as NotifyTransferIntentResult,
    );
  }
}

extension NotifyTransferIntentResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, NotifyTransferIntentResult, $Out> {
  NotifyTransferIntentResultCopyWith<$R, NotifyTransferIntentResult, $Out>
  get $asNotifyTransferIntentResult => $base.as(
    (v, t, t2) => _NotifyTransferIntentResultCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class NotifyTransferIntentResultCopyWith<
  $R,
  $In extends NotifyTransferIntentResult,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({bool? delivered, DeliveryChannel? channel});
  NotifyTransferIntentResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _NotifyTransferIntentResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NotifyTransferIntentResult, $Out>
    implements
        NotifyTransferIntentResultCopyWith<
          $R,
          NotifyTransferIntentResult,
          $Out
        > {
  _NotifyTransferIntentResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<NotifyTransferIntentResult> $mapper =
      NotifyTransferIntentResultMapper.ensureInitialized();
  @override
  $R call({bool? delivered, DeliveryChannel? channel}) => $apply(
    FieldCopyWithData({
      if (delivered != null) #delivered: delivered,
      if (channel != null) #channel: channel,
    }),
  );
  @override
  NotifyTransferIntentResult $make(CopyWithData data) =>
      NotifyTransferIntentResult(
        delivered: data.get(#delivered, or: $value.delivered),
        channel: data.get(#channel, or: $value.channel),
      );

  @override
  NotifyTransferIntentResultCopyWith<$R2, NotifyTransferIntentResult, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _NotifyTransferIntentResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

