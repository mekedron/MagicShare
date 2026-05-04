// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'delivery_channel.dart';

class DeliveryChannelMapper extends EnumMapper<DeliveryChannel> {
  DeliveryChannelMapper._();

  static DeliveryChannelMapper? _instance;
  static DeliveryChannelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeliveryChannelMapper._());
    }
    return _instance!;
  }

  static DeliveryChannel fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DeliveryChannel decode(dynamic value) {
    switch (value) {
      case r'fcm':
        return DeliveryChannel.fcm;
      case r'inbox':
        return DeliveryChannel.inbox;
      case r'none':
        return DeliveryChannel.none;
      default:
        return DeliveryChannel.values[2];
    }
  }

  @override
  dynamic encode(DeliveryChannel self) {
    switch (self) {
      case DeliveryChannel.fcm:
        return r'fcm';
      case DeliveryChannel.inbox:
        return r'inbox';
      case DeliveryChannel.none:
        return r'none';
    }
  }
}

extension DeliveryChannelMapperExtension on DeliveryChannel {
  String toValue() {
    DeliveryChannelMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DeliveryChannel>(this) as String;
  }
}

