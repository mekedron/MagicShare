// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'cloud_device_platform.dart';

class CloudDevicePlatformMapper extends EnumMapper<CloudDevicePlatform> {
  CloudDevicePlatformMapper._();

  static CloudDevicePlatformMapper? _instance;
  static CloudDevicePlatformMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudDevicePlatformMapper._());
    }
    return _instance!;
  }

  static CloudDevicePlatform fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  CloudDevicePlatform decode(dynamic value) {
    switch (value) {
      case r'android':
        return CloudDevicePlatform.android;
      case r'ios':
        return CloudDevicePlatform.ios;
      case r'macos':
        return CloudDevicePlatform.macos;
      case r'windows':
        return CloudDevicePlatform.windows;
      case r'linux':
        return CloudDevicePlatform.linux;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(CloudDevicePlatform self) {
    switch (self) {
      case CloudDevicePlatform.android:
        return r'android';
      case CloudDevicePlatform.ios:
        return r'ios';
      case CloudDevicePlatform.macos:
        return r'macos';
      case CloudDevicePlatform.windows:
        return r'windows';
      case CloudDevicePlatform.linux:
        return r'linux';
    }
  }
}

extension CloudDevicePlatformMapperExtension on CloudDevicePlatform {
  String toValue() {
    CloudDevicePlatformMapper.ensureInitialized();
    return MapperContainer.globals.toValue<CloudDevicePlatform>(this) as String;
  }
}

