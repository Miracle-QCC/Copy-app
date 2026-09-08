#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipStack"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS_DIR/MacOS/$APP_NAME"
cp "$ROOT_DIR/Sources/ClipStack/Resources/ClipStack.icns" "$CONTENTS_DIR/Resources/ClipStack.icns"
cp "$ROOT_DIR/Sources/ClipStack/Resources/AppIcon.png" "$CONTENTS_DIR/Resources/AppIcon.png"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>ClipStack</string>
    <key>CFBundleExecutable</key>
    <string>ClipStack</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.clipstack</string>
    <key>CFBundleIconFile</key>
    <string>ClipStack.icns</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ClipStack</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION:-1.2.3}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_DIR"
    echo "Warning: built with an ad-hoc signature; other Macs will show a Gatekeeper warning." >&2
else
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --entitlements "$ROOT_DIR/Config/ClipStack.entitlements" \
        --sign "$SIGN_IDENTITY" \
        "$APP_DIR"
fi

codesign --verify --deep --strict "$APP_DIR"
echo "Built $APP_DIR"
