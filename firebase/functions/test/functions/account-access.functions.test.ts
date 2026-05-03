import { beforeEach, describe, expect, it } from 'vitest';

import { assertSameAccount, assertSameAccountTx } from '../../src/account-access';
import { getDb } from '../../src/admin';

import { clearEmulator, seedAccount, seedDevice } from './_helpers';

const UID_OWNER = 'owner';
const UID_OUTSIDER = 'outsider';
const DEVICE = 'shared-device-id';

describe('assertSameAccount', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('returns the device doc + ref when caller owns the device', async () => {
    await seedAccount(UID_OWNER);
    await seedDevice(UID_OWNER, DEVICE, { displayName: 'My laptop' });

    const lookup = await assertSameAccount(getDb(), UID_OWNER, DEVICE);

    expect(lookup.doc.displayName).toBe('My laptop');
    expect(lookup.ref.path).toBe(`accounts/${UID_OWNER}/devices/${DEVICE}`);
  });

  it('rejects with not-found when the caller is from a different account', async () => {
    // Two separate accounts each register the same deviceId. The
    // outsider's lookup against UID_OUTSIDER's namespace must miss
    // even though UID_OWNER has a doc with that exact id.
    await seedAccount(UID_OWNER);
    await seedDevice(UID_OWNER, DEVICE);
    await seedAccount(UID_OUTSIDER);

    await expect(assertSameAccount(getDb(), UID_OUTSIDER, DEVICE)).rejects.toMatchObject({
      code: 'not-found',
    });
  });

  it('rejects with not-found when the device id does not exist anywhere', async () => {
    await seedAccount(UID_OWNER);
    await expect(assertSameAccount(getDb(), UID_OWNER, 'no-such-device')).rejects.toMatchObject({
      code: 'not-found',
    });
  });
});

describe('assertSameAccountTx', () => {
  beforeEach(async () => {
    await clearEmulator();
  });

  it('reads inside a transaction so the returned ref is usable for tx.update', async () => {
    await seedAccount(UID_OWNER);
    await seedDevice(UID_OWNER, DEVICE, { displayName: 'before' });

    await getDb().runTransaction(async (tx) => {
      const { ref, doc } = await assertSameAccountTx(tx, getDb(), UID_OWNER, DEVICE);
      expect(doc.displayName).toBe('before');
      tx.update(ref, { displayName: 'after' });
    });

    const after = await getDb().doc(`accounts/${UID_OWNER}/devices/${DEVICE}`).get();
    expect((after.data() as { displayName: string }).displayName).toBe('after');
  });

  it('rejects with not-found inside a transaction for cross-account access', async () => {
    await seedAccount(UID_OWNER);
    await seedDevice(UID_OWNER, DEVICE);
    await seedAccount(UID_OUTSIDER);

    await expect(
      getDb().runTransaction(async (tx) => {
        await assertSameAccountTx(tx, getDb(), UID_OUTSIDER, DEVICE);
      }),
    ).rejects.toMatchObject({ code: 'not-found' });
  });
});
