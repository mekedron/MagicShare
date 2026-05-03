import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';

import { getDb } from './admin';
import { requireAuth } from './auth';
import { type AccountDoc, accountPath } from './models';

export interface CreateAccountResult {
  created: boolean;
  accountId: string;
}

export interface DeleteAccountResult {
  deleted: boolean;
}

/**
 * Idempotent: creates `accounts/{uid}` if missing, leaves it alone if
 * already there. The bootstrap path is anonymous-sign-in →
 * `createAccount` → `registerDevice`, so this is the very first
 * mutation any new install makes.
 */
export async function createAccountLogic(db: Firestore, uid: string): Promise<CreateAccountResult> {
  const ref = db.doc(accountPath(uid));
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      return { created: false, accountId: uid };
    }
    const now = Timestamp.now();
    const doc: AccountDoc = {
      createdAt: now,
      lastActiveAt: now,
      deviceCount: 0,
    };
    tx.set(ref, doc);
    return { created: true, accountId: uid };
  });
}

/**
 * Idempotent destroy: tears down the entire account subtree (devices +
 * their inbox subcollections) plus the account doc itself. Returns
 * `{ deleted: false }` when there was nothing to delete.
 *
 * `recursiveDelete` is not transactional, but it is the canonical
 * Admin-SDK primitive for nuking a Firestore subtree. The scheduled
 * cleanup job in Epic 6 sweeps any stragglers from a partial run.
 */
export async function deleteAccountLogic(db: Firestore, uid: string): Promise<DeleteAccountResult> {
  const ref = db.doc(accountPath(uid));
  const snap = await ref.get();
  if (!snap.exists) {
    return { deleted: false };
  }
  await db.recursiveDelete(ref);
  return { deleted: true };
}

/** Bumps `lastActiveAt` on the account doc. Caller is responsible for
 *  ensuring the account exists. */
export async function touchAccountLastActive(db: Firestore, uid: string): Promise<void> {
  await db.doc(accountPath(uid)).update({ lastActiveAt: FieldValue.serverTimestamp() });
}

export const createAccount = onCall<unknown, Promise<CreateAccountResult>>(async (request) => {
  const uid = requireAuth(request);
  return createAccountLogic(getDb(), uid);
});

export const deleteAccount = onCall<unknown, Promise<DeleteAccountResult>>(async (request) => {
  const uid = requireAuth(request);
  return deleteAccountLogic(getDb(), uid);
});
