import { beforeEach, describe, expect, it } from 'vitest';

import { createAccountLogic, deleteAccountLogic } from '../../src/accounts';
import { getDb } from '../../src/admin';
import {
  registerDeviceLogic,
  removeDeviceLogic,
  renameDeviceLogic,
  setDeviceIconLogic,
} from '../../src/devices';
import { createJoinTokenLogic, joinNetworkLogic, previewJoinTokenLogic } from '../../src/pairing';

import {
  clearEmulator,
  listDeviceIds,
  readAccount,
  readDevice,
  readJoinToken,
  seedInboxItem,
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
    const join = await joinNetworkLogic(db, UID_B, {
      tokenId: minted.tokenId,
      deviceId: B1,
    });
    expect(join.accountId).toBe(UID_A);
    expect(join.oldAccountDeleted).toBe(true);
    expect(join.devices.map((d) => d.deviceId).sort()).toEqual([A1, B1].sort());

    // 5. End state: A has both devices, B is gone, token is consumed,
    //    moved device is offline (waiting for the LAN-side key handshake
    //    in Epic 11 before it can act on wake notifications).
    expect((await readAccount(UID_A))?.deviceCount).toBe(2);
    expect(await readAccount(UID_B)).toBeNull();
    expect((await listDeviceIds(UID_A)).sort()).toEqual([A1, B1].sort());
    expect(await listDeviceIds(UID_B)).toEqual([]);
    expect((await readDevice(UID_A, B1))?.presence).toBe('offline');
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
    const join = await joinNetworkLogic(db, UID_B, {
      tokenId: minted.tokenId,
      deviceId: B1,
    });

    expect(join.oldAccountDeleted).toBe(false);
    expect((await readAccount(UID_A))?.deviceCount).toBe(2);
    expect((await readAccount(UID_B))?.deviceCount).toBe(1);
    expect((await listDeviceIds(UID_B)).sort()).toEqual([B2]);
    expect((await listDeviceIds(UID_A)).sort()).toEqual([A1, B1].sort());
    expect(await readDevice(UID_A, B1)).not.toBeNull();
    expect(await readDevice(UID_B, B1)).toBeNull();
  });
});
