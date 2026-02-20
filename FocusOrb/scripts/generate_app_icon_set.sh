#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_IMAGE="${1:-$ROOT_DIR/photo/Gemini_Generated_Image_x3ccf5x3ccf5x3cc_alpha.png}"
OUT_DIR="$ROOT_DIR/Sources/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC_IMAGE" ]]; then
  echo "Source image not found: $SRC_IMAGE"
  exit 1
fi

mkdir -p "$OUT_DIR"
TMP_MASTER="$OUT_DIR/.icon_master_1024.png"

read -r width height < <(sips -g pixelWidth -g pixelHeight "$SRC_IMAGE" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END {print w, h}')
if [[ -z "${width:-}" || -z "${height:-}" ]]; then
  echo "Failed to read source image size."
  exit 1
fi

crop=$(( width < height ? width : height ))
sips -c "$crop" "$crop" "$SRC_IMAGE" --out "$TMP_MASTER" >/dev/null
sips -z 1024 1024 "$TMP_MASTER" --out "$TMP_MASTER" >/dev/null

make_icon() {
  local px="$1"
  local name="$2"
  sips -z "$px" "$px" "$TMP_MASTER" --out "$OUT_DIR/$name" >/dev/null
}

make_icon 16  icon_16x16.png
make_icon 32  icon_16x16@2x.png
make_icon 32  icon_32x32.png
make_icon 64  icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
cp "$TMP_MASTER" "$OUT_DIR/icon_512x512@2x.png"

rm -f "$TMP_MASTER"

cat > "$ROOT_DIR/Sources/Resources/Assets.xcassets/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat > "$OUT_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "AppIcon set generated at: $OUT_DIR"
