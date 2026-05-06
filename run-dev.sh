#!/usr/bin/env bash
# run-dev.sh — launch MagicShare on macOS desktop and the Android
# emulator in two Terminal.app windows so each has a TTY for
# hot-reload (`r`) and quit (`q`).
#
# Both runs are pinned to the local Firebase emulator suite via
# `--dart-define=USE_FIREBASE_EMULATOR=true`. Make sure
# `cd firebase/functions && npm run dev` is up before launching.
#
# Pairing-friendly setup
# ----------------------
# The Android emulator can't reach the macOS host's real LAN IP
# reliably (qemu user-mode NAT, captive portals, IPv6-only
# interfaces, host firewall, etc. — all of these break the LAN
# reachability probe and surface as "Both devices need to be on
# the same Wi-Fi to pair"). So we use the same trick documented in
# `docs/development/pairing-testing.md` Recipe 3, applied to the
# more common direction (macOS issuer ↔ emulator joiner):
#
# 1. Pin the LAN handshake server on macOS to a known port via
#    CLOUD_PAIRING_LAN_PORT.
# 2. Tell macOS to advertise `127.0.0.1:<port>` in the QR / manual
#    code via CLOUD_PAIRING_LAN_HOST.
# 3. `adb reverse tcp:<port> tcp:<port>` so the emulator's own
#    `localhost:<port>` routes to the host's `localhost:<port>` —
#    where the macOS pairing server is now bound. Same trick used
#    for the Firebase emulator ports.
#
# Result: pairing works regardless of the host's actual LAN config.
#
# Overrides:
#   ANDROID_DEVICE=<id>           connect to a specific device id
#   ANDROID_AVD=<avd-name>        boot a specific AVD when none is up
#   FIREBASE_EMULATOR_HOST=<ip>   how the Android emulator reaches
#                                 the host (default 10.0.2.2)
#   PAIRING_LAN_PORT=<n>          fixed port for the LAN handshake
#                                 server on macOS (default 51820).
#                                 Anything in the ephemeral range works.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_ROOT/app"
ANDROID_DEVICE="${ANDROID_DEVICE:-}"
ANDROID_AVD="${ANDROID_AVD:-}"
FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"
PAIRING_LAN_PORT="${PAIRING_LAN_PORT:-51820}"
EMULATOR_BOOT_TIMEOUT_SECONDS="${EMULATOR_BOOT_TIMEOUT_SECONDS:-180}"

# Firebase emulator ports the Android app needs to reach. Mirror of
# `app/lib/config/cloud/firebase_init.dart` `_emulator*Port` consts.
FIREBASE_EMULATOR_PORTS=(9099 8080 5001)

if [[ ! -d "$APP_DIR" ]]; then
  echo "error: $APP_DIR not found — run this from the repo root." >&2
  exit 1
fi

if ! command -v fvm >/dev/null 2>&1; then
  echo "error: fvm not on PATH (the project pins Flutter via .fvmrc)." >&2
  exit 1
fi

# adb ships with the Android SDK; commonly on PATH via $ANDROID_HOME.
# Fall back to the standard install path if not.
adb_bin="$(command -v adb || true)"
if [[ -z "$adb_bin" && -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
  adb_bin="$HOME/Library/Android/sdk/platform-tools/adb"
fi

# Returns the first running Android emulator id (e.g. emulator-5554),
# or empty string when none is up.
running_emulator_id() {
  if [[ -n "$adb_bin" ]]; then
    "$adb_bin" devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1; exit}'
    return
  fi
  # adb not available — fall back to flutter devices output.
  cd "$APP_DIR" && fvm flutter devices --machine 2>/dev/null \
    | awk -F\" '/"id":/{ if ($4 ~ /^emulator-/) {print $4; exit} }'
}

# Default AVD: prefer ANDROID_AVD; otherwise the first one
# `flutter emulators` lists.
pick_avd() {
  if [[ -n "$ANDROID_AVD" ]]; then
    echo "$ANDROID_AVD"
    return
  fi
  cd "$APP_DIR" \
    && fvm flutter emulators 2>/dev/null \
    | awk '/^[a-zA-Z0-9_]+ +• +/ && $1 != "apple_ios_simulator" { print $1; exit }'
}

ensure_emulator_running() {
  local current
  current="$(running_emulator_id)"
  if [[ -n "$current" ]]; then
    echo "Android emulator already running: $current"
    ANDROID_DEVICE="${ANDROID_DEVICE:-$current}"
    return
  fi

  local avd
  avd="$(pick_avd)"
  if [[ -z "$avd" ]]; then
    cat >&2 <<'EOF'
error: no Android emulator running and no AVD configured.

Create one in Android Studio (Tools → Device Manager → Create
Device) or via:
  $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd ...
EOF
    exit 1
  fi

  echo "Starting Android emulator: $avd"
  cd "$APP_DIR" && fvm flutter emulators --launch "$avd" >/dev/null 2>&1 &

  echo -n "Waiting for the emulator to come online "
  local deadline=$(( SECONDS + EMULATOR_BOOT_TIMEOUT_SECONDS ))
  while (( SECONDS < deadline )); do
    current="$(running_emulator_id)"
    if [[ -n "$current" ]]; then
      echo " → $current"
      ANDROID_DEVICE="${ANDROID_DEVICE:-$current}"
      return
    fi
    echo -n "."
    sleep 2
  done
  echo
  echo "error: emulator did not come online within ${EMULATOR_BOOT_TIMEOUT_SECONDS}s." >&2
  exit 1
}

# adb reverse: emulator's localhost:<port> → host's localhost:<port>.
# Idempotent — `adb reverse` overwrites the existing mapping silently.
setup_adb_reverse() {
  if [[ -z "$adb_bin" ]]; then
    echo "warning: adb not on PATH; skipping reverse port forwards. Pairing may fail." >&2
    return
  fi
  for port in "${FIREBASE_EMULATOR_PORTS[@]}" "$PAIRING_LAN_PORT"; do
    if "$adb_bin" reverse "tcp:$port" "tcp:$port" >/dev/null 2>&1; then
      echo "  adb reverse tcp:$port → host tcp:$port"
    else
      echo "  warning: adb reverse tcp:$port failed" >&2
    fi
  done
}

ensure_emulator_running
echo "Wiring adb reverse port forwards (emulator → host) for pairing + Firebase:"
setup_adb_reverse

open_terminal_window() {
  local title="$1"
  local cmd="$2"
  /usr/bin/osascript <<EOF
tell application "Terminal"
  activate
  do script "echo '== $title =='; cd '$APP_DIR' && $cmd"
end tell
EOF
}

# macOS issuer: pin the pairing port and advertise 127.0.0.1 in the
# QR / manual code so the emulator joiner reaches it via the
# adb-reverse tunnel set up above. Production builds ignore both
# defines (defaults to ephemeral port + auto-detected IP).
open_terminal_window "MagicShare · macOS" \
  "fvm flutter run -d macos \
    --dart-define=USE_FIREBASE_EMULATOR=true \
    --dart-define=CLOUD_PAIRING_LAN_HOST=127.0.0.1 \
    --dart-define=CLOUD_PAIRING_LAN_PORT=$PAIRING_LAN_PORT"

open_terminal_window "MagicShare · Android ($ANDROID_DEVICE)" \
  "fvm flutter run -d $ANDROID_DEVICE \
    --dart-define=USE_FIREBASE_EMULATOR=true \
    --dart-define=FIREBASE_EMULATOR_HOST=$FIREBASE_EMULATOR_HOST"

cat <<NOTE

Two Terminal windows are opening. Each \`flutter run\` keeps a TTY:
  r        hot reload
  R        hot restart
  q        quit
  Ctrl+C   exit (also tears down the running app)

Pairing is wired host↔emulator over adb reverse on port $PAIRING_LAN_PORT.
The macOS-side QR / manual code will advertise 127.0.0.1:$PAIRING_LAN_PORT
— that's the right value for this dev setup; do NOT change it from a
real LAN IP.
NOTE
