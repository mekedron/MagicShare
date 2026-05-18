import { Timestamp } from 'firebase-admin/firestore';
import { type Message } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { getDb } from '../../src/admin';
import { SEND_RATE_LIMIT_PER_HOUR } from '../../src/rate-limit';
import { type MessagingSender, notifyTransferIntentLogic } from '../../src/transfer-notify';
import { parseNotifyTransferIntentInput } from '../../src/validation';

import { clearEmulator, readDevice, seedAccount, seedDevice } from './_helpers';

const UID = 'notifyUser';
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

describe('parseNotifyTransferIntentInput', () => {
  it('accepts the three valid kinds', () => {
    for (const kind of ['file', 'text', 'url'] as const) {
      expect(() =>
        parseNotifyTransferIntentInput({ sourceDeviceId: 's', targetDeviceId: 't', kind }),
      ).not.toThrow();
    }
  });

  it('rejects an unknown kind', () => {
    expect(() =>
      parseNotifyTransferIntentInput({ sourceDeviceId: 's', targetDeviceId: 't', kind: 'wat' }),
    ).toThrowError();
  });

  it('rejects empty source/target ids', () => {
    expect(() =>
      parseNotifyTransferIntentInput({ sourceDeviceId: '', targetDeviceId: 't', kind: 'file' }),
    ).toThrowError();
    expect(() =>
      parseNotifyTransferIntentInput({ sourceDeviceId: 's', targetDeviceId: '', kind: 'file' }),
    ).toThrowError();
  });
});

describe('notifyTransferIntentLogic', () => {
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
      notifyTransferIntentLogic(getDb(), messaging, UID, {
        sourceDeviceId: SRC,
        targetDeviceId: 'foreign-device',
        kind: 'file',
      }),
    ).rejects.toMatchObject({ code: 'not-found' });
    expect(messaging.send).not.toHaveBeenCalled();
  });

  it('rejects with not-found when the source device is not the caller’s', async () => {
    const messaging = fakeMessaging();
    await expect(
      notifyTransferIntentLogic(getDb(), messaging, UID, {
        sourceDeviceId: 'no-such-source',
        targetDeviceId: TGT_ANDROID,
        kind: 'file',
      }),
    ).rejects.toMatchObject({ code: 'not-found' });
    expect(messaging.send).not.toHaveBeenCalled();
  });

  it('sends a visible FCM notification to a target with an fcmToken', async () => {
    const messaging = fakeMessaging();

    const result = await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      kind: 'file',
    });

    expect(result).toEqual({ delivered: true, channel: 'fcm' });
    expect(messaging.send).toHaveBeenCalledTimes(1);
    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent.token).toBe('fcm-pixel');
    expect(sent.notification?.title).toBe('MagicShare');
    expect(sent.notification?.body).toContain('My laptop');
    expect(sent.notification?.body).toContain('files');
    expect(sent.data).toEqual({ type: 'transfer', kind: 'file' });
    expect(sent.android?.notification?.channelId).toBe('magicshare_cloud_sync');
    expect(sent.apns?.headers?.['apns-push-type']).toBe('alert');
  });

  it.each([
    ['file', 'files'],
    ['text', 'a message'],
    ['url', 'a link'],
  ] as const)('maps kind=%s to noun=%s in the notification body', async (kind, noun) => {
    const messaging = fakeMessaging();
    await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      kind,
    });
    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent.notification?.body).toContain(noun);
  });

  it("returns delivered:false channel:'none' when the target has no fcmToken (Linux or unregistered)", async () => {
    const messaging = fakeMessaging();

    const linuxResult = await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      kind: 'file',
    });
    const noTokenResult = await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_NO_FCM,
      kind: 'text',
    });

    expect(linuxResult).toEqual({ delivered: false, channel: 'none' });
    expect(noTokenResult).toEqual({ delivered: false, channel: 'none' });
    expect(messaging.send).not.toHaveBeenCalled();
  });

  it('charges the source device’s rate-limit window for every successful call', async () => {
    const messaging = fakeMessaging();

    await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      kind: 'file',
    });
    await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      kind: 'text',
    });

    const src = await readDevice(UID, SRC);
    expect(src?.recentSendsAt).toHaveLength(2);
  });

  it('rejects the (limit+1)th call within the window with resource-exhausted', async () => {
    const messaging = fakeMessaging();
    const now = Date.now();
    const window = Array.from({ length: SEND_RATE_LIMIT_PER_HOUR }, (_, i) =>
      Timestamp.fromMillis(now - i * 1000),
    );
    await getDb().doc(`accounts/${UID}/devices/${SRC}`).update({ recentSendsAt: window });

    await expect(
      notifyTransferIntentLogic(getDb(), messaging, UID, {
        sourceDeviceId: SRC,
        targetDeviceId: TGT_ANDROID,
        kind: 'file',
      }),
    ).rejects.toMatchObject({ code: 'resource-exhausted' });
    expect(messaging.send).not.toHaveBeenCalled();
  });

  it('falls back to a "someone" body when the source has no display name', async () => {
    await getDb().doc(`accounts/${UID}/devices/${SRC}`).update({ displayName: '' });
    const messaging = fakeMessaging();

    await notifyTransferIntentLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      kind: 'url',
    });

    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent.notification?.body?.toLowerCase()).toContain('someone');
    expect(sent.notification?.body).toContain('a link');
  });
});
