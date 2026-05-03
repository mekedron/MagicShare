import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import { createJoinTokenLogic, previewJoinTokenLogic } from '../../src/pairing';
import { parseCreateJoinTokenInput, parsePreviewJoinTokenInput } from '../../src/validation';

import {
  clearEmulator,
  listJoinTokenIds,
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
      presence: 'online',
      fcmToken: 'fcm-token-laptop',
    });
    await seedDevice(TARGET_UID, TARGET_DEVICE_B, {
      displayName: 'Pixel 8',
      icon: 'phone',
      platform: 'android',
      presence: 'offline',
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
    const expectedKeys = ['deviceId', 'displayName', 'icon', 'platform', 'presence'].sort();
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
