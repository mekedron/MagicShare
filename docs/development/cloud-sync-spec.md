# MagicShare — Cloud Sync Technical Specification

**Status:** Draft
**Owner:** Product (Nikita)
**Audience:** Engineers and AI coding agents implementing the feature
**Last updated:** 2026-05-03

---

## 1. Document Purpose

This is the technical specification for the cloud-assisted device sync
feature in MagicShare (a fork of LocalSend). It describes the product
behavior, the backend services to be built, the user-facing changes to
the Flutter app, and a flat task checklist to be worked through
top-to-bottom. Each task is sized to be completable in a single focused
30–60 minute session.

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

## 8. Tasks (priority order)

Work top-to-bottom. Each task is sized for a single 30–60 minute
session.

- [ ] 1. Create the Firebase project and enable Authentication
  (anonymous), Firestore (production mode), Cloud Functions, and Cloud
  Messaging. Add `.firebaserc` and `firebase.json` under a top-level
  `firebase/` directory.
- [ ] 2. Run `flutterfire configure` and commit `firebase_options.dart`
  plus the per-platform config files (`google-services.json`,
  `GoogleService-Info.plist`).
- [ ] 3. Scaffold a TypeScript Node 20 Cloud Functions package under
  `firebase/functions/` (`firebase init functions --typescript`). Add
  ESLint, Prettier, `tsconfig.json` with `strict: true`, and a deploy
  script.
- [ ] 4. Configure the Firebase emulator suite (Auth, Firestore,
  Functions, FCM passthrough) in `firebase.json`. Add an `npm run dev`
  script that runs all emulators. Document usage in
  `docs/development/firebase-local.md`.
- [ ] 5. Add a GitHub Actions workflow
  `.github/workflows/firebase-functions.yml` that lints and tests
  Cloud Functions on PRs touching `firebase/functions/**`.
- [ ] 6. Document the Firestore schema (`accounts`, `devices`,
  `joinTokens`, `inbox`) in `firebase/SCHEMA.md`.
- [ ] 7. Write Firestore security rules for `accounts/{id}` and
  `accounts/{id}/devices/{*}`: read/write only by an authenticated
  user whose UID equals the account ID, or by Cloud Functions.
- [ ] 8. Write Firestore security rules for `joinTokens/*`: written
  only by Cloud Functions, no direct client read access.
- [ ] 9. Add unit tests for the security rules using
  `@firebase/rules-unit-testing`. Cover happy path, unauthorized read,
  and direct write to `joinTokens`. Wire into CI.
- [ ] 10. Define shared TypeScript model types (`Account`, `Device`,
  `JoinToken`, `InboxItem`) in `firebase/functions/src/models.ts`.
- [ ] 11. Implement the `createAccount` callable function. Idempotent
  — creates `accounts/{uid}` if missing.
- [ ] 12. Implement the `registerDevice` callable function. Inputs:
  `deviceId`, `displayName`, `icon`, `platform`, `fcmToken`. Writes
  `accounts/{uid}/devices/{deviceId}` and bumps
  `accounts/{uid}.lastActiveAt`.
- [ ] 13. Implement the `updateDevicePresence` callable function.
  Updates `lastSeenAt` and `presence` on the caller's device.
  Rate-limited to one call per minute per device.
- [ ] 14. Implement the `renameDevice` and `setDeviceIcon` callable
  functions. Validate input (length, icon enum).
- [ ] 15. Implement the `removeDevice` callable function. Deletes a
  device. If it was the last one, also deletes the parent account.
- [ ] 16. Implement the `deleteAccount` callable function. Deletes
  the entire account and all device documents.
- [ ] 17. Implement the `createJoinToken` callable function. Generates
  a 5 min token in `joinTokens/{tokenId}`. Returns the token to the
  caller for QR display.
- [ ] 18. Implement the `previewJoinToken` callable function. Looks
  up a token, returns the target account ID and a public-safe view of
  its device list (display name, icon, platform — no FCM tokens).
  Rejects expired or consumed tokens.
- [ ] 19. Implement the `joinNetwork` callable function. Verifies the
  token, marks it consumed, copies the device into the target
  account, deletes the device from the caller's old account, and
  deletes the old account if it is now empty. All in a Firestore
  transaction. Does not deliver the shared key — that is a separate
  LAN step.
- [ ] 20. Implement the `cleanupExpiredJoinTokens` scheduled function.
  Runs daily.
- [ ] 21. Implement the `sendWake` callable function. Inputs:
  `targetDeviceId`, `encryptedPayload` (opaque blob). Verifies
  same-account, looks up the target's FCM token, sends a data-only
  FCM message. For Linux targets, also writes an `inbox` item.
- [ ] 22. Implement the `sendLinkNotification` callable function. Two
  modes: `plaintext` (FCM `notification` message; verify the URL has
  `http`/`https` scheme) and `encrypted` (data-only FCM message
  carrying an opaque blob).
- [ ] 23. Extract a shared `assertSameAccount(callerUid,
  targetDeviceId)` authorization helper used by all functions that
  touch another device.
- [ ] 24. Add a soft rate limit (e.g., 30 sends per device per hour)
  to `sendWake` and `sendLinkNotification`. Reject excess calls with
  a clear error code.
- [ ] 25. Implement the `cleanupInactiveAccounts` scheduled function.
  Runs weekly. Deletes any account whose `lastActiveAt` is older than
  90 days, plus all child devices.
- [ ] 26. Implement auto-mark stale devices offline (scheduled
  function or Firestore TTL) for devices whose `lastSeenAt` is older
  than 5 minutes.
- [ ] 27. Add structured logging across all callables: calling UID,
  operation, success/error, latency. No PII.
- [ ] 28. Implement the `pollPendingWakes` callable function. Returns
  and atomically consumes the calling Linux device's inbox items.
  Items expire after 5 min.
- [ ] 29. Add Firebase Flutter dependencies to `app/pubspec.yaml`
  (`firebase_core`, `firebase_auth`, `cloud_firestore`,
  `cloud_functions`, `firebase_messaging`). Verify the app still
  builds on Android and macOS.
- [ ] 30. Initialize Firebase in `app/lib/main.dart` before
  `runApp`. Behind a feature flag in settings (`cloudSyncEnabled`,
  default `true`).
- [ ] 31. Implement an anonymous sign-in service in
  `app/lib/provider/cloud/auth_provider.dart` (refena). Signs in on
  first access; exposes the current `User`.
- [ ] 32. Define `dart_mappable` models for cloud entities:
  `CloudAccount`, `CloudDevice`, `CloudDeviceIcon` enum,
  `JoinTokenPreview`, `WakeRequest`, `LinkRequest`.
- [ ] 33. Implement a typed Cloud Functions client in
  `app/lib/provider/cloud/functions_client.dart` with a wrapper for
  every callable.
- [ ] 34. Implement FCM token retrieval & refresh in
  `app/lib/provider/cloud/fcm_provider.dart`. On startup, fetch the
  token. Subscribe to `onTokenRefresh` and post updates to
  `registerDevice`. Handle iOS APNS-token availability.
- [ ] 35. iOS push entitlements & APNs setup. Enable Push
  Notifications capability in `Runner.xcodeproj`. Add background
  mode `remote-notification`. Document APNs key upload in
  `docs/development/ios-push-setup.md`.
- [ ] 36. Android notification channels and FCM service. Declare a
  default high-priority data channel in `AndroidManifest.xml`. Add a
  stub `FirebaseMessagingService` for background data delivery.
- [ ] 37. Desktop notification source. Wire FCM via the Firebase Web
  Messaging SDK on Windows and macOS. On Linux, implement the 30 s
  polling loop against `pollPendingWakes`. Document platform
  decisions in `docs/development/desktop-push.md`.
- [ ] 38. Implement `AccountRepository` in
  `app/lib/provider/cloud/account_repository.dart`. Knows the current
  account ID, current device ID, and list of group devices. Watches
  Firestore for live updates.
- [ ] 39. Implement `DeviceIdentityService`. Returns a stable device
  ID (persisted in `flutter_secure_storage`), the platform, and a
  default icon based on `Platform.isXxx`.
- [ ] 40. Implement the first-launch bootstrap flow: anonymous
  sign-in, then `createAccount`, then `registerDevice` with this
  device's data. Idempotent.
- [ ] 41. Implement the device presence heartbeat. Calls
  `updateDevicePresence` on app foreground and once every 4 minutes
  while the app stays foregrounded.
- [ ] 42. Implement group shared key generation and storage. On first
  launch (account-creation path), generate a random 256-bit key and
  store it in `flutter_secure_storage`. Cleared on `deleteAccount`.
- [ ] 43. Implement notification payload encrypt/decrypt helpers
  (AES-GCM or chosen equivalent) wrapping the shared key. Round-trip
  tested.
- [ ] 44. Extend the LocalSend upload-request payload with an optional
  `wakeSessionId` string field. Update both Flutter and Rust sides if
  both touch the upload-request shape. Stock LocalSend clients must
  still interoperate (forward compatibility).
- [ ] 45. Add a new "Device group" section at the very top of
  `app/lib/pages/tabs/settings_tab.dart`. Section header localized;
  empty body for now.
- [ ] 46. Implement the device list widget. One tile per device:
  icon, display name, *This device* badge for the current device,
  online/offline dot. Sort: current device first, then online by
  name, then offline by name.
- [ ] 47. Implement the current-device bottom sheet. Actions: rename,
  change icon, *Leave or destroy this group*.
- [ ] 48. Implement the other-device bottom sheet. Actions: rename,
  change icon, *Remove this device from group* (with confirmation
  dialog).
- [ ] 49. Implement the icon picker dialog. Grid of supported device
  icons (laptop, desktop, phone, tablet, server, headless, generic).
- [ ] 50. Add the *Delete this device group* button below the device
  list. Red, with confirmation. Calls `deleteAccount`. On success,
  the app re-bootstraps a fresh account.
- [ ] 51. Add localization keys for all visible strings introduced in
  the device group section.
- [ ] 52. Implement the *Invite a device* button + QR code dialog.
  Calls `createJoinToken`, renders the result as a `pretty_qr_code`
  QR. Shows a countdown to expiry. Includes a copy-as-text fallback.
  The QR encodes the join token, the issuing device's LAN address,
  and a temporary public key.
- [ ] 53. Implement the *Join an existing group* button + camera
  flow. Opens a QR scanner page (e.g., `mobile_scanner`). Handles
  camera permission. After a successful scan, parses the token, LAN
  address, and temporary public key. If the LAN address is not
  reachable, shows the *"Both devices need to be on the same Wi-Fi
  to pair"* error and aborts.
- [ ] 54. Implement the pair preview dialog. Calls
  `previewJoinToken`, renders the device list, asks for confirmation.
- [ ] 55. Implement the LAN-side key exchange. The issuing device
  opens a one-shot LAN endpoint protected by the temporary keypair
  from the QR. The joining device, after `joinNetwork` succeeds,
  connects to that endpoint, authenticates, and receives the group's
  shared key. Both sides tear the endpoint down on success or after a
  5 min timeout.
- [ ] 56. Implement the post-pair flow. After `joinNetwork` and the
  LAN handshake succeed, refresh the AccountRepository, replace the
  locally stored shared key, clear the old key, and show a success
  snackbar.
- [ ] 57. Implement a desktop alternative to QR scanning: a
  paste-token text field that accepts the same payload as the QR.
- [ ] 58. Modify `app/lib/pages/tabs/send_tab.dart` to merge
  LAN-discovered devices with `AccountRepository` devices. Devices
  that match by ID are shown once.
- [ ] 59. Add online/offline status dots to send-tab tiles. Online =
  LAN-discoverable AND foregrounded recently.
- [ ] 60. Implement the wake flow for offline network devices. Call
  `sendWake` with an encrypted payload describing the sender's IP,
  port, and a session nonce. Show a *Waking up <device>…* indicator.
  Wait up to 60 s. On timeout, show an error.
- [ ] 61. Implement the URL fast-path send. When the payload is a
  single URL and the target is a network device, skip the P2P
  transfer and call `sendLinkNotification`. Read the *Encrypt link
  notifications* setting to decide between plaintext and encrypted
  modes.
- [ ] 62. Add the *Encrypt link notifications* per-device setting
  under the General section of the Settings tab. Default off.
  Persisted in the existing settings store. Localized.
- [ ] 63. Add send-tab UX states for *waking up*, *retrying*, and
  *error*. Error copy: *"Device did not respond. It might be
  offline."*.
- [ ] 64. Implement the background data-message handler. Register
  `FirebaseMessaging.onBackgroundMessage` with a top-level function
  that decrypts the payload and dispatches it via a platform-channel
  signal.
- [ ] 65. Implement the foreground data-message handler
  (`FirebaseMessaging.onMessage` listener). Same decrypt + dispatch
  path as background.
- [ ] 66. Implement the URL notification tap handler. Tapping a
  visible link notification opens the URL in the system browser via
  `url_launcher`. Where the OS allows, open without launching the
  app.
- [ ] 67. Implement the wake → P2P bridge. On receipt of a wake
  notification, ensure the LocalSend HTTP server is running. Read the
  wake session nonce from the payload and add it to a short-lived
  in-memory expected-nonce map (TTL ~2 min). Match incoming
  upload-requests against this map; auto-accept on hit, fall back to
  the standard prompt on miss.
- [ ] 68. Implement the notification permission request flow. iOS:
  request on first cloud-feature usage. Android 13+: request
  `POST_NOTIFICATIONS`. Show a non-blocking explanation if denied.
- [ ] 69. Implement desktop notification handling via
  `flutter_local_notifications` or platform channels. Tapping a URL
  notification opens the URL in the default browser. Tapping a wake
  notification brings the app to focus and triggers the wake flow.
- [ ] 70. Add the *Cloud features* master toggle in the General
  settings section. When off, the device-group section is hidden,
  FCM is uninitialized, and no network calls happen.
- [ ] 71. Add the privacy copy paragraph below the device-group
  section. Explain what data leaves the device: account ID, device
  ID, name, icon, FCM token, presence timestamps, encrypted wake
  payloads. Mention both link-mode paths. Localized.
- [ ] 72. Add a telemetry hook that wraps every cloud function call:
  function name, success/error, latency. No PII. Debug builds print;
  release builds suppress.
- [ ] 73. Handle offline / no-internet behavior gracefully. Cloud
  calls fail without blocking the UI. The device-group section shows
  a *Cloud unavailable* banner instead of an endless spinner.
- [ ] 74. Add an account-state debug page under the existing debug
  menu. Dumps account ID, device ID, FCM token (truncated),
  shared-key fingerprint, and last-presence timestamp.
- [ ] 75. Write a manual QA checklist at
  `docs/development/cloud-sync-qa-checklist.md`. Cover: fresh
  install, pairing, wake-on-offline, URL fast-path, group
  destruction, account expiry. Reference from the README.
- [ ] 76. Write an end-to-end automated test for the pairing happy
  path (`flutter_test` + Firebase emulator). Two simulated
  installations pair; one removes the other.
- [ ] 77. Write an end-to-end automated test for wake-and-receive.
  One simulated device sends a wake to a paused second device; the
  second device opens its receive window.
- [ ] 78. Update the top-level `README.md` and `docs-site/` with
  cloud-feature build/run instructions and a new *Cloud Sync* docs
  page.
- [ ] 79. Bump `app/pubspec.yaml` version. Add a `CHANGELOG.md` entry
  summarizing cloud features.

---

## 9. Out of Scope

- Multi-user / shared-with-friend flows.
- Server-mediated transfer (cloud relay for payloads).
- Cross-account device discovery.
- A web-based MagicShare client.
- iCloud / Google account fallback for backup of the shared key.
