#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_NAME="${DIST_NAME:-FocusOrb-macOS-test-unsigned}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/build/test-distribution}"
PAYLOAD_DIR="$OUT_DIR/$DIST_NAME"
ARCHIVE_PATH="${ARCHIVE_PATH:-$OUT_DIR/FocusOrb.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUT_DIR/DerivedData}"
APP_NAME="FocusOrb.app"
APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
APP_IN_PAYLOAD="$PAYLOAD_DIR/$APP_NAME"
DMG_PATH="$OUT_DIR/$DIST_NAME.dmg"
ZIP_PATH="$OUT_DIR/$DIST_NAME.zip"
README_TEMPLATE="$ROOT_DIR/scripts/README-在其它Mac运行.md"
OPEN_SCRIPT_TEMPLATE="$ROOT_DIR/scripts/open_after_download.command"
VALIDATION_PATH="$OUT_DIR/VALIDATION-打包机结果.txt"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "[FAIL] Missing required file: $path"
    exit 1
  fi
}

echo "== FocusOrb unsigned test distribution =="
echo "Root: $ROOT_DIR"
echo "Output: $OUT_DIR"
echo

require_file "$README_TEMPLATE"
require_file "$OPEN_SCRIPT_TEMPLATE"

rm -rf "$OUT_DIR"
mkdir -p "$PAYLOAD_DIR"

"$ROOT_DIR/scripts/release_preflight.sh"
"$ROOT_DIR/scripts/generate_xcodeproj.rb"

echo
echo "== Building release archive (unsigned) =="
xcodebuild \
  -project "$ROOT_DIR/FocusOrb.xcodeproj" \
  -scheme FocusOrb \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ENABLE_HARDENED_RUNTIME=YES \
  archive

if [[ ! -d "$APP_IN_ARCHIVE" ]]; then
  echo "[FAIL] Missing app in archive: $APP_IN_ARCHIVE"
  exit 1
fi

ditto "$APP_IN_ARCHIVE" "$APP_IN_PAYLOAD"
cp "$README_TEMPLATE" "$PAYLOAD_DIR/README-在其它Mac运行.md"
cp "$OPEN_SCRIPT_TEMPLATE" "$PAYLOAD_DIR/open_after_download.command"
chmod +x "$PAYLOAD_DIR/open_after_download.command"
ln -s /Applications "$PAYLOAD_DIR/Applications"

{
  echo "FocusOrb unsigned test package validation"
  echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo
  echo "== codesign -dv --verbose=4 =="
  codesign -dv --verbose=4 "$APP_IN_PAYLOAD" 2>&1 || true
  echo
  echo "== spctl -a -vv =="
  spctl -a -vv "$APP_IN_PAYLOAD" 2>&1 || true
  echo
  echo "== xattr -l (packaging machine) =="
  xattr -l "$APP_IN_PAYLOAD" 2>&1 || true
  echo
  echo "Note: quarantine xattrs are usually added on the receiver machine after download."
} > "$VALIDATION_PATH"

cp "$VALIDATION_PATH" "$PAYLOAD_DIR/VALIDATION-打包机结果.txt"

echo
echo "== Creating ZIP =="
ditto -c -k --sequesterRsrc --keepParent "$PAYLOAD_DIR" "$ZIP_PATH"

echo
echo "== Creating DMG =="
hdiutil create \
  -volname "FocusOrb Test" \
  -srcfolder "$PAYLOAD_DIR" \
  -format UDZO \
  "$DMG_PATH"

echo
echo "Done."
echo "- DMG: $DMG_PATH"
echo "- ZIP: $ZIP_PATH"
echo "- Validation: $VALIDATION_PATH"
