# Push notifications setup

**Audience:** Engineers setting up the cloud-sync push pipeline on a new
Apple Developer account, a new Firebase project, or a fresh dev machine.

Push notifications wake a backgrounded or killed receiver when the
sender taps a paired device in the Send tab. This page documents every
step from "nothing exists" to "the iPhone buzzes."

---

## Architecture in one diagram

```
sender (Send tab → tap device)
       │
       │  callable HTTPS, authenticated as user
       ▼
notifyTransferIntent  ─ runs in either ─►  Cloud Functions runtime (prod)
(firebase/functions/                       or Firebase emulator (local)
 src/transfer-notify.ts)
       │
       │  messaging.send(...) — always to REAL FCM (no FCM emulator exists)
       ▼
Firebase Cloud Messaging
       │
       ├── Android device ────────────►  Google Play Services → app
       │
       └── iOS device ► APNs (sandbox for Debug, production for Release)
                                                              │
                                                              ▼
                                              iPhone / iPad lock-screen banner
```

The receiver client (`firebase_messaging` plugin) registers an APNs/FCM
token at startup, writes it to its device document in Firestore
(`accounts/{uid}/devices/{deviceId}.fcmToken`), and listens for both
foreground and background messages.

The function payload is the same for both platforms — the OS-specific
fields under `apns` and `android` exist so the notification surfaces
visibly without app code running.

---

## One-time setup — Apple side

### 1. Apple Developer Portal: register App IDs

The app needs two App IDs registered against your team (currently
`A4HHRH8Y9M`):

- `com.magicshare.app` — Runner (iOS + macOS)
- `com.magicshare.app.ShareExtension` — Share extension (iOS + macOS)

Both need these capabilities enabled on the App ID:

- **Push Notifications**
- **App Groups** (group key: `group.com.magicshare.app` for iOS,
  `<team>.magicshare.shared_group` for macOS via
  `$(AppIdentifierPrefix)magicshare.shared_group`)
- **Keychain Sharing** (for Firebase Auth on macOS — see
  `app/macos/Runner/RunnerDebug.entitlements`)

Easiest way: open `app/ios/Runner.xcworkspace` or
`app/macos/Runner.xcworkspace` in Xcode, select Runner → Signing &
Capabilities, ensure the team is set, and click **Try Again** if Xcode
shows a signing warning. Xcode will register everything for you.

For macOS the first build also needs `-allowProvisioningUpdates`, which
`flutter run -d macos` does not pass. Run this once manually to create
the Mac provisioning profile:

```bash
cd app/macos
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Debug -allowProvisioningUpdates \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build build
```

After that the profile is cached locally and `flutter run -d macos`
works.

### 2. Apple Developer Portal: APNs Auth Key (.p8)

**Use an Auth Key, not a certificate.** A single `.p8` key handles
both sandbox (Debug `aps-environment=development`) and production
(Release `aps-environment=production`), and it doesn't expire.

1. https://developer.apple.com/account/resources/authkeys/list
2. Click **+** → enable **Apple Push Notifications service (APNs)** →
   Continue
3. Name it (e.g. "MagicShare APNs") → Register
4. **Download** the `AuthKey_XXXXXXXXXX.p8` — this is the only chance
   to download it. Store it in 1Password or similar.
5. Copy the **Key ID** (the `XXXXXXXXXX` part).
6. Note your **Team ID** (`A4HHRH8Y9M`).

### 3. iOS Xcode capabilities

Already wired up in this repo, but if you're setting up from scratch
on a clone, verify the Runner target has:

- **Push Notifications** capability
- **Background Modes** with **Remote notifications** checked
- `aps-environment` in entitlements: `development` for Debug
  (`Runner/DebugProfile.entitlements`), `development` or `production`
  for Release (`Runner/Runner.entitlements`)

Free-tier Apple Developer accounts cannot use the `aps-environment`
entitlement at all. Push testing on a physical iPhone requires a paid
Apple Developer Program membership.

---

## One-time setup — Firebase side

### 4. Upload the APNs key to Firebase Console

This is the step that bridges FCM to Apple's push service. Without it,
iOS sends fail with FCM error code `THIRD_PARTY_AUTH_ERROR`
(misleadingly worded as "Request is missing required authentication
credential").

1. https://console.firebase.google.com/project/magic-share-backend/settings/cloudmessaging
2. Under **Apple app configuration** → find the iOS app row → under
   **APNs Authentication Key**, click **Upload**
3. Upload the `.p8` file
4. Paste the **Key ID** (from Apple Developer Portal step 2.5)
5. Paste the **Team ID** (`A4HHRH8Y9M`)
6. Save

One upload covers both Debug and Release builds.

### 5. Generate a service account JSON for local development

The Firebase Functions **emulator** has no FCM emulator — every
`messaging.send()` reaches real FCM. The emulator's Functions runtime
also refuses to use Firebase CLI login credentials for production
services. You need a real service account JSON locally.

1. https://console.firebase.google.com/project/magic-share-backend/settings/serviceaccounts/adminsdk
2. **Generate new private key** → confirm → downloads
   `magic-share-backend-firebase-adminsdk-XXXXX.json`
3. Move it to the gitignored slot:
   ```bash
   mv ~/Downloads/magic-share-backend-firebase-adminsdk-*.json \
      <repo>/firebase/.local-credentials/service-account.json
   ```
4. The `firebase/.local-credentials/` directory is gitignored — never
   commit this file.

Alternative if you prefer Google Cloud Application Default Credentials
(no JSON on disk, cleaner for shared machines):

```bash
brew install --cask google-cloud-sdk
gcloud auth application-default login
gcloud auth application-default set-quota-project magic-share-backend
```

`run-dev.sh` will find ADC at the default location automatically.

---

## Running locally

`./run-dev.sh` does the credential plumbing automatically. The order it
searches:

1. `$GOOGLE_APPLICATION_CREDENTIALS` if exported in the parent shell
   (explicit override).
2. `firebase/.local-credentials/service-account.json` (project-local).
3. `~/.config/gcloud/application_default_credentials.json` (gcloud
   ADC).

If none are found, the script aborts before launching the emulator and
prints copy-paste setup instructions. When one is found, the chosen
path is printed on stdout before the emulator window opens:

```
Firebase Admin SDK credentials: <path> (<source>)
```

### Why the function calls a REST sender locally

`firebase/functions/src/admin.ts` returns
`fcm-rest-sender.ts`'s `restMessagingSender` instead of
`firebase-admin`'s `messaging()` when `FUNCTIONS_EMULATOR=true`. The
Firebase CLI's emulator runtime hijacks `firebase-admin`'s credential
resolution and refuses to authenticate to real FCM. The REST sender
signs its own JWT from the service-account JSON and POSTs directly to
`https://fcm.googleapis.com/v1/projects/.../messages:send`, bypassing
the emulator stub.

In deployed Cloud Functions (`FUNCTIONS_EMULATOR` unset), `admin.ts`
returns the standard `firebase-admin` Messaging client, which
authenticates via the metadata server — no JSON anywhere.

---

## Testing the pipeline

### Verify the receiver has an FCM token in Firestore

```bash
curl -s -H 'Authorization: Bearer owner' \
  "http://127.0.0.1:8080/v1/projects/magic-share-backend/databases/(default)/documents/accounts/<UID>/devices" \
  | python3 -c "
import json, sys
for d in json.load(sys.stdin).get('documents', []):
    f = d.get('fields', {})
    print(f.get('platform',{}).get('stringValue','?'),
          'tokenLen=', len(f.get('fcmToken',{}).get('stringValue','')))
"
```

A token length of 142+ (iOS) or ~163 (Android) is healthy. `0` means
the bootstrap registered the device before FCM finished acquiring its
token; see [Troubleshooting](#troubleshooting).

### Trigger a push end-to-end

From a second device on the same account (typically macOS running
`./run-dev.sh macos`), open Send tab → tap the iPhone → drop a file.
The iPhone should banner with:

> **MagicShare** — *{your-mac-alias} wants to send you files. Tap to
> open MagicShare.*

### Trigger a push from Firebase Console (no second device)

If you have the iPhone's FCM token in hand, send a test push directly:

1. Real Firebase Console → Engage → Cloud Messaging → **Send your
   first message** (or "New campaign" → Notifications).
2. **Send test message** → paste the iPhone's FCM token → Test.

### Logs to grep

```bash
# Sender side (macOS) — did the function call fire and succeed?
grep "notifyTransferIntent" logs/latest-macos.log

# Cloud function — did messaging.send accept the message?
grep -E '"op":"notifyTransferIntent","status"' logs/latest-firebase.log

# Receiver side (iPhone) — did the FCM listener see the message?
grep -E "FcmReady|Foreground FCM|Notification tap" logs/latest-ios.log
```

A healthy send shows `"status":"ok"` with latency 200–500ms (real FCM
round-trip). 20ms with `status:"ok"` means the function bailed early
because `fcmToken` was missing (see Troubleshooting).

---

## Troubleshooting

### `FCM REST send failed: HTTP 401 — THIRD_PARTY_AUTH_ERROR`

APNs Auth Key not uploaded to Firebase Console, or uploaded to a
different Firebase project. The error string says "missing OAuth 2
access token" but the `errorCode` is `THIRD_PARTY_AUTH_ERROR`, which
means *third-party (Apple's APNs) auth is missing*, not our auth.

Fix: [Step 4](#4-upload-the-apns-key-to-firebase-console).

Android pushes will still work in this state because they don't go
through APNs — useful smoke test for ruling in/out APNs as the cause.

### `"status":"ok"` with latency under 50ms, no push arrives

The function bailed out of the FCM call because `decision.target.fcmToken`
was empty. Look up the target's device doc in Firestore (see
[verify FCM token](#verify-the-receiver-has-an-fcm-token-in-firestore)).
If `tokenLen=0`, the receiver's bootstrap registered the device before
FCM finished acquiring its token. `cloud_bootstrap_service.dart`
re-uploads the token after BootstrapDone, but only if the FCM stream
emits a `FcmTokenAvailable` after that point.

Workaround: hot-restart the receiver app (capital R in the
`flutter run` terminal). The new bootstrap will see FCM already ready
and register with a real token.

### `Skipping notifyTransferIntent ... session has no stableTargetId`

The sender sees the target as a pure LAN peer, not a paired group
device. Usually means the LAN entry's cert hash doesn't match any
cloud-registered device's `fingerprint` field.

Check the merge inputs at runtime: enable fine-level logging on
`MergeNetworkDevices` to see `cloud[...] fp=...` and
`http=...:<port>/<certHash>...` lines. Cert hash mismatch is the
common case — either the receiver re-minted its TLS cert (clearing
emulator data does this) and Firestore is stale, or the LAN-discovered
device announces a different cert than the one bound to the cloud row.

### `Application Default Credentials detected` in firebase log

Cosmetic warning from the Firebase CLI. It's printed any time
`GOOGLE_APPLICATION_CREDENTIALS` is set — it does not mean credentials
are misconfigured.

### Push works on Android but not iOS

99% certain it's the APNs Auth Key step. Android skips APNs entirely.

### `Lost connection to device.` in iOS log

That's `flutter run`'s WebSocket dropping — has nothing to do with
push. Re-run `./run-dev.sh ios`.

### Free-tier Apple account: `aps-environment` is not supported

A free Apple Developer account cannot synthesize an APNs provisioning
profile. Either:

- Upgrade to the paid Apple Developer Program ($99/yr), or
- Comment `aps-environment` out of `Runner/DebugProfile.entitlements`
  to do non-push iOS development. Push will only work in
  Release/Profile builds, which the free tier can't sign either, so
  this effectively disables iOS push for that developer.

---

## Production deployment

When you eventually run `firebase deploy --only functions`:

- `FUNCTIONS_EMULATOR` is unset on Google's runtime → `admin.ts`
  switches back to `firebase-admin`'s `messaging()`.
- Credentials come from the metadata server — no service-account JSON
  in the deployed bundle.
- `firebase/.local-credentials/` is gitignored and is not part of the
  function source; it never leaves the dev machine.
- For App Store iOS builds with `aps-environment=production`, the same
  `.p8` key handles production APNs — no additional Firebase Console
  upload needed.

If you ever rotate the service-account JSON: revoke the old key in
Firebase Console → Project Settings → Service Accounts → Manage all
service-account keys, generate a new one, replace the file at
`firebase/.local-credentials/service-account.json`, and restart the
emulator via `./run-dev.sh firebase`.
