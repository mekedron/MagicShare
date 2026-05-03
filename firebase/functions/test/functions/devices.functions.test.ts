import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import { registerDeviceLogic } from '../../src/devices';

import { clearEmulator, readAccount, readDevice, seedAccount } from './_helpers';

const UID = 'devicesTester';
const DEVICE_A = 'device-a';
const DEVICE_B = 'device-b';

const baseRegisterInput = (deviceId: string) => ({
  deviceId,
  displayName: "Niki's Laptop",
  icon: 'laptop' as const,
  fcmToken: 'fcm-token-abc',
  platform: 'macos' as const,
});

describe('registerDeviceLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('creates a new device and bumps deviceCount on first register', async () => {
    await seedAccount(UID, { deviceCount: 0 });

    const result = await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));

    expect(result).toEqual({ created: true });
    const account = await readAccount(UID);
    expect(account?.deviceCount).toBe(1);
    const device = await readDevice(UID, DEVICE_A);
    expect(device?.displayName).toBe("Niki's Laptop");
    expect(device?.icon).toBe('laptop');
    expect(device?.platform).toBe('macos');
    expect(device?.fcmToken).toBe('fcm-token-abc');
    expect(device?.presence).toBe('online');
    expect(device?.lastSeenAt).toBeInstanceOf(Timestamp);
  });

  it('is idempotent: re-registering the same device does not bump deviceCount', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));

    const result = await registerDeviceLogic(getDb(), UID, {
      ...baseRegisterInput(DEVICE_A),
      displayName: 'Renamed Laptop',
      fcmToken: 'fcm-token-refreshed',
    });

    expect(result).toEqual({ created: false });
    const account = await readAccount(UID);
    expect(account?.deviceCount).toBe(1);
    const device = await readDevice(UID, DEVICE_A);
    expect(device?.displayName).toBe('Renamed Laptop');
    expect(device?.fcmToken).toBe('fcm-token-refreshed');
  });

  it('increments deviceCount for each new device', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_B));
    const account = await readAccount(UID);
    expect(account?.deviceCount).toBe(2);
  });

  it('throws failed-precondition when the account does not exist', async () => {
    await expect(registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A))).rejects.toThrow(
      HttpsError,
    );
    await expect(
      registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A)),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
