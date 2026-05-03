import { randomBytes } from 'node:crypto';

import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { getDb } from './admin';
import { requireAuth } from './auth';
import {
  ACCOUNTS_COLLECTION,
  accountPath,
  type DeviceDoc,
  type DeviceIcon,
  DEVICES_SUBCOLLECTION,
  type DevicePlatform,
  type DevicePresence,
  devicePath,
  type JoinTokenDoc,
  joinTokenPath,
} from './models';
import {
  type CreateJoinTokenInput,
  parseCreateJoinTokenInput,
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
 * - **Custom-token re-auth is deferred to Epic 11.** Post-`joinNetwork`,
 *   the joining device's auth UID still matches the now-deleted source
 *   account. Epic 11 (Pairing UI + LAN key exchange) is the right place
 *   to add the custom-token issuance + client-side re-auth, since that
 *   is where the LAN handshake also lands.
 *
 * - **LAN-reachability is client-side.** The server cannot verify that
 *   the calling device shares a LAN with the issuing device. Epic 11
 *   enforces this on the joining device before calling
 *   `previewJoinToken`. The unguessable token (192 bits) is the
 *   cloud-side authorization — guard it like a credential.
 */

const TOKEN_LIFETIME_MS = 5 * 60_000;
const TOKEN_ID_BYTES = 24;

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

export const createJoinToken = onCall<unknown, Promise<CreateJoinTokenResult>>(async (request) => {
  const uid = requireAuth(request);
  const input = parseCreateJoinTokenInput(request.data);
  return createJoinTokenLogic(getDb(), uid, input);
});

/**
 * Public-safe view of a device, returned by `previewJoinToken` so a
 * joining device can render the target group's device list before
 * confirming. `fcmToken` and `lastSeenAt` are intentionally absent —
 * `fcmToken` would let a leaker push directly, and `lastSeenAt` exposes
 * activity-pattern information the joining user has no need to see
 * before joining.
 */
export interface JoinTokenPreviewDevice {
  deviceId: string;
  displayName: string;
  icon: DeviceIcon;
  platform: DevicePlatform;
  presence: DevicePresence;
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
    presence: doc.presence,
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

  const devicesSnap = await db
    .collection(`${ACCOUNTS_COLLECTION}/${token.accountId}/${DEVICES_SUBCOLLECTION}`)
    .get();
  const devices: JoinTokenPreviewDevice[] = devicesSnap.docs
    .map((d) => projectDeviceForPreview(d.id, d.data() as DeviceDoc))
    .sort((a, b) => a.displayName.localeCompare(b.displayName));

  return {
    accountId: token.accountId,
    issuingDeviceId: token.issuingDeviceId,
    expiresAtMs: token.expiresAt.toMillis(),
    devices,
  };
}

export const previewJoinToken = onCall<unknown, Promise<PreviewJoinTokenResult>>(
  async (request) => {
    requireAuth(request);
    const input = parsePreviewJoinTokenInput(request.data);
    return previewJoinTokenLogic(getDb(), input);
  },
);
