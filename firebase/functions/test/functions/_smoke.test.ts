import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import {
  clearEmulator,
  listDeviceIds,
  readAccount,
  readDevice,
  seedAccount,
  seedDevice,
} from './_helpers';

const UID = 'smokeUser';
const DEVICE = 'smokeDevice';

describe('emulator + helpers smoke', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('seeds and reads back an account', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    const account = await readAccount(UID);
    expect(account).not.toBeNull();
    expect(account?.deviceCount).toBe(0);
    expect(account?.createdAt).toBeInstanceOf(Timestamp);
  });

  it('seeds and reads back a device', async () => {
    await seedAccount(UID);
    await seedDevice(UID, DEVICE, { displayName: 'Niki Pixel', icon: 'phone' });
    const device = await readDevice(UID, DEVICE);
    expect(device?.displayName).toBe('Niki Pixel');
    expect(device?.icon).toBe('phone');
    expect(await listDeviceIds(UID)).toEqual([DEVICE]);
  });

  it('clears between tests', async () => {
    expect(await readAccount(UID)).toBeNull();
  });
});
