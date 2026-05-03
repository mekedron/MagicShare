import type { Timestamp } from 'firebase-admin/firestore';

/**
 * Firestore data model for the MagicShare cloud-sync backend.
 *
 * The collections, fields, and access semantics described here mirror
 * `firebase/SCHEMA.md` and `firestore.rules`. If you add or rename a
 * field, update both in the same commit.
 */

export const DEVICE_ICONS = [
  'laptop',
  'desktop',
  'phone',
  'tablet',
  'server',
  'headless',
  'other',
] as const;
export type DeviceIcon = (typeof DEVICE_ICONS)[number];

export const DEVICE_PLATFORMS = ['android', 'ios', 'macos', 'windows', 'linux'] as const;
export type DevicePlatform = (typeof DEVICE_PLATFORMS)[number];

export type DevicePresence = 'online' | 'offline';

export type InboxItemType = 'wake' | 'link';

/** A plaintext link payload as stored in `inbox` for opt-in plaintext mode. */
export interface PlaintextLinkPayload {
  url: string;
  title?: string;
}

/** `accounts/{accountId}` — a device group keyed by anonymous-auth UID. */
export interface AccountDoc {
  createdAt: Timestamp;
  lastActiveAt: Timestamp;
  deviceCount: number;
}

/** `accounts/{accountId}/devices/{deviceId}` — a single registered device. */
export interface DeviceDoc {
  displayName: string;
  icon: DeviceIcon;
  fcmToken: string | null;
  platform: DevicePlatform;
  lastSeenAt: Timestamp;
  presence: DevicePresence;
  /**
   * Sliding-window record of recent `sendWake` / `sendLinkNotification`
   * timestamps. Used by `src/rate-limit.ts` to enforce the soft
   * 30-sends-per-hour ceiling. Optional so existing devices migrate in
   * place — an absent or empty array reads as "no sends yet".
   */
  recentSendsAt?: Timestamp[];
}

/**
 * `accounts/{accountId}/devices/{deviceId}/inbox/{itemId}` — Linux-only
 * polling queue. `payload` is an encrypted blob for `wake` / encrypted
 * link items, and a plaintext object for plaintext-mode link items.
 */
export interface InboxItemDoc {
  type: InboxItemType;
  payload: string | PlaintextLinkPayload;
  createdAt: Timestamp;
  expiresAt: Timestamp;
}

/** `joinTokens/{tokenId}` — a one-time pairing token, server-only. */
export interface JoinTokenDoc {
  accountId: string;
  createdAt: Timestamp;
  expiresAt: Timestamp;
  consumedAt: Timestamp | null;
  issuingDeviceId: string;
}

/** Collection-name constants — single source of truth for paths. */
export const ACCOUNTS_COLLECTION = 'accounts';
export const DEVICES_SUBCOLLECTION = 'devices';
export const INBOX_SUBCOLLECTION = 'inbox';
export const JOIN_TOKENS_COLLECTION = 'joinTokens';

export const accountPath = (accountId: string): string => `${ACCOUNTS_COLLECTION}/${accountId}`;

export const devicePath = (accountId: string, deviceId: string): string =>
  `${accountPath(accountId)}/${DEVICES_SUBCOLLECTION}/${deviceId}`;

export const inboxItemPath = (accountId: string, deviceId: string, itemId: string): string =>
  `${devicePath(accountId, deviceId)}/${INBOX_SUBCOLLECTION}/${itemId}`;

export const joinTokenPath = (tokenId: string): string => `${JOIN_TOKENS_COLLECTION}/${tokenId}`;
