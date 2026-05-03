import { type DocumentReference, type Firestore, type Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { type DeviceDoc, devicePath } from './models';

/**
 * Result of an `assertSameAccount(...)` lookup. The reference is handy
 * for the caller's subsequent transactional update — it saves the
 * caller from rebuilding the same path.
 */
export interface DeviceLookup {
  ref: DocumentReference;
  doc: DeviceDoc;
}

/**
 * Assert that the caller's account owns a device, returning the device
 * document plus its reference. Throws `HttpsError('not-found', …)` when
 * the device does not exist under `accounts/{callerUid}/devices/{deviceId}`.
 *
 * This enforces the spec invariant: "Cloud Functions reject any request
 * where the caller's account ID does not match the owner of the target
 * device" (`docs/development/cloud-sync-spec.md` §5.3 Privacy & Security).
 *
 * Two variants exist for the same reason `Firestore.runTransaction`
 * does: a callable that already holds a `Transaction` must use
 * `assertSameAccountTx` so the read participates in the transaction's
 * lock set; a callable doing only out-of-transaction work uses
 * `assertSameAccount`.
 */
export async function assertSameAccount(
  db: Firestore,
  callerUid: string,
  deviceId: string,
): Promise<DeviceLookup> {
  const ref = db.doc(devicePath(callerUid, deviceId));
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Device not found.');
  }
  return { ref, doc: snap.data() as DeviceDoc };
}

export async function assertSameAccountTx(
  tx: Transaction,
  db: Firestore,
  callerUid: string,
  deviceId: string,
): Promise<DeviceLookup> {
  const ref = db.doc(devicePath(callerUid, deviceId));
  const snap = await tx.get(ref);
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Device not found.');
  }
  return { ref, doc: snap.data() as DeviceDoc };
}
