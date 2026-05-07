import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:magicshare_app/model/persistence/favorite_device.dart';

extension FavoriteDevicesExt on Iterable<FavoriteDevice> {
  /// Returns the favorite device with the given [device] or null if
  /// not found. Matches against the device's HTTP cert hashes only —
  /// favorites are persisted with the cert hash, not signaling tokens
  /// (tokens rotate per signaling connection).
  FavoriteDevice? findDevice(Device device) {
    final certHashes = device.certHashes;
    if (certHashes.isEmpty) return null;
    return firstWhereOrNull((e) => certHashes.contains(e.fingerprint));
  }

  /// Returns true if the list contains the given [device].
  bool containsDevice(Device device) {
    final certHashes = device.certHashes;
    if (certHashes.isEmpty) return false;
    return any((e) => certHashes.contains(e.fingerprint));
  }
}
