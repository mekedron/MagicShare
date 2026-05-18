import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { type Message, type Messaging } from 'firebase-admin/messaging';
import { onCall } from 'firebase-functions/v2/https';

import { assertSameAccountTx } from './account-access';
import { getDb, getMessaging } from './admin';
import { requireAuth } from './auth';
import { instrument } from './logging';
import { accountPath, type DeviceDoc } from './models';
import { consumeSendQuota } from './rate-limit';
import { parseNotifyTransferIntentInput, type NotifyTransferIntentInput } from './validation';

/**
 * `notifyTransferIntent` — the only cloud→device notification channel
 * MagicShare uses. The sender's client calls this the moment the user
 * taps a group device in the Send tab, regardless of whether the target
 * is currently reachable on LAN. The cloud's job is narrow: verify the
 * caller owns both devices, apply the per-source rate limit, and
 * publish a visible FCM notification so the receiver phone surfaces it
 * even when the app is backgrounded or killed. Tapping the
 * notification just opens the app — there is no encrypted payload, no
 * auto-accept handshake, no Linux inbox fallback. The wait-for-online
 * popup on the sender side resolves the rest.
 */

/** Minimal slice of the admin Messaging API we depend on. Tests pass
 *  an in-memory stub that records calls. */
export type MessagingSender = Pick<Messaging, 'send'>;

export interface NotifyTransferIntentResult {
  /** True iff a notification reached an FCM token. False is not an
   *  error — Linux targets and stale registrations land here silently. */
  delivered: boolean;
  /** Which channel actually carried the notification. `none` means the
   *  target has no FCM token registered. */
  channel: 'fcm' | 'none';
}

function kindNoun(kind: NotifyTransferIntentInput['kind']): string {
  switch (kind) {
    case 'file':
      return 'files';
    case 'text':
      return 'a message';
    case 'url':
      return 'a link';
  }
}

function buildFcmMessage(
  token: string,
  source: DeviceDoc,
  kind: NotifyTransferIntentInput['kind'],
): Message {
  const senderDisplayName = source.displayName ?? '';
  const noun = kindNoun(kind);
  const body =
    senderDisplayName.length > 0
      ? `${senderDisplayName} wants to send you ${noun}. Tap to open MagicShare.`
      : `Someone wants to send you ${noun}. Tap to open MagicShare.`;

  return {
    token,
    // Data carries the kind purely so the foreground listener can log
    // it. No business logic depends on the data payload — the OS shows
    // the visible notification, the user taps, the app opens.
    data: { type: 'transfer', kind },
    notification: {
      title: 'MagicShare',
      body,
    },
    android: {
      priority: 'high',
      notification: {
        // Reuse the channel declared in
        // app/android/app/src/main/AndroidManifest.xml.
        channelId: 'magicshare_cloud_sync',
      },
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
      payload: { aps: { alert: { title: 'MagicShare', body } } },
    },
  };
}

/**
 * Authoritative `notifyTransferIntent` implementation. Exported so the
 * test suite can call it directly against the emulator with a stub
 * `Messaging`. The `onCall` wrapper below threads the production
 * singletons and structured logging through.
 *
 * Design notes:
 *
 * - Both source and target must live under `accounts/{callerUid}` —
 *   enforced by `assertSameAccountTx`.
 * - The per-source rate limit lives on the source device's
 *   `recentSendsAt` field and is shared across every cloud→device
 *   notification this account ever fires.
 * - FCM publish runs *after* the transaction commits. Worst case (FCM
 *   rejects after the quota debit landed) we leak one unit of quota
 *   for the source device — acceptable for a soft 30/hour limit and
 *   avoids two-phase commit between Firestore and FCM.
 * - Targets without `fcmToken` (Linux, or a non-Linux client that
 *   never registered) return `channel: 'none'` silently. The sender's
 *   wait-for-online popup is the real fallback.
 */
export async function notifyTransferIntentLogic(
  db: Firestore,
  messaging: MessagingSender,
  callerUid: string,
  input: NotifyTransferIntentInput,
): Promise<NotifyTransferIntentResult> {
  const accountRef = db.doc(accountPath(callerUid));

  const decision = await db.runTransaction(async (tx) => {
    const source = await assertSameAccountTx(tx, db, callerUid, input.sourceDeviceId);
    const target = await assertSameAccountTx(tx, db, callerUid, input.targetDeviceId);

    const now = Timestamp.now();
    const newQuota = consumeSendQuota(source.doc.recentSendsAt, now);

    tx.update(source.ref, { recentSendsAt: newQuota });
    tx.update(accountRef, { lastActiveAt: now });

    return { source: source.doc, target: target.doc };
  });

  if (!decision.target.fcmToken) {
    return { delivered: false, channel: 'none' };
  }

  await messaging.send(buildFcmMessage(decision.target.fcmToken, decision.source, input.kind));
  return { delivered: true, channel: 'fcm' };
}

export const notifyTransferIntent = onCall<unknown, Promise<NotifyTransferIntentResult>>(
  instrument('notifyTransferIntent', async (request) => {
    const uid = requireAuth(request);
    const input = parseNotifyTransferIntentInput(request.data);
    return notifyTransferIntentLogic(getDb(), getMessaging(), uid, input);
  }),
);
