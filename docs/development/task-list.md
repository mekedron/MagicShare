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

**Testing policy.** Every epic adds tests for the MagicShare-specific
code it introduces — unit tests in the same commit as the code they
cover, plus integration / end-to-end tests for any cross-component
flow. We do **not** retroactively cover upstream LocalSend code we
have not touched. All tests pass locally and in CI before any commit
lands.

- [x] **Epic 1 — Project foundations.** Stand up the Firebase
  project, the Cloud Functions package, the emulator suite, and the
  CI workflow. Local development and testing of cloud-sync code runs
  against the Firebase emulator suite — no browser build is shipped.

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
  - **Tests:** the CI workflows added in this epic must run
    `npm test` (Cloud Functions, even on the empty stub),
    `flutter analyze` and `flutter test` (Flutter), and `dart test`
    (`common/`) on every PR. A no-op PR is green on all of them.
  - **Done when:** `firebase use [project]` works locally;
    `npm run dev` brings up all emulators; CI passes on a PR
    touching `firebase/functions/`.

- [x] **Epic 2 — Rebrand to MagicShare.** Rename every code-level
  reference (Dart package, application IDs, display names, classes,
  user-visible strings) from LocalSend to MagicShare. Keep upstream
  attribution: do not touch the `LICENSE`, source-header copyrights,
  README credits, docs-site landing copy, or protocol-level mentions
  of LocalSend. Add a settings *About MagicShare* section that names
  MagicShare as a fork of LocalSend.

  - Adopt canonical identifiers — app display name `MagicShare`,
    Dart package name `magicshare_app`, reverse-DNS application id
    `com.magicshare.app`. Document the brand-mention policy (where
    LocalSend stays vs gets rebranded) as a *Brand mentions*
    section in `CONTRIBUTING.md`.
  - Dart package rename in `app/pubspec.yaml` (`name:` field);
    rewrite every `package:localsend_app/...` import across `app/`
    and `common/`. Top-level `LocalSendApp` widget →
    `MagicShareApp` (rename only the class added on top of the
    upstream UI; do not rename internal LocalSend identifiers used
    by upstream code).
  - Platform identifiers and display names:
    - Android: `applicationId` in `app/android/app/build.gradle`;
      `android:label` in `AndroidManifest.xml`; rename Kotlin
      package directories under `app/android/app/src/`.
    - iOS: `PRODUCT_BUNDLE_IDENTIFIER` in
      `app/ios/Runner.xcodeproj/project.pbxproj`;
      `CFBundleDisplayName` and `CFBundleName` in `Info.plist`.
    - macOS: bundle identifier and display names in the macOS
      Xcode project.
    - Windows: MSIX `Identity Name` and `Publisher`; product name
      in the Visual Studio project under `app/windows/`; Inno
      Setup script `scripts/compile_windows_exe-inno.iss`.
    - Linux: package name in Debian / RPM / AppImage scripts;
      `Name=` in the generated `.desktop` file.
  - Default device name and any other branding string visible to
    LAN peers, in `app/lib/...` and `common/lib/...`.
  - Localization: replace user-visible `LocalSend` brand strings
    with `MagicShare`. Preserve `LocalSend` where it refers to the
    upstream project, the wire protocol, or interop ("compatible
    with LocalSend").
  - Firebase apps: rename the registered apps in the Firebase
    console; update bundle IDs to the new values. Re-run
    `flutterfire configure` to refresh `firebase_options.dart` and
    per-platform config files.
  - Settings *About MagicShare* section appended to
    `app/lib/pages/tabs/settings_tab.dart`, placed after every
    existing settings group. Contains: app name and version, the
    line *"MagicShare is a fork of LocalSend"* with a link to
    https://localsend.org, and a link to the bundled LICENSE.
    Localized.
  - Keep (do **not** touch): `LICENSE`, source-header copyright
    comments, README credits and the *LocalSend fork* paragraph,
    docs-site landing copy, and protocol-level mentions of
    LocalSend in code comments.
  - **Tests:**
    - Static / unit: `flutter analyze` and `flutter test` (in
      `app/`), `dart analyze` / `test` (in `common/`),
      `npm test` (in `firebase/functions/`) all green after
      rename.
    - Widget (`flutter test`): the new *About MagicShare* card
      renders the LocalSend attribution and the LICENSE link.
    - Smoke build: `flutter build apk --debug`, plus one desktop
      target available locally, succeed with the new identifiers.
    - Manual interop: a stock LocalSend client still sends to and
      receives from this build.
  - **Done when:** searching for `localsend_app` and
    `org.localsend` under `app/`, `common/`, and `firebase/`
    returns zero hits outside attribution files (`LICENSE`, README
    credits, source-header copyrights, protocol references); the
    settings *About MagicShare* card renders with LocalSend
    attribution; the app installs and runs end-to-end on at least
    one mobile and one desktop target with the new identifiers.

- [x] **Epic 3 — Schema and security rules.** Lock down the
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
  - **Tests:** `@firebase/rules-unit-testing` cases for
    happy-path reads, unauthorized cross-group reads, and direct
    `joinTokens` writes. Run on every PR touching
    `firestore.rules` or `firebase/functions/`.
  - **Done when:** rules deploy without warnings; unit tests pass
    locally and in CI; schema doc and TypeScript types stay in
    sync.

- [x] **Epic 4 — Account and device callables.** Implement the
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
  - **Tests:**
    - Unit (emulator): idempotency of `createAccount`; input
      validation paths for `renameDevice` and `setDeviceIcon`;
      rate-limit boundary for `updateDevicePresence`; cascade
      behaviour of `removeDevice` and `deleteAccount`.
    - Integration: the create → register two devices → rename
      → remove → delete scenario described in *Done when*.
  - **Done when:** an end-to-end emulator test creates an
    account, registers two devices, renames one, removes one, and
    deletes the account — with Firestore state consistent at
    every step.

- [x] **Epic 5 — Pairing callables.** Implement the cloud-side of
  the pairing flow. The LAN-side key handshake is a separate epic.

  - `createJoinToken` (5 min one-time token in
    `joinTokens/{tokenId}`).
  - `previewJoinToken` (returns target account plus a public-safe
    device list; rejects expired or consumed tokens).
  - `joinNetwork` (verifies the token, marks it consumed, moves
    the device to the target account, deletes the empty old
    account, all in one transaction).
  - **Tests:**
    - Unit (emulator): expired-token rejection; consumed-token
      rejection; public-safe filtering of the preview device
      list (no FCM tokens leak); transactional integrity of
      `joinNetwork`.
    - Integration: emulator pairing flow including old-account
      destruction when the last device leaves.
  - **Done when:** an emulator integration test pairs two
    simulated installations end-to-end (cloud side only) and the
    old account is destroyed when its last device leaves.

- [x] **Epic 6 — Notifications and maintenance.** Round out the
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
  - **Tests:**
    - Unit (emulator): cross-account auth rejection in
      `sendWake` and `sendLinkNotification`; URL scheme
      validation in plaintext mode; rate-limit boundary
      behaviour; scheduled-job logic against a fake clock;
      atomic consumption in `pollPendingWakes`; Linux inbox
      writeback path.
    - Integration: dispatch path end-to-end via the emulator's
      FCM stub; scheduled jobs trigger correctly under the
      emulator clock.
  - **Done when:** dispatch works in the emulator with auth
    enforced; scheduled jobs execute on schedule; logs are
    structured and PII-free; Linux polling returns inbox items.

- [ ] **Epic 7 — Flutter Firebase integration.** Wire Firebase
  into the Flutter app on every supported platform (Android, iOS,
  macOS, Windows, Linux).

  - **Prerequisite (carry-over from Epic 2):** rename the Android,
    iOS, and macOS apps in the Firebase Console to the new bundle
    IDs (`com.magicshare.app`) and re-run `flutterfire configure`
    so `firebase_options.dart`, `google-services.json`, and the iOS /
    macOS `GoogleService-Info.plist` files regenerate against the
    renamed Console apps. Until this happens, Firebase init will
    succeed locally (the per-platform config files were patched
    in place during Epic 2) but real cloud calls will fail because
    the project still has the old bundle ids registered.
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
  - Desktop notification source: FCM via the Firebase Messaging
    SDK on Windows and macOS; a 30 s polling loop against
    `pollPendingWakes` on Linux. Document platform decisions in
    `docs/development/desktop-push.md`.
  - **Tests:**
    - Unit (`flutter test`): typed Cloud Functions client
      wrappers (mock the underlying `cloud_functions` API);
      FCM provider state on token + refresh events; anonymous
      sign-in service.
    - Integration (`flutter test` against emulator): app boot
      reaches a non-null current user within ~1 s.
  - **Done when:** the app builds on Android, iOS, macOS,
    Windows, and Linux; an anonymous user is signed in within
    ~1 s of launch; a test FCM data message reaches the app on
    at least one mobile platform.

- [ ] **Epic 8 — Account and device state in the app.** Implement
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
  - **Tests:**
    - Unit (`flutter test`): AccountRepository state transitions
      on Firestore events; DeviceIdentityService persistence
      across restarts; AES-GCM round-trip with fixed vectors;
      tampered-ciphertext rejection (auth-tag failure).
    - Integration (`flutter test` against emulator): first-launch
      bootstrap end-to-end (anonymous sign-in → `createAccount`
      → `registerDevice`) is idempotent across restarts.
  - **Done when:** a fresh install produces an account + device
    row in Firestore within ~3 s; the device shows online while
    foregrounded and offline within 5 min of backgrounding;
    round-trip encryption tests pass.

- [ ] **Epic 9 — LocalSend protocol extension.** Add the optional
  `wakeSessionId` field that lets receivers auto-accept transfers
  triggered by a wake notification.

  - Extend the LocalSend upload-request payload with an optional
    `wakeSessionId` string field. Update both Flutter and Rust
    sides if both touch the upload-request shape.
  - Stock LocalSend clients must still interoperate. Verify with
    a fixture or a manual round-trip test.
  - **Tests:**
    - Unit: parse / serialize the upload-request with and
      without `wakeSessionId` on both Flutter (`flutter test`)
      and Rust (`cargo test`) sides.
    - Integration: stock-LocalSend ↔ MagicShare interop check
      using a captured fixture, both directions.
  - **Done when:** a stock LocalSend client can still send to and
    receive from a MagicShare client both ways; a request
    carrying a `wakeSessionId` parses correctly on both sides.

- [ ] **Epic 10 — Settings: device group section.** Build the new
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
  - **Tests:**
    - Widget (`flutter test`): device list rendering for
      current / online / offline variants; bottom sheet actions;
      icon picker selection; delete-group confirmation dialog.
    - Integration (`flutter_test` against emulator): rename,
      remove, and delete-group flows driven from the UI.
  - **Done when:** every action above works against the emulator;
    localization is complete; deleting the group from one device
    wipes Firestore docs and the local app re-creates a fresh
    account.

- [ ] **Epic 11 — Pairing UI and LAN key exchange.** Wire up the
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
  - **Tests:**
    - Widget (`flutter test`): QR display dialog (countdown,
      copy-as-text fallback); scan preview; paste-token
      alternative.
    - Integration / E2E (emulator + virtual LAN): two simulated
      installations pair end-to-end, both end up with the same
      shared key, the joining device's old account is
      destroyed; cross-LAN pairing fails fast with the
      LAN-required error.
  - **Done when:** two simulated installations on the same LAN
    pair end-to-end, both end up with the same shared key, and
    the joining device's old (now empty) account is destroyed;
    pairing across different LANs fails fast with the expected
    error.

- [ ] **Epic 12 — Send tab integration.** Make network devices
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
  - **Tests:**
    - Widget (`flutter test`): merged device list with both LAN
      and network sources; status dots; the three send-tab UX
      states (waking / retrying / error).
    - Integration: send-to-offline wake flow against a paused
      receiver; URL fast-path with both encryption modes
      observed end-to-end.
  - **Done when:** a manual smoke test with two real devices
    delivers a small file via wake-on-offline, and a URL via the
    fast-path with both setting modes; UX states for waking /
    retrying / error all reachable.

- [ ] **Epic 13 — Notification reception.** Make sure
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
  - **Tests:**
    - Unit (`flutter test`): payload decryption error paths;
      expected-nonce map TTL expiry; URL scheme handling; auth
      failure for tampered payloads.
    - Integration / E2E: wake notification with the app fully
      closed brings up a P2P receive that auto-accepts on a
      matching nonce and falls back to the prompt on a missing
      one; URL notification taps open a browser without
      launching the app where supported.
  - **Done when:** receiving a wake notification with the app
    fully closed brings the device into a state where it
    accepts a P2P connection from the sender without the user
    pressing *Accept*; receiving a link notification opens the
    URL in the browser without launching the app where
    supported.

- [ ] **Epic 14 — Polish and operability.** Cross-cutting work
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
  - **Tests:**
    - Widget (`flutter test`): master-toggle hides the
      device-group section and short-circuits cloud calls; the
      *Cloud unavailable* banner appears when cloud calls fail;
      debug page renders every field.
    - Unit: telemetry hook captures function name, status, and
      latency; debug-only logging is suppressed in release
      builds.
  - **Done when:** turning the master toggle off and relaunching
    produces a stock-LocalSend-like experience; airplane-mode
    shows the unavailable banner; the debug page renders real
    values.

- [ ] **Epic 15 — QA and release.** Final verification and
  shipping.

  - Manual QA checklist at
    `docs/development/cloud-sync-qa-checklist.md`. Cover: fresh
    install, pairing, wake-on-offline, URL fast-path (both
    modes), group destruction, account expiry. Reference from
    the README.
  - Confirm every per-epic unit, integration, and E2E suite is
    green in CI on the release branch. The pairing E2E (Epic
    11) and the wake-and-receive E2E (Epic 13) are the
    load-bearing ones for release readiness.
  - Release prep: update the top-level `README.md` and
    `docs-site/` with cloud-feature instructions and a new
    *Cloud Sync* docs page; bump `app/pubspec.yaml` version;
    add a `CHANGELOG.md` entry.
  - **Tests:** all suites added in earlier epics must be green
    in CI; the manual QA checklist must be fully ticked off.
    Block the release on any red test.
  - **Done when:** the manual QA checklist passes; CI is green
    on the release commit; release notes published.
