import { Timestamp } from 'firebase-admin/firestore';
import { type Message } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { getDb } from '../../src/admin';
import {
  type MessagingSender,
  pollPendingWakesLogic,
  sendLinkNotificationLogic,
  sendWakeLogic,
} from '../../src/notifications';
import { SEND_RATE_LIMIT_PER_HOUR } from '../../src/rate-limit';
import { parseSendLinkNotificationInput } from '../../src/validation';

import {
  clearEmulator,
  listInboxIds,
  readDevice,
  seedAccount,
  seedDevice,
  seedInboxItem,
} from './_helpers';

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

  it('sends an FCM message with a tappable wake notification to a non-Linux target', async () => {
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
      android: {
        priority: 'high',
        notification: { channelId: 'magicshare_cloud_sync' },
      },
    });
    expect(sent.notification?.title).toBe('MagicShare');
    expect(sent.notification?.body).toContain('My laptop');
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

describe('parseSendLinkNotificationInput URL validation', () => {
  const baseIds = { sourceDeviceId: 'src', targetDeviceId: 'tgt', mode: 'plaintext' };

  it.each([
    ['https://example.com'],
    ['http://example.com/path?q=1'],
    ['https://example.com:8080/with#fragment'],
  ])('accepts %s', (url) => {
    expect(() => parseSendLinkNotificationInput({ ...baseIds, url })).not.toThrow();
  });

  it.each([
    'javascript:alert(1)',
    'file:///etc/passwd',
    'data:text/html,<script>alert(1)</script>',
    'ftp://example.com',
    'not a url',
    '',
  ])('rejects %s', (url) => {
    expect(() => parseSendLinkNotificationInput({ ...baseIds, url })).toThrowError();
  });

  it('rejects URLs over the length cap', () => {
    const url = 'https://example.com/' + 'x'.repeat(2100);
    expect(() => parseSendLinkNotificationInput({ ...baseIds, url })).toThrowError();
  });

  it('rejects an unknown mode value', () => {
    expect(() =>
      parseSendLinkNotificationInput({ ...baseIds, mode: 'wat', url: 'https://example.com' }),
    ).toThrowError();
  });

  it('requires payload in encrypted mode', () => {
    expect(() =>
      parseSendLinkNotificationInput({
        sourceDeviceId: 'src',
        targetDeviceId: 'tgt',
        mode: 'encrypted',
      }),
    ).toThrowError();
  });
});

describe('sendLinkNotificationLogic', () => {
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
  });

  it('sends a visible FCM notification in plaintext mode with the URL in body', async () => {
    const messaging = fakeMessaging();

    const result = await sendLinkNotificationLogic(getDb(), messaging, UID, {
      mode: 'plaintext',
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      url: 'https://example.com/article',
      title: 'Cool article',
    });

    expect(result).toEqual({ delivered: true, channel: 'fcm' });
    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent.token).toBe('fcm-pixel');
    expect(sent.notification).toEqual({
      title: 'Cool article',
      body: 'https://example.com/article',
    });
    expect(sent.data).toEqual({
      type: 'link',
      url: 'https://example.com/article',
      title: 'Cool article',
    });
  });

  it("uses 'Open link' as default title when none is provided", async () => {
    const messaging = fakeMessaging();
    await sendLinkNotificationLogic(getDb(), messaging, UID, {
      mode: 'plaintext',
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      url: 'https://example.com/x',
    });
    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent.notification?.title).toBe('Open link');
  });

  it('sends a data-only FCM message in encrypted mode (no notification field)', async () => {
    const messaging = fakeMessaging();

    await sendLinkNotificationLogic(getDb(), messaging, UID, {
      mode: 'encrypted',
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      payload: 'opaque-link-blob',
    });

    const sent = messaging.send.mock.calls[0]?.[0] as Message;
    expect(sent.notification).toBeUndefined();
    expect(sent.data).toEqual({ type: 'link', payload: 'opaque-link-blob' });
  });

  it('writes a Linux inbox item with the plaintext object payload', async () => {
    const messaging = fakeMessaging();

    await sendLinkNotificationLogic(getDb(), messaging, UID, {
      mode: 'plaintext',
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      url: 'https://example.com/path',
      title: 'Hi',
    });

    expect(messaging.send).not.toHaveBeenCalled();
    const inbox = await listInboxIds(UID, TGT_LINUX);
    expect(inbox).toHaveLength(1);
    const data = (
      await getDb().doc(`accounts/${UID}/devices/${TGT_LINUX}/inbox/${inbox[0]}`).get()
    ).data() as { type: string; payload: { url: string; title?: string } };
    expect(data.type).toBe('link');
    expect(data.payload).toEqual({ url: 'https://example.com/path', title: 'Hi' });
  });

  it('writes a Linux inbox item with the encrypted blob payload', async () => {
    const messaging = fakeMessaging();

    await sendLinkNotificationLogic(getDb(), messaging, UID, {
      mode: 'encrypted',
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      payload: 'opaque-link-blob',
    });

    const inbox = await listInboxIds(UID, TGT_LINUX);
    const data = (
      await getDb().doc(`accounts/${UID}/devices/${TGT_LINUX}/inbox/${inbox[0]}`).get()
    ).data() as { type: string; payload: string };
    expect(data.payload).toBe('opaque-link-blob');
  });

  it('shares the rate-limit window with sendWake', async () => {
    const messaging = fakeMessaging();
    await sendLinkNotificationLogic(getDb(), messaging, UID, {
      mode: 'plaintext',
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      url: 'https://example.com',
    });
    await sendWakeLogic(getDb(), messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      payload: 'wake-blob',
    });
    const src = await readDevice(UID, SRC);
    expect(src?.recentSendsAt).toHaveLength(2);
  });
});

describe('pollPendingWakesLogic', () => {
  const LINUX_DEVICE = 'linux-poller';
  const SIBLING_DEVICE = 'sibling';

  beforeEach(async () => {
    await clearEmulator();
    await seedAccount(UID);
    await seedDevice(UID, LINUX_DEVICE, { platform: 'linux', fcmToken: null });
    await seedDevice(UID, SIBLING_DEVICE, { platform: 'macos' });
  });

  it('returns an empty list when the inbox is empty', async () => {
    const result = await pollPendingWakesLogic(getDb(), UID, { deviceId: LINUX_DEVICE });
    expect(result).toEqual({ items: [] });
  });

  it('returns all pending items in createdAt order and clears the inbox', async () => {
    const t0 = Timestamp.fromMillis(Date.now() - 30_000);
    const t1 = Timestamp.fromMillis(Date.now() - 10_000);
    const t2 = Timestamp.fromMillis(Date.now() - 5_000);
    // Seed deliberately out of insertion order so the sort path is exercised.
    await seedInboxItem(UID, LINUX_DEVICE, 'middle', { createdAt: t1, payload: 'b' });
    await seedInboxItem(UID, LINUX_DEVICE, 'oldest', { createdAt: t0, payload: 'a' });
    await seedInboxItem(UID, LINUX_DEVICE, 'newest', { createdAt: t2, payload: 'c' });

    const result = await pollPendingWakesLogic(getDb(), UID, { deviceId: LINUX_DEVICE });

    expect(result.items.map((i) => i.id)).toEqual(['oldest', 'middle', 'newest']);
    expect(result.items.map((i) => i.payload)).toEqual(['a', 'b', 'c']);
    expect(result.items[0].createdAtMs).toBe(t0.toMillis());
    expect(await listInboxIds(UID, LINUX_DEVICE)).toEqual([]);
  });

  it('does not touch sibling devices’ inboxes', async () => {
    await seedInboxItem(UID, LINUX_DEVICE, 'mine');
    await seedInboxItem(UID, SIBLING_DEVICE, 'theirs');

    const result = await pollPendingWakesLogic(getDb(), UID, { deviceId: LINUX_DEVICE });

    expect(result.items.map((i) => i.id)).toEqual(['mine']);
    expect(await listInboxIds(UID, LINUX_DEVICE)).toEqual([]);
    expect(await listInboxIds(UID, SIBLING_DEVICE)).toEqual(['theirs']);
  });

  it('rejects with not-found when the caller does not own the device', async () => {
    await seedAccount(OTHER_UID);
    await seedDevice(OTHER_UID, LINUX_DEVICE, { platform: 'linux', fcmToken: null });
    await seedInboxItem(OTHER_UID, LINUX_DEVICE, 'theirs');

    await expect(
      pollPendingWakesLogic(getDb(), UID, { deviceId: 'no-such-device' }),
    ).rejects.toMatchObject({ code: 'not-found' });
    // The other account's inbox stays untouched.
    expect(await listInboxIds(OTHER_UID, LINUX_DEVICE)).toEqual(['theirs']);
  });

  it('does not double-deliver under concurrent polls', async () => {
    // Seed multiple items, then race two polls against the same device.
    const ids = Array.from({ length: 5 }, (_, i) => `item-${i}`);
    for (let i = 0; i < ids.length; i++) {
      await seedInboxItem(UID, LINUX_DEVICE, ids[i], {
        createdAt: Timestamp.fromMillis(Date.now() - 10_000 + i),
      });
    }

    const [a, b] = await Promise.all([
      pollPendingWakesLogic(getDb(), UID, { deviceId: LINUX_DEVICE }),
      pollPendingWakesLogic(getDb(), UID, { deviceId: LINUX_DEVICE }),
    ]);

    const seen = [...a.items.map((i) => i.id), ...b.items.map((i) => i.id)].sort();
    expect(seen).toEqual([...ids].sort());
    expect(await listInboxIds(UID, LINUX_DEVICE)).toEqual([]);
  });
});
