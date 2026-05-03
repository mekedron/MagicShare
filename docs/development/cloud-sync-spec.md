# Spec

**Status:** Draft
**Owner:** Product (Nikita)
**Audience:** Engineers and AI coding agents implementing the feature
**Last updated:** 2026-05-03

> The implementation checklist lives in
> [`task-list.md`](./task-list.md). This file is the reference spec;
> that file is the work tracker.

---

## 1. Document Purpose

This is the technical specification for the cloud-assisted device sync
feature in MagicShare (a fork of LocalSend). It describes the product
behavior, the backend services to be built, and the user-facing
changes to the Flutter app.

---

## 2. Background

MagicShare reuses LocalSend's peer-to-peer transfer protocol unchanged.
On top of it we add a thin cloud layer (Firebase only) that solves two
problems LocalSend does not:

1. **Wake-up.** The receiving device does not need to have the app in
   the foreground when a transfer is initiated.
2. **Address book.** A user can see and pick the devices they own,
   even when those devices are not on the local network.

The cloud sees only encrypted metadata. Payload content (files, file
lists, link content for non-trivial links) never goes through the
cloud.

There is no always-on web server. All backend logic runs in callable
Firebase Cloud Functions plus a couple of scheduled functions for
maintenance. Cost target: well under \$1/month per active user.

---

## 3. High-Level Architecture

```
┌──────────┐   anonymous sign-in                       ┌──────────────┐
│  Device  │ ────────────────────────────────────────▶│ Firebase     │
│          │   register self                           │ Auth         │
│          │ ────────────────────────────────────────▶│ Firestore    │
│          │   call sendWake(targetDevice, payload)    │ Cloud        │
│          │ ────────────────────────────────────────▶│ Functions    │
└──────────┘                                           │     │        │
                                                       │     ▼        │
                                                       │   FCM ─────────▶  target device
                                                       └──────────────┘
                       direct P2P transfer (LocalSend protocol)
                       ──────────────────────────────────────────▶
```

---

## 4. Glossary

- **Account / Network / Device Group** — used interchangeably
  internally; all refer to a single anonymous Firebase user identity
  that owns one or more devices. The user-facing wording is **device
  group**. Avoid the words *account* and *network* in UI copy.
- **Device** — a single MagicShare installation registered under a
  device group. Identified by a stable device ID.
- **Pairing** — the act of moving a device from one device group to
  another via a QR code.
- **Wake notification** — an FCM data-only push that prompts the
  receiving device to start a P2P receive flow. Encrypted with the
  group's shared key.
- **Link notification** — a visible (or, optionally, encrypted
  data-only) FCM notification whose only purpose is to open a URL on
  the receiving device.

---

## 5. Product Requirements

### 5.1 Goals

- Each MagicShare install has exactly one device group at any time.
  New installs auto-create one on first launch.
- A user can rename, re-icon, and unlink any device in their group
  from any device.
- A user can move this device into another group via a QR code.
- A user can see their own devices in the Send tab alongside
  LAN-discovered devices.
- A user can send a file or link to one of their own devices even
  when the target is asleep / app not running, by triggering a push
  notification that wakes it.
- A user can delete their entire device group from any device with a
  single button + confirmation.

### 5.2 Non-Goals

- Multi-user / multi-account features.
- Cloud storage of payloads.
- Server-mediated transfer.
- Replacing the LocalSend protocol.
- A web-app version of MagicShare.

### 5.3 Functional Requirements

#### Account & Device Lifecycle

- On first launch, the app creates an anonymous Firebase account and
  registers the current device under it.
- The app stores the account ID and a per-group shared encryption key
  locally in secure storage.
- A user can rename their own device. The new name propagates to other
  devices in the group within a few seconds.
- A user can change the icon of their own device (laptop, desktop,
  phone, tablet, server, headless, other). Default icon is inferred
  from `Platform`.
- A user can remove another device from their group with a single tap
  + confirmation modal.
- A user can delete their entire device group from any device with a
  single tap + confirmation modal. Removing the last device in a group
  destroys the group automatically.
- Inactive groups (no device check-in for 90 days) are
  garbage-collected by a scheduled job.

#### Pairing

- From the settings screen, a user can show a pairing QR code. The QR
  encodes three things: a short-lived (5 min) one-time join token
  bound to the current device group, the issuing device's local
  network address, and a temporary public key for the LAN-side key
  handshake.
- From the settings screen, a user can scan a pairing QR code from
  another device. The app verifies the issuing device is reachable on
  the same local network, fetches the target group's device list from
  the cloud, and shows it for confirmation.
- On confirmation, the joining device is registered under the target
  group via the cloud, opens a direct LAN connection to the issuing
  device, and receives the group's shared encryption key over that
  channel. It then leaves its previous group; if it was the only
  member of that group, the previous group is destroyed.
- Pairing requires both devices to be on the same local network. If
  the issuing device is not LAN-reachable, the joining device shows a
  clear error (*"Both devices need to be on the same Wi-Fi to pair"*)
  and aborts. The group's shared key never leaves the local network.
- A device can refuse pairing at any point before tapping Confirm.
- Button names: **"Invite a device"** (show QR) and **"Join an
  existing group"** (scan QR).

#### Notifications

- The cloud function `sendWake` accepts a target device ID and an
  opaque (already-encrypted) payload. It verifies caller and target
  are in the same device group, then publishes a data-only FCM
  message to the target's push token.
- Wake notification payloads are encrypted with the group's shared
  key.
- Link notifications respect a per-device user setting *Encrypt link
  notifications*:
  - **Plaintext mode (default).** Visible FCM notification; click
    action opens the URL in the browser without launching the app.
  - **Encrypted mode (opt-in).** Data-only FCM message identical in
    shape to a wake notification; the receiver app wakes, decrypts the
    URL, and opens it in the system browser.
- No notifications are persisted in Firestore. Functions publish to
  FCM and forget. (Linux is a small exception — see the Send Flow
  section below.)
- A wake notification triggers the receiving device to listen for an
  inbound LocalSend connection. It does not initiate a transfer — it
  just opens the receive window.

#### Send Flow

- The Send tab lists, in addition to LAN-discovered devices, all
  devices in the user's group. Devices that appear in both lists are
  merged.
- Each network device has an online/offline status. **Online** =
  LAN-reachable AND app foregrounded recently. **Offline** = anything
  else.
- Sending to an online network device behaves exactly like sending to
  a LAN device today.
- Sending to an offline network device first calls `sendWake`, then
  waits for the target to come online (a P2P receive window opens),
  then proceeds with the normal LocalSend transfer. If the target does
  not come online within 60 s, the user gets a "device did not
  respond" error.
- Sending a URL to any network device uses the link-notification
  fast-path instead of opening a P2P transfer.
- The same logic works on desktop. Windows and macOS use FCM via the
  Firebase Web Messaging SDK. **Linux has no FCM support; on Linux
  the app polls a `pollPendingWakes` Cloud Function every 30 s while
  running.** Linux delivery latency is therefore up to ~30 s; other
  platforms are sub-second.
- Auto-acceptance of a wake-triggered transfer relies on a wake
  session nonce generated by the sender, included in the encrypted
  wake payload, and presented by the sender in the LocalSend
  upload-request via a new optional `wakeSessionId` field. The
  receiver maintains a short-lived in-memory map of expected nonces; a
  match auto-accepts, a miss falls back to the standard prompt. The
  protocol extension is forward-compatible — stock LocalSend ignores
  unknown fields.

#### Privacy & Security

- The Firebase project never sees plaintext file content, file names
  beyond what is required for transfer initiation, or link content
  (except when the user has chosen plaintext link notifications).
- Cloud Functions reject any request where the caller's account ID
  does not match the owner of the target device.
- Firestore security rules enforce that a device document can only
  be read or written by Cloud Functions or by an authenticated user
  whose UID matches the owning account.
- The shared device-group key is generated on the device that first
  creates the group. When a device is paired in, the key is delivered
  only over a direct LAN connection — never through Firebase.
- The user can disable cloud features entirely. When disabled,
  MagicShare behaves like stock LocalSend.

### 5.4 Non-Functional Requirements

- Cold-start cost of cloud functions on the user-perceived path is
  ≤ 2 s.
- Cloud cost target: well under \$1/month for a single user with up
  to 10 devices.
- The app must keep working when offline (Firebase down or no
  internet) — only network-device features degrade.
- All UI strings are localizable.

---

## 6. Data Model

Firestore collections:

```
accounts/{accountId}
  - createdAt
  - lastActiveAt
  - deviceCount

accounts/{accountId}/devices/{deviceId}
  - displayName
  - icon
  - fcmToken
  - platform
  - lastSeenAt
  - presence: online | offline

accounts/{accountId}/devices/{deviceId}/inbox/{itemId}
  - type: wake | link
  - payload                    (encrypted blob, or { url, title } in plaintext mode)
  - createdAt
  - expiresAt                  (5 min after createdAt)
  Used only for Linux clients (polling fallback).

joinTokens/{tokenId}
  - accountId
  - createdAt
  - expiresAt                  (5 min after createdAt)
  - consumedAt                 (null until used)
  - issuingDeviceId
```

---

## 7. UX Specification

### 7.1 Settings Screen — Device Group Section

A new section is added at the very top of the Settings tab, above all
existing sections.

```
╔════════════════════════════════════════════╗
║  Device group                              ║
║                                            ║
║  ▣ Macbook Pro          ◉ This device      ║
║  ▣ Pixel 8              ●  Online          ║
║  ▣ iPad                 ○  Offline         ║
║  ▣ Desktop              ●  Online          ║
║                                            ║
║  [ Invite a device ]   [ Join an existing  ║
║                          group ]           ║
║                                            ║
║  [ Delete this device group ]              ║
╚════════════════════════════════════════════╝
```

- Tapping any non-current device opens a sheet: *Rename*, *Change
  icon*, *Remove from group*.
- Tapping the current device opens a sheet: *Rename*, *Change icon*,
  *Leave or destroy this group*.
- The destructive *Delete this device group* button removes the group
  entirely from any device.

### 7.2 Send Tab

The Send tab keeps showing LAN-discovered devices. Network devices
are added to the same list.

- Each device tile shows an online/offline dot.
- Online network devices behave exactly like LAN devices.
- Offline network devices show a small *Wake* indicator. Tapping
  starts the wake flow.

### 7.3 Notifications

- **Wake notification:** silent (data-only). The user does not see a
  notification balloon — the app receives it in the background and
  opens a P2P receive window.
- **Link notification:** behaviour depends on the user setting:
  - *Plaintext mode (default):* visible notification. Tapping opens
    the URL in the system browser. The app does not need to launch.
  - *Encrypted mode:* silent data-only notification. The app wakes,
    decrypts, and opens the URL.
- iOS data-only notifications need APNs `content-available: 1`
  priority and matching entitlements.
- Android data-only notifications use FCM data messages with high
  priority.
- Windows / macOS use FCM web bindings.
- Linux polls every 30 s and surfaces results via
  `flutter_local_notifications`.

---

## 8. Out of Scope

- Multi-user / shared-with-friend flows.
- Server-mediated transfer (cloud relay for payloads).
- Cross-account device discovery.
- A web-based MagicShare client.
- iCloud / Google account fallback for backup of the shared key.
