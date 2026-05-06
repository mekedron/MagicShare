/// Short-lived expected-nonce map for the wake → P2P bridge.
///
/// When a wake notification arrives, the receiver decrypts the payload
/// and registers the session nonce here; when the sender's
/// `prepareUpload` arrives carrying the matching `wakeSessionId`, the
/// receive controller calls [consume] and short-circuits the Accept
/// prompt. Single-use: a successful [consume] removes the entry, so a
/// peer that learns a nonce cannot re-trigger auto-accept.
///
/// Lives in the main isolate. The background FCM isolate cannot reach
/// this object directly — it persists nonces via
/// [WakeNoncePersistence] and the foreground listener drains them into
/// this registry on app start / resume.
class WakeNonceRegistry {
  WakeNonceRegistry({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, DateTime> _expiries = <String, DateTime>{};

  /// Adds [nonce] with absolute expiry [expiresAt]. If the entry is
  /// already past expiry it is dropped silently. Re-registering an
  /// existing nonce extends its expiry.
  void register(String nonce, DateTime expiresAt) {
    final now = _clock();
    if (!expiresAt.isAfter(now)) {
      return;
    }
    _expiries[nonce] = expiresAt;
  }

  /// Atomic remove-and-return-true on hit, false on miss / expired.
  /// Single-use by design; a peer that learns a nonce cannot replay it
  /// because the second [consume] will miss.
  bool consume(String nonce) {
    final expiresAt = _expiries.remove(nonce);
    if (expiresAt == null) {
      return false;
    }
    if (!expiresAt.isAfter(_clock())) {
      // Expired between register and consume; treat as a miss.
      return false;
    }
    return true;
  }

  /// Drops every entry whose expiry is at or before [now]. Called
  /// opportunistically and from the periodic prune timer.
  void prune() {
    final now = _clock();
    _expiries.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
  }

  /// Test-only: number of live entries.
  int get size => _expiries.length;
}
