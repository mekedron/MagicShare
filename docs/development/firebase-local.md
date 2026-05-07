# Firebase local development

> Reference spec: [`cloud-sync-spec.md`](./cloud-sync-spec.md). Task list:
> [`task-list.md`](./task-list.md). Pairing-flow specific testing
> recipes (including the Android-emulator-as-issuer workaround):
> [`pairing-testing.md`](./pairing-testing.md).

This page explains how to run the MagicShare Firebase backend locally.
Everything in this guide runs against the **Firebase emulator suite** —
no real cloud project is touched, no credentials are required, and you
can iterate on Cloud Functions and Firestore rules without deploying.

The real cloud project, `magic-share-backend`, is only used for
deployments and the per-platform `flutterfire configure` step that
produces `app/lib/firebase_options.dart`.

---

## One-time setup

You need three things on your machine:

| Tool          | Why                                              |
|---------------|--------------------------------------------------|
| Node 20       | Cloud Functions runtime + dev tools.             |
| Java 17+      | Required by the Firestore emulator.              |
| Firebase CLI  | `npm i -g firebase-tools` or `brew install firebase-cli`. |

Then, install Cloud Functions deps:

```bash
cd firebase/functions
npm install
```

Authenticate the Firebase CLI once (only needed for deploys, not for the
emulator):

```bash
firebase login
```

If you use multiple Firebase accounts, switch with `firebase login:list`
and `firebase login:use`.

---

## Daily commands

From `firebase/functions/`:

```bash
npm run dev           # alias for: firebase --project=magic-share-backend emulators:start
npm test              # vitest run (Cloud Functions unit tests)
npm run lint          # eslint
npm run build         # tsc → lib/
npm run deploy        # firebase deploy --only functions (needs auth)
```

`npm run dev` starts the full emulator suite. Equivalent to running
`firebase emulators:start` inside `firebase/`.

---

## What the emulator runs

When `npm run dev` is up, the following endpoints are reachable:

| Service              | Port | Notes                                                    |
|----------------------|------|----------------------------------------------------------|
| Auth emulator        | 9099 | Anonymous + email/password.                              |
| Firestore emulator   | 8080 | Pulls rules from `firebase/firestore.rules`.             |
| Cloud Functions      | 5001 | Triggers from `firebase/functions/lib/index.js`.         |
| Emulator UI          | 4000 | Browse Firestore, view Function logs, replay invocations.|

Open [http://127.0.0.1:4000](http://127.0.0.1:4000) for the unified UI — fastest way to
inspect data, logs, and triggered functions.

FCM has no fully featured emulator; for local push delivery you can stub
the messaging channel from the Flutter side (see Epic 7 in
[`task-list.md`](./task-list.md)).

---

## Pointing the Flutter app at the emulator

There is no browser build — local testing of cloud-sync code paths
runs the app on a native target (Android emulator, iOS simulator,
macOS / Windows / Linux desktop) wired up to the local emulator suite.
Once Epic 7 lands the Firebase initialization path, the app will read
the `USE_FIREBASE_EMULATOR` `--dart-define` flag and route through
`localhost` instead of the real cloud:

```bash
cd app
flutter run -d <device> --dart-define=USE_FIREBASE_EMULATOR=true
```

Pick the device from `flutter devices`. Until Epic 7 ships, this flag
is documented but not yet wired up.

---

## Logs and persistence

`npm run dev` persists emulator state by default. The script passes
`--import=../.emulator-data --export-on-exit=../.emulator-data`, so the
Auth users + Firestore documents you create during a session are
written to `firebase/.emulator-data/` when you Ctrl+C the emulator and
loaded back on the next start. This keeps a paired device group alive
across emulator restarts, so you don't have to re-pair every time.

`firebase/.emulator-data/` is ignored by `firebase/.gitignore`.

Caveats:

- **Graceful shutdown only.** `--export-on-exit` runs on SIGINT
  (Ctrl+C). A hard kill (`kill -9`, closing the Terminal window before
  the export finishes) will skip the snapshot.
- **Wiping the slate.** When you *want* a clean cloud (e.g. to verify
  the stale-session recovery banner, or to switch Firebase projects),
  delete the snapshot:
  ```bash
  rm -rf firebase/.emulator-data
  ```
  The next `npm run dev` will start fresh and create the directory on
  the next graceful exit.
- **First run.** Before the directory exists, the CLI logs a one-time
  warning that the import path is missing, then proceeds normally.

Cloud Functions logs print to the terminal running `npm run dev` and are
also surfaced under the *Logs* tab in the emulator UI. Structured logs
emitted via `firebase-functions/logger` are searchable from there.

---

## Common gotchas

- **Port already in use.** Another emulator instance is still running.
  `lsof -ti :4000 | xargs kill -9` and retry, or change the port in
  `firebase/firebase.json` under `emulators.<service>.port`.
- **"Project not found".** You forgot the project flag. Either run
  `firebase use magic-share-backend` once in `firebase/` or pass
  `--project=magic-share-backend` explicitly. The npm scripts already
  pass it.
- **Functions emulator can't find code.** Run `npm run build` in
  `firebase/functions/` first — the emulator reads compiled JS from
  `lib/`.
- **Firestore rules error in the emulator UI.** Edit
  `firebase/firestore.rules`, save; the emulator hot-reloads.

---

## Don't commit credentials

`firebase/.gitignore` and `firebase/functions/.gitignore` block
`*-firebase-adminsdk-*.json`, `service-account*.json`, and
`*.local`. Never check in real cloud credentials. The
[deploy story (Epic 15)](./task-list.md) uses GitHub Actions secrets,
not files in the repo.
