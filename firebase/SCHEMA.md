# Firestore Schema

**Status:** Draft
**Owner:** Product (Nikita)
**Last updated:** 2026-05-03

> Reference spec: [`../docs/development/cloud-sync-spec.md`](../docs/development/cloud-sync-spec.md) §6.
> TypeScript types live in [`functions/src/models.ts`](./functions/src/models.ts) and must
> stay in sync with this document.

This file documents the four Firestore collections used by MagicShare's
cloud-sync backend. Every field below has a matching property in
`models.ts`; if you add or rename a field in one, update the other in the
same commit.

All timestamps are Firestore `Timestamp` values. All writes go through
Cloud Functions using the admin SDK — no collection accepts direct
client writes (see [`firestore.rules`](./firestore.rules)).

---

## `accounts/{accountId}`

A device group. `accountId` equals the anonymous Firebase Auth UID of
the user who owns the group. Created lazily on first launch by the
`createAccount` callable.

| Field          | Type        | Notes                                             |
|----------------|-------------|---------------------------------------------------|
| `createdAt`    | `Timestamp` | Set once on creation; never updated.              |
| `lastActiveAt` | `Timestamp` | Bumped by every device check-in.                  |
| `deviceCount`  | `number`    | Cached count of `devices` subcollection members.  |

- **Read:** authenticated user where `request.auth.uid == accountId`.
- **Write:** Cloud Functions only.
- **Retention:** garbage-collected after 90 days of inactivity by the
  scheduled `cleanupInactiveAccounts` job (Epic 6).

---

## `accounts/{accountId}/devices/{deviceId}`

A single MagicShare installation registered under a device group.
`deviceId` is a UUID generated on first launch and persisted in
`flutter_secure_storage` on the device.

| Field            | Type                | Notes                                                                                                   |
|------------------|---------------------|---------------------------------------------------------------------------------------------------------|
| `displayName`    | `string`            | User-visible name. Default inferred from device hostname.                                               |
| `icon`           | `DeviceIcon`        | One of `laptop \| desktop \| phone \| tablet \| server \| headless \| other`. Default from `Platform`.  |
| `fcmToken`       | `string \| null`    | FCM push token. May be null on platforms without FCM (Linux).                                           |
| `platform`       | `DevicePlatform`    | One of `android \| ios \| macos \| windows \| linux`.                                                   |
| `lastSeenAt`     | `Timestamp`         | Bumped by `updateDevicePresence` (rate-limited to one call per minute per device).                      |
| `presence`       | `DevicePresence`    | `online` while the app is foregrounded; `offline` otherwise.                                            |
| `recentSendsAt?` | `Timestamp[]`       | Sliding-window record of recent `sendWake` / `sendLinkNotification` calls (≤ 30 entries, ≤ 1 h old).    |

- **Read:** authenticated user where `request.auth.uid == accountId`.
- **Write:** Cloud Functions only.
- **Retention:** removed when the user unlinks the device, when the
  parent account is deleted, or when the parent is GC'd by the
  scheduled cleanup job.

---

## `accounts/{accountId}/devices/{deviceId}/inbox/{itemId}`

A short-lived per-device delivery queue used **only** by Linux clients,
which cannot receive FCM pushes. Other platforms ignore this
subcollection.

| Field       | Type                                       | Notes                                                                |
|-------------|--------------------------------------------|----------------------------------------------------------------------|
| `type`      | `'wake' \| 'link'`                         | Same wire shape as the corresponding FCM data message.               |
| `payload`   | `string \| { url: string; title?: string }`| Encrypted blob (wake / encrypted-link), or plaintext-link object.    |
| `createdAt` | `Timestamp`                                | Set on insert.                                                       |
| `expiresAt` | `Timestamp`                                | `createdAt + 5 min`. Used by the polling consumer and the TTL sweep. |

- **Read:** Cloud Functions only — Linux clients pull items via the
  `pollPendingWakes` callable (Epic 6), which atomically consumes them.
- **Write:** Cloud Functions only.
- **Retention:** consumed on poll, swept by TTL when expired.

---

## `joinTokens/{tokenId}`

A one-time pairing token. Created by `createJoinToken` (issuing
device), validated and consumed by `joinNetwork` (joining device). Both
calls are Cloud Functions.

| Field             | Type                | Notes                                                              |
|-------------------|---------------------|--------------------------------------------------------------------|
| `accountId`       | `string`            | The device group the token grants access to.                       |
| `createdAt`       | `Timestamp`         | Set on insert.                                                     |
| `expiresAt`       | `Timestamp`         | `createdAt + 5 min`. Validated server-side on every read.          |
| `consumedAt`      | `Timestamp \| null` | `null` until the token is used; set when `joinNetwork` succeeds.   |
| `issuingDeviceId` | `string`            | The device that produced the QR. Used for LAN-side key handshake.  |

- **Read:** Cloud Functions only.
- **Write:** Cloud Functions only.
- **Retention:** swept daily by `cleanupExpiredJoinTokens` (Epic 6).
