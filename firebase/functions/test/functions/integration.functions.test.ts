import { beforeEach, describe, expect, it } from 'vitest';

import { createAccountLogic, deleteAccountLogic } from '../../src/accounts';
import { getDb } from '../../src/admin';
import {
  registerDeviceLogic,
  removeDeviceLogic,
  renameDeviceLogic,
  setDeviceIconLogic,
} from '../../src/devices';

import { clearEmulator, listDeviceIds, readAccount, readDevice, seedInboxItem } from './_helpers';

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
