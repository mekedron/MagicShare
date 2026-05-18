import { HttpsError } from 'firebase-functions/v2/https';

import { DEVICE_ICONS, DEVICE_PLATFORMS, type DeviceIcon, type DevicePlatform } from './models';

const DEVICE_ID_MAX = 128;
const DISPLAY_NAME_MAX = 80;
const FCM_TOKEN_MAX = 4096;
const TOKEN_ID_MAX = 128;
/**
 * LocalSend's cert hash is a SHA-256 hex digest (64 chars). 128 leaves
 * headroom in case the upstream protocol switches digest. Below this
 * the field is opaque to the backend — we don't validate the format.
 */
const FINGERPRINT_MAX = 128;
const TRANSFER_KINDS = ['file', 'text', 'url'] as const;
export type TransferKind = (typeof TRANSFER_KINDS)[number];

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

function assertFcmToken(value: unknown): string | null {
  if (value === null) return null;
  if (typeof value !== 'string') fail('fcmToken', `expected a string or null`);
  if ((value as string).length === 0) fail('fcmToken', `must not be empty`);
  if ((value as string).length > FCM_TOKEN_MAX) {
    fail('fcmToken', `must be ${FCM_TOKEN_MAX} characters or fewer`);
  }
  return value as string;
}

function assertFingerprint(value: unknown): string | null {
  if (value === null) return null;
  if (typeof value !== 'string') fail('fingerprint', `expected a string or null`);
  if ((value as string).length === 0) fail('fingerprint', `must not be empty`);
  if ((value as string).length > FINGERPRINT_MAX) {
    fail('fingerprint', `must be ${FINGERPRINT_MAX} characters or fewer`);
  }
  return value as string;
}

export interface RegisterDeviceInput {
  deviceId: string;
  displayName: string;
  icon: DeviceIcon;
  fcmToken: string | null;
  platform: DevicePlatform;
  /**
   * Optional. When the input omits the field entirely (older clients
   * that pre-date the field), `parseRegisterDeviceInput` leaves the
   * key undefined and `registerDeviceLogic` preserves whatever value
   * is already on the doc.
   */
  fingerprint?: string | null;
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
   * these are ignored — the existing source device doc is copied over
   * verbatim.
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
  const result: RegisterDeviceInput = {
    deviceId: assertDeviceId(obj.deviceId),
    displayName: assertDisplayName(obj.displayName),
    icon: assertDeviceIcon(obj.icon),
    fcmToken: assertFcmToken(obj.fcmToken),
    platform: assertDevicePlatform(obj.platform),
  };
  if (obj.fingerprint !== undefined) {
    result.fingerprint = assertFingerprint(obj.fingerprint);
  }
  return result;
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

function assertSourceDeviceId(value: unknown): string {
  return assertNonEmptyString(value, 'sourceDeviceId', DEVICE_ID_MAX);
}

function assertTargetDeviceId(value: unknown): string {
  return assertNonEmptyString(value, 'targetDeviceId', DEVICE_ID_MAX);
}

function assertTransferKind(value: unknown): TransferKind {
  if (typeof value !== 'string' || !(TRANSFER_KINDS as readonly string[]).includes(value)) {
    fail('kind', `expected one of ${TRANSFER_KINDS.join(', ')}`);
  }
  return value as TransferKind;
}

export interface NotifyTransferIntentInput {
  sourceDeviceId: string;
  targetDeviceId: string;
  kind: TransferKind;
}

export function parseNotifyTransferIntentInput(raw: unknown): NotifyTransferIntentInput {
  const obj = asObject(raw);
  return {
    sourceDeviceId: assertSourceDeviceId(obj.sourceDeviceId),
    targetDeviceId: assertTargetDeviceId(obj.targetDeviceId),
    kind: assertTransferKind(obj.kind),
  };
}
