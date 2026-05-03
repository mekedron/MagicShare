import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { getDb } from './admin';
import { ACCOUNTS_COLLECTION, DEVICES_SUBCOLLECTION, JOIN_TOKENS_COLLECTION } from './models';

/**
 * Scheduled maintenance jobs (Epic 6). Three sweeps keep the cloud
 * footprint bounded:
 *
 *   - cleanupExpiredJoinTokens (daily): delete pairing tokens past
 *     their 5-minute window. Belt-and-braces — `joinNetwork` and
 *     `previewJoinToken` already reject expired tokens at read time;
 *     the sweep just stops the collection from growing forever.
 *
 *   - cleanupInactiveAccounts (weekly): tear down accounts whose
 *     last device check-in was more than 90 days ago. Spec §5.3
 *     "Inactive groups (no device check-in for 90 days) are
 *     garbage-collected by a scheduled job."
 *
 *   - markStalePresence (every ~5 min): flip devices that haven't
 *     heartbeated in 10 minutes from `online` to `offline`. The
 *     client only updates `presence` while foregrounded; without
 *     this sweep a backgrounded app would stay green in the Send tab
 *     until its FCM token rotation, which is hours.
 *
 * Each `*Logic` function is pure, takes `now: Date` so tests pass a
 * fake clock, and returns a small summary so the scheduler logs are
 * useful for ops dashboards (Epic 14).
 */

const STALE_PRESENCE_MS = 10 * 60_000;
const INACTIVE_ACCOUNT_DAYS = 90;
const INACTIVE_ACCOUNT_MS = INACTIVE_ACCOUNT_DAYS * 24 * 60 * 60 * 1000;

export interface CleanupResult {
  deleted: number;
}

export interface MarkStalePresenceResult {
  marked: number;
}

export async function cleanupExpiredJoinTokensLogic(
  db: Firestore,
  now: Date,
): Promise<CleanupResult> {
  const cutoff = Timestamp.fromDate(now);
  const snap = await db.collection(JOIN_TOKENS_COLLECTION).where('expiresAt', '<=', cutoff).get();
  if (snap.empty) {
    return { deleted: 0 };
  }
  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
  return { deleted: snap.size };
}

export async function cleanupInactiveAccountsLogic(
  db: Firestore,
  now: Date,
): Promise<CleanupResult> {
  const cutoff = Timestamp.fromMillis(now.getTime() - INACTIVE_ACCOUNT_MS);
  const snap = await db.collection(ACCOUNTS_COLLECTION).where('lastActiveAt', '<=', cutoff).get();
  if (snap.empty) {
    return { deleted: 0 };
  }
  // Sequential `recursiveDelete` per account: each one is its own
  // batched subtree sweep, and parallelizing would risk smashing
  // Firestore's per-second write limit on a large GC. The job runs
  // weekly so latency is irrelevant.
  for (const doc of snap.docs) {
    await db.recursiveDelete(doc.ref);
  }
  return { deleted: snap.size };
}

export async function markStalePresenceLogic(
  db: Firestore,
  now: Date,
): Promise<MarkStalePresenceResult> {
  const cutoff = Timestamp.fromMillis(now.getTime() - STALE_PRESENCE_MS);
  const snap = await db
    .collectionGroup(DEVICES_SUBCOLLECTION)
    .where('presence', '==', 'online')
    .where('lastSeenAt', '<=', cutoff)
    .get();
  if (snap.empty) {
    return { marked: 0 };
  }
  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.update(doc.ref, { presence: 'offline' });
  }
  await batch.commit();
  return { marked: snap.size };
}

export const cleanupExpiredJoinTokens = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'UTC' },
  async () => {
    const start = Date.now();
    const result = await cleanupExpiredJoinTokensLogic(getDb(), new Date());
    logger.info('scheduled:cleanupExpiredJoinTokens', {
      deleted: result.deleted,
      latencyMs: Date.now() - start,
    });
  },
);

export const cleanupInactiveAccounts = onSchedule(
  { schedule: 'every monday 04:00', timeZone: 'UTC' },
  async () => {
    const start = Date.now();
    const result = await cleanupInactiveAccountsLogic(getDb(), new Date());
    logger.info('scheduled:cleanupInactiveAccounts', {
      deleted: result.deleted,
      latencyMs: Date.now() - start,
    });
  },
);

export const markStalePresence = onSchedule({ schedule: 'every 5 minutes' }, async () => {
  const start = Date.now();
  const result = await markStalePresenceLogic(getDb(), new Date());
  logger.info('scheduled:markStalePresence', {
    marked: result.marked,
    latencyMs: Date.now() - start,
  });
});
