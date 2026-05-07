#!/usr/bin/env bash
# run-dev.sh — launch the Firebase emulator suite plus MagicShare on
# any combination of macOS desktop, a USB-connected physical iPhone,
# and the Android emulator. Each picked target gets its own Terminal
# window and TTY for hot-reload (`r`) and quit (`q`); the emulator
# window is the place to Ctrl+C / restart Firebase without disturbing
# the apps.
#
# Usage:
#   ./run-dev.sh                       # default targets: macos + ios + firebase
#   ./run-dev.sh macos                 # only the macOS desktop app
#   ./run-dev.sh firebase              # only the Firebase emulator suite
#   ./run-dev.sh android ios macos     # all three apps, no Firebase
#   ./run-dev.sh android firebase      # Android emulator + Firebase suite
#
# Valid target names: macos, ios, android, firebase. Anything else aborts.
# When `firebase` is omitted, the apps still pass
# `--dart-define=USE_FIREBASE_EMULATOR=true` and assume the suite is
# already running elsewhere — they will fail if it isn't.
#
# All app runs are pinned to the local Firebase emulator suite via
# `--dart-define=USE_FIREBASE_EMULATOR=true`. Before launching, the
# script pre-flights every Firebase port (auth/firestore/functions/
# UI). If any is held by another process — a previous Ctrl-C'd run-dev
# session, a stray `firebase emulators:start`, or an unrelated dev
# server on 8080 — it lists the offending PIDs and offers to kill
# them, so the user doesn't have to drop into `lsof`/`pkill` manually.
#
# Pairing-friendly setup
# ----------------------
# The Android emulator can't reach the macOS host's real LAN IP
# reliably (qemu user-mode NAT, captive portals, IPv6-only
# interfaces, host firewall, etc. — all of these break the LAN
# reachability probe and surface as "Both devices need to be on
# the same Wi-Fi to pair"). So we use the same trick documented in
# `docs/development/pairing-testing.md` Recipe 3, applied to the
# macOS issuer ↔ Android emulator joiner direction:
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
# The physical iPhone has its own real LAN interface, so it does
# NOT need any host/port override — the app's normal LAN-IP
# auto-detection works. It does need the Mac's LAN IP to reach the
# host-side Firebase emulator, so HOST_LAN_IP is auto-detected and
# passed via FIREBASE_EMULATOR_HOST. The iPhone must be on the same
# Wi-Fi as the Mac for that to work.
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
#   IOS_DEVICE=<udid>             connect to a specific physical iPhone
#                                 UDID (default: the first non-emulator
#                                 iOS device reported by `flutter
#                                 devices`)
#   FIREBASE_EMULATOR_HOST=<ip>   how the Android emulator reaches
#                                 the host (default 10.0.2.2; macOS
#                                 uses localhost; the iPhone uses
#                                 HOST_LAN_IP)
#   HOST_LAN_IP=<ip>              the Mac's LAN IP that the physical
#                                 iPhone uses to reach the Firebase
#                                 emulator (default: auto-detected
#                                 via `ipconfig getifaddr en0`/`en1`)
#   PAIRING_LAN_PORT=<n>          fixed port for the LAN handshake
#                                 server on macOS (default 51820).
#                                 Anything in the ephemeral range works.
#   LOG_DIR=<path>                where to write per-run log files
#                                 (default <repo>/logs)

set -euo pipefail

print_usage() {
  cat <<'EOF'
Usage: ./run-dev.sh [target ...]

Targets (any subset, in any order):
  macos     run the app on the macOS desktop
  ios       run the app on a USB-connected physical iPhone
  android   run the app on a running/auto-launched Android emulator
  firebase  start the local Firebase emulator suite

When no target is supplied, defaults to: macos ios firebase.
EOF
}

# Parse positional args into TARGETS. Empty list → default
# (macos+ios+firebase). Unknown args fail loud rather than silently
# dropping a typo.
TARGETS=()
if [[ $# -eq 0 ]]; then
  TARGETS=(macos ios firebase)
else
  for arg in "$@"; do
    case "$arg" in
      macos|ios|android|firebase)
        TARGETS+=("$arg")
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        echo "error: unknown target '$arg'" >&2
        echo >&2
        print_usage >&2
        exit 1
        ;;
    esac
  done
fi

has_target() {
  local needle="$1"
  for t in "${TARGETS[@]}"; do
    [[ "$t" == "$needle" ]] && return 0
  done
  return 1
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_ROOT/app"
FIREBASE_FUNCTIONS_DIR="$REPO_ROOT/firebase/functions"
ANDROID_DEVICE="${ANDROID_DEVICE:-}"
ANDROID_AVD="${ANDROID_AVD:-}"
IOS_DEVICE="${IOS_DEVICE:-}"
FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"
HOST_LAN_IP="${HOST_LAN_IP:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)}"
PAIRING_LAN_PORT="${PAIRING_LAN_PORT:-51820}"
EMULATOR_BOOT_TIMEOUT_SECONDS="${EMULATOR_BOOT_TIMEOUT_SECONDS:-180}"

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

# Per-target logs are only created when the user actually picked that
# target — otherwise a stale `latest-<target>.log` symlink would
# mislead `tail -F`.
FIREBASE_LOG=""
MACOS_LOG=""
IOS_LOG=""
ANDROID_LOG=""
has_target firebase && FIREBASE_LOG="$(make_log firebase)"
has_target macos    && MACOS_LOG="$(make_log macos)"
has_target ios      && IOS_LOG="$(make_log ios)"
has_target android  && ANDROID_LOG="$(make_log android)"

# Firebase emulator ports the Android app needs to reach. Mirror of
# `app/lib/config/cloud/firebase_init.dart` `_emulator*Port` consts.
FIREBASE_EMULATOR_PORTS=(9099 8080 5001)

# All host-bound Firebase emulator ports — must match
# firebase/firebase.json. The suite refuses to start as soon as any
# one of these is taken (Firestore on 8080 is the most common
# offender), so we pre-flight every one, not just auth.
FIREBASE_PREFLIGHT_PORTS=("${FIREBASE_EMULATOR_PORTS[@]}" 4000)

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

# Returns the UDID of the first USB-connected physical iPhone, or
# empty string. Parses `flutter devices --machine` for an entry where
# `targetPlatform` starts with `ios` and `emulator` is false (i.e.
# not a simulator).
connected_ios_device_id() {
  cd "$APP_DIR" && fvm flutter devices --machine 2>/dev/null | awk -F\" '
    /^  \{/         { id=""; is_ios=0; is_emulator=1 }
    /"id":/         { id = $4 }
    /"targetPlatform":/ { if ($4 ~ /^ios/) is_ios = 1 }
    /"emulator":/   { is_emulator = ($0 ~ /true/) ? 1 : 0 }
    /^  \}/ {
      if (is_ios && !is_emulator && id != "") { print id; exit }
    }
  '
}

ensure_ios_device_connected() {
  if [[ -n "$IOS_DEVICE" ]]; then
    echo "Using preset iPhone UDID: $IOS_DEVICE"
  else
    local current
    current="$(connected_ios_device_id)"
    if [[ -z "$current" ]]; then
      cat >&2 <<'EOF'
error: no USB-connected iPhone detected.

Plug your iPhone into the Mac with a USB cable, unlock it, and tap
"Trust This Computer" if prompted. If `flutter devices` still doesn't
list it, check:

  - Developer Mode is on (Settings → Privacy & Security → Developer
    Mode), and the device has been restarted since enabling it.
  - Xcode has been opened at least once on this Mac so the device-
    support files are installed.
  - The cable supports data (some are charge-only).

Run `flutter devices` to confirm. Drop `ios` from the run-dev.sh
arguments to skip iOS entirely.
EOF
      exit 1
    fi
    IOS_DEVICE="$current"
    echo "Found USB-connected iPhone: $IOS_DEVICE"
  fi

  if [[ -z "$HOST_LAN_IP" ]]; then
    echo "error: could not auto-detect the Mac's LAN IP (en0/en1). Pass HOST_LAN_IP=<ip> so the iPhone can reach the Firebase emulator." >&2
    exit 1
  fi
  echo "iPhone will reach the host's Firebase emulator at $HOST_LAN_IP (must share Wi-Fi)."
}

# adb reverse: emulator's localhost:<port> → host's localhost:<port>.
# Idempotent — `adb reverse` overwrites the existing mapping silently.
setup_adb_reverse() {
  if [[ -z "$adb_bin" ]]; then
    echo "warning: adb not on PATH; skipping reverse port forwards. Pairing may fail." >&2
    return
  fi
  local ports=("${FIREBASE_EMULATOR_PORTS[@]}" "$PAIRING_LAN_PORT")
  for port in "${ports[@]}"; do
    if "$adb_bin" reverse "tcp:$port" "tcp:$port" >/dev/null 2>&1; then
      echo "  adb reverse tcp:$port → host tcp:$port"
    else
      echo "  warning: adb reverse tcp:$port failed" >&2
    fi
  done
}

# Returns the PIDs (one per line) listening on tcp:<port>, or empty.
pids_listening_on_port() {
  local port="$1"
  lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
}

# Pre-flight every Firebase emulator port. If any is held — by a
# previous suite, a stray `firebase emulators:start`, or an unrelated
# dev server — list the holding PIDs and prompt to kill them. The
# suite must launch fresh from this script so the binding picks up
# the latest firebase/firebase.json (host: 0.0.0.0, which a physical
# iPhone joiner needs to reach Firebase Auth over Wi-Fi).
ensure_firebase_ports_free() {
  local blocked_ports=()
  local pids_to_kill=()
  for port in "${FIREBASE_PREFLIGHT_PORTS[@]}"; do
    local pids
    pids="$(pids_listening_on_port "$port")"
    if [[ -n "$pids" ]]; then
      blocked_ports+=("$port")
      while IFS= read -r pid; do
        [[ -n "$pid" ]] && pids_to_kill+=("$pid")
      done <<<"$pids"
    fi
  done

  if (( ${#blocked_ports[@]} == 0 )); then
    return
  fi

  echo >&2
  echo "Firebase emulator port(s) already in use: ${blocked_ports[*]}" >&2
  for port in "${blocked_ports[@]}"; do
    echo "  tcp:$port" >&2
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      local cmd
      cmd="$(ps -o command= -p "$pid" 2>/dev/null | head -c 120)"
      printf "    pid %s  %s\n" "$pid" "${cmd:-<unknown>}" >&2
    done <<<"$(pids_listening_on_port "$port")"
  done

  if [[ ! -t 0 ]]; then
    echo "error: stdin is not a TTY; cannot prompt. Stop the listed processes and re-run." >&2
    exit 1
  fi

  # De-duplicate PIDs — a single process can hold several ports.
  local unique_pids
  unique_pids="$(printf '%s\n' "${pids_to_kill[@]}" | sort -u)"

  echo >&2
  local reply=""
  read -r -p "Kill the listed process(es) and continue? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborting — stop those processes manually and re-run ./run-dev.sh." >&2
    exit 1
  fi

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    if kill "$pid" 2>/dev/null; then
      echo "  sent SIGTERM to pid $pid"
    else
      echo "  warning: could not signal pid $pid (already gone?)" >&2
    fi
  done <<<"$unique_pids"

  # Give them up to 5s to release the ports, then SIGKILL holdouts.
  local deadline=$(( SECONDS + 5 ))
  while (( SECONDS < deadline )); do
    local still_listening=0
    for port in "${blocked_ports[@]}"; do
      if [[ -n "$(pids_listening_on_port "$port")" ]]; then
        still_listening=1
        break
      fi
    done
    (( still_listening == 0 )) && break
    sleep 1
  done

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      echo "  pid $pid still alive — sending SIGKILL"
      kill -9 "$pid" 2>/dev/null || true
    fi
  done <<<"$unique_pids"

  for port in "${blocked_ports[@]}"; do
    if [[ -n "$(pids_listening_on_port "$port")" ]]; then
      echo "error: tcp:$port is still in use after kill — aborting." >&2
      exit 1
    fi
  done

  echo "All Firebase emulator ports are free now."
}

# Block until the auth emulator is accepting TCP. The auth emulator
# is the slowest of the three to bind in practice, so once it answers
# the rest of the suite is already up too.
wait_for_firebase_emulator_ready() {
  echo -n "Waiting for the Firebase emulator suite to come online "
  local deadline=$(( SECONDS + 90 ))
  while (( SECONDS < deadline )); do
    if lsof -nP -iTCP:9099 -sTCP:LISTEN >/dev/null 2>&1; then
      echo " → up"
      return
    fi
    echo -n "."
    sleep 1
  done
  echo
  cat >&2 <<'EOF'
warning: the Firebase emulator suite did not come online within 90s.
The flutter apps are still starting; if they fail to reach Firebase,
check the "MagicShare · Firebase emulators" Terminal window for the
actual startup error.
EOF
}

# `set -o pipefail` inside the inner shell so a flutter crash
# propagates through tee. `tee -a` keeps the log file on disk
# (a fresh empty file is created by make_log), and stdin still
# flows to flutter so r/R/q hot-reload keys work.
open_terminal_window_in() {
  local title="$1"
  local log="$2"
  local cwd="$3"
  local cmd="$4"
  /usr/bin/osascript <<EOF
tell application "Terminal"
  activate
  do script "set -o pipefail; echo '== $title =='; echo 'log: $log'; cd '$cwd' && $cmd 2>&1 | tee -a '$log'"
end tell
EOF
}

# Convenience wrapper for the three flutter-run windows, which all
# launch from the app directory.
open_terminal_window() {
  open_terminal_window_in "$1" "$2" "$APP_DIR" "$3"
}

echo "Selected targets: ${TARGETS[*]}"

if has_target firebase; then
  ensure_firebase_ports_free
fi

if has_target android; then
  ensure_emulator_running
fi
if has_target ios; then
  ensure_ios_device_connected
fi
if has_target android; then
  echo "Wiring adb reverse port forwards (emulator → host) for pairing + Firebase:"
  setup_adb_reverse
fi

# Open the Firebase emulator window FIRST so the suite has the most
# time to come online while the flutter builds are still spinning up.
# `npm run dev` runs `firebase --project=magic-share-backend
# emulators:start`, which walks up the tree to find firebase/firebase.json.
# Block here until the suite answers on tcp:9099 — otherwise the
# flutter apps will race the emulator startup and the first
# previewJoinToken / signInAnonymously call may fail.
if has_target firebase; then
  open_terminal_window_in "MagicShare · Firebase emulators" "$FIREBASE_LOG" \
    "$FIREBASE_FUNCTIONS_DIR" \
    "npm run dev"
  wait_for_firebase_emulator_ready
fi

if has_target macos; then
  # macOS issuer: pin the pairing port and advertise 127.0.0.1 in the
  # QR / manual code so an Android-emulator joiner reaches it via the
  # adb-reverse tunnel. The v2 PairingPayload also carries the real
  # LAN IP, so a physical iPhone joiner can pair against the same
  # QR. Production builds ignore both defines (defaults to ephemeral
  # port + auto-detected IP).
  open_terminal_window "MagicShare · macOS" "$MACOS_LOG" \
    "fvm flutter run -d macos \
      --dart-define=USE_FIREBASE_EMULATOR=true \
      --dart-define=CLOUD_PAIRING_LAN_HOST=127.0.0.1 \
      --dart-define=CLOUD_PAIRING_LAN_PORT=$PAIRING_LAN_PORT"
fi

if has_target ios; then
  # Physical iPhone: has its own real LAN interface, so the app's
  # normal LAN-IP auto-detection works for the pairing handshake (no
  # CLOUD_PAIRING_LAN_HOST override needed). To reach the host-side
  # Firebase emulator over Wi-Fi, the iPhone uses the Mac's LAN IP
  # instead of localhost. `flutter run -d <udid>` builds, installs,
  # and launches the debug build on the device.
  open_terminal_window "MagicShare · iOS ($IOS_DEVICE)" "$IOS_LOG" \
    "fvm flutter run -d $IOS_DEVICE \
      --dart-define=USE_FIREBASE_EMULATOR=true \
      --dart-define=FIREBASE_EMULATOR_HOST=$HOST_LAN_IP"
fi

if has_target android; then
  open_terminal_window "MagicShare · Android ($ANDROID_DEVICE)" "$ANDROID_LOG" \
    "fvm flutter run -d $ANDROID_DEVICE \
      --dart-define=USE_FIREBASE_EMULATOR=true \
      --dart-define=FIREBASE_EMULATOR_HOST=$FIREBASE_EMULATOR_HOST"
fi

# One Terminal window per picked target.
window_count=${#TARGETS[@]}

cat <<NOTE

$window_count Terminal windows are opening:
$( has_target firebase && echo "  · \"Firebase emulators\" — Ctrl+C here to stop the suite, then re-run" \
                            && echo "    \`npm run dev\` in the same window to bring it back without" \
                            && echo "    restarting the flutter apps." )
  · Each \`flutter run\` window keeps its own TTY:
      r        hot reload
      R        hot restart
      q        quit
      Ctrl+C   exit (also tears down the running app)

Logs (mirrored from each console via tee):
$( has_target firebase && echo "  $FIREBASE_LOG" )
$( has_target macos    && echo "  $MACOS_LOG" )
$( has_target ios      && echo "  $IOS_LOG" )
$( has_target android  && echo "  $ANDROID_LOG" )

Stable symlinks for tailing:
$( has_target firebase && echo "  tail -F $LOG_DIR/latest-firebase.log" )
$( has_target macos    && echo "  tail -F $LOG_DIR/latest-macos.log" )
$( has_target ios      && echo "  tail -F $LOG_DIR/latest-ios.log" )
$( has_target android  && echo "  tail -F $LOG_DIR/latest-android.log" )

Pairing:
$( has_target macos   && echo "  macOS issuer            127.0.0.1:$PAIRING_LAN_PORT (Android joiner via adb reverse)" )
$( has_target ios     && echo "  iPhone                  auto-detected LAN IP (must share Wi-Fi with Mac)" )
$( has_target android && echo "  Android emulator        joins macOS via adb reverse on the port above" )

The macOS QR / manual code advertises both 127.0.0.1 and the host's
real LAN IP — the Android-emulator joiner reaches it via adb reverse
on 127.0.0.1, while a physical iPhone joiner picks up the real LAN
IP. v2 PairingPayload races both addresses on the joiner side and
uses whichever answers first.
NOTE
