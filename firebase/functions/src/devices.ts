import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { assertSameAccountTx } from './account-access';
import { getDb } from './admin';
import { requireAuth } from './auth';
import { instrument } from './logging';
import { type AccountDoc, accountPath, type DeviceDoc, devicePath } from './models';
import {
  parseRegisterDeviceInput,
  parseRemoveDeviceInput,
  parseRenameDeviceInput,
  parseSetDeviceIconInput,
  type RegisterDeviceInput,
  type RemoveDeviceInput,
  type RenameDeviceInput,
  type SetDeviceIconInput,
} from './validation';

export interface RegisterDeviceResult {
  created: boolean;
}

/**
 * Register a device under the caller's account, or refresh transient
 * fields on an existing device with the same `deviceId`. Idempotent:
 * re-registering the same device does not bump `deviceCount`.
 *
 * Field-level contract:
 * - On *create* (no existing doc): the full input is written. The
 *   client's `defaultDisplayName` (LAN alias) and `defaultIcon`
 *   become the initial values.
 * - On *update* (doc already exists): only transient fields refresh
 *   (`fcmToken`, `platform`). User-edited fields — `displayName` and
 *   `icon` — are preserved. Otherwise every bootstrap on app relaunch
 *   would overwrite a previous `renameDevice` or `setDeviceIcon` call.
 *   Subsequent renames go through the dedicated callables.
 *
 * Pre-condition: `accounts/{uid}` must exist (call `createAccount` first).
 */
export async function registerDeviceLogic(
  db: Firestore,
  uid: string,
  input: RegisterDeviceInput,
): Promise<RegisterDeviceResult> {
  const accountRef = db.doc(accountPath(uid));
  const deviceRef = db.doc(devicePath(uid, input.deviceId));
  return db.runTransaction(async (tx) => {
    const accountSnap = await tx.get(accountRef);
    if (!accountSnap.exists) {
      throw new HttpsError(
        'failed-precondition',
        'Account does not exist; call createAccount first.',
      );
    }
    const deviceSnap = await tx.get(deviceRef);
    const now = Timestamp.now();
    const created = !deviceSnap.exists;

    if (created) {
      const deviceDoc: DeviceDoc = {
        displayName: input.displayName,
        icon: input.icon,
        fcmToken: input.fcmToken,
        platform: input.platform,
        fingerprint: input.fingerprint ?? null,
      };
      tx.set(deviceRef, deviceDoc);
    } else {
      // Preserve user-customisable displayName + icon on re-register.
      const refresh: Partial<DeviceDoc> = {
        fcmToken: input.fcmToken,
        platform: input.platform,
      };
      // Only refresh fingerprint when the caller actually supplied it.
      // An older client that omits the field must not clobber whatever
      // a newer client already wrote.
      if (input.fingerprint !== undefined) {
        refresh.fingerprint = input.fingerprint;
      }
      tx.update(deviceRef, refresh);
    }

    const accountUpdate: Record<string, FieldValue | Timestamp> = {
      lastActiveAt: now,
    };
    if (created) {
      accountUpdate.deviceCount = FieldValue.increment(1);
    }
    tx.update(accountRef, accountUpdate);

    return { created };
  });
}

export const registerDevice = onCall<unknown, Promise<RegisterDeviceResult>>(
  instrument('registerDevice', async (request) => {
    const uid = requireAuth(request);
    const input = parseRegisterDeviceInput(request.data);
    return registerDeviceLogic(getDb(), uid, input);
  }),
);

async function patchDeviceField(
  db: Firestore,
  uid: string,
  deviceId: string,
  patch: Partial<DeviceDoc>,
): Promise<void> {
  const accountRef = db.doc(accountPath(uid));
  await db.runTransaction(async (tx) => {
    const { ref: deviceRef } = await assertSameAccountTx(tx, db, uid, deviceId);
    tx.update(deviceRef, patch);
    tx.update(accountRef, { lastActiveAt: Timestamp.now() });
  });
}

export async function renameDeviceLogic(
  db: Firestore,
  uid: string,
  input: RenameDeviceInput,
): Promise<void> {
  await patchDeviceField(db, uid, input.deviceId, { displayName: input.displayName });
}

export async function setDeviceIconLogic(
  db: Firestore,
  uid: string,
  input: SetDeviceIconInput,
): Promise<void> {
  await patchDeviceField(db, uid, input.deviceId, { icon: input.icon });
}

export const renameDevice = onCall<unknown, Promise<{ ok: true }>>(
  instrument('renameDevice', async (request) => {
    const uid = requireAuth(request);
    const input = parseRenameDeviceInput(request.data);
    await renameDeviceLogic(getDb(), uid, input);
    return { ok: true };
  }),
);

export const setDeviceIcon = onCall<unknown, Promise<{ ok: true }>>(
  instrument('setDeviceIcon', async (request) => {
    const uid = requireAuth(request);
    const input = parseSetDeviceIconInput(request.data);
    await setDeviceIconLogic(getDb(), uid, input);
    return { ok: true };
  }),
);

export interface RemoveDeviceResult {
  accountDeleted: boolean;
}

/**
 * Remove one device from the caller's account. If it was the last
 * device, the entire account subtree (account doc + devices) is
 * destroyed — matching the spec's "removing the last device in a
 * group destroys the group automatically."
 *
 * The transaction picks the branch (decrement vs nuke) atomically.
 * `recursiveDelete` runs after the transaction to sweep any
 * subcollections — Firestore transactions can delete docs but not
 * their subcollections.
 */
export async function removeDeviceLogic(
  db: Firestore,
  uid: string,
  input: RemoveDeviceInput,
): Promise<RemoveDeviceResult> {
  const accountRef = db.doc(accountPath(uid));
  const deviceRef = db.doc(devicePath(uid, input.deviceId));

  const result = await db.runTransaction(async (tx) => {
    // Read account first so we know whether this is the last-device branch.
    // `assertSameAccountTx` then validates the device and gives us the
    // `not-found` rejection if the caller doesn't own it.
    const accountSnap = await tx.get(accountRef);
    if (!accountSnap.exists) {
      throw new HttpsError('not-found', 'Account not found.');
    }
    await assertSameAccountTx(tx, db, uid, input.deviceId);
    const currentCount = (accountSnap.data() as AccountDoc).deviceCount;
    const now = Timestamp.now();
    if (currentCount > 1) {
      tx.delete(deviceRef);
      tx.update(accountRef, {
        deviceCount: FieldValue.increment(-1),
        lastActiveAt: now,
      });
      return { accountDeleted: false };
    }
    tx.delete(deviceRef);
    tx.delete(accountRef);
    return { accountDeleted: true };
  });

  // Transactional deletes don't cascade into subcollections. Sweep
  // any out of band: the whole account subtree on the last-device path
  // (which also nukes any other lingering devices from a partial
  // earlier failure).
  if (result.accountDeleted) {
    await db.recursiveDelete(accountRef);
  } else {
    await db.recursiveDelete(deviceRef);
  }
  return result;
}

export const removeDevice = onCall<unknown, Promise<RemoveDeviceResult>>(
  instrument('removeDevice', async (request) => {
    const uid = requireAuth(request);
    const input = parseRemoveDeviceInput(request.data);
    return removeDeviceLogic(getDb(), uid, input);
  }),
);
