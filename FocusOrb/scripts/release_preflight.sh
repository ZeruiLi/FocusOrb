#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPICON_DIR="$ROOT_DIR/Sources/Resources/Assets.xcassets/AppIcon.appiconset"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "[FAIL] Missing file: $path"
    return 1
  fi
  echo "[ OK ] $path"
}

require_icon() {
  local name="$1"
  local path="$APPICON_DIR/$name"
  if [[ ! -f "$path" ]]; then
    echo "[FAIL] Missing icon: $name"
    return 1
  fi
  echo "[ OK ] icon $name"
}

require_plist_key() {
  local plist="$1"
  local key="$2"
  local value
  if ! value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null); then
    echo "[FAIL] Missing Info.plist key: $key"
    return 1
  fi
  if [[ -z "$value" ]]; then
    echo "[FAIL] Empty Info.plist key: $key"
    return 1
  fi
  echo "[ OK ] Info.plist $key = $value"
}

main() {
  require_file "$ROOT_DIR/Sources/Resources/PrivacyInfo.xcprivacy"
  require_file "$ROOT_DIR/FocusOrb.entitlements"
  require_file "$ROOT_DIR/Info.plist"
  require_plist_key "$ROOT_DIR/Info.plist" "LSApplicationCategoryType"
  require_file "$ROOT_DIR/scripts/generate_xcodeproj.rb"
  require_file "$ROOT_DIR/Sources/Resources/Assets.xcassets/Contents.json"
  require_file "$ROOT_DIR/Sources/Resources/Assets.xcassets/AccentColor.colorset/Contents.json"
  require_file "$APPICON_DIR/Contents.json"

  require_icon "icon_16x16.png"
  require_icon "icon_16x16@2x.png"
  require_icon "icon_32x32.png"
  require_icon "icon_32x32@2x.png"
  require_icon "icon_128x128.png"
  require_icon "icon_128x128@2x.png"
  require_icon "icon_256x256.png"
  require_icon "icon_256x256@2x.png"
  require_icon "icon_512x512.png"
  require_icon "icon_512x512@2x.png"

  echo
  echo "Preflight passed."
  echo "Next: run scripts/archive_app_store.sh with signing variables."
}

main "$@"
