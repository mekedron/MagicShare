import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { getDb } from './admin';
import { requireAuth } from './auth';
import { accountPath, type DeviceDoc, devicePath } from './models';
import { parseRegisterDeviceInput, type RegisterDeviceInput } from './validation';

export interface RegisterDeviceResult {
  created: boolean;
}

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
