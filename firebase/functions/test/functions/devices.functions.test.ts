import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import {
  registerDeviceLogic,
  renameDeviceLogic,
  setDeviceIconLogic,
  updateDevicePresenceLogic,
} from '../../src/devices';
import { parseRenameDeviceInput, parseSetDeviceIconInput } from '../../src/validation';

import { clearEmulator, readAccount, readDevice, seedAccount, seedDevice } from './_helpers';

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

describe('updateDevicePresenceLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('throws not-found when the device does not exist', async () => {
    await seedAccount(UID);
    await expect(
      updateDevicePresenceLogic(getDb(), UID, { deviceId: DEVICE_A, presence: 'online' }),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it('rejects a second update inside the 60 s window with resource-exhausted', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    // Register stamps lastSeenAt = now, so the next presence update lands
    // inside the rate-limit window.
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));
    await expect(
      updateDevicePresenceLogic(getDb(), UID, { deviceId: DEVICE_A, presence: 'offline' }),
    ).rejects.toMatchObject({ code: 'resource-exhausted' });
  });

  it('accepts an update once the 60 s window has passed', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    // Seed lastSeenAt 90 s in the past so we are past the rate-limit window.
    const stale = Timestamp.fromMillis(Date.now() - 90_000);
    await seedDevice(UID, DEVICE_A, { lastSeenAt: stale, presence: 'online' });

    const result = await updateDevicePresenceLogic(getDb(), UID, {
      deviceId: DEVICE_A,
      presence: 'offline',
    });

    expect(result).toEqual({ updated: true });
    const device = await readDevice(UID, DEVICE_A);
    expect(device?.presence).toBe('offline');
    expect(device?.lastSeenAt.toMillis()).toBeGreaterThan(stale.toMillis());
  });

  it('bumps account.lastActiveAt on a successful update', async () => {
    await seedAccount(UID, {
      deviceCount: 1,
      lastActiveAt: Timestamp.fromMillis(Date.now() - 90_000),
    });
    const stale = Timestamp.fromMillis(Date.now() - 90_000);
    await seedDevice(UID, DEVICE_A, { lastSeenAt: stale });

    await updateDevicePresenceLogic(getDb(), UID, { deviceId: DEVICE_A, presence: 'online' });

    const account = await readAccount(UID);
    expect(account?.lastActiveAt.toMillis()).toBeGreaterThan(stale.toMillis());
  });
});

describe('renameDeviceLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('updates displayName on an existing device', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    await seedDevice(UID, DEVICE_A, { displayName: 'Old Name' });

    await renameDeviceLogic(getDb(), UID, { deviceId: DEVICE_A, displayName: 'New Name' });

    const device = await readDevice(UID, DEVICE_A);
    expect(device?.displayName).toBe('New Name');
  });

  it('throws not-found when the device does not exist', async () => {
    await seedAccount(UID);
    await expect(
      renameDeviceLogic(getDb(), UID, { deviceId: DEVICE_A, displayName: 'Nope' }),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it('rejects an empty displayName during input parsing', () => {
    expect(() => parseRenameDeviceInput({ deviceId: DEVICE_A, displayName: '   ' })).toThrow(
      HttpsError,
    );
  });

  it('rejects a displayName longer than 80 characters', () => {
    const oversized = 'x'.repeat(81);
    expect(() => parseRenameDeviceInput({ deviceId: DEVICE_A, displayName: oversized })).toThrow(
      HttpsError,
    );
  });
});

describe('setDeviceIconLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('updates the icon on an existing device', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    await seedDevice(UID, DEVICE_A, { icon: 'laptop' });

    await setDeviceIconLogic(getDb(), UID, { deviceId: DEVICE_A, icon: 'phone' });

    const device = await readDevice(UID, DEVICE_A);
    expect(device?.icon).toBe('phone');
  });

  it('throws not-found when the device does not exist', async () => {
    await seedAccount(UID);
    await expect(
      setDeviceIconLogic(getDb(), UID, { deviceId: DEVICE_A, icon: 'phone' }),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it('rejects an unknown icon during input parsing', () => {
    expect(() => parseSetDeviceIconInput({ deviceId: DEVICE_A, icon: 'spaceship' })).toThrow(
      HttpsError,
    );
  });
});
