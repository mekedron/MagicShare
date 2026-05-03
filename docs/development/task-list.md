# MagicShare — Cloud Sync Implementation Checklist

**Status:** Draft
**Owner:** Product (Nikita)
**Last updated:** 2026-05-03

> Reference spec: [`cloud-sync-spec.md`](./cloud-sync-spec.md). Read it
> first if you need context on what is being built and why.

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
  Cloud Functions on PRs touching `firebase/functions/**`. Skip on
  docs-only changes.

- [ ] 6. Document the Firestore schema (`accounts`, `devices`,
  `joinTokens`, `inbox`) in `firebase/SCHEMA.md` and define matching
  TypeScript model types (`Account`, `Device`, `JoinToken`,
  `InboxItem`) in `firebase/functions/src/models.ts`.

- [ ] 7. Write Firestore security rules covering all collections:
  `accounts/{id}` and `accounts/{id}/devices/{*}` are readable and
  writable only by an authenticated user whose UID equals the account
  ID, or by Cloud Functions; `joinTokens/*` are written only by Cloud
  Functions and not directly readable by clients.

- [ ] 8. Add unit tests for the security rules using
  `@firebase/rules-unit-testing`. Cover happy path (own group reads),
  unauthorized read (cross-group), and direct write to `joinTokens`.
  Wire into CI.

- [ ] 9. Implement `createAccount` and `registerDevice` callable
  functions. `createAccount` is idempotent and creates `accounts/{uid}`
  if missing. `registerDevice` writes
  `accounts/{uid}/devices/{deviceId}` with the supplied `displayName`,
  `icon`, `platform`, `fcmToken`, and bumps `lastActiveAt`.

- [ ] 10. Implement device-management callables:
  `updateDevicePresence` (updates `lastSeenAt` and `presence`,
  rate-limited to one call per minute per device); `renameDevice` and
  `setDeviceIcon` (validate length and icon enum).

- [ ] 11. Implement device and account deletion callables.
  `removeDevice` deletes a device and, if it was the last one, the
  parent account. `deleteAccount` deletes the entire account and all
  device documents in one transaction.

- [ ] 12. Implement pairing token callables. `createJoinToken`
  generates a 5 min one-time token in `joinTokens/{tokenId}` and
  returns it for QR display. `previewJoinToken` returns the target
  account ID and a public-safe device list (display name, icon,
  platform — no FCM tokens) and rejects expired or consumed tokens.

- [ ] 13. Implement the `joinNetwork` callable function. Verifies the
  token, marks it consumed, copies the device into the target
  account, deletes the device from the caller's old account, and
  deletes the old account if it is now empty. All in a Firestore
  transaction. Does not deliver the shared key — that is a separate
  LAN step.

- [ ] 14. Implement scheduled maintenance functions:
  `cleanupExpiredJoinTokens` (daily; deletes tokens past
  `expiresAt`), `cleanupInactiveAccounts` (weekly; deletes accounts
  whose `lastActiveAt` is older than 90 days plus all child devices),
  and stale-presence marking (every ~5 min, or via Firestore TTL where
  simpler; marks devices offline whose `lastSeenAt` is older than 5
  min).

- [ ] 15. Implement the `sendWake` callable function and extract a
  shared `assertSameAccount(callerUid, targetDeviceId)` authorization
  helper used by every function that touches another device.
  `sendWake` verifies same-account, looks up the target's FCM token,
  sends a data-only FCM message, and writes an `inbox` item for Linux
  targets.

- [ ] 16. Implement the `sendLinkNotification` callable function with
  two modes: `plaintext` (FCM `notification` message; verify the URL
  has an `http`/`https` scheme) and `encrypted` (data-only FCM message
  carrying an opaque blob).

- [ ] 17. Add a soft rate limit (e.g., 30 sends per device per hour)
  to `sendWake` and `sendLinkNotification`. Reject excess calls with a
  clear error code.

- [ ] 18. Add structured logging across all callables: calling UID,
  operation, success/error, latency. No PII.

- [ ] 19. Implement the `pollPendingWakes` callable function for Linux
  clients. Returns and atomically consumes the calling device's
  `inbox` items. Items expire after 5 min.

- [ ] 20. Add Firebase to the Flutter app. Add `firebase_core`,
  `firebase_auth`, `cloud_firestore`, `cloud_functions`, and
  `firebase_messaging` to `app/pubspec.yaml`. Initialize Firebase in
  `app/lib/main.dart` before `runApp`, behind a feature flag
  (`cloudSyncEnabled`, default `true`). Verify the app still builds on
  Android and macOS.

- [ ] 21. Implement an anonymous sign-in service in
  `app/lib/provider/cloud/auth_provider.dart` (refena). Signs in on
  first access; exposes the current `User`. Same UID across app
  restarts.

- [ ] 22. Define `dart_mappable` models for cloud entities
  (`CloudAccount`, `CloudDevice`, `CloudDeviceIcon` enum,
  `JoinTokenPreview`, `WakeRequest`, `LinkRequest`) and implement a
  typed Cloud Functions client in
  `app/lib/provider/cloud/functions_client.dart` with a wrapper for
  every callable using these models.

- [ ] 23. Implement FCM token retrieval & refresh in
  `app/lib/provider/cloud/fcm_provider.dart`. On startup, fetch the
  token. Subscribe to `onTokenRefresh` and post updates to
  `registerDevice`. Handle iOS APNS-token availability quirks.

- [ ] 24. Configure mobile platforms for push notifications. iOS:
  enable Push Notifications capability in `Runner.xcodeproj`, add
  background mode `remote-notification`, document APNs key upload in
  `docs/development/ios-push-setup.md`. Android: declare a default
  high-priority data channel in `AndroidManifest.xml`, add a stub
  `FirebaseMessagingService` for background data delivery.

- [ ] 25. Implement the desktop notification source. Wire FCM via the
  Firebase Web Messaging SDK on Windows and macOS. On Linux,
  implement the 30 s polling loop against `pollPendingWakes`. Document
  platform decisions in `docs/development/desktop-push.md`.

- [ ] 26. Implement the AccountRepository and DeviceIdentityService.
  AccountRepository (in `app/lib/provider/cloud/account_repository.dart`)
  knows the current account ID, current device ID, and list of group
  devices, and watches Firestore for live updates. DeviceIdentityService
  returns a stable device ID (persisted in `flutter_secure_storage`),
  the platform, and a default icon based on `Platform.isXxx`.

- [ ] 27. Implement the first-launch bootstrap flow: anonymous
  sign-in, then `createAccount`, then `registerDevice` with this
  device's data. Idempotent.

- [ ] 28. Implement the device presence heartbeat. Calls
  `updateDevicePresence` on app foreground and once every 4 minutes
  while the app stays foregrounded. Marks self offline on app
  backgrounding (best-effort).

- [ ] 29. Implement group key generation, storage, and AES-GCM (or
  chosen equivalent) encrypt/decrypt helpers. On first launch
  (account-creation path), generate a random 256-bit key and store it
  in `flutter_secure_storage`. Cleared on `deleteAccount`. Round-trip
  tests with known vectors.

- [ ] 30. Extend the LocalSend upload-request payload with an optional
  `wakeSessionId` string field. Update both Flutter and Rust sides if
  both touch the upload-request shape. Stock LocalSend clients must
  still interoperate (forward compatibility).

- [ ] 31. Add a new "Device group" section at the very top of
  `app/lib/pages/tabs/settings_tab.dart`, including the device list
  widget. Each tile shows: icon, display name, *This device* badge
  for the current device, online/offline dot. Sort: current device
  first, then online by name, then offline by name.

- [ ] 32. Implement device-detail bottom sheets. Current-device sheet
  actions: rename, change icon, *Leave or destroy this group*.
  Other-device sheet actions: rename, change icon, *Remove this
  device from group* (with confirmation dialog).

- [ ] 33. Implement the icon picker dialog. Grid of supported device
  icons (laptop, desktop, phone, tablet, server, headless, generic).
  Selection persists via `setDeviceIcon` and re-renders.

- [ ] 34. Add the *Delete this device group* button below the device
  list. Red, with confirmation. Calls `deleteAccount`. On success,
  the app re-bootstraps a fresh account.

- [ ] 35. Add localization keys for all visible strings introduced in
  the device group section, following the existing LocalSend
  localization workflow.

- [ ] 36. Implement the *Invite a device* button + QR code dialog.
  Calls `createJoinToken`, renders the result as a `pretty_qr_code`
  QR. Shows a countdown to expiry. Includes a copy-as-text fallback.
  The QR encodes the join token, the issuing device's LAN address,
  and a temporary public key.

- [ ] 37. Implement the *Join an existing group* flow: button, QR
  scanner page (e.g., `mobile_scanner`) with camera permission
  handling, and the pair preview dialog (calls `previewJoinToken` and
  renders the device list for confirmation). After a successful scan,
  parse the token, LAN address, and temporary public key. If the LAN
  address is not reachable, show the *"Both devices need to be on the
  same Wi-Fi to pair"* error and abort.

- [ ] 38. Implement the LAN-side key exchange and post-pair flow. The
  issuing device opens a one-shot LAN endpoint protected by the
  temporary keypair from the QR. The joining device, after
  `joinNetwork` succeeds, connects to that endpoint, authenticates,
  and receives the group's shared key. After success, refresh the
  AccountRepository, replace the locally stored shared key, clear the
  old key, and show a success snackbar. Tear the endpoint down on
  success or after a 5 min timeout.

- [ ] 39. Implement a desktop alternative to QR scanning: a
  paste-token text field that accepts the same payload as the QR.

- [ ] 40. Modify `app/lib/pages/tabs/send_tab.dart` to merge
  LAN-discovered devices with `AccountRepository` devices (devices
  matching by ID are shown once) and add online/offline status dots
  to each tile. Online = LAN-discoverable AND foregrounded recently.

- [ ] 41. Implement the wake flow for offline network devices. Call
  `sendWake` with an encrypted payload describing the sender's IP,
  port, and a session nonce. Show a *Waking up \[device\]…* indicator.
  Wait up to 60 s. On timeout, show an error.

- [ ] 42. Implement the URL fast-path send and the *Encrypt link
  notifications* setting. When the payload is a single URL and the
  target is a network device, skip the P2P transfer and call
  `sendLinkNotification` in the mode chosen by the setting. Setting
  lives under General; default off; persisted in the existing
  settings store; localized.

- [ ] 43. Add send-tab UX states for *waking up*, *retrying*, and
  *error*. Error copy: *"Device did not respond. It might be
  offline."* Includes a retry button.

- [ ] 44. Implement the FCM data-message handler for both background
  (`FirebaseMessaging.onBackgroundMessage` with a top-level function)
  and foreground (`FirebaseMessaging.onMessage` listener). Both
  decrypt the payload and dispatch it to the same internal handler
  via a platform-channel signal.

- [ ] 45. Implement the URL notification tap handler. Tapping a
  visible link notification opens the URL in the system browser via
  `url_launcher`. Where the OS allows (Android intent filter, iOS
  deep link), open without launching the app.

- [ ] 46. Implement the wake → P2P bridge. On receipt of a wake
  notification, ensure the LocalSend HTTP server is running. Read the
  wake session nonce from the decrypted payload and add it to a
  short-lived in-memory expected-nonce map (TTL ~2 min). Match
  incoming upload-requests against this map; auto-accept on hit, fall
  back to the standard prompt on miss.

- [ ] 47. Implement the notification permission request flow. iOS:
  request on first cloud-feature usage. Android 13+: request
  `POST_NOTIFICATIONS`. Show a non-blocking explanation if denied.

- [ ] 48. Implement desktop notification handling via
  `flutter_local_notifications` or platform channels. Source from FCM
  on Windows/macOS, from the polling loop on Linux. Tapping a URL
  notification opens the URL in the default browser. Tapping a wake
  notification brings the app to focus and triggers the wake flow.

- [ ] 49. Add the *Cloud features* master toggle in the General
  settings section and the privacy copy paragraph below the
  device-group section. When the toggle is off, the device-group
  section is hidden, FCM is uninitialized, and no network calls
  happen. The privacy copy explains what data leaves the device
  (account ID, device ID, name, icon, FCM token, presence timestamps,
  encrypted wake payloads) and mentions both link-mode paths.
  Localized.

- [ ] 50. Add a telemetry hook that wraps every cloud function call:
  function name, success/error, latency. No PII. Debug builds print;
  release builds suppress.

- [ ] 51. Handle offline / no-internet behavior gracefully. Cloud
  calls fail without blocking the UI. The device-group section shows
  a *Cloud unavailable* banner instead of an endless spinner.

- [ ] 52. Add an account-state debug page under the existing debug
  menu. Dumps account ID, device ID, FCM token (truncated),
  shared-key fingerprint, and last-presence timestamp.

- [ ] 53. Write a manual QA checklist at
  `docs/development/cloud-sync-qa-checklist.md`. Cover: fresh
  install, pairing, wake-on-offline, URL fast-path, group
  destruction, account expiry. Reference from the README.

- [ ] 54. Write an end-to-end automated test for the pairing happy
  path (`flutter_test` + Firebase emulator). Two simulated
  installations pair; one removes the other.

- [ ] 55. Write an end-to-end automated test for wake-and-receive.
  One simulated device sends a wake to a paused second device; the
  second device opens its receive window.

- [ ] 56. Release prep: update the top-level `README.md` and
  `docs-site/` with cloud-feature build/run instructions and a new
  *Cloud Sync* docs page; bump `app/pubspec.yaml` version; add a
  `CHANGELOG.md` entry summarizing cloud features.
