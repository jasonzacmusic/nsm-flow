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
#   # Normal release: sign the app CI already built (both architectures).
#   gh run download <run-id> -R jasonzacmusic/nsm-flow
#   PREBUILT_APP="nsm-flow-alpha-aarch64-apple-darwin/macos/NSM Flow.app" \
#     scripts/release-macos.sh aarch64-apple-darwin
#
#   # Or build from source, for the host architecture only.
#   scripts/release-macos.sh
#
# Env overrides:
#   PREBUILT_APP    unsigned .app to sign instead of building from source
#   VOLUME_ICON_DMG DMG to lift the volume icon from (defaults to Tauri's own)
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

# ---------------------------------------------------------- build or adopt --
# Two ways in. PREBUILT_APP takes an unsigned .app that CI already produced and
# signs it here; that is the normal release path, because CI builds both Mac
# architectures reliably and only this Mac holds the Developer ID. With no
# PREBUILT_APP the script builds from source instead, which only works for the
# architecture of the machine it runs on.
WORK=""
if [ -n "${PREBUILT_APP:-}" ]; then
  [ -d "$PREBUILT_APP" ] || { echo "ERROR PREBUILT_APP is not a directory: $PREBUILT_APP" >&2; exit 1; }
  say "Signing a prebuilt app"
  echo "source     $PREBUILT_APP"
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/nsm-flow-sign.XXXXXX")"
  APP="$WORK/NSM Flow.app"
  ditto "$PREBUILT_APP" "$APP"
  BUNDLE_DIR=""

  # Sign inside-out: nested code must be signed before the bundle that seals it,
  # or the outer signature is invalidated the moment the inner one is replaced.
  # The Intel build ships libonnxruntime in Contents/Frameworks.
  while IFS= read -r nested; do
    [ -n "$nested" ] || continue
    echo "  nested   $(basename "$nested")"
    codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$nested"
  done < <(find "$APP/Contents/Frameworks" -type f \( -name '*.dylib' -o -name '*.so' \) 2>/dev/null || true)

  codesign --force --timestamp --options runtime \
    --entitlements "$ROOT/src-tauri/Entitlements.plist" \
    --sign "$SIGN_IDENTITY" "$APP"
else
  # APPLE_SIGNING_IDENTITY is what makes tauri-bundler codesign with a real
  # identity. tauri.conf.json deliberately does NOT pin signingIdentity, because
  # a value there wins over this variable and would force ad-hoc signing again.
  say "Building from source (this takes a while)"
  export APPLE_SIGNING_IDENTITY="$SIGN_IDENTITY"
  export CMAKE_POLICY_VERSION_MINIMUM=3.5
  bun run tauri build --target "$TARGET"

  BUNDLE_DIR="$ROOT/src-tauri/target/$TARGET/release/bundle"
  APP="$BUNDLE_DIR/macos/NSM Flow.app"
  [ -d "$APP" ] || { echo "ERROR app bundle not produced at: $APP" >&2; exit 1; }
fi

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

# Guard against labelling an arm64 build "Intel" (or the reverse) when the app
# came from CI and the target was passed by hand.
EXPECT_ARCH=${TARGET%%-*}
ACTUAL_ARCH=$(lipo -archs "$APP/Contents/MacOS/nsm-flow" 2>/dev/null || echo unknown)
case "$EXPECT_ARCH:$ACTUAL_ARCH" in
  aarch64:*arm64*|x86_64:*x86_64*) echo "arch       OK  $ACTUAL_ARCH" ;;
  *) echo "ERROR target says $EXPECT_ARCH but the binary is $ACTUAL_ARCH" >&2; exit 1 ;;
esac

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
trap 'rm -rf "$STAGE" "${WORK:-/nonexistent}"' EXIT
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
DIST="$ROOT/dist-release"
mkdir -p "$DIST"
DMG="$DIST/$DMG_NAME"
rm -f "$DMG"

IMG="$STAGE/image"
mkdir -p "$IMG"
ditto "$APP" "$IMG/NSM Flow.app"
ln -s /Applications "$IMG/Applications"
# Keep the volume icon Tauri's own DMG ships, when it produced one. VOLUME_ICON
# lets the CI path point at the icon inside the artifact's unsigned DMG.
TAURI_DMG="${VOLUME_ICON_DMG:-}"
if [ -z "$TAURI_DMG" ] && [ -n "$BUNDLE_DIR" ]; then
  TAURI_DMG=$(ls -t "$BUNDLE_DIR"/dmg/*.dmg 2>/dev/null | head -1 || true)
fi
if [ -n "$TAURI_DMG" ] && [ -f "$TAURI_DMG" ]; then
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
