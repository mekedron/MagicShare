import { HttpsError } from 'firebase-functions/v2/https';

import {
  DEVICE_ICONS,
  DEVICE_PLATFORMS,
  type DeviceIcon,
  type DevicePlatform,
  type DevicePresence,
} from './models';

const DEVICE_ID_MAX = 128;
const DISPLAY_NAME_MAX = 80;
const FCM_TOKEN_MAX = 4096;
const TOKEN_ID_MAX = 128;
/**
 * Encrypted wake/link payloads are AES-GCM ciphertext over a small
 * JSON envelope, base64-encoded by the client. 16 KiB is comfortable
 * headroom over the LocalSend wake metadata + nonce; well below FCM's
 * 4 KiB data-message limit on the wire because that limit is the
 * decoded message size, but storing oversize blobs in `inbox` would
 * still be wasteful.
 */
const ENCRYPTED_PAYLOAD_MAX = 16 * 1024;
const LINK_URL_MAX = 2048;
const LINK_TITLE_MAX = 200;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function fail(field: string, reason: string): never {
  throw new HttpsError('invalid-argument', `Invalid value for "${field}": ${reason}.`);
}

function assertNonEmptyString(value: unknown, field: string, max: number): string {
  if (typeof value !== 'string') fail(field, `expected a string`);
  const trimmed = (value as string).trim();
  if (trimmed.length === 0) fail(field, `must not be empty`);
  if ((value as string).length > max) fail(field, `must be ${max} characters or fewer`);
  return value as string;
}

function assertDeviceId(value: unknown): string {
  return assertNonEmptyString(value, 'deviceId', DEVICE_ID_MAX);
}

function assertTokenId(value: unknown): string {
  return assertNonEmptyString(value, 'tokenId', TOKEN_ID_MAX);
}

function assertDisplayName(value: unknown): string {
  return assertNonEmptyString(value, 'displayName', DISPLAY_NAME_MAX);
}

function assertDeviceIcon(value: unknown): DeviceIcon {
  if (typeof value !== 'string' || !(DEVICE_ICONS as readonly string[]).includes(value)) {
    fail('icon', `expected one of ${DEVICE_ICONS.join(', ')}`);
  }
  return value as DeviceIcon;
}

function assertDevicePlatform(value: unknown): DevicePlatform {
  if (typeof value !== 'string' || !(DEVICE_PLATFORMS as readonly string[]).includes(value)) {
    fail('platform', `expected one of ${DEVICE_PLATFORMS.join(', ')}`);
  }
  return value as DevicePlatform;
}

function assertPresence(value: unknown): DevicePresence {
  if (value !== 'online' && value !== 'offline') {
    fail('presence', `expected "online" or "offline"`);
  }
  return value;
}

function assertFcmToken(value: unknown): string | null {
  if (value === null) return null;
  if (typeof value !== 'string') fail('fcmToken', `expected a string or null`);
  if ((value as string).length === 0) fail('fcmToken', `must not be empty`);
  if ((value as string).length > FCM_TOKEN_MAX) {
    fail('fcmToken', `must be ${FCM_TOKEN_MAX} characters or fewer`);
  }
  return value as string;
}

export interface RegisterDeviceInput {
  deviceId: string;
  displayName: string;
  icon: DeviceIcon;
  fcmToken: string | null;
  platform: DevicePlatform;
}

export interface UpdatePresenceInput {
  deviceId: string;
  presence: DevicePresence;
}

export interface RenameDeviceInput {
  deviceId: string;
  displayName: string;
}

export interface SetDeviceIconInput {
  deviceId: string;
  icon: DeviceIcon;
}

export interface RemoveDeviceInput {
  deviceId: string;
}

export interface CreateJoinTokenInput {
  issuingDeviceId: string;
}

export interface PreviewJoinTokenInput {
  tokenId: string;
}

export interface JoinNetworkInput {
  tokenId: string;
  deviceId: string;
  /**
   * Optional new-device fields used by the welcome-card pairing route
   * (no source account doc exists yet for the caller's UID, so there
   * is nothing to copy from). When the source account does exist
   * these are ignored — the existing source device doc is copied
   * over verbatim with `presence` reset to `offline`.
   */
  newDevice?: {
    displayName: string;
    icon: DeviceIcon;
    fcmToken: string | null;
    platform: DevicePlatform;
  };
}

function asObject(raw: unknown): Record<string, unknown> {
  if (!isPlainObject(raw)) {
    throw new HttpsError('invalid-argument', 'Expected a JSON object payload.');
  }
  return raw;
}

export function parseRegisterDeviceInput(raw: unknown): RegisterDeviceInput {
  const obj = asObject(raw);
  return {
    deviceId: assertDeviceId(obj.deviceId),
    displayName: assertDisplayName(obj.displayName),
    icon: assertDeviceIcon(obj.icon),
    fcmToken: assertFcmToken(obj.fcmToken),
    platform: assertDevicePlatform(obj.platform),
  };
}

export function parseUpdatePresenceInput(raw: unknown): UpdatePresenceInput {
  const obj = asObject(raw);
  return {
    deviceId: assertDeviceId(obj.deviceId),
    presence: assertPresence(obj.presence),
  };
}

export function parseRenameDeviceInput(raw: unknown): RenameDeviceInput {
  const obj = asObject(raw);
  return {
    deviceId: assertDeviceId(obj.deviceId),
    displayName: assertDisplayName(obj.displayName),
  };
}

export function parseSetDeviceIconInput(raw: unknown): SetDeviceIconInput {
  const obj = asObject(raw);
  return {
    deviceId: assertDeviceId(obj.deviceId),
    icon: assertDeviceIcon(obj.icon),
  };
}

export function parseRemoveDeviceInput(raw: unknown): RemoveDeviceInput {
  const obj = asObject(raw);
  return {
    deviceId: assertDeviceId(obj.deviceId),
  };
}

export function parseCreateJoinTokenInput(raw: unknown): CreateJoinTokenInput {
  const obj = asObject(raw);
  return {
    issuingDeviceId: assertNonEmptyString(obj.issuingDeviceId, 'issuingDeviceId', DEVICE_ID_MAX),
  };
}

export function parsePreviewJoinTokenInput(raw: unknown): PreviewJoinTokenInput {
  const obj = asObject(raw);
  return {
    tokenId: assertTokenId(obj.tokenId),
  };
}

export function parseJoinNetworkInput(raw: unknown): JoinNetworkInput {
  const obj = asObject(raw);
  const result: JoinNetworkInput = {
    tokenId: assertTokenId(obj.tokenId),
    deviceId: assertDeviceId(obj.deviceId),
  };
  if (obj.newDevice !== undefined && obj.newDevice !== null) {
    if (!isPlainObject(obj.newDevice)) {
      fail('newDevice', 'expected an object');
    }
    const nd = obj.newDevice as Record<string, unknown>;
    result.newDevice = {
      displayName: assertDisplayName(nd.displayName),
      icon: assertDeviceIcon(nd.icon),
      fcmToken: assertFcmToken(nd.fcmToken),
      platform: assertDevicePlatform(nd.platform),
    };
  }
  return result;
}

function assertEncryptedPayload(value: unknown, field: string): string {
  if (typeof value !== 'string') fail(field, 'expected a string');
  if ((value as string).length === 0) fail(field, 'must not be empty');
  if ((value as string).length > ENCRYPTED_PAYLOAD_MAX) {
    fail(field, `must be ${ENCRYPTED_PAYLOAD_MAX} characters or fewer`);
  }
  return value as string;
}

function assertSourceDeviceId(value: unknown): string {
  return assertNonEmptyString(value, 'sourceDeviceId', DEVICE_ID_MAX);
}

function assertTargetDeviceId(value: unknown): string {
  return assertNonEmptyString(value, 'targetDeviceId', DEVICE_ID_MAX);
}

export interface SendWakeInput {
  sourceDeviceId: string;
  targetDeviceId: string;
  payload: string;
}

export function parseSendWakeInput(raw: unknown): SendWakeInput {
  const obj = asObject(raw);
  return {
    sourceDeviceId: assertSourceDeviceId(obj.sourceDeviceId),
    targetDeviceId: assertTargetDeviceId(obj.targetDeviceId),
    payload: assertEncryptedPayload(obj.payload, 'payload'),
  };
}

function assertHttpUrl(value: unknown, field: string): string {
  if (typeof value !== 'string') fail(field, 'expected a string');
  if ((value as string).length === 0) fail(field, 'must not be empty');
  if ((value as string).length > LINK_URL_MAX) {
    fail(field, `must be ${LINK_URL_MAX} characters or fewer`);
  }
  let parsed: URL;
  try {
    parsed = new URL(value as string);
  } catch {
    fail(field, 'must be a valid URL');
  }
  // Block javascript:, file:, data:, vbscript:, etc — only http(s)
  // links are allowed in plaintext mode per spec §5.3 Notifications.
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    fail(field, 'must use http or https scheme');
  }
  return value as string;
}

function assertOptionalTitle(value: unknown): string | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== 'string') fail('title', 'expected a string or undefined');
  const trimmed = (value as string).trim();
  if (trimmed.length === 0) fail('title', 'must not be empty');
  if ((value as string).length > LINK_TITLE_MAX) {
    fail('title', `must be ${LINK_TITLE_MAX} characters or fewer`);
  }
  return value as string;
}

export type SendLinkNotificationInput =
  | {
      mode: 'plaintext';
      sourceDeviceId: string;
      targetDeviceId: string;
      url: string;
      title?: string;
    }
  | {
      mode: 'encrypted';
      sourceDeviceId: string;
      targetDeviceId: string;
      payload: string;
    };

export function parseSendLinkNotificationInput(raw: unknown): SendLinkNotificationInput {
  const obj = asObject(raw);
  const sourceDeviceId = assertSourceDeviceId(obj.sourceDeviceId);
  const targetDeviceId = assertTargetDeviceId(obj.targetDeviceId);
  if (obj.mode === 'plaintext') {
    return {
      mode: 'plaintext',
      sourceDeviceId,
      targetDeviceId,
      url: assertHttpUrl(obj.url, 'url'),
      title: assertOptionalTitle(obj.title),
    };
  }
  if (obj.mode === 'encrypted') {
    return {
      mode: 'encrypted',
      sourceDeviceId,
      targetDeviceId,
      payload: assertEncryptedPayload(obj.payload, 'payload'),
    };
  }
  fail('mode', "expected 'plaintext' or 'encrypted'");
}

export interface PollPendingWakesInput {
  deviceId: string;
}

export function parsePollPendingWakesInput(raw: unknown): PollPendingWakesInput {
  const obj = asObject(raw);
  return {
    deviceId: assertDeviceId(obj.deviceId),
  };
}
