/// Sealed result type returned by [CloudMessageDispatcher.dispatch].
///
/// FCM data messages from `sendWake` and `sendLinkNotification` arrive
/// as opaque maps; the dispatcher decrypts them (when needed) and turns
/// them into one of the concrete [CloudMessage] subclasses below. The
/// caller (foreground listener, background handler, Linux poller in
/// Epic 16) decides what to do with the result.
sealed class CloudMessage {
  const CloudMessage();
}

/// A successfully-decrypted wake notification. The receiver registers
/// [nonce] in its short-lived expected-nonce map; an upcoming
/// `prepareUpload` carrying a matching `wakeSessionId` then auto-accepts
/// without prompting the user.
///
/// [sourceFingerprint] is informational — the LAN handshake will check
/// it independently. [initiatedAtMs] is the sender-side timestamp; the
/// receiver derives the nonce expiry from it (sender clock + 2 min) so
/// clock skew between isolates doesn't bite us.
class WakeMessage extends CloudMessage {
  const WakeMessage({
    required this.nonce,
    required this.sourceFingerprint,
    required this.initiatedAtMs,
  });

  final String nonce;
  final String sourceFingerprint;
  final int initiatedAtMs;
}

/// A link notification (plaintext or encrypted-mode). Both modes
/// converge on the same shape: the receiver is expected to open [url]
/// in the system browser via `url_launcher`. [title] is informational.
class LinkMessage extends CloudMessage {
  const LinkMessage({
    required this.url,
    this.title,
  });

  final String url;
  final String? title;
}

/// Returned when dispatch failed for a recoverable reason — bad type
/// field, missing payload, tampered ciphertext, malformed JSON. The
/// caller swallows it; we never throw out of the dispatcher.
class CloudMessageError extends CloudMessage {
  const CloudMessageError(this.reason, {this.cause});

  final String reason;
  final Object? cause;

  @override
  String toString() => 'CloudMessageError($reason${cause == null ? '' : ', cause: $cause'})';
}
