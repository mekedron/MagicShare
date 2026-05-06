# Desktop push notifications

**Status:** In progress (Epic 7 lays the foundation; Epics 13 + the
Linux/Windows REST follow-up complete it.)
**Last updated:** 2026-05-04

> Reference spec: [`cloud-sync-spec.md`](./cloud-sync-spec.md) §5.3
> Notifications. Implementation tracker:
> [`task-list.md`](./task-list.md).

## Platform support matrix

FlutterFire's official support varies per package — Linux is omitted
across the board, and Windows only ships native bindings for `firebase_core`,
`firebase_auth`, and `cloud_firestore`. The MagicShare runtime probes
this with `app/lib/util/native/cloud_platform.dart`.

| Platform | firebase_core | firebase_auth | cloud_firestore | cloud_functions | firebase_messaging |
|----------|:-------------:|:-------------:|:---------------:|:---------------:|:------------------:|
| Android  | yes | yes | yes | yes | yes |
| iOS      | yes | yes | yes | yes | yes |
| macOS    | yes | yes | yes | yes | yes |
| Windows  | yes (web shim) | yes (web shim) | yes (web shim) | no | no |
| Linux    | no | no | no | no | no |

The `flutter pub get` plugin registrants under
`app/{linux,windows}/flutter/` confirm what actually links: Linux gets
only `flutter_secure_storage_linux`; Windows additionally gets
`firebase_auth`, `cloud_firestore`, and `firebase_core`.

## Notification source per platform

- **Android** — `MagicShareFirebaseMessagingService` (Kotlin) is
  registered in `app/android/app/src/main/AndroidManifest.xml`. Wake and
  link FCM data messages flow through the Dart `firebase_messaging`
  plugin. A high-importance notification channel id
  (`magicshare_cloud_sync`) is declared via meta-data so Epic 13 can hook
  the channel without further manifest changes.
- **iOS** — `UIBackgroundModes: [remote-notification]` in
  `app/ios/Runner/Info.plist` lets silent data messages wake the app.
  The Push Notifications capability and the APNs key upload to the
  Firebase Console are required at deploy time; both are tracked as
  release blockers (see Epic 7 prerequisite carry-over below).
- **macOS** — `aps-environment` entitlement added to both
  `DebugProfile.entitlements` (`development`) and
  `Release.entitlements` (`production`). FCM uses the same APNs path as
  iOS.
- **Windows** — `firebase_messaging` has no Windows binding. Wake
  delivery on Windows is deferred to the Linux/Windows REST follow-up
  epic, which adds an HTTPS poller against `pollPendingWakes`.
- **Linux** — `firebase_messaging` and the rest of FlutterFire have no
  Linux binding. The `LinuxWakePollerService` provider scaffolds the
  30-second polling loop required by spec §5.3, but the actual transport
  (signed-callable HTTPS request to `pollPendingWakes`) is deferred to
  the same follow-up epic.

## Linux / Windows REST cloud client (follow-up epic)

The follow-up appended to `task-list.md` covers what's needed to make
Linux and Windows fully cloud-capable:

1. Anonymous Firebase auth via REST (signupNewUser → ID-token refresh
   loop, refresh token persisted in `flutter_secure_storage`).
2. Signed callable invocation against
   `https://europe-west1-magic-share-backend.cloudfunctions.net/<name>`.
3. Wire-format adapters that match the existing Cloud Functions JSON
   envelopes so the typed `CloudFunctionsClient` can swap its
   `HttpsCallableInvoker` for the REST one when the FlutterFire path
   isn't available.
4. Linux desktop notification surfacing via
   `flutter_local_notifications` once the inbox items arrive.

## Epic 13 dispatcher hook for Linux poller (Epic 16)

Epic 13 lands a stateless `CloudMessageDispatcher` plus a
`LocalNotificationsService` that the Linux poller can call once its
REST transport is in place. The integration shape Epic 16 should
adopt:

```dart
// Inside LinuxWakePollerService.pollOnce, after pollPendingWakes returns:
for (final item in pending.items) {
  final result = dispatcher.dispatch(
    <String, dynamic>{
      'type': item.type.name,
      if (item.encryptedPayload != null) 'payload': item.encryptedPayload!,
      if (item.plaintextPayload != null) ...{
        'url': item.plaintextPayload!.url,
        if (item.plaintextPayload!.title != null) 'title': item.plaintextPayload!.title!,
      },
    },
    groupKey: groupKey,
  );
  switch (result) {
    case WakeMessage():
      registry.register(result.nonce, expiry);
    case LinkMessage():
      await notifications.showLinkNotification(url: result.url, title: result.title);
    case CloudMessageError():
      // log and drop
  }
}
```

The dispatcher is identical to the foreground / background path, so
the poller doesn't need its own decoding logic — only the transport.

## Epic 7 prerequisite (Firebase Console rename)

The per-platform configs in `app/{android,ios,macos}` were patched to
the `com.magicshare.app` bundle identifier during Epic 2, but the
matching apps in the Firebase Console still carry the old upstream
LocalSend identifiers. Local development and CI both work today (the
emulator suite doesn't care about Console state), but production cloud
calls will fail until the Console rename + `flutterfire configure`
re-run lands. Treat as a release blocker for the first build that
exercises real cloud calls (Epics 11+).
