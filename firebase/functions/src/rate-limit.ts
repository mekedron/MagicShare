import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Soft per-device send limit: 30 calls per rolling hour. Both
 * `sendWake` and `sendLinkNotification` share the same counter — the
 * spec calls out "30 sends per device per hour" as a guard against
 * runaway callers, not a per-callable ceiling.
 *
 * Stored on the source device's `recentSendsAt` field as an array of
 * Timestamps; `consumeSendQuota` slides the window, throws when full,
 * and returns the new array for the caller to persist.
 */
export const SEND_RATE_LIMIT_PER_HOUR = 30;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;

/**
 * Drop entries older than 1 h, append `now`, throw
 * `HttpsError('resource-exhausted', …)` if the resulting set would
 * exceed `SEND_RATE_LIMIT_PER_HOUR`. Returns the new array — pure
 * function, no Firestore IO. The transactional caller writes the
 * result back via `tx.update(deviceRef, { recentSendsAt })`.
 */
export function consumeSendQuota(existing: Timestamp[] | undefined, now: Timestamp): Timestamp[] {
  const cutoffMs = now.toMillis() - RATE_LIMIT_WINDOW_MS;
  const trimmed = (existing ?? []).filter((t) => t.toMillis() > cutoffMs);
  if (trimmed.length >= SEND_RATE_LIMIT_PER_HOUR) {
    throw new HttpsError(
      'resource-exhausted',
      `Send rate limit exceeded (${SEND_RATE_LIMIT_PER_HOUR}/hour).`,
    );
  }
  return [...trimmed, now];
}
