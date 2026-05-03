import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import { createJoinTokenLogic } from '../../src/pairing';
import { parseCreateJoinTokenInput } from '../../src/validation';

import {
  clearEmulator,
  listJoinTokenIds,
  readJoinToken,
  seedAccount,
  seedDevice,
} from './_helpers';

const UID = 'pairingTester';
const DEVICE = 'issuing-device';

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
