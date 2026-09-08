#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-1.2.3}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ClipStackNotary}"
DMG_PATH="$ROOT_DIR/dist/ClipStack-$VERSION.dmg"

if [[ -z "$SIGN_IDENTITY" ]]; then
    cat >&2 <<'MESSAGE'
Missing SIGN_IDENTITY.

Set it to the full name of a Developer ID Application certificate, for example:
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
MESSAGE
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "$SIGN_IDENTITY"; then
    echo "Signing identity not found in the login keychain: $SIGN_IDENTITY" >&2
    exit 1
fi

SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT_DIR/scripts/build-dmg.sh" "$VERSION"

xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess \
    --type open \
    --context context:primary-signature \
    --verbose=4 \
    "$DMG_PATH"

echo "Built, notarized, and verified $DMG_PATH"
