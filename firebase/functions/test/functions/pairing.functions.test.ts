import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import { createJoinTokenLogic, joinNetworkLogic, previewJoinTokenLogic } from '../../src/pairing';
import {
  parseCreateJoinTokenInput,
  parseJoinNetworkInput,
  parsePreviewJoinTokenInput,
} from '../../src/validation';

import {
  clearEmulator,
  listDeviceIds,
  listJoinTokenIds,
  readAccount,
  readDevice,
  readJoinToken,
  seedAccount,
  seedDevice,
  seedJoinToken,
} from './_helpers';

const UID = 'pairingTester';
const DEVICE = 'issuing-device';
const TARGET_UID = 'targetAccount';
const TARGET_DEVICE_A = 'target-laptop';
const TARGET_DEVICE_B = 'target-phone';
const TOKEN_ID = 'token-id-fixture';

describe('createJoinTokenLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('writes a joinToken document with all fields populated', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    await seedDevice(UID, DEVICE);

    const result = await createJoinTokenLogic(getDb(), UID, { issuingDeviceId: DEVICE });

    // base64url of 24 bytes is always 32 chars (no padding needed).
    expect(result.tokenId).toMatch(/^[A-Za-z0-9_-]{32}$/);
    expect(result.expiresAtMs).toBeGreaterThan(Date.now());

    const token = await readJoinToken(result.tokenId);
    expect(token).not.toBeNull();
    expect(token?.accountId).toBe(UID);
    expect(token?.issuingDeviceId).toBe(DEVICE);
    expect(token?.consumedAt).toBeNull();
    expect(token?.createdAt).toBeInstanceOf(Timestamp);
    expect(token?.expiresAt).toBeInstanceOf(Timestamp);
    expect(token!.expiresAt.toMillis() - token!.createdAt.toMillis()).toBe(5 * 60_000);
    expect(result.expiresAtMs).toBe(token!.expiresAt.toMillis());
  });

  it('mints unique token IDs across calls', async () => {
    await seedAccount(UID, { deviceCount: 1 });
    await seedDevice(UID, DEVICE);

    const a = await createJoinTokenLogic(getDb(), UID, { issuingDeviceId: DEVICE });
    const b = await createJoinTokenLogic(getDb(), UID, { issuingDeviceId: DEVICE });

    expect(a.tokenId).not.toBe(b.tokenId);
    expect((await listJoinTokenIds()).sort()).toEqual([a.tokenId, b.tokenId].sort());
  });

  it('throws failed-precondition when the account does not exist', async () => {
    await expect(
      createJoinTokenLogic(getDb(), UID, { issuingDeviceId: DEVICE }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('throws failed-precondition when the issuing device does not exist', async () => {
    await seedAccount(UID, { deviceCount: 0 });
    await expect(
      createJoinTokenLogic(getDb(), UID, { issuingDeviceId: DEVICE }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('rejects an empty issuingDeviceId during input parsing', () => {
    expect(() => parseCreateJoinTokenInput({ issuingDeviceId: '   ' })).toThrow(HttpsError);
  });

  it('rejects an oversized issuingDeviceId during input parsing', () => {
    const oversized = 'x'.repeat(129);
    expect(() => parseCreateJoinTokenInput({ issuingDeviceId: oversized })).toThrow(HttpsError);
  });

  it('rejects a non-string issuingDeviceId during input parsing', () => {
    expect(() => parseCreateJoinTokenInput({ issuingDeviceId: 42 })).toThrow(HttpsError);
  });

  it('rejects a non-object payload', () => {
    expect(() => parseCreateJoinTokenInput(null)).toThrow(HttpsError);
    expect(() => parseCreateJoinTokenInput([])).toThrow(HttpsError);
  });
});

describe('previewJoinTokenLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  async function seedTargetGroup(): Promise<void> {
    await seedAccount(TARGET_UID, { deviceCount: 2 });
    await seedDevice(TARGET_UID, TARGET_DEVICE_A, {
      displayName: 'MacBook Pro',
      icon: 'laptop',
      platform: 'macos',
      fcmToken: 'fcm-token-laptop',
    });
    await seedDevice(TARGET_UID, TARGET_DEVICE_B, {
      displayName: 'Pixel 8',
      icon: 'phone',
      platform: 'android',
      fcmToken: 'fcm-token-phone',
    });
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
    });
  }

  it('returns the target group with a public-safe device list', async () => {
    await seedTargetGroup();

    const result = await previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID });

    expect(result.accountId).toBe(TARGET_UID);
    expect(result.issuingDeviceId).toBe(TARGET_DEVICE_A);
    expect(result.expiresAtMs).toBeGreaterThan(Date.now());
    expect(result.devices).toHaveLength(2);
  });

  it('exposes only the public-safe key set per device', async () => {
    await seedTargetGroup();

    const result = await previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID });

    // Locks the projection: any new field added to DeviceDoc must be
    // explicitly opted into the preview projection or this test fails.
    const expectedKeys = ['deviceId', 'displayName', 'icon', 'platform'].sort();
    for (const device of result.devices) {
      expect(Object.keys(device).sort()).toEqual(expectedKeys);
    }
  });

  it('sorts devices by displayName', async () => {
    await seedTargetGroup();

    const result = await previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID });

    expect(result.devices.map((d) => d.displayName)).toEqual(['MacBook Pro', 'Pixel 8']);
  });

  it('does not consume the token', async () => {
    await seedTargetGroup();

    await previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID });

    const token = await readJoinToken(TOKEN_ID);
    expect(token?.consumedAt).toBeNull();
  });

  it('throws not-found when the token does not exist', async () => {
    await expect(previewJoinTokenLogic(getDb(), { tokenId: 'missing' })).rejects.toMatchObject({
      code: 'not-found',
    });
  });

  it('throws failed-precondition when the token has expired', async () => {
    await seedTargetGroup();
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
      expiresAt: Timestamp.fromMillis(Date.now() - 1_000),
    });

    await expect(previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('throws failed-precondition when the token has already been consumed', async () => {
    await seedTargetGroup();
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
      consumedAt: Timestamp.now(),
    });

    await expect(previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('returns an empty device list when the target account has no devices yet', async () => {
    await seedAccount(TARGET_UID, { deviceCount: 0 });
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
    });

    const result = await previewJoinTokenLogic(getDb(), { tokenId: TOKEN_ID });

    expect(result.devices).toEqual([]);
  });

  it('rejects an empty tokenId during input parsing', () => {
    expect(() => parsePreviewJoinTokenInput({ tokenId: '   ' })).toThrow(HttpsError);
  });

  it('rejects an oversized tokenId during input parsing', () => {
    const oversized = 'x'.repeat(129);
    expect(() => parsePreviewJoinTokenInput({ tokenId: oversized })).toThrow(HttpsError);
  });

  it('rejects a non-string tokenId during input parsing', () => {
    expect(() => parsePreviewJoinTokenInput({ tokenId: 42 })).toThrow(HttpsError);
  });
});

describe('joinNetworkLogic', () => {
  const SOURCE_UID = 'sourceAccount';
  const SOURCE_DEVICE = 'source-device';
  const SOURCE_OTHER = 'source-other';

  const FAKE_CUSTOM_TOKEN_PREFIX = 'fake-custom-token-for:';
  const fakeMinter = async (uid: string) => `${FAKE_CUSTOM_TOKEN_PREFIX}${uid}`;

  beforeEach(async () => {
    await clearEmulator();
  });

  async function seedTargetGroupOnly(): Promise<void> {
    await seedAccount(TARGET_UID, { deviceCount: 1 });
    await seedDevice(TARGET_UID, TARGET_DEVICE_A, {
      displayName: 'MacBook Pro',
      icon: 'laptop',
      platform: 'macos',
      fcmToken: 'fcm-target-laptop',
    });
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
    });
  }

  async function seedSourceWithLastDevice(): Promise<void> {
    await seedAccount(SOURCE_UID, { deviceCount: 1 });
    await seedDevice(SOURCE_UID, SOURCE_DEVICE, {
      displayName: 'Pixel 8',
      icon: 'phone',
      platform: 'android',
      fcmToken: 'fcm-source-pixel',
    });
  }

  async function seedSourceWithSurvivor(): Promise<void> {
    await seedAccount(SOURCE_UID, { deviceCount: 2 });
    await seedDevice(SOURCE_UID, SOURCE_DEVICE, {
      displayName: 'Pixel 8',
      icon: 'phone',
      platform: 'android',
      fcmToken: 'fcm-source-pixel',
    });
    await seedDevice(SOURCE_UID, SOURCE_OTHER, {
      displayName: 'iPad',
      icon: 'tablet',
      platform: 'ios',
      fcmToken: 'fcm-source-ipad',
    });
  }

  it('moves the device into the target group, decrements source, marks token consumed', async () => {
    await seedTargetGroupOnly();
    await seedSourceWithSurvivor();

    const result = await joinNetworkLogic(
      getDb(),
      SOURCE_UID,
      { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
      fakeMinter,
    );

    expect(result.accountId).toBe(TARGET_UID);
    expect(result.oldAccountDeleted).toBe(false);
    expect(result.devices.map((d) => d.deviceId).sort()).toEqual(
      [TARGET_DEVICE_A, SOURCE_DEVICE].sort(),
    );
    expect(result.customToken).toBe(`${FAKE_CUSTOM_TOKEN_PREFIX}${TARGET_UID}`);

    const sourceAccount = await readAccount(SOURCE_UID);
    expect(sourceAccount).not.toBeNull();
    expect(sourceAccount?.deviceCount).toBe(1);
    expect(await listDeviceIds(SOURCE_UID)).toEqual([SOURCE_OTHER]);

    const targetAccount = await readAccount(TARGET_UID);
    expect(targetAccount?.deviceCount).toBe(2);

    const moved = await readDevice(TARGET_UID, SOURCE_DEVICE);
    expect(moved?.displayName).toBe('Pixel 8');
    expect(moved?.icon).toBe('phone');
    expect(moved?.platform).toBe('android');
    expect(moved?.fcmToken).toBe('fcm-source-pixel');

    const token = await readJoinToken(TOKEN_ID);
    expect(token?.consumedAt).not.toBeNull();
  });

  it('destroys the source account when the moving device was the only member', async () => {
    await seedTargetGroupOnly();
    await seedSourceWithLastDevice();

    const result = await joinNetworkLogic(
      getDb(),
      SOURCE_UID,
      { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
      fakeMinter,
    );

    expect(result.oldAccountDeleted).toBe(true);
    expect(await readAccount(SOURCE_UID)).toBeNull();
    expect(await listDeviceIds(SOURCE_UID)).toEqual([]);
    expect((await readAccount(TARGET_UID))?.deviceCount).toBe(2);
    expect(await readDevice(TARGET_UID, SOURCE_DEVICE)).not.toBeNull();
  });

  it('rejects self-join without consuming the token', async () => {
    await seedAccount(SOURCE_UID, { deviceCount: 1 });
    await seedDevice(SOURCE_UID, SOURCE_DEVICE);
    await seedJoinToken(TOKEN_ID, {
      accountId: SOURCE_UID,
      issuingDeviceId: SOURCE_DEVICE,
    });

    await expect(
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });

    const token = await readJoinToken(TOKEN_ID);
    expect(token?.consumedAt).toBeNull();
  });

  it('throws not-found when the token does not exist', async () => {
    await seedSourceWithLastDevice();
    await expect(
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: 'missing', deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ).rejects.toMatchObject({ code: 'not-found' });
  });

  it('throws failed-precondition when the token has expired', async () => {
    await seedTargetGroupOnly();
    await seedSourceWithLastDevice();
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
      expiresAt: Timestamp.fromMillis(Date.now() - 1_000),
    });

    await expect(
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('throws failed-precondition when the token has already been consumed', async () => {
    await seedTargetGroupOnly();
    await seedSourceWithLastDevice();
    await seedJoinToken(TOKEN_ID, {
      accountId: TARGET_UID,
      issuingDeviceId: TARGET_DEVICE_A,
      consumedAt: Timestamp.now(),
    });

    await expect(
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('throws failed-precondition when the source account exists but the device does not', async () => {
    await seedTargetGroupOnly();
    await seedAccount(SOURCE_UID, { deviceCount: 0 });

    await expect(
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('throws failed-precondition when the target account no longer exists', async () => {
    await seedSourceWithLastDevice();
    // Token references an accountId that does not have a matching
    // accounts/{accountId} doc — possible after a deleteAccount race.
    await seedJoinToken(TOKEN_ID, {
      accountId: 'ghostAccount',
      issuingDeviceId: 'ghost-device',
    });

    await expect(
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('serializes concurrent attempts: exactly one wins, the other rejects', async () => {
    await seedTargetGroupOnly();
    await seedSourceWithSurvivor();

    const [resA, resB] = await Promise.allSettled([
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
      joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        fakeMinter,
      ),
    ]);

    const fulfilled = [resA, resB].filter((r) => r.status === 'fulfilled');
    const rejected = [resA, resB].filter((r) => r.status === 'rejected');
    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0] as PromiseRejectedResult).reason).toMatchObject({
      code: 'failed-precondition',
    });

    // End state is consistent: the device is in the target group, source
    // shows deviceCount=1 (only SOURCE_OTHER remaining).
    expect((await readAccount(TARGET_UID))?.deviceCount).toBe(2);
    expect((await readAccount(SOURCE_UID))?.deviceCount).toBe(1);
    expect(await readDevice(TARGET_UID, SOURCE_DEVICE)).not.toBeNull();
  });

  describe('welcome-card path (no source account)', () => {
    const NEW_DEVICE = 'new-device-from-welcome';
    const ANON_UID = 'anon-temp-uid';

    it('creates the device under the target account using newDevice fields', async () => {
      await seedTargetGroupOnly();

      const result = await joinNetworkLogic(
        getDb(),
        ANON_UID,
        {
          tokenId: TOKEN_ID,
          deviceId: NEW_DEVICE,
          newDevice: {
            displayName: 'Niki iPad',
            icon: 'tablet',
            fcmToken: 'fcm-new-device',
            platform: 'ios',
          },
        },
        fakeMinter,
      );

      expect(result.accountId).toBe(TARGET_UID);
      expect(result.oldAccountDeleted).toBe(false);
      expect(result.customToken).toBe(`${FAKE_CUSTOM_TOKEN_PREFIX}${TARGET_UID}`);
      expect(result.devices.map((d) => d.deviceId).sort()).toEqual(
        [TARGET_DEVICE_A, NEW_DEVICE].sort(),
      );

      const created = await readDevice(TARGET_UID, NEW_DEVICE);
      expect(created?.displayName).toBe('Niki iPad');
      expect(created?.icon).toBe('tablet');
      expect(created?.platform).toBe('ios');
      expect(created?.fcmToken).toBe('fcm-new-device');

      // No source account doc was ever created or touched.
      expect(await readAccount(ANON_UID)).toBeNull();
      expect((await readAccount(TARGET_UID))?.deviceCount).toBe(2);

      const token = await readJoinToken(TOKEN_ID);
      expect(token?.consumedAt).not.toBeNull();
    });

    it('throws failed-precondition when newDevice is missing', async () => {
      await seedTargetGroupOnly();

      await expect(
        joinNetworkLogic(
          getDb(),
          ANON_UID,
          { tokenId: TOKEN_ID, deviceId: NEW_DEVICE },
          fakeMinter,
        ),
      ).rejects.toMatchObject({ code: 'failed-precondition' });

      const token = await readJoinToken(TOKEN_ID);
      // Transaction must roll back fully — token should still be unconsumed.
      expect(token?.consumedAt).toBeNull();
    });
  });

  describe('customToken minting', () => {
    it('uses the injected minter and includes the result in the response', async () => {
      await seedTargetGroupOnly();
      await seedSourceWithLastDevice();

      const seen: string[] = [];
      const minter = async (uid: string) => {
        seen.push(uid);
        return `signed:${uid}`;
      };

      const result = await joinNetworkLogic(
        getDb(),
        SOURCE_UID,
        { tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE },
        minter,
      );

      expect(seen).toEqual([TARGET_UID]);
      expect(result.customToken).toBe(`signed:${TARGET_UID}`);
    });
  });

  it('rejects an empty tokenId during input parsing', () => {
    expect(() => parseJoinNetworkInput({ tokenId: '   ', deviceId: SOURCE_DEVICE })).toThrow(
      HttpsError,
    );
  });

  it('rejects an empty deviceId during input parsing', () => {
    expect(() => parseJoinNetworkInput({ tokenId: TOKEN_ID, deviceId: '   ' })).toThrow(HttpsError);
  });

  it('rejects an oversized tokenId during input parsing', () => {
    const oversized = 'x'.repeat(129);
    expect(() => parseJoinNetworkInput({ tokenId: oversized, deviceId: SOURCE_DEVICE })).toThrow(
      HttpsError,
    );
  });

  it('rejects a missing deviceId during input parsing', () => {
    expect(() => parseJoinNetworkInput({ tokenId: TOKEN_ID })).toThrow(HttpsError);
  });

  it('parses a valid newDevice block', () => {
    const out = parseJoinNetworkInput({
      tokenId: TOKEN_ID,
      deviceId: SOURCE_DEVICE,
      newDevice: {
        displayName: 'Niki iPad',
        icon: 'tablet',
        fcmToken: null,
        platform: 'ios',
      },
    });
    expect(out.newDevice?.displayName).toBe('Niki iPad');
    expect(out.newDevice?.icon).toBe('tablet');
    expect(out.newDevice?.fcmToken).toBeNull();
    expect(out.newDevice?.platform).toBe('ios');
  });

  it('rejects a non-object newDevice', () => {
    expect(() =>
      parseJoinNetworkInput({ tokenId: TOKEN_ID, deviceId: SOURCE_DEVICE, newDevice: 'bad' }),
    ).toThrow(HttpsError);
  });

  it('rejects newDevice with an unknown icon', () => {
    expect(() =>
      parseJoinNetworkInput({
        tokenId: TOKEN_ID,
        deviceId: SOURCE_DEVICE,
        newDevice: { displayName: 'x', icon: 'fridge', fcmToken: null, platform: 'macos' },
      }),
    ).toThrow(HttpsError);
  });

  it('rejects newDevice with an unknown platform', () => {
    expect(() =>
      parseJoinNetworkInput({
        tokenId: TOKEN_ID,
        deviceId: SOURCE_DEVICE,
        newDevice: { displayName: 'x', icon: 'phone', fcmToken: null, platform: 'beos' },
      }),
    ).toThrow(HttpsError);
  });

  it('treats a null newDevice as absent', () => {
    const out = parseJoinNetworkInput({
      tokenId: TOKEN_ID,
      deviceId: SOURCE_DEVICE,
      newDevice: null,
    });
    expect(out.newDevice).toBeUndefined();
  });
});
