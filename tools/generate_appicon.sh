#!/bin/zsh
set -euo pipefail
SRC_IMAGE=${1:-IconSource.png}
FUZZ=${2:-10}
APPICON_DIR="Assets.xcassets/AppIcon.appiconset"
BASE_PNG="$APPICON_DIR/icon-base.png"

if [ ! -f "$SRC_IMAGE" ]; then
  echo "Source image not found: $SRC_IMAGE" >&2
  echo "Place your image at $SRC_IMAGE and re-run." >&2
  exit 1
fi

/usr/bin/xcrun swift tools/white_to_alpha.swift "$SRC_IMAGE" "$BASE_PNG" "$FUZZ"

function mk() {
  local size="$1" ; local scale="$2" ; local px
  if [ "$scale" = "1x" ]; then px=$size; else px=$((size*2)); fi
  local out
  case "$size-$scale" in
    16-1x) out="$APPICON_DIR/icon_16x16.png";;
    16-2x) out="$APPICON_DIR/icon_16x16@2x.png";;
    32-1x) out="$APPICON_DIR/icon_32x32.png";;
    32-2x) out="$APPICON_DIR/icon_32x32@2x.png";;
    128-1x) out="$APPICON_DIR/icon_128x128.png";;
    128-2x) out="$APPICON_DIR/icon_128x128@2x.png";;
    256-1x) out="$APPICON_DIR/icon_256x256.png";;
    256-2x) out="$APPICON_DIR/icon_256x256@2x.png";;
    512-1x) out="$APPICON_DIR/icon_512x512.png";;
    512-2x) out="$APPICON_DIR/icon_512x512@2x.png";;
  esac
  /usr/bin/sips -s format png -z "$px" "$px" "$BASE_PNG" --out "$out" >/dev/null
}

mk 16 1x; mk 16 2x; mk 32 1x; mk 32 2x; mk 128 1x; mk 128 2x; mk 256 1x; mk 256 2x; mk 512 1x; mk 512 2x

echo "AppIcon images generated in $APPICON_DIR"
