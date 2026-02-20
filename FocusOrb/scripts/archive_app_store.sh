#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/FocusOrb.xcarchive}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_DIR/DerivedData}"

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM, e.g. ABCD123456}"
: "${APP_BUNDLE_ID:?Set APP_BUNDLE_ID, e.g. com.yourcompany.focusorb}"
: "${MARKETING_VERSION:?Set MARKETING_VERSION, e.g. 1.0.0}"
: "${BUILD_NUMBER:?Set BUILD_NUMBER, e.g. 1}"

"$ROOT_DIR/scripts/release_preflight.sh"
"$ROOT_DIR/scripts/generate_xcodeproj.rb"

extra_args=()
if [[ -n "${CODE_SIGNING_ALLOWED:-}" ]]; then
  extra_args+=("CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED")
fi
if [[ -n "${CODE_SIGNING_REQUIRED:-}" ]]; then
  extra_args+=("CODE_SIGNING_REQUIRED=$CODE_SIGNING_REQUIRED")
fi

xcodebuild \
  -project "$ROOT_DIR/FocusOrb.xcodeproj" \
  -scheme FocusOrb \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  PRODUCT_BUNDLE_IDENTIFIER="$APP_BUNDLE_ID" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon \
  CODE_SIGN_ENTITLEMENTS="$ROOT_DIR/FocusOrb.entitlements" \
  ENABLE_HARDENED_RUNTIME=YES \
  "${extra_args[@]}" \
  archive

echo
echo "Archive complete: $ARCHIVE_PATH"
echo "Open in Xcode Organizer and Distribute App -> App Store Connect."
