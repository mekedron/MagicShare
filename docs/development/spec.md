# Spec — Device groups

**Status:** Draft
**Owner:** Product (Nikita)
**Audience:** Engineers and AI coding agents implementing the feature
**Last updated:** 2026-05-07

> Implementation checklist: [`task-list.md`](./task-list.md).

---

## 1. Goal

Let a user link the devices they own under a single anonymous identity
and send a push notification from one to another. Nothing more.

This is the **first** cloud feature added on top of upstream LocalSend.
File and link transfers continue to use the LocalSend protocol
unchanged and are out of scope for this document.

## 2. Non-goals

- Cloud-routed file or link transfers.
- End-to-end encrypted payloads through the cloud.
- Per-device session revocation at the Firebase Auth level (all devices
  in a group share one UID — see [§ 7](#7-known-limitations-v1)).
- Multi-account / multi-group on the same device.
- Email, password, social sign-in, or any user-identifying profile.

## 3. Concepts

| Term            | Meaning                                                                 |
|-----------------|-------------------------------------------------------------------------|
| Group           | A set of devices that share one anonymous Firebase Auth user (one UID). |
| Device          | A single install of the MagicShare app, signed in to the group's UID.   |
| Device record   | The Firestore document holding a device's name, icon, and FCM token.    |
| Invite          | A short-lived token that lets a second device join an existing group.   |

A "group" is not a separate entity in Firebase Auth — it is just one
anonymous user with several active sessions (one per device). The
[Firebase session model](https://firebase.google.com/docs/auth/admin/manage-sessions)
allows the same UID to be signed in on many devices simultaneously.

## 4. User experience

All of this lives in a new **Device group** section of *Settings*,
placed at the top of the page.

### 4.1 Empty state — not in a group

Two buttons:

- **Create group** — sign in anonymously, register this device, become
  the only device in the group.
- **Join group** — open a scanner / code-input screen and join an
  existing group invited by another device.

### 4.2 Joined state — in a group

Header shows the device count.

Below it, the **device list**: one row per device in the group, each
row shows the device's icon and name. Tapping a row opens a sheet with:

- **Rename** — change this device's name (free-text, ≤ 32 chars).
- **Change icon** — pick from a fixed set (phone, tablet, laptop,
  desktop, watch, tv, headphones, generic).
- **Send test notification** — fires a push to the selected device.
  Only enabled for *other* devices, not self.
- **Remove from group** — delete the selected device's record.
  Confirmation required. Only enabled for *other* devices.

Below the list, three actions:

- **Invite another device** — generate a fresh invite, show as QR + as
  an 8-character text code for typing (rendered as two groups of
  four).
- **Leave group** — delete *this* device's record and sign out
  locally. Confirmation required.
- **Delete group entirely** — delete every device record in the
  group. Strong confirmation required.

### 4.3 First-run notification permission

The first time the app launches *after* a device joins a group, request
the OS notification permission if not already granted, with a short
rationale ("MagicShare uses notifications to wake this device when
another device sends you something"). If denied, surface a banner in
*Settings → Device group* with a deep link to the system settings.

## 5. Architecture

```
┌────────────────┐  signInAnonymously                ┌──────────────────┐
│ Device A       │ ─────────────────────────────────▶│ Firebase Auth    │
│ (creator)      │                                   │ (anonymous user) │
│                │  registerSelf (Firestore write)   │                  │
│                │ ─────────────────────────────────▶│ Firestore        │
│                │                                   │                  │
│                │  createInvite (Cloud Function)    │ Cloud Functions  │
│                │ ─────────────────────────────────▶│   ↳ mint token   │
└────────────────┘                                   └──────────────────┘
        │                                                      ▲
        │  show QR / 8-char code                               │
        ▼                                                      │
┌────────────────┐  redeemInvite(code)                         │
│ Device B       │ ────────────────────────────────────────────┘
│ (joiner)       │  → custom token
│                │  signInWithCustomToken
│                │  registerSelf (Firestore write)
│                │  send/receive push via FCM
└────────────────┘
```

### 5.1 Authentication

- `firebase_auth` only; **anonymous** provider is the only one enabled.
- Each device signs in with the same UID by passing through a
  custom-token bridge (see § 5.3).
- The Auth user is never deleted while at least one device record
  remains. When the last device leaves or the group is deleted, the
  Cloud Function deletes the anonymous Auth user as well.

### 5.2 Firestore data model

```
groups/{uid}                      ← exists for the lifetime of the group
  ├─ createdAt: Timestamp
  └─ devices/{deviceId}
       ├─ name: string            ← user-editable, 1..32 chars
       ├─ icon: string            ← enum: phone|tablet|laptop|desktop|...
       ├─ fcmToken: string        ← refreshed by the device on each launch
       ├─ platform: string        ← android|ios|macos|windows|linux
       ├─ createdAt: Timestamp
       └─ lastSeenAt: Timestamp   ← refreshed on app start

invites/{code}                    ← short-lived join codes
  ├─ uid: string                  ← group's UID, what the joiner signs in to
  ├─ createdAt: Timestamp
  └─ expiresAt: Timestamp         ← TTL = 5 minutes; cleaned up by scheduler

redeemAttempts/{ipHash}           ← rate-limit ledger for redeemInvite
  ├─ count: number                ← attempts in the current window
  ├─ windowStart: Timestamp       ← start of the rolling window
  └─ blockedUntil: Timestamp?     ← set when count exceeds the limit
```

`{deviceId}` is a UUID v4 generated locally by each device on first
launch and stored in `flutter_secure_storage`. It survives reinstalls
only if the platform's keychain backup carries it; otherwise the
device gets a new ID and a new record.

Security rules (sketch):

- `groups/{uid}/devices/**`: read + write **only** if the caller's UID
  matches `{uid}`. No anonymous reads of other groups, ever.
- `invites/{code}`: write and read both blocked from the client.
  Reads happen only via the `redeemInvite` Cloud Function (Admin SDK
  bypasses rules); writes happen only via `createInvite`.
- `redeemAttempts/{ipHash}`: write and read both blocked from the
  client. The Cloud Functions service account is the only writer.

### 5.3 Cloud Functions

Three callable functions and one scheduler. All TypeScript on Node 20.

| Function          | Caller          | Purpose                                                                 |
|-------------------|-----------------|-------------------------------------------------------------------------|
| `createInvite`    | Signed-in user  | Mint an 8-char code → `{ code, uid: callerUid }` in `invites/`. Return `{ code, expiresAt }`. |
| `redeemInvite`    | Anyone (no auth)| Look up `invites/{code}`, verify not expired, delete it, mint a custom token for the stored UID, return `{ customToken }`. |
| `sendPush`        | Signed-in user  | Look up `groups/{callerUid}/devices/{targetDeviceId}.fcmToken`. Send FCM message with title/body. Reject if target not in same group. |
| `cleanupInvites`  | Scheduler (1h)  | Delete `invites/` documents past `expiresAt` and `redeemAttempts/` ledgers older than 1 hour. |

#### Codes and TTL

`createInvite` codes are **8 characters** from a confusion-free
alphabet (`A–Z` + `2–9` minus `0/O`, `1/I/L` — 32 symbols, ~1.1 × 10¹²
combinations). On collision in `invites/`, retry up to 3 times.

Every invite has a hard **5-minute TTL** stored in `expiresAt`. The
client SHOULD also auto-rotate the displayed code well before
expiry (e.g., regenerate after 4 minutes) so users don't paste a code
that the server has already evicted.

#### Rate limiting

Both write-paths are rate-limited to keep the code space defensible
at 8 chars and to make brute force pointless:

- **`redeemInvite`** is throttled per source IP (hashed before storage
  so we don't keep PII). The function increments
  `redeemAttempts/{ipHash}.count` inside a rolling 60-second window;
  if `count` exceeds **10**, the function returns `RESOURCE_EXHAUSTED`
  and sets `blockedUntil = now + 5min`. Successful redemptions still
  count toward the cap so a successful guess after many failures
  doesn't free the attacker.
- **`createInvite`** caps each group at **5 outstanding invites** at
  any time. When the cap is hit the oldest unconsumed invite is
  deleted before the new one is written. This keeps the active code
  set per group small and bounded.

These limits live as constants in `firebase/functions/src/config.ts`
so they can be tuned without a schema change.

### 5.4 Push delivery

- Delivery uses **Firebase Cloud Messaging** via the `firebase_messaging`
  package on the client and the Admin SDK in Cloud Functions.
- For v1, payloads carry only `{ title, body }`. There is no
  encrypted-metadata channel yet.
- The receiving device shows the notification through
  `flutter_local_notifications` on platforms that need foreground
  presentation (Android, desktop).

### 5.5 QR + text code

- The QR encodes a short URL of the form
  `https://magic.share/g?c=ABCD2345` — same code as the text code.
- The text code is the 8-char alphanumeric code displayed in a large
  monospace font and copyable. UI renders it as two groups of four
  (`ABCD-2345`) to make typing on mobile less error-prone.
- Scanner uses `mobile_scanner`. Generator uses `pretty_qr_code`.

## 6. Local development

The Firebase emulator suite runs Auth, Firestore, and Functions
locally. FCM has no full emulator, so push delivery in dev is verified
against the real `magic-share-backend` project on a separate test
group, *not* the user's primary group. The `--dart-define` flag
`USE_FIREBASE_EMULATOR=true` routes Auth / Firestore / Functions
through `localhost`.

## 7. Known limitations (v1)

- Removing a device or deleting the group does **not** revoke that
  device's Firebase ID token at the Auth layer. The Firestore security
  rule still keeps it from reading or writing anyone's data, but
  perfect session-level revocation is a follow-up.
- Invite codes have a 5-minute TTL and are single-use — there is no
  rotating-key mechanism.
- A device that loses its `flutter_secure_storage` (e.g., factory
  reset) becomes a stranger to the group and must rejoin with a new
  invite.
