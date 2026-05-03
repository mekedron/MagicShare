import { Timestamp } from 'firebase-admin/firestore';

import { getDb } from '../../src/admin';
import {
  type AccountDoc,
  ACCOUNTS_COLLECTION,
  accountPath,
  type DeviceDoc,
  type DeviceIcon,
  type DevicePlatform,
  type DevicePresence,
  devicePath,
  inboxItemPath,
  type InboxItemDoc,
  JOIN_TOKENS_COLLECTION,
  type JoinTokenDoc,
  joinTokenPath,
} from '../../src/models';

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'demo-magicshare-functions';

/**
 * Wipes the entire Firestore emulator project between tests. Uses the
 * emulator's REST endpoint rather than walking collections so it stays
 * O(1) even as the schema grows.
 */
export async function clearEmulator(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) {
    throw new Error('FIRESTORE_EMULATOR_HOST is not set; run via firebase emulators:exec.');
  }
  const url = `http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
  const response = await fetch(url, { method: 'DELETE' });
  if (!response.ok) {
    throw new Error(
      `Failed to clear Firestore emulator: ${response.status} ${response.statusText}`,
    );
  }
}

export interface SeedAccountOverrides {
  createdAt?: Timestamp;
  lastActiveAt?: Timestamp;
  deviceCount?: number;
}

export async function seedAccount(
  uid: string,
  overrides: SeedAccountOverrides = {},
): Promise<void> {
  const now = Timestamp.now();
  const doc: AccountDoc = {
    createdAt: overrides.createdAt ?? now,
    lastActiveAt: overrides.lastActiveAt ?? now,
    deviceCount: overrides.deviceCount ?? 0,
  };
  await getDb().doc(accountPath(uid)).set(doc);
}

export interface SeedDeviceOverrides {
  displayName?: string;
  icon?: DeviceIcon;
  fcmToken?: string | null;
  platform?: DevicePlatform;
  lastSeenAt?: Timestamp;
  presence?: DevicePresence;
}

export async function seedDevice(
  uid: string,
  deviceId: string,
  overrides: SeedDeviceOverrides = {},
): Promise<void> {
  const doc: DeviceDoc = {
    displayName: overrides.displayName ?? 'Test Device',
    icon: overrides.icon ?? 'laptop',
    fcmToken: overrides.fcmToken ?? null,
    platform: overrides.platform ?? 'macos',
    lastSeenAt: overrides.lastSeenAt ?? Timestamp.now(),
    presence: overrides.presence ?? 'offline',
  };
  await getDb().doc(devicePath(uid, deviceId)).set(doc);
}

export async function seedInboxItem(
  uid: string,
  deviceId: string,
  itemId: string,
  overrides: Partial<InboxItemDoc> = {},
): Promise<void> {
  const now = Timestamp.now();
  const doc: InboxItemDoc = {
    type: overrides.type ?? 'wake',
    payload: overrides.payload ?? 'encrypted-blob',
    createdAt: overrides.createdAt ?? now,
    expiresAt: overrides.expiresAt ?? Timestamp.fromMillis(now.toMillis() + 5 * 60_000),
  };
  await getDb()
    .doc(inboxItemPath(uid, deviceId, itemId))
    .set(doc);
}

export async function readAccount(uid: string): Promise<AccountDoc | null> {
  const snap = await getDb().doc(accountPath(uid)).get();
  return snap.exists ? (snap.data() as AccountDoc) : null;
}

export async function readDevice(uid: string, deviceId: string): Promise<DeviceDoc | null> {
  const snap = await getDb().doc(devicePath(uid, deviceId)).get();
  return snap.exists ? (snap.data() as DeviceDoc) : null;
}

export async function listDeviceIds(uid: string): Promise<string[]> {
  const snap = await getDb().collection(`${ACCOUNTS_COLLECTION}/${uid}/devices`).get();
  return snap.docs.map((d) => d.id);
}

export async function listInboxIds(uid: string, deviceId: string): Promise<string[]> {
  const snap = await getDb()
    .collection(`${devicePath(uid, deviceId)}/inbox`)
    .get();
  return snap.docs.map((d) => d.id);
}

export interface SeedJoinTokenOverrides {
  accountId?: string;
  issuingDeviceId?: string;
  createdAt?: Timestamp;
  expiresAt?: Timestamp;
  consumedAt?: Timestamp | null;
}

export async function seedJoinToken(
  tokenId: string,
  overrides: SeedJoinTokenOverrides = {},
): Promise<void> {
  const now = Timestamp.now();
  const doc: JoinTokenDoc = {
    accountId: overrides.accountId ?? 'seedAccount',
    issuingDeviceId: overrides.issuingDeviceId ?? 'seedDevice',
    createdAt: overrides.createdAt ?? now,
    expiresAt: overrides.expiresAt ?? Timestamp.fromMillis(now.toMillis() + 5 * 60_000),
    consumedAt: overrides.consumedAt ?? null,
  };
  await getDb().doc(joinTokenPath(tokenId)).set(doc);
}

export async function readJoinToken(tokenId: string): Promise<JoinTokenDoc | null> {
  const snap = await getDb().doc(joinTokenPath(tokenId)).get();
  return snap.exists ? (snap.data() as JoinTokenDoc) : null;
}

export async function listJoinTokenIds(): Promise<string[]> {
  const snap = await getDb().collection(JOIN_TOKENS_COLLECTION).get();
  return snap.docs.map((d) => d.id);
}
