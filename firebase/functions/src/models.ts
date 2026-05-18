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
  /**
   * The LocalSend cert hash that this device announces over multicast.
   * Lets the Send tab dedup LAN-discovered devices against the cloud
   * device list using a stable join key (cloud `deviceId` is a UUIDv4
   * generated independently). Optional so devices that haven't
   * re-registered since the field was introduced read as `null`.
   */
  fingerprint?: string | null;
  /**
   * Sliding-window record of recent `notifyTransferIntent` timestamps.
   * Used by `src/rate-limit.ts` to enforce the soft 30-sends-per-hour
   * ceiling. Optional so existing devices migrate in place — an absent
   * or empty array reads as "no sends yet".
   */
  recentSendsAt?: Timestamp[];
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
export const JOIN_TOKENS_COLLECTION = 'joinTokens';

export const accountPath = (accountId: string): string => `${ACCOUNTS_COLLECTION}/${accountId}`;

export const devicePath = (accountId: string, deviceId: string): string =>
  `${accountPath(accountId)}/${DEVICES_SUBCOLLECTION}/${deviceId}`;

export const joinTokenPath = (tokenId: string): string => `${JOIN_TOKENS_COLLECTION}/${tokenId}`;
