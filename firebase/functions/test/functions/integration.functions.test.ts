import { Timestamp } from 'firebase-admin/firestore';
import { type Message } from 'firebase-admin/messaging';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { createAccountLogic, deleteAccountLogic } from '../../src/accounts';
import { getDb } from '../../src/admin';
import {
  registerDeviceLogic,
  removeDeviceLogic,
  renameDeviceLogic,
  setDeviceIconLogic,
} from '../../src/devices';
import {
  type MessagingSender,
  pollPendingWakesLogic,
  sendWakeLogic,
} from '../../src/notifications';
import { createJoinTokenLogic, joinNetworkLogic, previewJoinTokenLogic } from '../../src/pairing';
import {
  cleanupExpiredJoinTokensLogic,
  cleanupInactiveAccountsLogic,
} from '../../src/scheduled';

import {
  clearEmulator,
  listDeviceIds,
  listInboxIds,
  listJoinTokenIds,
  readAccount,
  readDevice,
  readJoinToken,
  seedAccount,
  seedDevice,
  seedInboxItem,
  seedJoinToken,
} from './_helpers';

const UID = 'integrationUser';
const LAPTOP = 'laptop-id';
const PHONE = 'phone-id';

describe('Epic 4 integration: account + device lifecycle', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('drives the full lifecycle end-to-end with consistent Firestore state', async () => {
    const db = getDb();

    // 1. createAccount
    const create = await createAccountLogic(db, UID);
    expect(create).toEqual({ created: true, accountId: UID });
    expect((await readAccount(UID))?.deviceCount).toBe(0);

    // 2. registerDevice ×2 (laptop, phone)
    const registerLaptop = await registerDeviceLogic(db, UID, {
      deviceId: LAPTOP,
      displayName: "Niki's Laptop",
      icon: 'laptop',
      fcmToken: 'fcm-laptop',
      platform: 'macos',
    });
    expect(registerLaptop).toEqual({ created: true });
    expect((await readAccount(UID))?.deviceCount).toBe(1);

    const registerPhone = await registerDeviceLogic(db, UID, {
      deviceId: PHONE,
      displayName: 'Pixel',
      icon: 'phone',
      fcmToken: 'fcm-phone',
      platform: 'android',
    });
    expect(registerPhone).toEqual({ created: true });
    expect((await readAccount(UID))?.deviceCount).toBe(2);
    expect((await listDeviceIds(UID)).sort()).toEqual([LAPTOP, PHONE].sort());

    // 3. renameDevice (laptop → "Work Laptop")
    await renameDeviceLogic(db, UID, { deviceId: LAPTOP, displayName: 'Work Laptop' });
    expect((await readDevice(UID, LAPTOP))?.displayName).toBe('Work Laptop');

    // 4. setDeviceIcon (phone → tablet, just to prove it)
    await setDeviceIconLogic(db, UID, { deviceId: PHONE, icon: 'tablet' });
    expect((await readDevice(UID, PHONE))?.icon).toBe('tablet');

    // 5. Seed an inbox item on the laptop so the cascade has something
    //    to clean up when we remove it.
    await seedInboxItem(UID, LAPTOP, 'pendingWake');

    // 6. removeDevice (laptop): account survives, deviceCount drops
    //    to 1, laptop's inbox is cleared.
    const removeLaptop = await removeDeviceLogic(db, UID, { deviceId: LAPTOP });
    expect(removeLaptop).toEqual({ accountDeleted: false });
    expect((await readAccount(UID))?.deviceCount).toBe(1);
    expect(await readDevice(UID, LAPTOP)).toBeNull();
    expect(await readDevice(UID, PHONE)).not.toBeNull();
    expect(await listDeviceIds(UID)).toEqual([PHONE]);

    // 7. deleteAccount: account, remaining device, and any leftover
    //    inbox items are wiped.
    const deletion = await deleteAccountLogic(db, UID);
    expect(deletion).toEqual({ deleted: true });
    expect(await readAccount(UID)).toBeNull();
    expect(await listDeviceIds(UID)).toEqual([]);
  });
});

describe('Epic 5 integration: pairing', () => {
  const UID_A = 'integ-A';
  const UID_B = 'integ-B';
  const A1 = 'a1-laptop';
  const B1 = 'b1-pixel';
  const B2 = 'b2-ipad';

  // Stub minter mirrors production shape but bypasses the Auth
  // emulator round-trip. The integration test cares about Firestore
  // state, not custom-token signing.
  const fakeMinter = async (uid: string) => `stub-token:${uid}`;

  beforeEach(async () => {
    await clearEmulator();
  });

  it('pairs two installations end-to-end and destroys the joining account when its last device leaves', async () => {
    const db = getDb();

    // 1. Both groups bootstrap independently: A and B each create an
    //    account and register one device.
    await createAccountLogic(db, UID_A);
    await createAccountLogic(db, UID_B);
    await registerDeviceLogic(db, UID_A, {
      deviceId: A1,
      displayName: 'MacBook Pro',
      icon: 'laptop',
      fcmToken: 'fcm-a1',
      platform: 'macos',
    });
    await registerDeviceLogic(db, UID_B, {
      deviceId: B1,
      displayName: 'Pixel 8',
      icon: 'phone',
      fcmToken: 'fcm-b1',
      platform: 'android',
    });

    // 2. A shows a QR code: createJoinToken from A's device.
    const minted = await createJoinTokenLogic(db, UID_A, { issuingDeviceId: A1 });
    expect(minted.tokenId).toBeTruthy();

    // 3. B scans the QR and previews: should see A's group (just A1).
    //    The preview must NOT consume the token.
    const preview = await previewJoinTokenLogic(db, { tokenId: minted.tokenId });
    expect(preview.accountId).toBe(UID_A);
    expect(preview.issuingDeviceId).toBe(A1);
    expect(preview.devices.map((d) => d.deviceId)).toEqual([A1]);
    expect((await readJoinToken(minted.tokenId))?.consumedAt).toBeNull();

    // 4. B confirms: joinNetwork moves B1 into A. B was a single-device
    //    group, so its account is destroyed in the same transaction.
    const join = await joinNetworkLogic(
      db,
      UID_B,
      { tokenId: minted.tokenId, deviceId: B1 },
      fakeMinter,
    );
    expect(join.accountId).toBe(UID_A);
    expect(join.oldAccountDeleted).toBe(true);
    expect(join.devices.map((d) => d.deviceId).sort()).toEqual([A1, B1].sort());
    expect(join.customToken).toBe(`stub-token:${UID_A}`);

    // 5. End state: A has both devices, B is gone, token is consumed.
    expect((await readAccount(UID_A))?.deviceCount).toBe(2);
    expect(await readAccount(UID_B)).toBeNull();
    expect((await listDeviceIds(UID_A)).sort()).toEqual([A1, B1].sort());
    expect(await listDeviceIds(UID_B)).toEqual([]);
    expect((await readDevice(UID_A, B1))?.displayName).toBe('Pixel 8');
    expect((await readJoinToken(minted.tokenId))?.consumedAt).not.toBeNull();
  });

  it('preserves the source group when only one of its devices leaves', async () => {
    const db = getDb();

    // A is the issuer with one device; B owns two devices and only
    // moves B1 over. B's account survives with B2 still registered.
    await createAccountLogic(db, UID_A);
    await createAccountLogic(db, UID_B);
    await registerDeviceLogic(db, UID_A, {
      deviceId: A1,
      displayName: 'MacBook Pro',
      icon: 'laptop',
      fcmToken: 'fcm-a1',
      platform: 'macos',
    });
    await registerDeviceLogic(db, UID_B, {
      deviceId: B1,
      displayName: 'Pixel 8',
      icon: 'phone',
      fcmToken: 'fcm-b1',
      platform: 'android',
    });
    await registerDeviceLogic(db, UID_B, {
      deviceId: B2,
      displayName: 'iPad',
      icon: 'tablet',
      fcmToken: 'fcm-b2',
      platform: 'ios',
    });

    const minted = await createJoinTokenLogic(db, UID_A, { issuingDeviceId: A1 });
    const join = await joinNetworkLogic(
      db,
      UID_B,
      { tokenId: minted.tokenId, deviceId: B1 },
      fakeMinter,
    );

    expect(join.oldAccountDeleted).toBe(false);
    expect((await readAccount(UID_A))?.deviceCount).toBe(2);
    expect((await readAccount(UID_B))?.deviceCount).toBe(1);
    expect((await listDeviceIds(UID_B)).sort()).toEqual([B2]);
    expect((await listDeviceIds(UID_A)).sort()).toEqual([A1, B1].sort());
    expect(await readDevice(UID_A, B1)).not.toBeNull();
    expect(await readDevice(UID_B, B1)).toBeNull();
  });

  it('welcome-card path: anon UID with no source state pairs into the target group', async () => {
    const db = getDb();
    const anonUid = 'transient-anon-uid';
    const newDeviceId = 'fresh-device-from-welcome';

    // A bootstraps as before; B is a pristine install that has only
    // signed in anonymously to authenticate the call — no
    // createAccount, no registerDevice on B's UID yet.
    await createAccountLogic(db, UID_A);
    await registerDeviceLogic(db, UID_A, {
      deviceId: A1,
      displayName: 'MacBook Pro',
      icon: 'laptop',
      fcmToken: 'fcm-a1',
      platform: 'macos',
    });

    const minted = await createJoinTokenLogic(db, UID_A, { issuingDeviceId: A1 });
    const join = await joinNetworkLogic(
      db,
      anonUid,
      {
        tokenId: minted.tokenId,
        deviceId: newDeviceId,
        newDevice: {
          displayName: 'Niki Pixel',
          icon: 'phone',
          fcmToken: 'fcm-fresh',
          platform: 'android',
        },
      },
      fakeMinter,
    );

    expect(join.accountId).toBe(UID_A);
    expect(join.oldAccountDeleted).toBe(false);
    expect(join.customToken).toBe(`stub-token:${UID_A}`);
    expect(join.devices.map((d) => d.deviceId).sort()).toEqual([A1, newDeviceId].sort());

    // No account doc was ever created for the anon UID.
    expect(await readAccount(anonUid)).toBeNull();
    // Target picked up the new device with the supplied identity.
    expect((await readAccount(UID_A))?.deviceCount).toBe(2);
    const created = await readDevice(UID_A, newDeviceId);
    expect(created?.displayName).toBe('Niki Pixel');
    expect(created?.icon).toBe('phone');
    expect(created?.platform).toBe('android');
    expect(created?.fcmToken).toBe('fcm-fresh');
  });
});

describe('Epic 6 integration: notifications + maintenance', () => {
  const UID = 'epic6User';
  const SRC = 'src-laptop';
  const TGT_ANDROID = 'tgt-pixel';
  const TGT_LINUX = 'tgt-linux';

  function fakeMessaging(): MessagingSender & { send: ReturnType<typeof vi.fn> } {
    return {
      send: vi
        .fn<(message: Message) => Promise<string>>()
        .mockResolvedValue('projects/test/messages/abc'),
    };
  }

  beforeEach(async () => {
    await clearEmulator();
  });

  it('drives wake → fan-out (FCM + inbox) → poll → maintenance end-to-end', async () => {
    const db = getDb();
    const messaging = fakeMessaging();

    // 1. Bootstrap one group with three devices: a sender, an Android
    //    target (FCM), and a Linux target (inbox-only).
    await createAccountLogic(db, UID);
    await registerDeviceLogic(db, UID, {
      deviceId: SRC,
      displayName: 'Macbook Pro',
      icon: 'laptop',
      fcmToken: 'fcm-src',
      platform: 'macos',
    });
    await registerDeviceLogic(db, UID, {
      deviceId: TGT_ANDROID,
      displayName: 'Pixel 8',
      icon: 'phone',
      fcmToken: 'fcm-pixel',
      platform: 'android',
    });
    await registerDeviceLogic(db, UID, {
      deviceId: TGT_LINUX,
      displayName: 'Linux box',
      icon: 'desktop',
      fcmToken: null,
      platform: 'linux',
    });

    // 2. Wake the Android target → goes through FCM, no inbox write.
    const a = await sendWakeLogic(db, messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_ANDROID,
      payload: 'wake-android-blob',
    });
    expect(a).toEqual({ delivered: true, channel: 'fcm' });
    expect(messaging.send).toHaveBeenCalledTimes(1);
    expect(await listInboxIds(UID, TGT_ANDROID)).toEqual([]);

    // 3. Wake the Linux target → inbox writeback, FCM untouched.
    const b = await sendWakeLogic(db, messaging, UID, {
      sourceDeviceId: SRC,
      targetDeviceId: TGT_LINUX,
      payload: 'wake-linux-blob',
    });
    expect(b).toEqual({ delivered: true, channel: 'inbox' });
    expect(messaging.send).toHaveBeenCalledTimes(1); // still 1
    expect(await listInboxIds(UID, TGT_LINUX)).toHaveLength(1);

    // 4. Source device's recentSendsAt accrued both sends.
    expect((await readDevice(UID, SRC))?.recentSendsAt).toHaveLength(2);

    // 5. The Linux device polls — sees the queued wake, and the
    //    transaction clears the inbox.
    const polled = await pollPendingWakesLogic(db, UID, { deviceId: TGT_LINUX });
    expect(polled.items).toHaveLength(1);
    expect(polled.items[0].type).toBe('wake');
    expect(polled.items[0].payload).toBe('wake-linux-blob');
    expect(await listInboxIds(UID, TGT_LINUX)).toEqual([]);

    // 6. Maintenance pass against the live state plus a few seeded
    //    stragglers — confirms the sweeps target the right rows
    //    without nuking anything still in use.

    const now = new Date();

    // Expired join token sweep: seed one expired and one valid; only
    // the expired one should disappear.
    await seedJoinToken('expired', {
      accountId: UID,
      issuingDeviceId: SRC,
      expiresAt: Timestamp.fromMillis(now.getTime() - 60_000),
    });
    await seedJoinToken('valid', {
      accountId: UID,
      issuingDeviceId: SRC,
      expiresAt: Timestamp.fromMillis(now.getTime() + 60_000),
    });
    const sweep = await cleanupExpiredJoinTokensLogic(db, now);
    expect(sweep.deleted).toBe(1);
    expect((await listJoinTokenIds()).sort()).toEqual(['valid']);

    // Inactive-account sweep: seed an unrelated zombie account; it
    // disappears, the Epic-6 group survives.
    await seedAccount('zombie', {
      lastActiveAt: Timestamp.fromMillis(now.getTime() - 91 * 24 * 60 * 60_000),
      deviceCount: 1,
    });
    await seedDevice('zombie', 'zombie-d');
    await seedInboxItem('zombie', 'zombie-d', 'queued');

    const inactive = await cleanupInactiveAccountsLogic(db, now);
    expect(inactive.deleted).toBe(1);
    expect(await readAccount('zombie')).toBeNull();
    expect(await readAccount(UID)).not.toBeNull();
    expect((await listDeviceIds(UID)).sort()).toEqual([SRC, TGT_ANDROID, TGT_LINUX].sort());
  });
});
