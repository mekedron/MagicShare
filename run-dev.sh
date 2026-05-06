#!/usr/bin/env bash
# run-dev.sh — launch MagicShare on macOS desktop and the Android
# emulator in two Terminal.app windows so each has a TTY for
# hot-reload (`r`) and quit (`q`).
#
# Both runs are pinned to the local Firebase emulator suite via
# `--dart-define=USE_FIREBASE_EMULATOR=true`. Make sure
# `cd firebase/functions && npm run dev` is up before launching.
#
# If no Android emulator is connected, the script launches one
# (prefers ANDROID_AVD, otherwise the first AVD `flutter emulators`
# reports) and waits up to ~3 min for it to come online.
#
# Overrides:
#   ANDROID_DEVICE=<id>           connect to a specific device id
#   ANDROID_AVD=<avd-name>        boot a specific AVD when none is up
#   FIREBASE_EMULATOR_HOST=<ip>   how the Android emulator reaches
#                                 the host (default 10.0.2.2)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_ROOT/app"
ANDROID_DEVICE="${ANDROID_DEVICE:-}"
ANDROID_AVD="${ANDROID_AVD:-}"
FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"
EMULATOR_BOOT_TIMEOUT_SECONDS="${EMULATOR_BOOT_TIMEOUT_SECONDS:-180}"

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

ensure_emulator_running

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

open_terminal_window "MagicShare · macOS" \
  "fvm flutter run -d macos --dart-define=USE_FIREBASE_EMULATOR=true"

open_terminal_window "MagicShare · Android ($ANDROID_DEVICE)" \
  "fvm flutter run -d $ANDROID_DEVICE --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=$FIREBASE_EMULATOR_HOST"

cat <<'NOTE'

Two Terminal windows are opening. Each `flutter run` keeps a TTY:
  r        hot reload
  R        hot restart
  q        quit
  Ctrl+C   exit (also tears down the running app)
NOTE
