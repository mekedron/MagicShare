import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _logger = Logger('WakeNoncePersistence');

/// Storage key for the pending-nonce buffer. Lives under the standard
/// `flutter.` prefix shared by every other [SharedPreferences] entry.
const String wakeNoncePersistenceKey = 'ls_pending_wake_nonces';

/// Bridge between the FCM background isolate (which writes) and the
/// main isolate (which drains on app start / resume).
///
/// Backed by [SharedPreferences.getInstance], which spins up its own
/// platform-channel binding inside any isolate Flutter spawns. The
/// in-memory [WakeNonceRegistry] is the source of truth in the
/// foreground; this layer only buffers nonces until the foreground
/// runs.
class WakeNoncePersistence {
  const WakeNoncePersistence();

  /// Appends a single nonce/expiry pair. Tolerates concurrent writes
  /// (last-writer-wins on the SharedPreferences slot). Drops entries
  /// whose expiry has already passed.
  Future<void> append(String nonce, DateTime expiresAt) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _readEntries(prefs);
    final now = DateTime.now();
    final filtered = existing.where((e) => e.expiresAt.isAfter(now)).toList(growable: true);
    if (expiresAt.isAfter(now)) {
      filtered.add(_PersistedNonce(nonce: nonce, expiresAt: expiresAt));
    }
    await prefs.setString(wakeNoncePersistenceKey, _encodeEntries(filtered));
  }

  /// Atomic read-and-clear. Returns every live (non-expired) entry and
  /// wipes the slot in one go so a follow-up [drain] sees an empty
  /// buffer. Expired entries are dropped silently.
  Future<List<DrainedNonce>> drain() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _readEntries(prefs);
    if (entries.isEmpty) {
      return const <DrainedNonce>[];
    }
    await prefs.remove(wakeNoncePersistenceKey);
    final now = DateTime.now();
    return entries.where((e) => e.expiresAt.isAfter(now)).map((e) => DrainedNonce(nonce: e.nonce, expiresAt: e.expiresAt)).toList(growable: false);
  }

  List<_PersistedNonce> _readEntries(SharedPreferences prefs) {
    final raw = prefs.getString(wakeNoncePersistenceKey);
    if (raw == null || raw.isEmpty) {
      return const <_PersistedNonce>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _logger.warning('Pending-nonce buffer is not a JSON list, clearing it');
        return const <_PersistedNonce>[];
      }
      final out = <_PersistedNonce>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final nonce = item['nonce'];
        final expiresAtMs = item['expiresAtMs'];
        if (nonce is! String || expiresAtMs is! num) continue;
        out.add(
          _PersistedNonce(
            nonce: nonce,
            expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs.toInt()),
          ),
        );
      }
      return out;
    } catch (e, st) {
      _logger.warning('Pending-nonce buffer is corrupt, dropping it', e, st);
      return const <_PersistedNonce>[];
    }
  }

  String _encodeEntries(List<_PersistedNonce> entries) {
    final json = entries
        .map(
          (e) => <String, dynamic>{
            'nonce': e.nonce,
            'expiresAtMs': e.expiresAt.millisecondsSinceEpoch,
          },
        )
        .toList(growable: false);
    return jsonEncode(json);
  }
}

/// One drained entry. The foreground listener feeds these into the
/// in-memory [WakeNonceRegistry].
class DrainedNonce {
  const DrainedNonce({required this.nonce, required this.expiresAt});

  final String nonce;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DrainedNonce && other.nonce == nonce && other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(nonce, expiresAt);
}

class _PersistedNonce {
  const _PersistedNonce({required this.nonce, required this.expiresAt});

  final String nonce;
  final DateTime expiresAt;
}
