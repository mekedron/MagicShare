import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import {
  cleanupExpiredJoinTokensLogic,
  cleanupInactiveAccountsLogic,
} from '../../src/scheduled';

import {
  clearEmulator,
  listDeviceIds,
  listJoinTokenIds,
  readAccount,
  readDevice,
  seedAccount,
  seedDevice,
  seedInboxItem,
  seedJoinToken,
} from './_helpers';

const DAY_MS = 24 * 60 * 60 * 1000;

describe('cleanupExpiredJoinTokensLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('returns deleted:0 when there are no tokens', async () => {
    const result = await cleanupExpiredJoinTokensLogic(getDb(), new Date());
    expect(result).toEqual({ deleted: 0 });
  });

  it('deletes tokens whose expiresAt is at or before now and preserves valid ones', async () => {
    const now = new Date();
    await seedJoinToken('expired-1', {
      expiresAt: Timestamp.fromMillis(now.getTime() - 60_000),
    });
    await seedJoinToken('expired-boundary', {
      expiresAt: Timestamp.fromMillis(now.getTime()),
    });
    await seedJoinToken('valid', {
      expiresAt: Timestamp.fromMillis(now.getTime() + 60_000),
    });

    const result = await cleanupExpiredJoinTokensLogic(getDb(), now);

    expect(result).toEqual({ deleted: 2 });
    expect((await listJoinTokenIds()).sort()).toEqual(['valid']);
  });
});

describe('cleanupInactiveAccountsLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('returns deleted:0 when there are no accounts', async () => {
    const result = await cleanupInactiveAccountsLogic(getDb(), new Date());
    expect(result).toEqual({ deleted: 0 });
  });

  it('recursively deletes accounts whose lastActiveAt is past the 90-day cutoff', async () => {
    const now = new Date();
    const inactive = Timestamp.fromMillis(now.getTime() - 91 * DAY_MS);
    const fresh = Timestamp.fromMillis(now.getTime() - 30 * DAY_MS);

    await seedAccount('zombie', { lastActiveAt: inactive, deviceCount: 1 });
    await seedDevice('zombie', 'd1');
    await seedInboxItem('zombie', 'd1', 'queued');

    await seedAccount('alive', { lastActiveAt: fresh, deviceCount: 1 });
    await seedDevice('alive', 'd2');

    const result = await cleanupInactiveAccountsLogic(getDb(), now);

    expect(result).toEqual({ deleted: 1 });
    expect(await readAccount('zombie')).toBeNull();
    expect(await listDeviceIds('zombie')).toEqual([]);
    expect(await readAccount('alive')).not.toBeNull();
    expect(await readDevice('alive', 'd2')).not.toBeNull();
  });

  it('treats lastActiveAt exactly at the cutoff as inactive', async () => {
    const now = new Date();
    const cutoff = Timestamp.fromMillis(now.getTime() - 90 * DAY_MS);
    await seedAccount('boundary', { lastActiveAt: cutoff, deviceCount: 0 });

    const result = await cleanupInactiveAccountsLogic(getDb(), now);

    expect(result.deleted).toBe(1);
    expect(await readAccount('boundary')).toBeNull();
  });
});

