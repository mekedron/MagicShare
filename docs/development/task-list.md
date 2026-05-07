# Task list — Device groups (v1)

**Status:** Draft
**Owner:** Product (Nikita)
**Last updated:** 2026-05-07

> Reference spec: [`spec.md`](./spec.md). Read it first.

Work top-to-bottom, **one epic at a time**. Subtasks within an epic
suggest implementation order — finish the whole epic before moving on.
Tick the epic-level checkbox when its last subtask lands.

**Testing policy.** Every epic adds tests for the MagicShare-specific
code it introduces — unit tests in the same commit as the code they
cover, plus integration / E2E tests for any cross-component flow. We
do **not** retroactively cover upstream LocalSend code we have not
touched. All tests pass locally and in CI before any commit lands.

**Foundations already in place** (do not redo): Firebase project,
emulator suite, Cloud Functions package, MagicShare rebrand,
`flutterfire configure` outputs, Notifications + Camera permission
sections in *Settings*. Pick up from Epic 1 below.

---

- [ ] **Epic 1 — Firestore schema + security rules.** Lock down the
  data model from § 5.2 of the spec before any client code touches it.

  - Add Firestore rules for `groups/{uid}/devices/**` allowing read +
    write only when `request.auth.uid == uid`.
  - Add rules for `invites/{code}` blocking all client access (writes
    and reads happen via Cloud Functions only).
  - Add a Firestore composite index for `invites` on `expiresAt` if
    the cleanup query needs it.
  - **Tests:** `firebase/functions/test/rules/*.spec.ts` covering
    same-group read/write allowed, cross-group read/write denied,
    `invites/` client access denied. Run via the Firestore rules
    emulator in CI.
  - **Done when:** rules deploy clean to the emulator and the test
    suite is green in CI.

- [ ] **Epic 2 — Cloud Functions: invite + push.** Implement the four
  callables / scheduler from § 5.3 of the spec.

  - `firebase/functions/src/config.ts` — single module exporting the
    tunable constants: `INVITE_CODE_LENGTH = 8`,
    `INVITE_CODE_ALPHABET` (32 confusion-free symbols),
    `INVITE_TTL_SECONDS = 300`, `INVITE_MAX_OUTSTANDING_PER_GROUP = 5`,
    `REDEEM_RATE_LIMIT_PER_MINUTE = 10`,
    `REDEEM_BLOCK_DURATION_SECONDS = 300`.
  - `createInvite` — caller must be authenticated; returns
    `{ code, expiresAt }` and writes `invites/{code}` with the
    caller's UID. **8-char** code from the confusion-free alphabet.
    Retry on collision up to 3 times. Before writing, query the
    caller's outstanding invites; if at the cap, delete the oldest
    one in the same transaction.
  - `redeemInvite` — public callable; before any lookup, hash the
    source IP (`sha256(ip + serverSalt)`) and consult
    `redeemAttempts/{ipHash}`: if `blockedUntil` is in the future,
    return `RESOURCE_EXHAUSTED`; otherwise increment the rolling
    60-second counter and persist. Then look up `invites/{code}`,
    verify not expired, delete it, mint a custom token for the
    stored UID via the Admin SDK, return `{ customToken }`. A
    successful redemption still counts toward the per-IP cap.
  - `sendPush` — caller must be authenticated; takes
    `{ targetDeviceId, title, body }`; reads
    `groups/{callerUid}/devices/{targetDeviceId}.fcmToken`; rejects
    when target is missing or in another group; sends FCM message via
    Admin SDK.
  - `cleanupInvites` — scheduled every hour; deletes invites past
    `expiresAt` and `redeemAttempts/` ledgers older than 1 hour. Uses
    `pubsub.schedule('every 1 hours')`.
  - **Tests:** `firebase/functions/test/functions/*.spec.ts` covering
    happy path + auth failure + expired-invite + cross-group
    rejection for each callable, plus dedicated rate-limit tests:
    11th `redeemInvite` from the same IP within 60 s is rejected,
    rejected attempts after `blockedUntil` set still fail until the
    block expires, `createInvite` past the per-group cap evicts the
    oldest. Run via the Functions emulator.
  - **Done when:** `npm test` in `firebase/functions/` is green and
    each function deploys clean to the emulator.

- [ ] **Epic 3 — Firebase init in the Flutter app.** Wire Firebase
  into the app entry point and add the emulator-routing flag.

  - Initialize `Firebase.initializeApp(options:
    DefaultFirebaseOptions.currentPlatform)` in `main()` before
    `runApp`.
  - Read `USE_FIREBASE_EMULATOR=true` via `String.fromEnvironment` and
    route Auth, Firestore, and Functions through `localhost` when
    set.
  - Add a thin `lib/services/firebase_bootstrap.dart` that exposes a
    single `bootstrap()` entry point — testable, no globals.
  - **Tests:** widget test that boots the app under the emulator flag
    and verifies all three SDKs use `localhost`.
  - **Done when:** the app builds on every platform and the emulator
    receives traffic when the flag is set.

- [ ] **Epic 4 — Create group: anonymous sign-in + register self.**
  The minimum end-to-end flow: hit *Create group*, end up in the
  joined state with one device in the list.

  - `lib/services/device_identity.dart` — generates and persists a
    UUIDv4 `deviceId` in `flutter_secure_storage`. Survives app
    restarts.
  - `lib/services/device_group_service.dart` —
    `createGroup()` calls `signInAnonymously()`, registers the device
    record at `groups/{uid}/devices/{deviceId}` with default name
    (`"This {platform}"`), default icon (`platform-default`), current
    `fcmToken`, and `lastSeenAt`. Refreshes `fcmToken` and
    `lastSeenAt` on every app start.
  - `lib/pages/settings/device_group/` — *Device group* settings
    section with the empty state from § 4.1: a *Create group* button
    and a *Join group* button (the latter opens a placeholder until
    Epic 6).
  - On success, transition into the joined state showing the device
    list with one entry.
  - **Tests:** unit tests for `device_identity` (deterministic
    persistence) and `device_group_service.createGroup` (against the
    Auth + Firestore emulator). Widget test for the empty-state UI.
  - **Done when:** tapping *Create group* on a fresh install creates
    an Auth user, writes a device record, and shows the joined state
    with one device.

- [ ] **Epic 5 — First-run notification permission.** After a
  successful create/join, request notifications.

  - Reuse the existing `notification_permission_provider` from the
    Permissions section of Settings.
  - Request the OS prompt the first time a device transitions into
    the joined state, with the rationale string from § 4.3.
  - If denied, surface a banner above the device list with a deep
    link to the system Settings page (use `permission_handler`'s
    `openAppSettings()`).
  - **Tests:** widget test asserting the prompt is requested exactly
    once on first join and the banner appears when permission is
    denied.
  - **Done when:** a fresh install creates a group, gets prompted,
    and either receives or surfaces the denied-state banner
    correctly.

- [ ] **Epic 6 — Invite generation: QR + 8-char code.** *Invite
  another device* button in the joined state.

  - `device_group_service.createInvite()` calls the
    `createInvite` Cloud Function and returns
    `{ code, expiresAt }`.
  - `lib/pages/settings/device_group/invite_sheet.dart` shows the
    code in a large monospace block (copyable, formatted as
    `XXXX-XXXX`) and a QR rendered with `pretty_qr_code` encoding
    `https://magic.share/g?c={code}`.
  - Show a countdown next to the code based on `expiresAt`; when the
    clock hits ~60 seconds remaining, request a fresh invite so the
    user never reads off an already-expired code.
  - **Tests:** widget test rendering the sheet with a stub service
    returning a fixed code; a unit test for the
    countdown / auto-refresh timer.
  - **Done when:** an invited code is visible as both QR and text and
    the corresponding Firestore document exists in the emulator.

- [ ] **Epic 7 — Join group: QR scan + code input.** The other half
  of pairing — Device B becomes the second device in the group.

  - *Join group* button opens a screen with two tabs: **Scan** (using
    `mobile_scanner`) and **Type code** (an 8-char input split as
    `XXXX-XXXX`, accepting upper-case letters and digits from the
    confusion-free alphabet only).
  - Scanner detects QR strings of the form
    `https://magic.share/g?c={code}` and extracts the code.
  - `device_group_service.joinGroup(code)` calls `redeemInvite`,
    receives a custom token, calls `signInWithCustomToken`, then
    runs the same registration logic as `createGroup`.
  - Error states: invalid code, expired code, network error,
    rate-limit exceeded (`RESOURCE_EXHAUSTED`) — each with a clear
    localized message. The rate-limit message tells the user how
    long to wait based on the function's response.
  - **Tests:** integration test against the emulator: device A
    creates a group + invite; device B redeems the code and ends up
    with both devices visible in `groups/{uid}/devices`.
  - **Done when:** two devices end up in the same group via QR or
    text code, and both see each other in the device list.

- [ ] **Epic 8 — Device list: rename + change icon.** Edit per-device
  metadata.

  - Tap a device row → bottom sheet with rename + change-icon
    actions (and disabled-for-self placeholders for the destructive
    actions added in Epic 9 / 10).
  - Rename: text field with 1..32 char validation; writes
    `name` field.
  - Change icon: grid of the 8 enum values from § 5.2; writes `icon`
    field.
  - The list is a real-time `StreamBuilder` over
    `groups/{uid}/devices`. Use `ListView.builder`.
  - **Tests:** widget tests covering rename validation and icon
    selection; integration test covering Firestore write through.
  - **Done when:** edits made on one device propagate to the other
    in real time.

- [ ] **Epic 9 — Send test push.** Receive a notification on another
  device.

  - Bottom-sheet *Send test notification* action calls
    `device_group_service.sendTestPush(targetDeviceId)` which invokes
    the `sendPush` Cloud Function with title `"MagicShare test"` and
    body `"Hello from {sourceDeviceName}"`.
  - On the receiving device, foreground messages render through
    `flutter_local_notifications`; background / killed-state
    messages use the platform's default FCM display path.
  - Disabled when target is self.
  - **Tests:** integration test that, against the real test Firebase
    project (since FCM has no emulator), confirms `sendPush` returns
    success when called from a paired device. Receiver-side delivery
    is checked manually on each platform and recorded in the PR.
  - **Done when:** a push fired from device A appears on device B in
    foreground, background, and killed states on at least Android +
    iOS + macOS.

- [ ] **Epic 10 — Leave, remove, delete.** The three destructive
  actions, each gated by an explicit confirmation.

  - **Remove from group** (action on another device's row): deletes
    `groups/{uid}/devices/{targetDeviceId}` from the actor's client.
    Security rules already ensure only same-group callers can do
    this.
  - **Leave group** (action on the bottom of the list): deletes own
    device record, signs out locally, returns to the empty state.
  - **Delete group entirely**: deletes every device record under
    `groups/{uid}`, then signs out and clears local credentials.
    Implemented as a client-side batched delete; if the batch
    exceeds 500 docs (it won't for v1), fall back to a Cloud
    Function.
  - All three show a confirmation dialog with the device / group
    name. *Delete group* requires typing the device count or the
    word "delete" to confirm.
  - **Tests:** integration tests against the emulator covering each
    action's effect on Firestore and on the local sign-in state.
  - **Done when:** all three actions work end-to-end with no
    orphaned records and the UI returns to the correct state.

- [ ] **Epic 11 — i18n + accessibility pass.** Polish before merge.

  - Localize every user-visible string introduced by Epics 4 –10
    through the existing `assets/i18n/en.json` flow, using nested
    keys under `settings.deviceGroup.*`.
  - Verify all interactive elements have `Semantics` labels suitable
    for screen readers.
  - Verify color contrast ≥ 4.5:1 against both light and dark themes.
  - **Tests:** snapshot tests for each new screen in light + dark.
  - **Done when:** `flutter analyze` is clean, no untranslated keys
    remain, and a screen-reader pass on iOS + Android reports no
    blocking gaps.
