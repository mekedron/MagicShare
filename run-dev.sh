#!/usr/bin/env bash
# run-dev.sh — launch MagicShare on macOS desktop, the iOS Simulator,
# and the Android emulator in three Terminal.app windows so each has
# a TTY for hot-reload (`r`) and quit (`q`).
#
# All three runs are pinned to the local Firebase emulator suite via
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
# The iOS Simulator shares the host's loopback, so it doesn't need
# the adb-reverse trick — but it can't bind the same port as macOS.
# We pin it to a separate port (default PAIRING_LAN_PORT + 1) and
# reverse-forward that port too so the Android emulator can reach
# the iOS pairing server.
#
# Result: pairing works regardless of the host's actual LAN config,
# in any direction across the three runtimes.
#
# Each `flutter run` is mirrored through `tee` to a timestamped log
# under <repo>/logs/, with `latest-<platform>.log` symlinks for easy
# tailing:
#   tail -F logs/latest-macos.log
#   tail -F logs/latest-ios.log
#   tail -F logs/latest-android.log
#
# Overrides:
#   ANDROID_DEVICE=<id>           connect to a specific device id
#   ANDROID_AVD=<avd-name>        boot a specific AVD when none is up
#   IOS_DEVICE=<udid>             connect to a specific simulator UDID
#                                 (default: first booted, or whatever
#                                 `flutter emulators --launch
#                                 apple_ios_simulator` brings up)
#   FIREBASE_EMULATOR_HOST=<ip>   how the Android emulator reaches
#                                 the host (default 10.0.2.2; macOS
#                                 and iOS Simulator already use
#                                 localhost)
#   PAIRING_LAN_PORT=<n>          fixed port for the LAN handshake
#                                 server on macOS (default 51820).
#                                 Anything in the ephemeral range works.
#   IOS_PAIRING_LAN_PORT=<n>      fixed port for the iOS Simulator
#                                 pairing server (default
#                                 PAIRING_LAN_PORT + 1). Must differ
#                                 from PAIRING_LAN_PORT — they share
#                                 the host's loopback.
#   SKIP_IOS=1                    don't launch the iOS Simulator
#   LOG_DIR=<path>                where to write per-run log files
#                                 (default <repo>/logs)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_ROOT/app"
ANDROID_DEVICE="${ANDROID_DEVICE:-}"
ANDROID_AVD="${ANDROID_AVD:-}"
IOS_DEVICE="${IOS_DEVICE:-}"
SKIP_IOS="${SKIP_IOS:-}"
FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"
PAIRING_LAN_PORT="${PAIRING_LAN_PORT:-51820}"
IOS_PAIRING_LAN_PORT="${IOS_PAIRING_LAN_PORT:-$((PAIRING_LAN_PORT + 1))}"
EMULATOR_BOOT_TIMEOUT_SECONDS="${EMULATOR_BOOT_TIMEOUT_SECONDS:-180}"

if [[ "$IOS_PAIRING_LAN_PORT" == "$PAIRING_LAN_PORT" ]]; then
  echo "error: IOS_PAIRING_LAN_PORT must differ from PAIRING_LAN_PORT (both = $PAIRING_LAN_PORT) — they share the host's loopback." >&2
  exit 1
fi

# Per-run logs: one file per platform, timestamped, with a `latest-*`
# symlink so `tail -F logs/latest-macos.log` always follows the most
# recent run.
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
LOG_TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$LOG_DIR"

# Sets <platform>_LOG (path to today's log) and refreshes the
# `latest-<platform>.log` symlink to point at it. Symlinks are
# relative so they survive moving the repo.
make_log() {
  local platform="$1"
  local stamp_file="$LOG_DIR/${LOG_TIMESTAMP}-${platform}.log"
  : > "$stamp_file"
  ln -sfn "$(basename "$stamp_file")" "$LOG_DIR/latest-${platform}.log"
  echo "$stamp_file"
}

MACOS_LOG="$(make_log macos)"
IOS_LOG="$(make_log ios)"
ANDROID_LOG="$(make_log android)"

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
# `flutter emulators` lists. Skips the column header row (`Id` …)
# and the iOS simulator row.
pick_avd() {
  if [[ -n "$ANDROID_AVD" ]]; then
    echo "$ANDROID_AVD"
    return
  fi
  cd "$APP_DIR" \
    && fvm flutter emulators 2>/dev/null \
    | awk '/^[a-z0-9_]+ +• +/ && $1 != "apple_ios_simulator" { print $1; exit }'
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

# Returns the UDID of the first booted iOS Simulator, or empty string.
# `xcrun simctl list devices booted` prints lines like:
#   iPhone 15 Pro (5B9B6F3A-...) (Booted)
running_ios_simulator_id() {
  if ! command -v xcrun >/dev/null 2>&1; then
    return
  fi
  xcrun simctl list devices booted 2>/dev/null \
    | awk -F'[()]' '/\(Booted\)/ { print $2; exit }'
}

ensure_ios_simulator_running() {
  if [[ -n "$SKIP_IOS" ]]; then
    echo "SKIP_IOS set — not launching the iOS Simulator."
    return
  fi

  if ! command -v xcrun >/dev/null 2>&1; then
    echo "warning: xcrun not on PATH — install Xcode command-line tools or set SKIP_IOS=1." >&2
    exit 1
  fi

  local current
  current="$(running_ios_simulator_id)"
  if [[ -n "$current" ]]; then
    echo "iOS Simulator already running: $current"
    IOS_DEVICE="${IOS_DEVICE:-$current}"
    return
  fi

  echo "Starting iOS Simulator (apple_ios_simulator)…"
  cd "$APP_DIR" && fvm flutter emulators --launch apple_ios_simulator >/dev/null 2>&1 &

  echo -n "Waiting for the iOS Simulator to come online "
  local deadline=$(( SECONDS + EMULATOR_BOOT_TIMEOUT_SECONDS ))
  while (( SECONDS < deadline )); do
    current="$(running_ios_simulator_id)"
    if [[ -n "$current" ]]; then
      echo " → $current"
      IOS_DEVICE="${IOS_DEVICE:-$current}"
      return
    fi
    echo -n "."
    sleep 2
  done
  echo
  echo "error: iOS Simulator did not come online within ${EMULATOR_BOOT_TIMEOUT_SECONDS}s." >&2
  exit 1
}

# adb reverse: emulator's localhost:<port> → host's localhost:<port>.
# Idempotent — `adb reverse` overwrites the existing mapping silently.
setup_adb_reverse() {
  if [[ -z "$adb_bin" ]]; then
    echo "warning: adb not on PATH; skipping reverse port forwards. Pairing may fail." >&2
    return
  fi
  local ports=("${FIREBASE_EMULATOR_PORTS[@]}" "$PAIRING_LAN_PORT")
  if [[ -z "$SKIP_IOS" ]]; then
    ports+=("$IOS_PAIRING_LAN_PORT")
  fi
  for port in "${ports[@]}"; do
    if "$adb_bin" reverse "tcp:$port" "tcp:$port" >/dev/null 2>&1; then
      echo "  adb reverse tcp:$port → host tcp:$port"
    else
      echo "  warning: adb reverse tcp:$port failed" >&2
    fi
  done
}

ensure_emulator_running
ensure_ios_simulator_running
echo "Wiring adb reverse port forwards (emulator → host) for pairing + Firebase:"
setup_adb_reverse

open_terminal_window() {
  local title="$1"
  local log="$2"
  local cmd="$3"
  # `set -o pipefail` inside the inner shell so a flutter crash
  # propagates through tee. `tee -a` keeps the log file on disk
  # (a fresh empty file is created by make_log), and stdin still
  # flows to flutter so r/R/q hot-reload keys work.
  /usr/bin/osascript <<EOF
tell application "Terminal"
  activate
  do script "set -o pipefail; echo '== $title =='; echo 'log: $log'; cd '$APP_DIR' && $cmd 2>&1 | tee -a '$log'"
end tell
EOF
}

# macOS issuer: pin the pairing port and advertise 127.0.0.1 in the
# QR / manual code so the emulator joiner reaches it via the
# adb-reverse tunnel set up above. Production builds ignore both
# defines (defaults to ephemeral port + auto-detected IP).
open_terminal_window "MagicShare · macOS" "$MACOS_LOG" \
  "fvm flutter run -d macos \
    --dart-define=USE_FIREBASE_EMULATOR=true \
    --dart-define=CLOUD_PAIRING_LAN_HOST=127.0.0.1 \
    --dart-define=CLOUD_PAIRING_LAN_PORT=$PAIRING_LAN_PORT"

# iOS Simulator: shares the host's loopback with macOS, so it can
# advertise 127.0.0.1 directly — but it must bind a different port
# than macOS. The Android emulator reaches this port via the matching
# adb-reverse tunnel set up above.
if [[ -z "$SKIP_IOS" ]]; then
  open_terminal_window "MagicShare · iOS ($IOS_DEVICE)" "$IOS_LOG" \
    "fvm flutter run -d $IOS_DEVICE \
      --dart-define=USE_FIREBASE_EMULATOR=true \
      --dart-define=CLOUD_PAIRING_LAN_HOST=127.0.0.1 \
      --dart-define=CLOUD_PAIRING_LAN_PORT=$IOS_PAIRING_LAN_PORT"
fi

open_terminal_window "MagicShare · Android ($ANDROID_DEVICE)" "$ANDROID_LOG" \
  "fvm flutter run -d $ANDROID_DEVICE \
    --dart-define=USE_FIREBASE_EMULATOR=true \
    --dart-define=FIREBASE_EMULATOR_HOST=$FIREBASE_EMULATOR_HOST"

window_count=2
[[ -z "$SKIP_IOS" ]] && window_count=3

cat <<NOTE

$window_count Terminal windows are opening. Each \`flutter run\` keeps a TTY:
  r        hot reload
  R        hot restart
  q        quit
  Ctrl+C   exit (also tears down the running app)

Logs (mirrored from each console via tee):
  $MACOS_LOG
$( [[ -z "$SKIP_IOS" ]] && echo "  $IOS_LOG" )
  $ANDROID_LOG

Stable symlinks for tailing:
  tail -F $LOG_DIR/latest-macos.log
$( [[ -z "$SKIP_IOS" ]] && echo "  tail -F $LOG_DIR/latest-ios.log" )
  tail -F $LOG_DIR/latest-android.log

Pairing ports:
  macOS issuer            127.0.0.1:$PAIRING_LAN_PORT
$( [[ -z "$SKIP_IOS" ]] && echo "  iOS Simulator issuer    127.0.0.1:$IOS_PAIRING_LAN_PORT" )
  Android emulator        joins via adb reverse on the ports above

The macOS- and iOS-side QR / manual codes will advertise 127.0.0.1
— that's the right value for this dev setup; do NOT change them to
a real LAN IP.
NOTE
