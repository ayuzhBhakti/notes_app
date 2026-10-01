#!/usr/bin/env bash
# Runs the Maestro CLI with the environment it needs on a machine that has
# Android Studio but no standalone JDK or adb on the PATH.
#
#   ./tool/maestro.sh test .maestro
#   ./tool/maestro.sh studio
set -euo pipefail

MAESTRO_BIN="$HOME/.maestro/bin"
if [[ ! -x "$MAESTRO_BIN/maestro" ]] && ! command -v maestro >/dev/null 2>&1; then
  echo "Maestro is not installed. See docs/08-e2e-testing.md." >&2
  exit 1
fi

# Maestro needs Java 17+. Fall back to the JDK bundled with Android Studio.
# `java -version` rather than `command -v java`: macOS ships a /usr/bin/java
# stub that exists even when no runtime is installed.
if [[ -z "${JAVA_HOME:-}" ]] && ! java -version >/dev/null 2>&1; then
  STUDIO_JDK="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [[ -x "$STUDIO_JDK/bin/java" ]]; then
    export JAVA_HOME="$STUDIO_JDK"
  else
    echo "No JDK found. Install Java 17+ or Android Studio, or set JAVA_HOME." >&2
    exit 1
  fi
fi

ANDROID_SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$MAESTRO_BIN:$ANDROID_SDK/platform-tools:$PATH"

# Usage analytics are off unless the caller opts in.
export MAESTRO_CLI_NO_ANALYTICS="${MAESTRO_CLI_NO_ANALYTICS:-1}"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED="${MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED:-true}"

# Run from the repository root so relative flow paths work from anywhere.
cd "$(dirname "$0")/.."

# Maestro cannot see the app behind a lock screen, and a screen that times out
# mid-run fails every remaining step. For a test run on an Android device:
# wake it, dismiss the lock screen, and hold it awake while on USB power. The
# device's own stay-awake setting is put back when the run ends. A lock screen
# with a PIN or pattern cannot be dismissed this way and must be unlocked by
# hand first.
if [[ "${1:-}" == "test" ]] && adb get-state >/dev/null 2>&1; then
  previous_stay_on="$(adb shell settings get global stay_on_while_plugged_in | tr -d '\r')"
  restore_stay_on() {
    adb shell settings put global stay_on_while_plugged_in "${previous_stay_on:-0}" >/dev/null 2>&1 || true
  }
  trap restore_stay_on EXIT
  adb shell svc power stayon usb
  adb shell input keyevent KEYCODE_WAKEUP
  adb shell wm dismiss-keyguard
  # Not exec: the trap above has to run after Maestro exits.
  maestro "$@"
  exit $?
fi

exec maestro "$@"
