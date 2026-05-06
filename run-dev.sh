#!/usr/bin/env bash
# run-dev.sh — launch MagicShare on macOS desktop and the Android
# emulator in two Terminal.app windows so each has a TTY for
# hot-reload (`r`) and quit (`q`).
#
# Both runs are pinned to the local Firebase emulator suite via
# `--dart-define=USE_FIREBASE_EMULATOR=true`. Make sure
# `cd firebase/functions && npm run dev` is up before launching.
#
# Override the Android device id with `ANDROID_DEVICE=<id>` if your
# emulator isn't `emulator-5554`. Override the host the Android
# emulator uses to reach the Firebase emulator with
# `FIREBASE_EMULATOR_HOST=10.0.2.2` (the default — the standard alias
# the Android emulator routes to the host machine).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$REPO_ROOT/app"
ANDROID_DEVICE="${ANDROID_DEVICE:-emulator-5554}"
FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "error: $APP_DIR not found — run this from the repo root." >&2
  exit 1
fi

if ! command -v fvm >/dev/null 2>&1; then
  echo "error: fvm not on PATH (the project pins Flutter via .fvmrc)." >&2
  exit 1
fi

open_terminal_window() {
  local title="$1"
  local cmd="$2"
  # `do script` opens a new window; `cd` first so a `pwd` is meaningful
  # if anything goes wrong.
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

Tip: if the Android window prints "device not found", check
`fvm flutter devices` for the right id and rerun with
ANDROID_DEVICE=<id> ./run-dev.sh
NOTE
