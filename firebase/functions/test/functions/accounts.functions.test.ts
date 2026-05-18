import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { createAccountLogic, deleteAccountLogic } from '../../src/accounts';
import { getDb } from '../../src/admin';

import { clearEmulator, listDeviceIds, readAccount, seedAccount, seedDevice } from './_helpers';

const UID = 'accountTester';

describe('createAccountLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('creates the account doc on first call', async () => {
    const result = await createAccountLogic(getDb(), UID);
    expect(result).toEqual({ created: true, accountId: UID });
    const account = await readAccount(UID);
    expect(account).not.toBeNull();
    expect(account?.deviceCount).toBe(0);
    expect(account?.createdAt).toBeInstanceOf(Timestamp);
    expect(account?.lastActiveAt).toBeInstanceOf(Timestamp);
  });

  it('is idempotent: a second call leaves the doc untouched', async () => {
    const first = await createAccountLogic(getDb(), UID);
    const created = await readAccount(UID);
    const second = await createAccountLogic(getDb(), UID);
    const after = await readAccount(UID);

    expect(first.created).toBe(true);
    expect(second).toEqual({ created: false, accountId: UID });
    // Same timestamps means the second call did not rewrite the doc.
    expect(after?.createdAt.toMillis()).toBe(created?.createdAt.toMillis());
    expect(after?.lastActiveAt.toMillis()).toBe(created?.lastActiveAt.toMillis());
  });
});

describe('deleteAccountLogic', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('returns { deleted: false } when the account does not exist', async () => {
    const result = await deleteAccountLogic(getDb(), UID);
    expect(result).toEqual({ deleted: false });
  });

  it('cascades through devices', async () => {
    await seedAccount(UID, { deviceCount: 2 });
    await seedDevice(UID, 'devA');
    await seedDevice(UID, 'devB');

    const result = await deleteAccountLogic(getDb(), UID);

    expect(result).toEqual({ deleted: true });
    expect(await readAccount(UID)).toBeNull();
    expect(await listDeviceIds(UID)).toEqual([]);
  });

  it('is idempotent: deleting a freshly-deleted account is a no-op', async () => {
    await seedAccount(UID);
    await deleteAccountLogic(getDb(), UID);
    const second = await deleteAccountLogic(getDb(), UID);
    expect(second).toEqual({ deleted: false });
  });
});
