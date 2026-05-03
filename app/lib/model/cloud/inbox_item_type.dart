import 'package:dart_mappable/dart_mappable.dart';

part 'inbox_item_type.mapper.dart';

/// Mirrors `InboxItemType` in firebase/functions/src/models.ts.
@MappableEnum()
enum InboxItemType {
  wake,
  link,
}
