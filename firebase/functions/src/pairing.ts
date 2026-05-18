import { randomBytes } from 'node:crypto';

import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { getAuth, getDb } from './admin';
import { requireAuth } from './auth';
import { instrument } from './logging';
import {
  type AccountDoc,
  ACCOUNTS_COLLECTION,
  accountPath,
  type DeviceDoc,
  type DeviceIcon,
  DEVICES_SUBCOLLECTION,
  type DevicePlatform,
  devicePath,
  type JoinTokenDoc,
  joinTokenPath,
} from './models';
import {
  type CreateJoinTokenInput,
  type JoinNetworkInput,
  parseCreateJoinTokenInput,
  parseJoinNetworkInput,
  parsePreviewJoinTokenInput,
  type PreviewJoinTokenInput,
} from './validation';

/**
 * Pairing callables. Implement the cloud-side of MagicShare's pairing
 * flow per `docs/development/cloud-sync-spec.md` §5.3 Pairing.
 *
 * Three callables make up the flow:
 *
 *   1. createJoinToken   — issuing device mints a 5-min one-time token.
 *   2. previewJoinToken  — joining device reads the target group's
 *                          public-safe device list for confirmation.
 *   3. joinNetwork       — joining device atomically moves into the
 *                          target group, destroying the old (now-empty)
 *                          group if applicable.
 *
 * Design notes:
 *
 * - **Atomic move (joinNetwork).** The token-consume, source-side
 *   delete, target-side write, and source-account destruction all run
 *   in one Firestore transaction. The spec's prose ordering (§5.3) is
 *   "register → LAN handshake → leave previous"; we do it in one shot
 *   to preserve the §5.1 invariant "exactly one device group at any
 *   time" and avoid a half-paired state on failure.
 *
 * - **Custom-token re-auth.** Post-move, the joining device's auth UID
 *   no longer matches its (now-deleted or stale) source account, and
 *   future Firestore reads under the target account would fail under
 *   the security rules. `joinNetwork` mints a Firebase custom token
 *   bound to the target accountId and returns it; the client signs in
 *   with it (replacing its prior anon UID) so subsequent reads/writes
 *   pass the rules. Tests inject a stub minter; production wires
 *   `getAuth().createCustomToken(uid)` via the live default minter.
 *
 * - **No-source-account path.** The first-launch welcome-card route
 *   pairs *before* any account doc has been created for the joining
 *   device's transient anon UID — there is intentionally no source
 *   account to clean up. `joinNetwork` tolerates this: when the
 *   source account doc is absent, source-side cleanup is skipped and
 *   only the target-side write + token-consume + custom-token mint
 *   run.
 *
 * - **LAN-reachability is client-side.** The server cannot verify that
 *   the calling device shares a LAN with the issuing device. Epic 11
 *   enforces this on the joining device before calling
 *   `previewJoinToken`. The unguessable token (192 bits) is the
 *   cloud-side authorization — guard it like a credential.
 */

const TOKEN_LIFETIME_MS = 5 * 60_000;
const TOKEN_ID_BYTES = 24;

/**
 * Mints a Firebase custom token for [uid]. Injected so tests can swap
 * a deterministic stub in without exercising the Auth emulator on
 * every call (and so production code never reaches the live Auth
 * service from inside the unit-test process).
 */
export type CustomTokenMinter = (uid: string) => Promise<string>;

export interface CreateJoinTokenResult {
  tokenId: string;
  expiresAtMs: number;
}

/**
 * Mint a one-time pairing token bound to the caller's account and a
 * specific issuing device. Each call generates a fresh tokenId
 * (192 bits of entropy via `crypto.randomBytes` — collisions are
 * statistically impossible).
 *
 * Validates that both the account doc and the issuing device doc exist
 * before writing the token, so a bogus issuingDeviceId can't pollute
 * the `joinTokens` collection.
 */
export async function createJoinTokenLogic(
  db: Firestore,
  uid: string,
  input: CreateJoinTokenInput,
): Promise<CreateJoinTokenResult> {
  const accountRef = db.doc(accountPath(uid));
  const deviceRef = db.doc(devicePath(uid, input.issuingDeviceId));

  const [accountSnap, deviceSnap] = await Promise.all([accountRef.get(), deviceRef.get()]);
  if (!accountSnap.exists) {
    throw new HttpsError(
      'failed-precondition',
      'Account does not exist; call createAccount first.',
    );
  }
  if (!deviceSnap.exists) {
    throw new HttpsError('failed-precondition', 'Issuing device not found.');
  }

  const tokenId = randomBytes(TOKEN_ID_BYTES).toString('base64url');
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + TOKEN_LIFETIME_MS);
  const doc: JoinTokenDoc = {
    accountId: uid,
    createdAt: now,
    expiresAt,
    consumedAt: null,
    issuingDeviceId: input.issuingDeviceId,
  };
  await db.doc(joinTokenPath(tokenId)).set(doc);

  return { tokenId, expiresAtMs: expiresAt.toMillis() };
}

export const createJoinToken = onCall<unknown, Promise<CreateJoinTokenResult>>(
  instrument('createJoinToken', async (request) => {
    const uid = requireAuth(request);
    const input = parseCreateJoinTokenInput(request.data);
    return createJoinTokenLogic(getDb(), uid, input);
  }),
);

/**
 * Public-safe view of a device, returned by `previewJoinToken` so a
 * joining device can render the target group's device list before
 * confirming. `fcmToken` is intentionally absent — it would let a
 * leaker push directly.
 */
export interface JoinTokenPreviewDevice {
  deviceId: string;
  displayName: string;
  icon: DeviceIcon;
  platform: DevicePlatform;
}

export interface PreviewJoinTokenResult {
  accountId: string;
  issuingDeviceId: string;
  expiresAtMs: number;
  devices: JoinTokenPreviewDevice[];
}

function projectDeviceForPreview(deviceId: string, doc: DeviceDoc): JoinTokenPreviewDevice {
  return {
    deviceId,
    displayName: doc.displayName,
    icon: doc.icon,
    platform: doc.platform,
  };
}

/**
 * Read a join token and return the target group's public-safe device
 * list, plus token metadata, so the joining device can render a
 * confirmation UI. Read-only — does not consume the token. Users may
 * preview, cancel, and preview again until the 5-minute window closes.
 *
 * Auth: any authenticated user. The unguessable token is the
 * authorization; LAN-reachability is enforced client-side (Epic 11).
 */
export async function previewJoinTokenLogic(
  db: Firestore,
  input: PreviewJoinTokenInput,
): Promise<PreviewJoinTokenResult> {
  const tokenSnap = await db.doc(joinTokenPath(input.tokenId)).get();
  if (!tokenSnap.exists) {
    throw new HttpsError('not-found', 'Join token not found.');
  }
  const token = tokenSnap.data() as JoinTokenDoc;
  if (token.consumedAt !== null) {
    throw new HttpsError('failed-precondition', 'Join token already consumed.');
  }
  if (token.expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError('failed-precondition', 'Join token expired.');
  }

  const devices = await listGroupDevicesForPreview(db, token.accountId);
  return {
    accountId: token.accountId,
    issuingDeviceId: token.issuingDeviceId,
    expiresAtMs: token.expiresAt.toMillis(),
    devices,
  };
}

export const previewJoinToken = onCall<unknown, Promise<PreviewJoinTokenResult>>(
  instrument('previewJoinToken', async (request) => {
    requireAuth(request);
    const input = parsePreviewJoinTokenInput(request.data);
    return previewJoinTokenLogic(getDb(), input);
  }),
);

async function listGroupDevicesForPreview(
  db: Firestore,
  accountId: string,
): Promise<JoinTokenPreviewDevice[]> {
  const snap = await db
    .collection(`${ACCOUNTS_COLLECTION}/${accountId}/${DEVICES_SUBCOLLECTION}`)
    .get();
  return snap.docs
    .map((d) => projectDeviceForPreview(d.id, d.data() as DeviceDoc))
    .sort((a, b) => a.displayName.localeCompare(b.displayName));
}

export interface JoinNetworkResult {
  accountId: string;
  oldAccountDeleted: boolean;
  devices: JoinTokenPreviewDevice[];
  /**
   * Firebase custom token bound to [accountId]. The joining client
   * signs in with this token so its `auth.uid` switches from the
   * pre-pair anon UID to the target account's UID and Firestore
   * reads under the new account path start succeeding.
   */
  customToken: string;
}

/**
 * Atomically move the caller's device into the device group named by
 * the join token. If the source account was the moving device's only
 * home, the source account is destroyed in the same transaction.
 * Mints a Firebase custom token bound to the target accountId so the
 * client can re-auth to the new UID immediately after the move
 * lands, so subsequent Firestore reads under the new account path
 * pass the security rules.
 *
 * Behaviour:
 *
 * - Reads the token, source account/device, and target account inside
 *   one Firestore transaction (all reads before any writes per
 *   transactional integrity).
 * - Self-join (`sourceUid === token.accountId`) is rejected before any
 *   write so the token stays valid for a correct retry.
 * - Consumes the token (`consumedAt = now`) atomically with the move,
 *   making concurrent join attempts on the same token safe — the
 *   second attempt's transaction either retries and sees the
 *   non-null `consumedAt`, or sees the source device already missing.
 *   Either way it rejects with `failed-precondition`.
 * - Out-of-transaction `recursiveDelete` sweeps subcollections that
 *   transactions can't (any device-scoped subcollections on the
 *   surviving-source branch, or the entire source account subtree on
 *   the last-device branch). Mirrors `removeDeviceLogic`.
 * - **No source account.** When the caller's account doc does not
 *   exist (welcome-card route: anon sign-in happened only to
 *   authenticate the callable, no account/device docs were ever
 *   created), source-side cleanup is skipped entirely and a fresh
 *   device doc is written under the target account using the input
 *   alone (with a `pairing-pending` displayName / icon placeholder).
 *   The client will overwrite these via `registerDevice` after the
 *   custom-token re-auth completes.
 *
 * Returns the post-move target device list (public-safe projection)
 * plus a custom token bound to the target accountId so the client
 * can switch its `auth.uid` to the new value without a separate
 * round-trip.
 */
export async function joinNetworkLogic(
  db: Firestore,
  sourceUid: string,
  input: JoinNetworkInput,
  customTokenMinter: CustomTokenMinter = (uid) => getAuth().createCustomToken(uid),
): Promise<JoinNetworkResult> {
  const tokenRef = db.doc(joinTokenPath(input.tokenId));
  const sourceAccountRef = db.doc(accountPath(sourceUid));
  const sourceDeviceRef = db.doc(devicePath(sourceUid, input.deviceId));

  const result = await db.runTransaction(async (tx) => {
    const tokenSnap = await tx.get(tokenRef);
    if (!tokenSnap.exists) {
      throw new HttpsError('not-found', 'Join token not found.');
    }
    const token = tokenSnap.data() as JoinTokenDoc;
    if (token.consumedAt !== null) {
      throw new HttpsError('failed-precondition', 'Join token already consumed.');
    }
    if (token.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('failed-precondition', 'Join token expired.');
    }
    if (sourceUid === token.accountId) {
      throw new HttpsError('failed-precondition', 'Cannot join your own group.');
    }

    const targetAccountRef = db.doc(accountPath(token.accountId));
    const targetDeviceRef = db.doc(devicePath(token.accountId, input.deviceId));

    const [sourceAccountSnap, sourceDeviceSnap, targetAccountSnap] = await Promise.all([
      tx.get(sourceAccountRef),
      tx.get(sourceDeviceRef),
      tx.get(targetAccountRef),
    ]);
    if (!targetAccountSnap.exists) {
      throw new HttpsError('failed-precondition', 'Target account not found.');
    }

    const now = Timestamp.now();
    const hasSourceAccount = sourceAccountSnap.exists;

    if (hasSourceAccount && !sourceDeviceSnap.exists) {
      // Account exists but the device doesn't — partially-set-up source
      // group. The client should have called registerDevice first; fail
      // loudly so the joining UI surfaces a real error rather than
      // silently "moving" a non-existent device.
      throw new HttpsError('failed-precondition', 'Source device not found.');
    }

    tx.update(tokenRef, { consumedAt: now });

    let movedDevice: DeviceDoc;
    if (hasSourceAccount) {
      const sourceDevice = sourceDeviceSnap.data() as DeviceDoc;
      tx.delete(sourceDeviceRef);
      movedDevice = { ...sourceDevice };
    } else {
      // Welcome-card route: no source-side state to migrate. The
      // client must supply the new device's identity in
      // `input.newDevice`; otherwise we don't have enough information
      // to write a valid device doc (icon and platform are required
      // and have closed enums — there is no sensible "unknown"
      // value).
      if (!input.newDevice) {
        throw new HttpsError(
          'failed-precondition',
          'newDevice is required when no source account exists for the caller.',
        );
      }
      movedDevice = {
        displayName: input.newDevice.displayName,
        icon: input.newDevice.icon,
        fcmToken: input.newDevice.fcmToken,
        platform: input.newDevice.platform,
      };
    }

    tx.set(targetDeviceRef, movedDevice);
    tx.update(targetAccountRef, {
      deviceCount: FieldValue.increment(1),
      lastActiveAt: now,
    });

    if (!hasSourceAccount) {
      return { accountId: token.accountId, oldAccountDeleted: false, hadSourceAccount: false };
    }

    const sourceAccount = sourceAccountSnap.data() as AccountDoc;
    if (sourceAccount.deviceCount > 1) {
      tx.update(sourceAccountRef, {
        deviceCount: FieldValue.increment(-1),
        lastActiveAt: now,
      });
      return { accountId: token.accountId, oldAccountDeleted: false, hadSourceAccount: true };
    }
    tx.delete(sourceAccountRef);
    return { accountId: token.accountId, oldAccountDeleted: true, hadSourceAccount: true };
  });

  if (result.hadSourceAccount) {
    if (result.oldAccountDeleted) {
      await db.recursiveDelete(sourceAccountRef);
    } else {
      await db.recursiveDelete(sourceDeviceRef);
    }
  }

  const [devices, customToken] = await Promise.all([
    listGroupDevicesForPreview(db, result.accountId),
    customTokenMinter(result.accountId),
  ]);
  return {
    accountId: result.accountId,
    oldAccountDeleted: result.oldAccountDeleted,
    devices,
    customToken,
  };
}

export const joinNetwork = onCall<unknown, Promise<JoinNetworkResult>>(
  instrument('joinNetwork', async (request) => {
    const uid = requireAuth(request);
    const input = parseJoinNetworkInput(request.data);
    return joinNetworkLogic(getDb(), uid, input);
  }),
);
