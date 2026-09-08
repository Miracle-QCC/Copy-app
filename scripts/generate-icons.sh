#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGE="${1:-$ROOT_DIR/Assets/AppIconSource.png}"
RESOURCE_DIR="$ROOT_DIR/Sources/ClipStack/Resources"
ICONSET_DIR="$(mktemp -d)/ClipStack.iconset"
PROCESSED_IMAGE="$(mktemp -d)/AppIcon.png"

cleanup() {
    rm -rf "$(dirname "$ICONSET_DIR")"
    rm -rf "$(dirname "$PROCESSED_IMAGE")"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_IMAGE" ]]; then
    echo "Icon source not found: $SOURCE_IMAGE" >&2
    exit 1
fi

mkdir -p "$RESOURCE_DIR" "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/remove-icon-background.swift" "$SOURCE_IMAGE" "$PROCESSED_IMAGE"
cp "$PROCESSED_IMAGE" "$RESOURCE_DIR/AppIcon.png"

create_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "$PROCESSED_IMAGE" \
        --out "$ICONSET_DIR/$filename" >/dev/null
}

create_icon 16 icon_16x16.png
create_icon 32 icon_16x16@2x.png
create_icon 32 icon_32x32.png
create_icon 64 icon_32x32@2x.png
create_icon 128 icon_128x128.png
create_icon 256 icon_128x128@2x.png
create_icon 256 icon_256x256.png
create_icon 512 icon_256x256@2x.png
create_icon 512 icon_512x512.png
create_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCE_DIR/ClipStack.icns"
echo "Generated $RESOURCE_DIR/ClipStack.icns"
