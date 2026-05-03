import { randomBytes } from 'node:crypto';

import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { getDb } from './admin';
import { requireAuth } from './auth';
import { accountPath, devicePath, type JoinTokenDoc, joinTokenPath } from './models';
import { type CreateJoinTokenInput, parseCreateJoinTokenInput } from './validation';

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
