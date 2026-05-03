import { randomUUID } from 'node:crypto';

import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { type Message, type Messaging } from 'firebase-admin/messaging';
import { onCall } from 'firebase-functions/v2/https';

import { assertSameAccountTx } from './account-access';
import { getDb, getMessaging } from './admin';
import { requireAuth } from './auth';
import { instrument } from './logging';
import {
  accountPath,
  type DeviceDoc,
  type InboxItemDoc,
  type InboxItemType,
  inboxItemPath,
  inboxPath,
  type PlaintextLinkPayload,
} from './models';
import { consumeSendQuota } from './rate-limit';
import {
  parsePollPendingWakesInput,
  parseSendLinkNotificationInput,
  parseSendWakeInput,
  type PollPendingWakesInput,
  type SendLinkNotificationInput,
  type SendWakeInput,
} from './validation';

/**
 * Notification dispatch callables (Epic 6). The cloud's role here is
 * narrow: verify the caller owns both source and target devices,
 * apply the soft per-source rate limit, and route the encrypted
 * payload to the target — over FCM for platforms that support it,
 * via the per-device `inbox` subcollection for Linux clients.
 *
 * Spec ref: `docs/development/cloud-sync-spec.md` §5.3 Notifications.
 */

/** Minimal slice of the admin Messaging API we depend on. Tests pass
 *  an in-memory stub that records calls. */
export type MessagingSender = Pick<Messaging, 'send'>;

const INBOX_TTL_MS = 5 * 60_000;

export interface SendWakeResult {
  /** True iff a wake reached the target's delivery channel. False is
   *  not an error — the spec tolerates "device has not registered for
   *  push yet" silently. */
  delivered: boolean;
  /** Which channel actually carried the wake. `none` means the target
   *  has no FCM token registered and isn't a Linux device. */
  channel: 'fcm' | 'inbox' | 'none';
}

interface FcmRoute {
  kind: 'fcm';
  fcmToken: string;
}
interface InboxRoute {
  kind: 'inbox';
}
interface NoneRoute {
  kind: 'none';
}
type Route = FcmRoute | InboxRoute | NoneRoute;

function pickRoute(target: DeviceDoc): Route {
  // Linux clients have no FCM support per the spec — they pull from
  // the inbox subcollection on a 30 s timer. Routing by platform (not
  // by `fcmToken == null`) makes the decision deterministic even when
  // a misbehaving Linux client registers a token it can't actually
  // receive on. Both sendWake and sendLinkNotification share this
  // routing — Linux always inbox, non-Linux always FCM if available.
  if (target.platform === 'linux') {
    return { kind: 'inbox' };
  }
  if (!target.fcmToken) {
    return { kind: 'none' };
  }
  return { kind: 'fcm', fcmToken: target.fcmToken };
}

function buildWakeFcmMessage(token: string, payload: string): Message {
  // Wake notifications are silent: data-only on Android, and rely on
  // APNs `content-available: 1` on iOS so the system delivers the
  // payload to a backgrounded app without surfacing UI. The
  // foreground/background dispatch lives in Epic 13.
  return {
    token,
    data: { type: 'wake', payload },
    android: { priority: 'high' },
    apns: {
      headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
      payload: { aps: { contentAvailable: true } },
    },
  };
}

/**
 * Authoritative `sendWake` implementation. Exported for the tests in
 * `test/functions/notifications.functions.test.ts` to call directly
 * against the emulator with a stub `Messaging`. The `onCall` wrapper
 * below threads the production singletons and structured logging
 * through.
 *
 * Design:
 *
 * - Both source and target must live under `accounts/{callerUid}` —
 *   the cross-account guard from `assertSameAccountTx`.
 * - The rate limit is per source device, shared with
 *   `sendLinkNotification`: a single device that fans out 30 wakes
 *   in 60 minutes pays the limit even if each wake targets a
 *   different sibling.
 * - For Linux targets, the inbox write is part of the same
 *   transaction as the quota debit, so a successful return guarantees
 *   the item is visible to the next `pollPendingWakes`.
 * - For non-Linux targets, the FCM call runs after the transaction.
 *   Worst case (FCM fails after the transaction commits) we leak one
 *   unit of quota for that source device. That's acceptable for a
 *   soft limit and avoids the much worse alternative of two-phase
 *   commit between Firestore and FCM.
 */
export async function sendWakeLogic(
  db: Firestore,
  messaging: MessagingSender,
  callerUid: string,
  input: SendWakeInput,
): Promise<SendWakeResult> {
  const accountRef = db.doc(accountPath(callerUid));

  const decision = await db.runTransaction(async (tx) => {
    // All reads first per Firestore transaction rules.
    const source = await assertSameAccountTx(tx, db, callerUid, input.sourceDeviceId);
    const target = await assertSameAccountTx(tx, db, callerUid, input.targetDeviceId);

    const now = Timestamp.now();
    const newQuota = consumeSendQuota(source.doc.recentSendsAt, now);
    const route = pickRoute(target.doc);

    tx.update(source.ref, { recentSendsAt: newQuota });
    tx.update(accountRef, { lastActiveAt: now });

    if (route.kind === 'inbox') {
      const itemId = randomUUID();
      const inboxRef = db.doc(inboxItemPath(callerUid, input.targetDeviceId, itemId));
      const inboxDoc: InboxItemDoc = {
        type: 'wake',
        payload: input.payload,
        createdAt: now,
        expiresAt: Timestamp.fromMillis(now.toMillis() + INBOX_TTL_MS),
      };
      tx.set(inboxRef, inboxDoc);
    }

    return route;
  });

  if (decision.kind === 'fcm') {
    await messaging.send(buildWakeFcmMessage(decision.fcmToken, input.payload));
    return { delivered: true, channel: 'fcm' };
  }
  if (decision.kind === 'inbox') {
    return { delivered: true, channel: 'inbox' };
  }
  return { delivered: false, channel: 'none' };
}

export const sendWake = onCall<unknown, Promise<SendWakeResult>>(
  instrument('sendWake', async (request) => {
    const uid = requireAuth(request);
    const input = parseSendWakeInput(request.data);
    return sendWakeLogic(getDb(), getMessaging(), uid, input);
  }),
);

export interface SendLinkNotificationResult {
  delivered: boolean;
  channel: 'fcm' | 'inbox' | 'none';
}

function buildLinkFcmMessage(token: string, input: SendLinkNotificationInput): Message {
  if (input.mode === 'plaintext') {
    // Visible notification — tap-to-open in the system browser. The
    // `data` field carries the URL too so a foreground app can hijack
    // the tap and open in-app per Epic 13's notification reception.
    const data: Record<string, string> = { type: 'link', url: input.url };
    if (input.title !== undefined) {
      data.title = input.title;
    }
    return {
      token,
      notification: {
        title: input.title ?? 'Open link',
        body: input.url,
      },
      data,
      android: { priority: 'high' },
    };
  }
  // Encrypted mode: data-only, identical wire shape to a wake.
  return {
    token,
    data: { type: 'link', payload: input.payload },
    android: { priority: 'high' },
    apns: {
      headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
      payload: { aps: { contentAvailable: true } },
    },
  };
}

function buildInboxLinkPayload(input: SendLinkNotificationInput): string | PlaintextLinkPayload {
  if (input.mode === 'encrypted') {
    return input.payload;
  }
  // Firestore admin SDK rejects undefined values by default, so we
  // build the object conditionally instead of using
  // `{ url, title: input.title }`.
  return input.title !== undefined ? { url: input.url, title: input.title } : { url: input.url };
}

/**
 * Authoritative `sendLinkNotification` implementation. Same shape as
 * `sendWakeLogic` — the only differences are the FCM message
 * (visible-notification in plaintext mode, data-only in encrypted)
 * and the inbox payload type (`'link'` plus the matching shape).
 *
 * The per-device user toggle "Encrypt link notifications" lives on
 * the client (Epic 12); the cloud just honours whatever mode the
 * caller sends. URL-scheme validation already ran in
 * `parseSendLinkNotificationInput`, so plaintext URLs reaching this
 * function are guaranteed `http`/`https`.
 */
export async function sendLinkNotificationLogic(
  db: Firestore,
  messaging: MessagingSender,
  callerUid: string,
  input: SendLinkNotificationInput,
): Promise<SendLinkNotificationResult> {
  const accountRef = db.doc(accountPath(callerUid));

  const decision = await db.runTransaction(async (tx) => {
    const source = await assertSameAccountTx(tx, db, callerUid, input.sourceDeviceId);
    const target = await assertSameAccountTx(tx, db, callerUid, input.targetDeviceId);

    const now = Timestamp.now();
    const newQuota = consumeSendQuota(source.doc.recentSendsAt, now);
    const route = pickRoute(target.doc);

    tx.update(source.ref, { recentSendsAt: newQuota });
    tx.update(accountRef, { lastActiveAt: now });

    if (route.kind === 'inbox') {
      const itemId = randomUUID();
      const inboxRef = db.doc(inboxItemPath(callerUid, input.targetDeviceId, itemId));
      const inboxDoc: InboxItemDoc = {
        type: 'link',
        payload: buildInboxLinkPayload(input),
        createdAt: now,
        expiresAt: Timestamp.fromMillis(now.toMillis() + INBOX_TTL_MS),
      };
      tx.set(inboxRef, inboxDoc);
    }

    return route;
  });

  if (decision.kind === 'fcm') {
    await messaging.send(buildLinkFcmMessage(decision.fcmToken, input));
    return { delivered: true, channel: 'fcm' };
  }
  if (decision.kind === 'inbox') {
    return { delivered: true, channel: 'inbox' };
  }
  return { delivered: false, channel: 'none' };
}

export const sendLinkNotification = onCall<unknown, Promise<SendLinkNotificationResult>>(
  instrument('sendLinkNotification', async (request) => {
    const uid = requireAuth(request);
    const input = parseSendLinkNotificationInput(request.data);
    return sendLinkNotificationLogic(getDb(), getMessaging(), uid, input);
  }),
);

export interface PollPendingWakesItem {
  id: string;
  type: InboxItemType;
  payload: string | PlaintextLinkPayload;
  createdAtMs: number;
  expiresAtMs: number;
}

export interface PollPendingWakesResult {
  items: PollPendingWakesItem[];
}

/**
 * Linux clients call this every ~30 s (Epic 7's polling loop) to
 * pull and atomically consume their `inbox` queue. The transaction
 * reads every pending item then deletes them in the same commit, so
 * concurrent polls cannot double-deliver: the loser's transaction
 * retries against the post-commit snapshot and finds an empty inbox.
 *
 * Items are returned in `createdAt` order so the client processes
 * them in the same sequence the sender produced them. Timestamps
 * cross the wire as ms-since-epoch (callable JSON has no native
 * Timestamp encoding) — the client converts back to a `DateTime`.
 */
export async function pollPendingWakesLogic(
  db: Firestore,
  callerUid: string,
  input: PollPendingWakesInput,
): Promise<PollPendingWakesResult> {
  const inboxColl = db.collection(inboxPath(callerUid, input.deviceId));

  return db.runTransaction(async (tx) => {
    await assertSameAccountTx(tx, db, callerUid, input.deviceId);

    const snap = await tx.get(inboxColl);

    const items: PollPendingWakesItem[] = snap.docs.map((d) => {
      const data = d.data() as InboxItemDoc;
      return {
        id: d.id,
        type: data.type,
        payload: data.payload,
        createdAtMs: data.createdAt.toMillis(),
        expiresAtMs: data.expiresAt.toMillis(),
      };
    });

    items.sort((a, b) => a.createdAtMs - b.createdAtMs);

    for (const docSnap of snap.docs) {
      tx.delete(docSnap.ref);
    }

    return { items };
  });
}

export const pollPendingWakes = onCall<unknown, Promise<PollPendingWakesResult>>(
  instrument('pollPendingWakes', async (request) => {
    const uid = requireAuth(request);
    const input = parsePollPendingWakesInput(request.data);
    return pollPendingWakesLogic(getDb(), uid, input);
  }),
);
