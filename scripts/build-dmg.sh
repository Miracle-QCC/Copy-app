#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipStack"
VERSION="${1:-1.2.3}"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$(mktemp -d)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

APP_VERSION="$VERSION" SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT_DIR/scripts/build-app.sh"

cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo "Built $DMG_PATH"
