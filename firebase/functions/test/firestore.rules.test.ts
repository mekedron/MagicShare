import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, Timestamp } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

const PROJECT_ID = 'demo-magicshare-rules';
const RULES_PATH = resolve(__dirname, '..', '..', 'firestore.rules');

const USER_A = 'userA';
const USER_B = 'userB';
const DEVICE_ID = 'deviceOne';
const INBOX_ITEM_ID = 'itemOne';
const JOIN_TOKEN_ID = 'tokenOne';

let env: RulesTestEnvironment;

const accountDoc = () => ({
  createdAt: Timestamp.now(),
  lastActiveAt: Timestamp.now(),
  deviceCount: 1,
});

const deviceDoc = () => ({
  displayName: "Niki's Laptop",
  icon: 'laptop',
  fcmToken: null,
  platform: 'macos',
  lastSeenAt: Timestamp.now(),
  presence: 'offline',
});

const inboxItemDoc = () => ({
  type: 'wake',
  payload: 'encrypted-blob',
  createdAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 5 * 60_000),
});

const joinTokenDoc = () => ({
  accountId: USER_A,
  createdAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 5 * 60_000),
  consumedAt: null,
  issuingDeviceId: DEVICE_ID,
});

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, `accounts/${USER_A}`), accountDoc());
    await setDoc(doc(admin, `accounts/${USER_A}/devices/${DEVICE_ID}`), deviceDoc());
    await setDoc(
      doc(admin, `accounts/${USER_A}/devices/${DEVICE_ID}/inbox/${INBOX_ITEM_ID}`),
      inboxItemDoc(),
    );
    await setDoc(doc(admin, `accounts/${USER_B}`), accountDoc());
    await setDoc(doc(admin, `joinTokens/${JOIN_TOKEN_ID}`), joinTokenDoc());
  });
});

describe('accounts/{accountId}', () => {
  it('allows the owning user to read their own account', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertSucceeds(getDoc(doc(db, `accounts/${USER_A}`)));
  });

  it('rejects cross-account reads', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(getDoc(doc(db, `accounts/${USER_B}`)));
  });

  it('rejects unauthenticated reads', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, `accounts/${USER_A}`)));
  });

  it('rejects direct client writes (server-only)', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(setDoc(doc(db, `accounts/${USER_A}`), accountDoc()));
  });
});

describe('accounts/{accountId}/devices/{deviceId}', () => {
  it('allows the owning user to read their own devices', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertSucceeds(getDoc(doc(db, `accounts/${USER_A}/devices/${DEVICE_ID}`)));
  });

  it('rejects cross-account device reads', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(getDoc(doc(db, `accounts/${USER_B}/devices/${DEVICE_ID}`)));
  });

  it('rejects direct client writes to a device document (server-only)', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(setDoc(doc(db, `accounts/${USER_A}/devices/${DEVICE_ID}`), deviceDoc()));
  });
});

describe('accounts/{accountId}/devices/{deviceId}/inbox/{itemId}', () => {
  it('rejects owner reads (Linux polling goes through callables, not Firestore)', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(
      getDoc(doc(db, `accounts/${USER_A}/devices/${DEVICE_ID}/inbox/${INBOX_ITEM_ID}`)),
    );
  });

  it('rejects owner writes', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(
      setDoc(
        doc(db, `accounts/${USER_A}/devices/${DEVICE_ID}/inbox/${INBOX_ITEM_ID}`),
        inboxItemDoc(),
      ),
    );
  });
});

describe('joinTokens/{tokenId}', () => {
  it('rejects owner reads (server-only)', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(getDoc(doc(db, `joinTokens/${JOIN_TOKEN_ID}`)));
  });

  it('rejects owner writes (server-only)', async () => {
    const db = env.authenticatedContext(USER_A).firestore();
    await assertFails(setDoc(doc(db, `joinTokens/${JOIN_TOKEN_ID}`), joinTokenDoc()));
  });
});
