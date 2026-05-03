import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { getDb } from './admin';
import { requireAuth } from './auth';
import { accountPath, type DeviceDoc, devicePath } from './models';
import {
  parseRegisterDeviceInput,
  parseRenameDeviceInput,
  parseSetDeviceIconInput,
  parseUpdatePresenceInput,
  type RegisterDeviceInput,
  type RenameDeviceInput,
  type SetDeviceIconInput,
  type UpdatePresenceInput,
} from './validation';

export interface RegisterDeviceResult {
  created: boolean;
}

export interface UpdatePresenceResult {
  updated: boolean;
}

const PRESENCE_RATE_LIMIT_MS = 60_000;

/**
 * Register a device under the caller's account, or update fields on an
 * existing device with the same `deviceId`. Idempotent: re-registering
 * the same device does not bump `deviceCount`.
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

    const deviceDoc: DeviceDoc = {
      displayName: input.displayName,
      icon: input.icon,
      fcmToken: input.fcmToken,
      platform: input.platform,
      lastSeenAt: now,
      presence: 'online',
    };
    tx.set(deviceRef, deviceDoc);

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

export const registerDevice = onCall<unknown, Promise<RegisterDeviceResult>>(async (request) => {
  const uid = requireAuth(request);
  const input = parseRegisterDeviceInput(request.data);
  return registerDeviceLogic(getDb(), uid, input);
});

/**
 * Heartbeat / presence update. Hard rate-limited to one accepted call
 * per 60 s per device: a second call landing within 60 s of the
 * previous `lastSeenAt` throws `resource-exhausted`. The 4-minute
 * heartbeat in Epic 8 is well clear of the limit; the only legitimate
 * caller that may collide is the best-effort offline mark on
 * backgrounding shortly after registration, which the spec already
 * tolerates as best-effort.
 */
export async function updateDevicePresenceLogic(
  db: Firestore,
  uid: string,
  input: UpdatePresenceInput,
): Promise<UpdatePresenceResult> {
  const accountRef = db.doc(accountPath(uid));
  const deviceRef = db.doc(devicePath(uid, input.deviceId));
  return db.runTransaction(async (tx) => {
    const deviceSnap = await tx.get(deviceRef);
    if (!deviceSnap.exists) {
      throw new HttpsError('not-found', 'Device not found.');
    }
    const device = deviceSnap.data() as DeviceDoc;
    const now = Timestamp.now();
    if (now.toMillis() - device.lastSeenAt.toMillis() < PRESENCE_RATE_LIMIT_MS) {
      throw new HttpsError('resource-exhausted', 'Presence update rate limit exceeded.');
    }
    tx.update(deviceRef, {
      presence: input.presence,
      lastSeenAt: now,
    });
    tx.update(accountRef, { lastActiveAt: now });
    return { updated: true };
  });
}

export const updateDevicePresence = onCall<unknown, Promise<UpdatePresenceResult>>(
  async (request) => {
    const uid = requireAuth(request);
    const input = parseUpdatePresenceInput(request.data);
    return updateDevicePresenceLogic(getDb(), uid, input);
  },
);

async function patchDeviceField(
  db: Firestore,
  uid: string,
  deviceId: string,
  patch: Partial<DeviceDoc>,
): Promise<void> {
  const accountRef = db.doc(accountPath(uid));
  const deviceRef = db.doc(devicePath(uid, deviceId));
  await db.runTransaction(async (tx) => {
    const deviceSnap = await tx.get(deviceRef);
    if (!deviceSnap.exists) {
      throw new HttpsError('not-found', 'Device not found.');
    }
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

export const renameDevice = onCall<unknown, Promise<{ ok: true }>>(async (request) => {
  const uid = requireAuth(request);
  const input = parseRenameDeviceInput(request.data);
  await renameDeviceLogic(getDb(), uid, input);
  return { ok: true };
});

export const setDeviceIcon = onCall<unknown, Promise<{ ok: true }>>(async (request) => {
  const uid = requireAuth(request);
  const input = parseSetDeviceIconInput(request.data);
  await setDeviceIconLogic(getDb(), uid, input);
  return { ok: true };
});
