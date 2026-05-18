import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import {
  registerDeviceLogic,
  removeDeviceLogic,
  renameDeviceLogic,
  setDeviceIconLogic,
} from '../../src/devices';
import { parseRenameDeviceInput, parseSetDeviceIconInput } from '../../src/validation';

import {
  clearEmulator,
  listDeviceIds,
  readAccount,
  readDevice,
  seedAccount,
  seedDevice,
} from './_helpers';

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
  });

  it('is idempotent: re-registering the same device does not bump deviceCount', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));

    const result = await registerDeviceLogic(getDb(), UID, {
      ...baseRegisterInput(DEVICE_A),
      fcmToken: 'fcm-token-refreshed',
    });

    expect(result).toEqual({ created: false });
    const account = await readAccount(UID);
    expect(account?.deviceCount).toBe(1);
    const device = await readDevice(UID, DEVICE_A);
    expect(device?.fcmToken).toBe('fcm-token-refreshed');
  });

  it('preserves user-customised displayName and icon on re-register', async () => {
    // Regression: every bootstrap calls registerDevice with the LAN
    // alias as displayName. Without this guard, an earlier renameDevice
    // would be silently overwritten on the next launch.
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));
    // Simulate a renameDevice + setDeviceIcon by writing directly.
    await getDb()
      .doc(`accounts/${UID}/devices/${DEVICE_A}`)
      .update({ displayName: 'Timetravels MacBook', icon: 'desktop' });

    await registerDeviceLogic(getDb(), UID, {
      ...baseRegisterInput(DEVICE_A),
      // Bootstrap re-sends defaults — these must NOT clobber user edits.
      displayName: "Niki's Laptop",
      icon: 'laptop',
      fcmToken: 'fcm-token-after-relaunch',
    });

    const device = await readDevice(UID, DEVICE_A);
    expect(device?.displayName).toBe('Timetravels MacBook');
    expect(device?.icon).toBe('desktop');
    // Transient fields still refresh.
    expect(device?.fcmToken).toBe('fcm-token-after-relaunch');
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

  it('persists fingerprint on create and refreshes it on re-register', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, {
      ...baseRegisterInput(DEVICE_A),
      fingerprint: 'abc123',
    });
    let device = await readDevice(UID, DEVICE_A);
    expect(device?.fingerprint).toBe('abc123');

    await registerDeviceLogic(getDb(), UID, {
      ...baseRegisterInput(DEVICE_A),
      fingerprint: 'def456',
    });
    device = await readDevice(UID, DEVICE_A);
    expect(device?.fingerprint).toBe('def456');
  });

  it('writes fingerprint = null on create when the input omits the field', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));
    const device = await readDevice(UID, DEVICE_A);
    expect(device?.fingerprint).toBeNull();
  });

  it('preserves an existing fingerprint when an older client re-registers without the field', async () => {
    // A v2 client wrote a fingerprint; a v1 client coming back online
    // must not silently null it out by omitting the field.
    await seedAccount(UID, { deviceCount: 0 });
    await registerDeviceLogic(getDb(), UID, {
      ...baseRegisterInput(DEVICE_A),
      fingerprint: 'abc123',
    });
    await registerDeviceLogic(getDb(), UID, baseRegisterInput(DEVICE_A));
    const device = await readDevice(UID, DEVICE_A);
    expect(device?.fingerprint).toBe('abc123');
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

describe('removeDeviceLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('throws not-found when the account does not exist', async () => {
    await expect(removeDeviceLogic(getDb(), UID, { deviceId: DEVICE_A })).rejects.toMatchObject({
      code: 'not-found',
    });
  });

  it('throws not-found when the device does not exist', async () => {
    await seedAccount(UID);
    await expect(removeDeviceLogic(getDb(), UID, { deviceId: DEVICE_A })).rejects.toMatchObject({
      code: 'not-found',
    });
  });

  it('removes a device from the middle of the list, preserving siblings', async () => {
    await seedAccount(UID, { deviceCount: 2 });
    await seedDevice(UID, DEVICE_A);
    await seedDevice(UID, DEVICE_B);

    const result = await removeDeviceLogic(getDb(), UID, { deviceId: DEVICE_A });

    expect(result).toEqual({ accountDeleted: false });
    const account = await readAccount(UID);
    expect(account?.deviceCount).toBe(1);
    expect(await readDevice(UID, DEVICE_A)).toBeNull();
    expect(await readDevice(UID, DEVICE_B)).not.toBeNull();
    expect(await listDeviceIds(UID)).toEqual([DEVICE_B]);
  });

  it('destroys the account when removing the last device', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    await seedDevice(UID, DEVICE_A);

    const result = await removeDeviceLogic(getDb(), UID, { deviceId: DEVICE_A });

    expect(result).toEqual({ accountDeleted: true });
    expect(await readAccount(UID)).toBeNull();
    expect(await listDeviceIds(UID)).toEqual([]);
  });
});
