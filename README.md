# MagicShare

> Send a file or open a link on any device you own — even when it's offline,
> on a different platform, or signed into a different account.

MagicShare is a fork of [LocalSend](https://github.com/localsend/localsend)
that adds **cloud-assisted device wake-up** and a **friction-free UX** on top
of LocalSend's proven peer-to-peer transfer protocol.

LocalSend already solves the hard part: secure, encrypted, cross-platform
transfers without third-party servers. MagicShare keeps all of that and fixes
the workflow problems that show up when you actually use it daily across many
devices.

---

## The Problem

If you regularly hop between several devices — phones, tablets, laptops on
different operating systems and different accounts — there is no good way to
just *get a thing onto another device*.

Today the options are all bad:

- **Email yourself.** Slow, leaves a trail, breaks for big files.
- **Custom QR code generators.** Works for tiny links, painful for long URLs,
  useless for files.
- **Messenger / chat apps.** Pollutes chat history, file size limits, requires
  accounts on both ends.
- **AirDrop / Quick Share / etc.** Only works inside one ecosystem.
- **LocalSend.** Solves the transfer cleanly, but the *workflow* is heavy:
  open LocalSend on the source device, open LocalSend on the target device,
  wait for discovery, pick the device, paste the content, send.

The recurring cost is opening the app on the *receiving* device every single
time. That's the friction MagicShare removes.

---

## The Idea

Each device installs MagicShare once and signs in with an **anonymous
Firebase account**. The device registers its identifier under that account
and stores its push notification token.

From then on, sending to one of your devices works like this:

1. On the source device, drop a file onto the MagicShare window (or a screen
   corner hot zone), or paste a link.
2. Pick one or more target devices from your account.
3. MagicShare sends a **push notification** containing only encrypted
   metadata — the source device ID, the payload reference, and the target
   device name. No file content goes through the cloud.
4. The target device receives the notification, decrypts the metadata, and
   uses LocalSend's existing transfer protocol to fetch the payload directly
   from the source device.
5. For files: download starts automatically and the user is prompted when
   it finishes. For links: the URL opens in the default browser.

The cloud is used only as a **wake-up channel and address book**. The actual
data transfer stays peer-to-peer and end-to-end encrypted, exactly like
LocalSend today.

---

## Goals

### 1. Cloud-assisted device discovery

- Anonymous Firebase auth — no email, no phone number, no personal data.
- Devices register themselves under an account ID and store a push token.
- A user can list, rename, and revoke their own devices from any of them.
- Only metadata flows through Firebase. Payloads stay peer-to-peer.

### 2. Push-triggered transfers

- The receiving device does not need to have MagicShare in the foreground.
- A push notification wakes the app, which then connects to the sender via
  the LocalSend protocol and starts the transfer.
- Notification payloads are encrypted with a key shared only between the
  user's own devices — Firebase cannot read what is being sent or to whom.

### 3. One-step UX

- **Drag and drop** anywhere onto the MagicShare window, or onto a
  configurable **screen-corner hot zone**, to start a send.
- A single prompt: pick one or many target devices, hit send.
- **Multi-device fan-out** in one action.
- **Link sending**: paste a URL, pick a device, the link opens on the
  target device after one tap on the notification.

### 4. Stay compatible with LocalSend

- The on-the-wire transfer protocol stays the same. A MagicShare device can
  still send to and receive from a stock LocalSend device on the same
  network.
- Cloud features are strictly additive and can be disabled.

---

## Use Cases

These are the everyday flows MagicShare is designed to make trivial:

- **Open a link on another device.** Copy URL on Mac, paste into MagicShare,
  pick "Pixel 8", tap notification on the phone — link opens in the browser.
  No QR code, no email.
- **Move a screenshot to your phone.** Drag it onto the corner hot zone,
  pick the phone, done.
- **Push the same file to multiple devices.** One send, many receivers,
  parallel transfers.
- **Cross-ecosystem sharing.** macOS to Android, Windows to iPhone, Linux
  to Fire tablet — same flow on every platform.
- **Devices on different networks.** As long as both devices can reach the
  internet for the wake-up push, the transfer can fall back through a
  relay (planned) when direct LAN connection isn't possible.

---

## Status

Early work in progress. The fork currently mirrors LocalSend; cloud-assisted
features are being designed and implemented. Expect breaking changes.

Track progress in:

- [`docs/`](docs) — design notes (planned)
- Issues and project board on GitHub

---

## Architecture (Planned)

```
┌──────────────────┐      push (encrypted metadata)      ┌──────────────────┐
│  Source device   │ ───────────────────────────────────▶│  Target device   │
│  (MagicShare)    │      via Firebase Cloud Messaging   │  (MagicShare)    │
└────────┬─────────┘                                     └─────────┬────────┘
         │                                                         │
         │           direct P2P transfer (LocalSend protocol,      │
         └────────────  HTTPS, on-the-fly TLS certs)  ─────────────┘
                              encrypted payload
```

Firebase responsibilities (and *only* these):

- Anonymous account creation.
- Per-account device registry (device ID, name, push token, public key).
- Delivery of opaque, encrypted metadata pushes between a user's own devices.

Everything else — payload, file content, link content — never leaves the
two devices involved in the transfer.

---

## Relationship to LocalSend

MagicShare is a respectful fork. LocalSend is a great app and the team
behind it has done excellent work. The goal here is not to replace it but
to explore a different point in the design space: trading "no servers at
all" for "minimal server, much better UX" while keeping the security
properties intact.

If you don't need cross-network sending or notification-driven receive,
[LocalSend](https://github.com/localsend/localsend) is probably what you
want.

License is unchanged from the upstream project — see [LICENSE](LICENSE).

---

## Building

MagicShare uses the same toolchain as LocalSend.

1. Install Flutter directly from [flutter.dev](https://flutter.dev), or pin
   the version with [mise](https://mise.jdx.dev) (`mise use flutter@3.38.10`)
   or [fvm](https://fvm.app). The expected version lives in
   [.fvmrc](.fvmrc).
2. Install [Rust](https://www.rust-lang.org/tools/install).
3. Clone this repository.
4. `cd app`
5. `flutter pub get`
6. `flutter run`

> [!NOTE]
> The project pins a specific Flutter version in `.fvmrc`. Using a different
> system Flutter can cause build errors. With `mise`, run `mise install` from
> the project root to pick up the pin; with `fvm`, run `fvm flutter ...`
> instead of `flutter ...` when in doubt.

### Platform builds

Run from the `app` directory.

| Platform | Command                                            |
|----------|----------------------------------------------------|
| Android  | `flutter build apk` / `flutter build appbundle`    |
| iOS      | `flutter build ipa`                                |
| macOS    | `flutter build macos`                              |
| Windows  | `flutter build windows` / `flutter pub run msix:create` |
| Linux    | `flutter build linux`                              |

---

## Network requirements

For the LAN transfer leg, the same firewall rules as LocalSend apply:

| Traffic Type | Protocol | Port  | Action |
|--------------|----------|-------|--------|
| Incoming     | TCP, UDP | 53317 | Allow  |
| Outgoing     | TCP, UDP | Any   | Allow  |

Disable AP isolation on your router. Some guest networks have it on by
default, which prevents devices from reaching each other.

For the cloud wake-up leg, devices need outbound HTTPS to Firebase.

---

## Contributing

Contributions are welcome, but the project is in heavy flux right now.
Open an issue first to discuss any non-trivial change so we don't both
build the same thing two different ways.

For the underlying transfer protocol, see the
[LocalSend protocol docs](https://github.com/localsend/protocol).

---

## Credits

- [LocalSend](https://github.com/localsend/localsend) and its contributors
  for the original app, protocol, and codebase this fork is built on.
