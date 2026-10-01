#!/usr/bin/env bash
# Opens the local onboarding test link, notes://onboarding, on the connected
# Android device. The link is registered by debug builds only.
#
#   ./tool/deeplink.sh            open the link (the app keeps its current state)
#   ./tool/deeplink.sh --fresh    clear the app's data first, then open the link
#   ./tool/deeplink.sh --reset    clear the app's data: back to the normal app
#   ./tool/deeplink.sh --check    run the automated check of cold and warm links
set -euo pipefail

APP_ID="com.spacewire.notes"
LINK="notes://onboarding"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--check" ]]; then
  exec ./tool/maestro.sh test .maestro/flows/deeplink_local.yaml
fi

if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "No Android device connected. Check with: flutter devices" >&2
  exit 1
fi
if ! "$ADB" shell pm list packages | grep -q "package:$APP_ID\$"; then
  echo "The app is not installed. Run: flutter run   (a debug build)" >&2
  exit 1
fi

case "${1:-}" in
  --fresh | --reset)
    "$ADB" shell pm clear "$APP_ID" >/dev/null
    echo "Cleared the app's data."
    [[ "$1" == "--reset" ]] && exit 0
    ;;
  "") ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
esac

# No package name is given on purpose: this resolves the link the way a tap on
# it would, so it fails if the app does not actually claim the link.
"$ADB" shell am start -W -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE -d "$LINK" | grep -E 'Status|Activity|Error' || true
echo "Opened $LINK. The app should show \"Tell us about you\"."
