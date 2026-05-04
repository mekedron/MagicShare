// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'inbox_item_type.dart';

class InboxItemTypeMapper extends EnumMapper<InboxItemType> {
  InboxItemTypeMapper._();

  static InboxItemTypeMapper? _instance;
  static InboxItemTypeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = InboxItemTypeMapper._());
    }
    return _instance!;
  }

  static InboxItemType fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  InboxItemType decode(dynamic value) {
    switch (value) {
      case r'wake':
        return InboxItemType.wake;
      case r'link':
        return InboxItemType.link;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(InboxItemType self) {
    switch (self) {
      case InboxItemType.wake:
        return r'wake';
      case InboxItemType.link:
        return r'link';
    }
  }
}

extension InboxItemTypeMapperExtension on InboxItemType {
  String toValue() {
    InboxItemTypeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<InboxItemType>(this) as String;
  }
}

