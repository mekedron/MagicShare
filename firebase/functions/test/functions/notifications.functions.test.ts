import { Timestamp } from 'firebase-admin/firestore';
import { type Message } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { getDb } from '../../src/admin';
import { type MessagingSender, sendWakeLogic } from '../../src/notifications';
import { SEND_RATE_LIMIT_PER_HOUR } from '../../src/rate-limit';

import { clearEmulator, listInboxIds, readDevice, seedAccount, seedDevice } from './_helpers';

const UID = 'wakeUser';
const OTHER_UID = 'otherUser';
const SRC = 'source-device';
const TGT_ANDROID = 'tgt-android';
const TGT_LINUX = 'tgt-linux';
const TGT_NO_FCM = 'tgt-no-fcm';

function fakeMessaging(): MessagingSender & { send: ReturnType<typeof vi.fn> } {
  return {
    send: vi
      .fn<(message: Message) => Promise<string>>()
      .mockResolvedValue('projects/test/messages/abc'),
  };
}

describe('sendWakeLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
    await seedAccount(UID);
    await seedDevice(UID, SRC, { displayName: 'My laptop', platform: 'macos' });
    await seedDevice(UID, TGT_ANDROID, {
      displayName: 'Pixel',
      platform: 'android',
      fcmToken: 'fcm-pixel',
    });
    await seedDevice(UID, TGT_LINUX, {
      displayName: 'Linux box',
      platform: 'linux',
      fcmToken: null,
    });
    await seedDevice(UID, TGT_NO_FCM, {
      displayName: 'Macbook (no token)',
      platform: 'macos',
      fcmToken: null,
    });
  });

  it('rejects with not-found when the target device lives in a different account', async () => {
    await seedAccount(OTHER_UID);
    await seedDevice(OTHER_UID, 'foreign-device', {
      platform: 'android',
      fcmToken: 'fcm-foreign',
    });
    const messaging = fakeMessaging();

    await expect(
      sendWakeLogic(getDb(), messaging, UID, {
        sourceDeviceId: SRC,
        targetDeviceId: 'foreign-device',
        payload: 'aGVsbG8',
      }),
    ).rejects.toMatchObject({ code: 'not-found' });
    expect(messaging.send).not.toHaveBeenCalled();
  });

  it('rejects with not-found when the source device is not the caller’s', async () => {
    const messaging = fakeMessaging();
    await expect(
      sendWakeLogic(getDb(), messaging, UID, {
        sourceDeviceId: 'no-such-source',
        targetDeviceId: TGT_ANDROID,
        payload: 'aGVsbG8',
      }),
    ).rejects.toMatchObject({ code: 'not-found' });
    expect(messaging.send).not.toHaveBeenCalled();
  });

  it('sends a data-only FCM message to a non-Linux target', async () => {
    const messaging = fakeMessaging();

    const result = await sendWakeLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      payload: 'opaque-blob',
    });

    expect(result).toEqual({ delivered: true, channel: 'fcm' });
    expect(messaging.send).toHaveBeenCalledTimes(1);
    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent).toMatchObject({
      token: 'fcm-pixel',
      data: { type: 'wake', payload: 'opaque-blob' },
      android: { priority: 'high' },
    });
    expect(sent.notification).toBeUndefined();
  });

  it('writes a Linux inbox item instead of calling FCM', async () => {
    const messaging = fakeMessaging();

    const result = await sendWakeLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      payload: 'opaque-blob',
    });

    expect(result).toEqual({ delivered: true, channel: 'inbox' });
    expect(messaging.send).not.toHaveBeenCalled();
    const inbox = await listInboxIds(UID, TGT_LINUX);
    expect(inbox).toHaveLength(1);
    const inboxSnap = await getDb()
      .doc(`accounts/${UID}/devices/${TGT_LINUX}/inbox/${inbox[0]}`)
      .get();
    const data = inboxSnap.data() as {
      type: string;
      payload: string;
      createdAt: Timestamp;
      expiresAt: Timestamp;
    };
    expect(data.type).toBe('wake');
    expect(data.payload).toBe('opaque-blob');
    expect(data.expiresAt.toMillis() - data.createdAt.toMillis()).toBe(5 * 60_000);
  });

  it("returns delivered:false channel:'none' when a non-Linux target has no fcmToken", async () => {
    const messaging = fakeMessaging();

    const result = await sendWakeLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_NO_FCM,
      payload: 'opaque-blob',
    });

    expect(result).toEqual({ delivered: false, channel: 'none' });
    expect(messaging.send).not.toHaveBeenCalled();
    expect(await listInboxIds(UID, TGT_NO_FCM)).toEqual([]);
  });

  it('charges the source device’s rate-limit window for every successful send', async () => {
    const messaging = fakeMessaging();

    await sendWakeLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      payload: 'p1',
    });
    await sendWakeLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      payload: 'p2',
    });

    const src = await readDevice(UID, SRC);
    expect(src?.recentSendsAt).toHaveLength(2);
  });

  it('rejects the (limit+1)th send within the window with resource-exhausted', async () => {
    const messaging = fakeMessaging();
    // Pre-load the source device with `limit` recent sends so the
    // very next call lands exactly at the boundary.
    const now = Date.now();
    const window = Array.from({ length: SEND_RATE_LIMIT_PER_HOUR }, (_, i) =>
      Timestamp.fromMillis(now - i * 1000),
    );
    await getDb().doc(`accounts/${UID}/devices/${SRC}`).update({ recentSendsAt: window });

    await expect(
      sendWakeLogic(getDb(), messaging, UID, {
        sourceDeviceId: SRC,
        targetDeviceId: TGT_ANDROID,
        payload: 'overflow',
      }),
    ).rejects.toMatchObject({ code: 'resource-exhausted' });
    expect(messaging.send).not.toHaveBeenCalled();
  });
});
