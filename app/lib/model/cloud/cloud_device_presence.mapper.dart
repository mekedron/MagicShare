// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'cloud_device_presence.dart';

class CloudDevicePresenceMapper extends EnumMapper<CloudDevicePresence> {
  CloudDevicePresenceMapper._();

  static CloudDevicePresenceMapper? _instance;
  static CloudDevicePresenceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudDevicePresenceMapper._());
    }
    return _instance!;
  }

  static CloudDevicePresence fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  CloudDevicePresence decode(dynamic value) {
    switch (value) {
      case r'online':
        return CloudDevicePresence.online;
      case r'offline':
        return CloudDevicePresence.offline;
      default:
        return CloudDevicePresence.values[1];
    }
  }

  @override
  dynamic encode(CloudDevicePresence self) {
    switch (self) {
      case CloudDevicePresence.online:
        return r'online';
      case CloudDevicePresence.offline:
        return r'offline';
    }
  }
}

extension CloudDevicePresenceMapperExtension on CloudDevicePresence {
  String toValue() {
    CloudDevicePresenceMapper.ensureInitialized();
    return MapperContainer.globals.toValue<CloudDevicePresence>(this) as String;
  }
}

