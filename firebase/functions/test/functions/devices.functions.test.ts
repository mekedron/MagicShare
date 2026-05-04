import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import {
  registerDeviceLogic,
  removeDeviceLogic,
  renameDeviceLogic,
  setDeviceIconLogic,
  updateDevicePresenceLogic,
} from '../../src/devices';
import { parseRenameDeviceInput, parseSetDeviceIconInput } from '../../src/validation';

import {
  clearEmulator,
  listDeviceIds,
  listInboxIds,
  readAccount,
  readDevice,
  seedAccount,
  seedDevice,
  seedInboxItem,
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
    expect(device?.presence).toBe('online');
    expect(device?.lastSeenAt).toBeInstanceOf(Timestamp);
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

  it("clears the removed device's inbox subcollection", async () => {
    await seedAccount(UID, { deviceCount: 2 });
    await seedDevice(UID, DEVICE_A);
    await seedDevice(UID, DEVICE_B);
    await seedInboxItem(UID, DEVICE_A, 'inboxOne');
    await seedInboxItem(UID, DEVICE_A, 'inboxTwo');
    await seedInboxItem(UID, DEVICE_B, 'survivor');

    await removeDeviceLogic(getDb(), UID, { deviceId: DEVICE_A });

    expect(await listInboxIds(UID, DEVICE_A)).toEqual([]);
    expect(await listInboxIds(UID, DEVICE_B)).toEqual(['survivor']);
  });

  it('destroys the account when removing the last device', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    await seedDevice(UID, DEVICE_A);
    await seedInboxItem(UID, DEVICE_A, 'soonGone');

    const result = await removeDeviceLogic(getDb(), UID, { deviceId: DEVICE_A });

    expect(result).toEqual({ accountDeleted: true });
    expect(await readAccount(UID)).toBeNull();
    expect(await listDeviceIds(UID)).toEqual([]);
    expect(await listInboxIds(UID, DEVICE_A)).toEqual([]);
  });
});
