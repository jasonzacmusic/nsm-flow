#!/bin/bash
# Build, sign, notarize, and staple a macOS release of NSM Flow.
#
# Why this exists: Tauri's own build only ad-hoc signs. An ad-hoc signed app
# downloaded from the internet carries a quarantine flag, and macOS refuses to
# open it with "NSM Flow is damaged and can't be opened" — which looks like a
# corrupt download to the person who just installed it. Gatekeeper only accepts
# a Developer ID signature plus an Apple notarization ticket.
#
# Run this on a Mac that has:
#   - the "Developer ID Application: Jason Zachariah (R3UNCZH45H)" identity in
#     the login keychain (security find-identity -v -p codesigning)
#   - a notarytool keychain profile (xcrun notarytool store-credentials)
#
# Usage:
#   scripts/release-macos.sh                              # host architecture
#   scripts/release-macos.sh x86_64-apple-darwin          # Intel
#
# Env overrides:
#   SIGN_IDENTITY   codesigning identity            (default: Developer ID for R3UNCZH45H)
#   NOTARY_PROFILE  notarytool keychain profile     (default: shruti-notary)
#   SKIP_NOTARIZE=1 sign only, skip Apple round-trip (for local smoke tests)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

TARGET="${1:-$(rustc -vV | awk '/^host: /{print $2}')}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Jason Zachariah (R3UNCZH45H)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-shruti-notary}"
TEAM_ID="R3UNCZH45H"

case "$TARGET" in
  aarch64-apple-darwin) ARCH_LABEL="Apple-Silicon" ;;
  x86_64-apple-darwin)  ARCH_LABEL="Intel" ;;
  *) echo "ERROR unsupported target: $TARGET" >&2; exit 1 ;;
esac

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------- preflight --
say "Preflight"
security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY" || {
  echo "ERROR signing identity not found in keychain: $SIGN_IDENTITY" >&2
  echo "      Available:" >&2
  security find-identity -v -p codesigning >&2
  exit 1
}
echo "identity   OK  $SIGN_IDENTITY"

if [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || {
    echo "ERROR notarytool profile '$NOTARY_PROFILE' is missing or invalid." >&2
    echo "      Create it with: xcrun notarytool store-credentials $NOTARY_PROFILE" >&2
    exit 1
  }
  echo "notary     OK  $NOTARY_PROFILE"
fi

VERSION=$(python3 -c "import json;print(json.load(open('src-tauri/tauri.conf.json'))['version'])")
echo "version    $VERSION"
echo "target     $TARGET ($ARCH_LABEL)"

# -------------------------------------------------------------------- build --
# APPLE_SIGNING_IDENTITY is what makes tauri-bundler codesign with a real
# identity. tauri.conf.json deliberately does NOT pin signingIdentity, because a
# value there wins over this variable and would force ad-hoc signing again.
say "Building (this takes a while)"
export APPLE_SIGNING_IDENTITY="$SIGN_IDENTITY"
export CMAKE_POLICY_VERSION_MINIMUM=3.5
bun run tauri build --target "$TARGET"

BUNDLE_DIR="$ROOT/src-tauri/target/$TARGET/release/bundle"
APP="$BUNDLE_DIR/macos/NSM Flow.app"
[ -d "$APP" ] || { echo "ERROR app bundle not produced at: $APP" >&2; exit 1; }

# ------------------------------------------------------------------ verify ---
say "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
SIG=$(codesign -dvv "$APP" 2>&1)
echo "$SIG" | grep -q "TeamIdentifier=$TEAM_ID" || {
  echo "ERROR app is not signed with team $TEAM_ID:" >&2; echo "$SIG" >&2; exit 1
}
echo "$SIG" | grep -q "flags=.*runtime" || {
  echo "ERROR hardened runtime is not enabled (notarization would be rejected)" >&2; exit 1
}
echo "signature  OK  Developer ID + hardened runtime"

if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
  say "SKIP_NOTARIZE=1 — stopping before the Apple round-trip"
  echo "$APP"
  exit 0
fi

# --------------------------------------------------------------- notarize ----
# Notarize and staple the .app itself, not just the disk image. A ticket stapled
# only to the DMG disappears the moment the app is dragged to /Applications, and
# the copied app then needs a live Apple lookup to launch — which fails offline.
say "Notarizing the app"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/nsm-flow-notarize.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto -c -k --keepParent "$APP" "$STAGE/app.zip"
xcrun notarytool submit "$STAGE/app.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
echo "app        OK  notarized + stapled"

# ------------------------------------------------------------------- image ---
# Rebuild the disk image around the stapled app. Tauri already produced one, but
# it contains the pre-staple app, so it is discarded here.
say "Building the disk image"
DMG_NAME="NSM-Flow-mac-$ARCH_LABEL.dmg"
DIST="$ROOT/dist-mac"
mkdir -p "$DIST"
DMG="$DIST/$DMG_NAME"
rm -f "$DMG"

IMG="$STAGE/image"
mkdir -p "$IMG"
ditto "$APP" "$IMG/NSM Flow.app"
ln -s /Applications "$IMG/Applications"
# Keep the volume icon Tauri's own DMG ships, when it produced one.
TAURI_DMG=$(ls -t "$BUNDLE_DIR"/dmg/*.dmg 2>/dev/null | head -1 || true)
if [ -n "$TAURI_DMG" ]; then
  MNT="$STAGE/mnt"; mkdir -p "$MNT"
  hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$TAURI_DMG" >/dev/null
  [ -f "$MNT/.VolumeIcon.icns" ] && cp "$MNT/.VolumeIcon.icns" "$IMG/.VolumeIcon.icns"
  hdiutil detach "$MNT" -quiet
  [ -f "$IMG/.VolumeIcon.icns" ] && SetFile -a C "$IMG" 2>/dev/null || true
fi

hdiutil create -volname "NSM Flow" -srcfolder "$IMG" -ov -format UDZO "$DMG" >/dev/null
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"

say "Notarizing the disk image"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# ------------------------------------------------------------------ assess ---
# The real test: what Gatekeeper says about a freshly downloaded copy.
say "Gatekeeper assessment"
spctl -a -vvv -t install "$DMG"
spctl -a -vvv -t exec "$APP"

say "Done"
echo "$DMG"
shasum -a 256 "$DMG"
