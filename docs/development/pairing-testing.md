# Pairing testing recipes

> Reference spec: [`cloud-sync-spec.md`](./cloud-sync-spec.md) §5.3
> Pairing. Local emulator setup:
> [`firebase-local.md`](./firebase-local.md).

This page covers how to exercise the Epic 11 pairing flow during
development. The flow has two halves and they have very different
testing constraints:

1. **Cloud half** — `createJoinToken` → `previewJoinToken` →
   `joinNetwork` → custom-token re-auth. Runs through the Firebase
   emulator suite. Trivially testable on any combination of devices.
2. **LAN handshake half** — joining device opens a TCP connection to
   the issuing device's ephemeral listener and ECDH-exchanges the
   group key. Requires the joiner to actually have a network route
   to the issuer's advertised IP. **This is where most real-world
   testing pain lives.**

The recipes below assume you already have the Firebase emulator
running (`cd firebase/functions && npm run dev`) and both apps
launched with `--dart-define=USE_FIREBASE_EMULATOR=true`.

---

## Recipe 1: macOS ↔ macOS (cloud-only smoke test)

Easiest way to validate the cloud half end-to-end without thinking
about LAN routing.

```bash
# Two macOS instances of the app on the same machine
cd app
flutter run -d macos --debug --no-pub --dart-define=USE_FIREBASE_EMULATOR=true
# In a second terminal, with a different release dir or `--release`
# variant; the simpler path is to use macOS + a real / virtual
# Android device since the macOS app dedupes by bundle id.
```

In practice macOS-to-macOS on the same machine is awkward (single
bundle id), so most local testing pairs **macOS ↔ Android emulator**.

---

## Recipe 2: macOS as issuer, Android emulator as joiner (works out of the box)

This is the recommended dev loop. The macOS app advertises its real
Wi-Fi IP (e.g. `192.168.1.x`) in the QR. The Android emulator
reaches it via qemu's user-mode NAT — qemu forwards the connection
to the host, the host loops back to itself.

```bash
# macOS app
cd app
flutter run -d macos --debug --no-pub --dart-define=USE_FIREBASE_EMULATOR=true

# Android emulator app — relies on adb reverse for the emulator
# subprocess to reach the host's emulator suite at "localhost"
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:5001 tcp:5001
flutter run -d emulator-5554 --debug --no-pub \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Test flow: tap *Invite a device* on macOS → scan QR (or type the
code) on the Android emulator → confirm. Both ends end up holding
the same group key.

---

## Recipe 3: Android emulator as issuer, macOS as joiner (needs the override)

This direction does **not** work out of the box. The Android
emulator's only IP is qemu's NAT-internal `10.0.2.15`, which no
real-LAN host can route to. The QR generated on the emulator
points at `10.0.2.15:<random-port>` — the Mac's `Socket.connect`
to that address gets *no route to host* every time.

The fix: bridge the emulator's pairing port to the host with
`adb forward`, then use the **debug-only override knobs** to make
the QR point at `127.0.0.1:<bridged-port>` instead.

```bash
# 1. Pick a stable port and bridge it from the host into the emulator.
adb forward tcp:51820 tcp:51820

# 2. Relaunch the emulator app with the LAN host + port overrides.
cd app
flutter run -d emulator-5554 --debug --no-pub \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 \
  --dart-define=CLOUD_PAIRING_LAN_HOST=127.0.0.1 \
  --dart-define=CLOUD_PAIRING_LAN_PORT=51820

# 3. macOS app stays as-is — it just sees 127.0.0.1:51820 in the
#    QR and connects there. adb forwards the connection into the
#    emulator's pairing server.
flutter run -d macos --debug --no-pub --dart-define=USE_FIREBASE_EMULATOR=true
```

Test flow: tap *Invite a device* on the emulator → the QR shows
`127.0.0.1:51820` → on macOS, scan or type the code → confirm. The
macOS LAN client connects to `127.0.0.1:51820`, adb forwards into
the emulator, the pairing server runs the ECDH exchange, both
ends end up holding the same group key.

### What the dart-define knobs do

| Knob                            | Effect                                                                 |
|---------------------------------|------------------------------------------------------------------------|
| `CLOUD_PAIRING_LAN_HOST=<ip>`   | Overrides the IP put in the QR / manual code. Default: auto-detected primary local IP. |
| `CLOUD_PAIRING_LAN_PORT=<n>`    | Pins the LAN handshake server's bind port. Default: `0` (OS-chosen).   |

Both are only consulted by the issuing-side dialog. Defaulting to
empty / 0 means production builds and unspecified launches behave
identically — no production drift.

---

## Recipe 4: macOS ↔ real Android phone on the same Wi-Fi (closest to production)

The way actual users will pair. No dart-defines needed.

```bash
# macOS app
cd app
flutter run -d macos --debug --no-pub --dart-define=USE_FIREBASE_EMULATOR=true

# Real Android phone connected via USB/Wi-Fi adb. Replace the device
# id with what `flutter devices` shows for your phone.
adb -s <phone-serial> reverse tcp:8080 tcp:8080
adb -s <phone-serial> reverse tcp:9099 tcp:9099
adb -s <phone-serial> reverse tcp:5001 tcp:5001
flutter run -d <phone-serial> --debug --no-pub \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Note: the `10.0.2.2` host doesn't apply to real phones — that's
qemu-emulator-only. On a real phone, replace it with your Mac's
LAN IP (e.g. `192.168.101.129`). The phone needs network access to
your Mac for the Firebase emulator suite, and obviously both
devices must be on the same Wi-Fi for the LAN handshake to work
without `adb forward`.

---

## Diagnosing pairing failures

| Symptom                                                            | Likely cause                                                                                                                                                                                                              |
|--------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| *"Both devices need to be on the same Wi-Fi to pair"*              | The joiner's TCP probe to the IP in the QR timed out. Either devices really aren't on the same LAN (most common with the emulator-as-issuer trap from Recipe 3), or the issuer's `HttpServer.bind` raced the joiner's probe. |
| *"Something went wrong while pairing"* on the preview dialog       | Almost always a cloud auth issue. Look for `unauthenticated` in the Functions emulator log. Most common cause: joiner isn't anonymously signed in yet. Fixed in `695e0a03`; if you see it again, capture logs.            |
| Preview shows but *Join group* hangs / errors                      | Either `joinNetwork` failed (check Firestore rules + Functions log) or the LAN handshake failed post-join. Distinguish by looking at `[CloudJoin]` logs in the joiner's Flutter output.                                   |
| Issuer shows the success snackbar but joiner sits at "Joining…"    | LAN handshake succeeded server-side but the joiner failed to install the group key. Check the joiner's Flutter log for `[GroupKeyService]`.                                                                              |
| The whole pairing UI flickers / fails to render                    | Something in `_startSession` threw. The `[InviteDeviceDialog]` log line will have the stack.                                                                                                                              |

---

## Cleanup after an emulator pairing test

The Firebase emulator is in-memory and resets on restart. The
Android emulator's `adb forward` and `adb reverse` mappings persist
across app relaunches but die when the emulator process exits. To
reset everything between sessions:

```bash
adb reverse --remove-all
adb forward --remove-all
# Then restart the Firebase emulator if you want a clean Firestore.
```

The `CLOUD_PAIRING_LAN_*` overrides are read at app startup, so
relaunching the Flutter app without those flags switches the issuer
back to the auto-detected IP. Drop the dart-defines from your launch
command when you're done with Recipe 3.
