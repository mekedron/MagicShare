import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { getDb } from '../../src/admin';
import {
  cleanupExpiredJoinTokensLogic,
  cleanupInactiveAccountsLogic,
  markStalePresenceLogic,
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
const MIN_MS = 60 * 1000;

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
    await seedDevice('zombie', 'd1', { lastSeenAt: inactive });
    await seedInboxItem('zombie', 'd1', 'queued');

    await seedAccount('alive', { lastActiveAt: fresh, deviceCount: 1 });
    await seedDevice('alive', 'd2', { lastSeenAt: fresh });

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

describe('markStalePresenceLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
    await seedAccount('user-A');
    await seedAccount('user-B');
  });

  it('returns marked:0 when nothing is online', async () => {
    await seedDevice('user-A', 'offline-already', { presence: 'offline' });
    const result = await markStalePresenceLogic(getDb(), new Date());
    expect(result).toEqual({ marked: 0 });
  });

  it('flips online devices whose lastSeenAt is past the 10-min cutoff', async () => {
    const now = new Date();
    const stale = Timestamp.fromMillis(now.getTime() - 11 * MIN_MS);
    const fresh = Timestamp.fromMillis(now.getTime() - 1 * MIN_MS);

    await seedDevice('user-A', 'stale-online', { presence: 'online', lastSeenAt: stale });
    await seedDevice('user-A', 'fresh-online', { presence: 'online', lastSeenAt: fresh });
    await seedDevice('user-B', 'stale-but-offline', { presence: 'offline', lastSeenAt: stale });
    await seedDevice('user-B', 'another-stale-online', {
      presence: 'online',
      lastSeenAt: stale,
    });

    const result = await markStalePresenceLogic(getDb(), now);

    expect(result.marked).toBe(2);
    expect((await readDevice('user-A', 'stale-online'))?.presence).toBe('offline');
    expect((await readDevice('user-A', 'fresh-online'))?.presence).toBe('online');
    expect((await readDevice('user-B', 'stale-but-offline'))?.presence).toBe('offline');
    expect((await readDevice('user-B', 'another-stale-online'))?.presence).toBe('offline');
  });
});
