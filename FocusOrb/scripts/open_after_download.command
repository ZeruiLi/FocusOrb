#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FocusOrb.app"
TARGET_APP="/Applications/$APP_NAME"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NEXT_TO_SCRIPT="$SCRIPT_DIR/$APP_NAME"

echo "[1/4] Checking app location..."
if [[ ! -d "$TARGET_APP" ]]; then
  if [[ -d "$APP_NEXT_TO_SCRIPT" ]]; then
    echo "Copying $APP_NAME to /Applications ..."
    ditto "$APP_NEXT_TO_SCRIPT" "$TARGET_APP"
  else
    echo "Cannot find $APP_NAME next to this script."
    echo "Please drag $APP_NAME to /Applications first, then run this script again."
    exit 1
  fi
fi

echo "[2/4] Clearing quarantine attributes..."
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo "[3/4] Verifying app exists..."
if [[ ! -d "$TARGET_APP" ]]; then
  echo "App was not found at: $TARGET_APP"
  exit 1
fi

echo "[4/4] Launching app..."
open "$TARGET_APP"

echo
echo "If macOS still blocks the app:"
echo "System Settings -> Privacy & Security -> Open Anyway"
