import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';

/**
 * Asserts the callable request carries an authenticated user, and
 * returns the caller's UID. The UID is the MagicShare account ID —
 * accounts are keyed by `request.auth.uid` per `firebase/SCHEMA.md`,
 * never by a client-supplied accountId field.
 *
 * Throws `HttpsError('unauthenticated', …)` when auth is missing.
 */
export function requireAuth(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Caller must be signed in.');
  }
  return uid;
}
