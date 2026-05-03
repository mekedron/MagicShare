// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'cloud_device_icon.dart';

class CloudDeviceIconMapper extends EnumMapper<CloudDeviceIcon> {
  CloudDeviceIconMapper._();

  static CloudDeviceIconMapper? _instance;
  static CloudDeviceIconMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudDeviceIconMapper._());
    }
    return _instance!;
  }

  static CloudDeviceIcon fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  CloudDeviceIcon decode(dynamic value) {
    switch (value) {
      case r'laptop':
        return CloudDeviceIcon.laptop;
      case r'desktop':
        return CloudDeviceIcon.desktop;
      case r'phone':
        return CloudDeviceIcon.phone;
      case r'tablet':
        return CloudDeviceIcon.tablet;
      case r'server':
        return CloudDeviceIcon.server;
      case r'headless':
        return CloudDeviceIcon.headless;
      case r'other':
        return CloudDeviceIcon.other;
      default:
        return CloudDeviceIcon.values[6];
    }
  }

  @override
  dynamic encode(CloudDeviceIcon self) {
    switch (self) {
      case CloudDeviceIcon.laptop:
        return r'laptop';
      case CloudDeviceIcon.desktop:
        return r'desktop';
      case CloudDeviceIcon.phone:
        return r'phone';
      case CloudDeviceIcon.tablet:
        return r'tablet';
      case CloudDeviceIcon.server:
        return r'server';
      case CloudDeviceIcon.headless:
        return r'headless';
      case CloudDeviceIcon.other:
        return r'other';
    }
  }
}

extension CloudDeviceIconMapperExtension on CloudDeviceIcon {
  String toValue() {
    CloudDeviceIconMapper.ensureInitialized();
    return MapperContainer.globals.toValue<CloudDeviceIcon>(this) as String;
  }
}

