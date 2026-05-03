import 'package:magicshare_app/model/cloud/inbox_item.dart';

/// Mirrors `PollPendingWakesResult` in firebase/functions/src/notifications.ts.
///
/// Hand-written (no dart_mappable) because it carries a list of [InboxItem],
/// whose union-typed `payload` field is also hand-decoded.
class PollPendingWakesResult {
  final List<InboxItem> items;

  const PollPendingWakesResult({required this.items});

  factory PollPendingWakesResult.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    if (rawItems is! List) {
      throw ArgumentError('PollPendingWakesResult.items must be a list');
    }
    return PollPendingWakesResult(
      items: rawItems.map((raw) => InboxItem.fromMap((raw as Map).cast<String, dynamic>())).toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'items': items.map((item) => item.toMap()).toList(growable: false),
  };

  @override
  bool operator ==(Object other) => identical(this, other) || other is PollPendingWakesResult && _listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
