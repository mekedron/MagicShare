# Tasks

**Status:** Draft
**Owner:** Product (Nikita)
**Last updated:** 2026-05-03

> Reference spec: [`cloud-sync-spec.md`](./cloud-sync-spec.md). Read
> it first if you need context on what is being built and why.

Work top-to-bottom, **one epic at a time**. Subtasks within an epic
are suggested implementation order — finish the whole epic before
moving on. Tick the epic-level checkbox when the last subtask
lands.

- [ ] **Epic 1 — Project foundations.** Stand up the Firebase
  project, the Cloud Functions package, the emulator suite, the CI
  workflow, and the Flutter web build that the agent uses for
  browser-based smoke tests.

  - Enable Flutter web for the app. From `app/`, run
    `flutter create . --platforms=web`. Verify
    `flutter run -d chrome` boots the existing UI.
  - Create the Firebase project; enable Authentication
    (anonymous), Firestore (production), Cloud Functions, and
    Cloud Messaging. Add `.firebaserc` and `firebase.json` under a
    top-level `firebase/` directory.
  - Run `flutterfire configure` and commit `firebase_options.dart`
    plus the per-platform config files (`google-services.json`,
    `GoogleService-Info.plist`).
  - Scaffold a TypeScript Node 20 Cloud Functions package under
    `firebase/functions/` with ESLint, Prettier, strict
    TypeScript, and a deploy script.
  - Configure the Firebase emulator suite (Auth, Firestore,
    Functions, FCM passthrough). Add an `npm run dev` script.
    Document usage in `docs/development/firebase-local.md`.
  - Add `.github/workflows/firebase-functions.yml` that lints and
    tests Cloud Functions on PRs touching `firebase/functions/**`.
    Skip on docs-only changes.
  - **Done when:** `flutter run -d chrome` opens the app in a
    browser; `firebase use [project]` works locally;
    `npm run dev` brings up all emulators; CI passes on a PR
    touching `firebase/functions/`.

- [ ] **Epic 2 — Schema and security rules.** Lock down the
  Firestore data model and the rules that protect it before any
  callable functions go in.

  - Document the Firestore schema (`accounts`, `devices`,
    `joinTokens`, `inbox`) in `firebase/SCHEMA.md` and define
    matching TypeScript types in
    `firebase/functions/src/models.ts`.
  - Write Firestore security rules covering all collections:
    `accounts/{id}` and `accounts/{id}/devices/{*}` are accessible
    only by an authenticated user whose UID equals the account
    ID, or by Cloud Functions; `joinTokens/*` are written only by
    Cloud Functions and not directly readable by clients.
  - Add unit tests for the security rules using
    `@firebase/rules-unit-testing`. Cover happy path,
    unauthorized cross-group reads, and direct `joinTokens`
    writes. Wire into CI.
  - **Done when:** rules deploy without warnings; unit tests pass
    locally and in CI; schema doc and TypeScript types stay in
    sync.

- [ ] **Epic 3 — Account and device callables.** Implement the
  cloud functions that create and manage accounts and devices.

  - `createAccount` (idempotent; creates `accounts/{uid}` if
    missing).
  - `registerDevice` (writes the device document; bumps
    `lastActiveAt`).
  - Device-management callables: `updateDevicePresence`
    (rate-limited to one call per minute per device),
    `renameDevice`, `setDeviceIcon` (input validation).
  - Deletion callables: `removeDevice` (deletes the parent
    account if it was the last device); `deleteAccount` (deletes
    the account and all child devices in one transaction).
  - **Done when:** an end-to-end emulator test creates an
    account, registers two devices, renames one, removes one, and
    deletes the account — with Firestore state consistent at
    every step.

- [ ] **Epic 4 — Pairing callables.** Implement the cloud-side of
  the pairing flow. The LAN-side key handshake is a separate epic.

  - `createJoinToken` (5 min one-time token in
    `joinTokens/{tokenId}`).
  - `previewJoinToken` (returns target account plus a public-safe
    device list; rejects expired or consumed tokens).
  - `joinNetwork` (verifies the token, marks it consumed, moves
    the device to the target account, deletes the empty old
    account, all in one transaction).
  - **Done when:** an emulator integration test pairs two
    simulated installations end-to-end (cloud side only) and the
    old account is destroyed when its last device leaves.

- [ ] **Epic 5 — Notifications and maintenance.** Round out the
  backend with notification dispatch, scheduled cleanup, rate
  limiting, structured logging, and the Linux polling fallback.

  - `sendWake`: data-only FCM message with the encrypted payload;
    for Linux targets, also write an `inbox` item.
  - Shared `assertSameAccount(callerUid, targetDeviceId)` helper
    used by every function that touches another device.
  - `sendLinkNotification` with two modes: `plaintext` (visible
    FCM notification; verify `http`/`https` scheme) and
    `encrypted` (data-only FCM data message).
  - Soft rate limit (e.g., 30 sends per device per hour) on
    `sendWake` and `sendLinkNotification`.
  - Scheduled jobs: `cleanupExpiredJoinTokens` (daily),
    `cleanupInactiveAccounts` (weekly, 90-day window),
    stale-presence marking (every ~5 min, or via Firestore TTL).
  - Structured logging across all callables: caller UID, op,
    success/error, latency. No PII.
  - `pollPendingWakes` callable for Linux clients: returns and
    atomically consumes the calling device's `inbox` items.
  - **Done when:** dispatch works in the emulator with auth
    enforced; scheduled jobs execute on schedule; logs are
    structured and PII-free; Linux polling returns inbox items.

- [ ] **Epic 6 — Flutter Firebase integration.** Wire Firebase
  into the Flutter app on every supported platform (Android, iOS,
  macOS, Windows, Linux, web).

  - Add Firebase Flutter dependencies (`firebase_core`,
    `firebase_auth`, `cloud_firestore`, `cloud_functions`,
    `firebase_messaging`) to `app/pubspec.yaml`. Initialize
    Firebase in `app/lib/main.dart` before `runApp`, behind a
    feature flag (`cloudSyncEnabled`, default `true`).
  - Anonymous sign-in service in
    `app/lib/provider/cloud/auth_provider.dart` (refena). Same
    UID across app restarts.
  - Define `dart_mappable` models for cloud entities
    (`CloudAccount`, `CloudDevice`, `CloudDeviceIcon`,
    `JoinTokenPreview`, `WakeRequest`, `LinkRequest`) and a typed
    Cloud Functions client with a wrapper for every callable.
  - FCM token retrieval and refresh in
    `app/lib/provider/cloud/fcm_provider.dart`. Handle iOS
    APNS-token availability quirks.
  - Mobile push config: iOS Push Notifications capability +
    `remote-notification` background mode + APNs key upload doc;
    Android high-priority data channel + stub
    `FirebaseMessagingService`.
  - Desktop notification source: FCM via the Firebase Web
    Messaging SDK on Windows and macOS; a 30 s polling loop
    against `pollPendingWakes` on Linux. Document platform
    decisions in `docs/development/desktop-push.md`.
  - **Done when:** the app builds on Android, iOS, macOS,
    Windows, Linux, and web; an anonymous user is signed in
    within ~1 s of launch; a test FCM data message reaches the
    app on at least one mobile platform.

- [ ] **Epic 7 — Account and device state in the app.** Implement
  the local state and bootstrap path that registers this device
  and keeps it talking to the cloud.

  - AccountRepository
    (`app/lib/provider/cloud/account_repository.dart`): knows
    current account ID, current device ID, list of group devices;
    watches Firestore live.
  - DeviceIdentityService: stable device ID persisted in
    `flutter_secure_storage`; platform; default icon based on
    `Platform.isXxx`.
  - First-launch bootstrap (idempotent): anonymous sign-in →
    `createAccount` → `registerDevice`.
  - Presence heartbeat: `updateDevicePresence` on app foreground
    and every 4 minutes while foregrounded. Best-effort offline
    mark on backgrounding.
  - Group key generation, secure storage, and AES-GCM (or chosen
    equivalent) encrypt/decrypt helpers. Generated on first launch
    (account-creation path); cleared on `deleteAccount`.
    Round-trip tested.
  - **Done when:** a fresh install produces an account + device
    row in Firestore within ~3 s; the device shows online while
    foregrounded and offline within 5 min of backgrounding;
    round-trip encryption tests pass.

- [ ] **Epic 8 — LocalSend protocol extension.** Add the optional
  `wakeSessionId` field that lets receivers auto-accept transfers
  triggered by a wake notification.

  - Extend the LocalSend upload-request payload with an optional
    `wakeSessionId` string field. Update both Flutter and Rust
    sides if both touch the upload-request shape.
  - Stock LocalSend clients must still interoperate. Verify with
    a fixture or a manual round-trip test.
  - **Done when:** a stock LocalSend client can still send to and
    receive from a MagicShare client both ways; a request
    carrying a `wakeSessionId` parses correctly on both sides.

- [ ] **Epic 9 — Settings: device group section.** Build the new
  settings section: list of devices, bottom sheets, icon picker,
  delete-group button, plus localization.

  - Add a "Device group" section at the top of
    `app/lib/pages/tabs/settings_tab.dart`.
  - Device list widget: icon, display name, *This device* badge
    for the current device, online/offline dot. Sort: current
    device first, then online by name, then offline by name.
  - Device-detail bottom sheets: current device (rename, change
    icon, *Leave or destroy this group*) and other device
    (rename, change icon, *Remove from group* with confirmation).
  - Icon picker dialog with the supported icons (laptop, desktop,
    phone, tablet, server, headless, generic). Selection persists
    via `setDeviceIcon`.
  - *Delete this device group* button below the list. Red, with
    confirmation. Calls `deleteAccount` and re-bootstraps a fresh
    account on success.
  - Localization keys for every visible string introduced in this
    section.
  - **Done when:** every action above works against the emulator;
    localization is complete; deleting the group from one device
    wipes Firestore docs and the local app re-creates a fresh
    account.

- [ ] **Epic 10 — Pairing UI and LAN key exchange.** Wire up the
  user-visible pairing flow plus the direct LAN handshake that
  delivers the group's shared key.

  - *Invite a device* button + QR code dialog: calls
    `createJoinToken`, renders a `pretty_qr_code` QR, shows
    expiry countdown, copy-as-text fallback. The QR encodes the
    join token, the issuing device's LAN address, and a temporary
    public key.
  - *Join an existing group* flow: button, QR scanner page (e.g.,
    `mobile_scanner`) with camera permission handling, and the
    pair preview dialog (calls `previewJoinToken`, renders the
    device list for confirmation).
  - LAN reachability check: if the issuing device's LAN address
    is not reachable after a successful scan, show *"Both devices
    need to be on the same Wi-Fi to pair"* and abort.
  - LAN-side key exchange: the issuing device opens a one-shot
    LAN endpoint protected by the temporary keypair from the QR.
    The joining device, after `joinNetwork` succeeds, connects,
    authenticates, and receives the group's shared key. Both
    sides tear the endpoint down on success or after a 5 min
    timeout.
  - Post-pair flow: refresh AccountRepository, replace the
    locally stored shared key, clear the old key, show a success
    snackbar.
  - Desktop alternative to QR scanning: a paste-token text field
    that accepts the same payload as the QR.
  - **Done when:** two simulated installations on the same LAN
    pair end-to-end, both end up with the same shared key, and
    the joining device's old (now empty) account is destroyed;
    pairing across different LANs fails fast with the expected
    error.

- [ ] **Epic 11 — Send tab integration.** Make network devices
  first-class targets in the Send tab.

  - Merge LAN-discovered devices with `AccountRepository` devices
    in `app/lib/pages/tabs/send_tab.dart`. Devices matching by ID
    are shown once.
  - Online/offline status dot per tile. Online =
    LAN-discoverable AND foregrounded recently.
  - Wake flow for offline targets: call `sendWake` with an
    encrypted payload describing the sender's IP, port, and a
    session nonce; show a *Waking up \[device\]…* indicator;
    wait up to 60 s; on timeout, show an error with a retry
    button. Error copy: *"Device did not respond. It might be
    offline."*.
  - URL fast-path: when the payload is a single URL and the
    target is a network device, skip P2P entirely and call
    `sendLinkNotification` in the mode chosen by the *Encrypt
    link notifications* setting. Add the setting under General;
    default off; persisted in the existing settings store;
    localized.
  - **Done when:** a manual smoke test with two real devices
    delivers a small file via wake-on-offline, and a URL via the
    fast-path with both setting modes; UX states for waking /
    retrying / error all reachable.

- [ ] **Epic 12 — Notification reception.** Make sure
  notifications actually do the right thing on every platform
  when they arrive.

  - Background data-message handler
    (`FirebaseMessaging.onBackgroundMessage` with a top-level
    function): decrypt and dispatch via a platform-channel
    signal.
  - Foreground data-message handler
    (`FirebaseMessaging.onMessage`): same decrypt + dispatch
    path.
  - URL notification tap handler: tap opens the URL in the
    system browser via `url_launcher`. Where the OS allows
    (Android intent filter, iOS deep link), open without
    launching the app.
  - Wake → P2P bridge: ensure the LocalSend HTTP server is
    running, read the wake nonce from the payload, populate the
    short-lived in-memory expected-nonce map (TTL ~2 min). Match
    incoming upload-requests against the map; auto-accept on
    hit, fall back to the standard prompt on miss.
  - Notification permission request flow: iOS on first
    cloud-feature use; Android 13+ for `POST_NOTIFICATIONS`.
    Non-blocking explanation if denied.
  - Desktop notification handling via
    `flutter_local_notifications` or platform channels: source
    from FCM on Windows/macOS, from polling on Linux. URL tap
    opens browser; wake tap focuses app and triggers the wake
    handler.
  - **Done when:** receiving a wake notification with the app
    fully closed brings the device into a state where it
    accepts a P2P connection from the sender without the user
    pressing *Accept*; receiving a link notification opens the
    URL in the browser without launching the app where
    supported.

- [ ] **Epic 13 — Polish and operability.** Cross-cutting work
  that ties the feature together.

  - *Cloud features* master toggle in the General settings
    section. When off: device-group section hidden, FCM
    uninitialized, no cloud calls.
  - Privacy copy below the device-group section: lists what data
    leaves the device (account ID, device ID, name, icon, FCM
    token, presence timestamps, encrypted wake payloads); covers
    both link-mode paths. Localized.
  - Telemetry hook around every cloud function call: function
    name, success/error, latency. No PII. Debug builds print;
    release builds suppress.
  - Offline / no-internet handling: cloud calls fail without
    blocking the UI. The device-group section shows a *Cloud
    unavailable* banner instead of a spinner.
  - Account-state debug page under the existing debug menu.
    Dumps account ID, device ID, FCM token (truncated),
    shared-key fingerprint, last-presence timestamp.
  - **Done when:** turning the master toggle off and relaunching
    produces a stock-LocalSend-like experience; airplane-mode
    shows the unavailable banner; the debug page renders real
    values.

- [ ] **Epic 14 — QA and release.** Final verification and
  shipping.

  - Manual QA checklist at
    `docs/development/cloud-sync-qa-checklist.md`. Cover: fresh
    install, pairing, wake-on-offline, URL fast-path (both
    modes), group destruction, account expiry. Reference from
    the README.
  - E2E test: pairing happy path (`flutter_test` + Firebase
    emulator). Two simulated installations pair; one removes
    the other.
  - E2E test: wake-and-receive. One simulated device sends a
    wake to a paused second device; the second device opens
    its receive window.
  - Release prep: update the top-level `README.md` and
    `docs-site/` with cloud-feature instructions and a new
    *Cloud Sync* docs page; bump `app/pubspec.yaml` version;
    add a `CHANGELOG.md` entry.
  - **Done when:** the manual QA checklist passes; E2E tests
    are green in CI; release notes published.
