#!/bin/bash
# Sign the release artifacts for the auto-updater and publish the update feed.
#
# Tauri's updater trusts a minisign signature, not the installer's own code
# signature. Each platform artifact therefore needs a detached `.sig` produced
# with the NSM Flow updater private key, plus a JSON feed listing them.
#
# The key lives in the macOS login Keychain (via nsm-pass), never on disk and
# never in a repo. Its public half is pinned in tauri.conf.json, so a feed
# signed with any other key is rejected by every installed copy.
#
# Deliberately NOT using tauri.conf.json's `createUpdaterArtifacts`: that builds
# the macOS tarball at bundle time, which is before notarization, so the tarball
# would contain an app with no notarization ticket. This script archives the
# stapled app instead.
#
# Run AFTER scripts/release-macos.sh has produced notarized DMGs and the Windows
# installers have been staged into dist-release/.
#
# Usage: scripts/publish-update-feed.sh --prepare-only
#        scripts/publish-update-feed.sh --publish-prepared
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DIST="$ROOT/dist-release"
HUB="${LABS_DOWNLOADS:-$HOME/Documents/Claude/labs-downloads}"
TAURI="$ROOT/node_modules/.bin/tauri"
RELEASE_TAG=""
RELEASE_BASE=""
MODE="${1:-}"
case "$MODE" in
  ""|--prepare-only|--publish-prepared) ;;
  *) echo "ERROR expected --prepare-only or --publish-prepared" >&2; exit 1 ;;
esac

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

VERSION=$(python3 -c "import json;print(json.load(open('src-tauri/tauri.conf.json'))['version'])")

RELEASE_TAG="nsm-flow-v$VERSION"
RELEASE_BASE="https://github.com/jasonzacmusic/labs-downloads/releases/download/$RELEASE_TAG"

# ---------------------------------------------------------------- preflight --
say "Preflight"
python3 scripts/verify-release.py
[ -d "$HUB/.git" ] || { echo "ERROR labs-downloads checkout not found at $HUB" >&2; exit 1; }
[ -z "$(git -C "$HUB" status --porcelain)" ] || { echo "ERROR delivery checkout has concurrent changes; use a clean checkout" >&2; exit 1; }
git -C "$HUB" fetch -q origin main
[ "$(git -C "$HUB" rev-parse HEAD)" = "$(git -C "$HUB" rev-parse origin/main)" ] || { echo "ERROR delivery checkout must match origin/main" >&2; exit 1; }
[ -x "$TAURI" ] || { echo "ERROR tauri CLI missing — run: bun install" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "ERROR commit the verified source before preparing a release" >&2; exit 1; }

if [ "$MODE" != "--publish-prepared" ]; then

TAURI_SIGNING_PRIVATE_KEY=$(nsm-pass pass nsm-flow-updater-key 2>/dev/null || true)
TAURI_SIGNING_PRIVATE_KEY_PASSWORD=$(nsm-pass pass nsm-flow-updater-pass 2>/dev/null || true)
[ -n "$TAURI_SIGNING_PRIVATE_KEY" ] || {
  echo "ERROR updater private key not in the Keychain (nsm-pass get nsm-flow-updater-key)." >&2
  echo "      Without it no update can ever be published for the installed copies," >&2
  echo "      because they only trust the public key pinned in tauri.conf.json." >&2
  exit 1
}
export TAURI_SIGNING_PRIVATE_KEY TAURI_SIGNING_PRIVATE_KEY_PASSWORD
echo "key        OK  loaded from Keychain"
echo "version    $VERSION"

# The feed is worthless if the app it points at was never notarized.
for f in NSM-Flow-mac-Apple-Silicon.dmg NSM-Flow-mac-Intel.dmg; do
  [ -f "$DIST/$f" ] || { echo "ERROR missing $DIST/$f" >&2; exit 1; }
  xcrun stapler validate "$DIST/$f" >/dev/null 2>&1 \
    || { echo "ERROR $f is not notarized; run scripts/release-macos.sh first" >&2; exit 1; }
done
[ -f "$DIST/NSM-Flow-windows-x64-setup.exe" ] || {
  echo "ERROR missing $DIST/NSM-Flow-windows-x64-setup.exe" >&2; exit 1; }

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/nsm-flow-feed.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

# ------------------------------------------------------ macOS update bundles --
# The macOS updater replaces the .app in place, so it wants a gzipped tar of the
# bundle — taken here from inside the notarized DMG so the stapled ticket rides
# along and the updated copy still launches offline.
sign_and_record() {  # $1 = artifact path -> echoes the signature
  "$TAURI" signer sign "$1" >/dev/null 2>&1
  [ -f "$1.sig" ] || { echo "ERROR signing produced no .sig for $1" >&2; exit 1; }
  cat "$1.sig"
}

# Plain variables, not an associative array: macOS still ships bash 3.2, which
# has no `declare -A`.
SIG_ARM=""; SIG_X64=""; SIG_WIN=""

for label in Apple-Silicon Intel; do
  say "Packaging $label update bundle"
  MNT="$STAGE/mnt-$label"; mkdir -p "$MNT"
  hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DIST/NSM-Flow-mac-$label.dmg" >/dev/null
  xcrun stapler validate "$MNT/NSM Flow.app" >/dev/null 2>&1 || {
    hdiutil detach "$MNT" -quiet
    echo "ERROR the app inside NSM-Flow-mac-$label.dmg has no stapled ticket" >&2
    exit 1
  }
  APPDIR="$STAGE/app-$label"; mkdir -p "$APPDIR"
  ditto "$MNT/NSM Flow.app" "$APPDIR/NSM Flow.app"
  hdiutil detach "$MNT" -quiet

  TARBALL="$DIST/NSM-Flow-mac-$label.app.tar.gz"
  rm -f "$TARBALL" "$TARBALL.sig"
  COPYFILE_DISABLE=1 tar -czf "$TARBALL" -C "$APPDIR" "NSM Flow.app"
  CHECK="$STAGE/extracted-$label/NSM Flow.app"
  cargo run --quiet --manifest-path scripts/updater-archive-check/Cargo.toml -- "$TARBALL" "$CHECK"
  codesign --verify --deep --strict "$CHECK"
  xcrun stapler validate "$CHECK" >/dev/null
  spctl -a -t exec "$CHECK"
  SIG=$(sign_and_record "$TARBALL")
  case "$label" in
    Apple-Silicon) SIG_ARM="$SIG" ;;
    Intel)         SIG_X64="$SIG" ;;
  esac
  echo "signed     $(basename "$TARBALL")"
done

# ----------------------------------------------------- Windows update target --
# The Windows updater downloads and runs the NSIS installer directly, so the
# installer itself is the artifact and only needs a signature beside it.
say "Signing the Windows installer"
rm -f "$DIST/NSM-Flow-windows-x64-setup.exe.sig"
SIG_WIN=$(sign_and_record "$DIST/NSM-Flow-windows-x64-setup.exe")
echo "signed     NSM-Flow-windows-x64-setup.exe"

# ----------------------------------------------------------------- the feed --
say "Writing the feed"
NOTES=$(VERSION="$VERSION" python3 - <<'PYNOTES'
import os, pathlib
notes = pathlib.Path("src/content/release-notes") / (os.environ["VERSION"] + ".md")
if not notes.is_file(): raise SystemExit("Missing release notes for exact app version")
print(notes.read_text())
PYNOTES
)

PUB_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FEED="$DIST/nsm-flow.json"
VERSION="$VERSION" NOTES="$NOTES" PUB_DATE="$PUB_DATE" \
SIG_ARM="$SIG_ARM" URL_ARM="$RELEASE_BASE/NSM-Flow-mac-Apple-Silicon.app.tar.gz" \
SIG_X64="$SIG_X64" URL_X64="$RELEASE_BASE/NSM-Flow-mac-Intel.app.tar.gz" \
SIG_WIN="$SIG_WIN" URL_WIN="$RELEASE_BASE/NSM-Flow-windows-x64-setup.exe" \
python3 - "$FEED" <<'PY'
import json, os, sys
feed = {
    "version": os.environ["VERSION"],
    "notes": os.environ["NOTES"],
    "pub_date": os.environ["PUB_DATE"],
    "platforms": {
        "darwin-aarch64": {"signature": os.environ["SIG_ARM"], "url": os.environ["URL_ARM"]},
        "darwin-x86_64":  {"signature": os.environ["SIG_X64"], "url": os.environ["URL_X64"]},
        "windows-x86_64": {"signature": os.environ["SIG_WIN"], "url": os.environ["URL_WIN"]},
    },
}
with open(sys.argv[1], "w") as f:
    json.dump(feed, f, indent=2)
    f.write("\n")
PY
echo "feed       $FEED"

# --------------------------------------------------------------- publishing --
# Produce a complete, reviewable feed without publishing when requested.
bash scripts/stage-release-bundle.sh
fi

FEED="$DIST/nsm-flow.json"
python3 scripts/verify-release.py --prepared
if [ "$MODE" = "--prepare-only" ]; then
  say "Prepared signed artifacts and feed; publication remains pending"
  exit 0
fi

say "Publishing immutable release artifacts"
# Never clobber an existing version. An interrupted prior publish may resume
# only when every remote artifact has identical bytes (verified separately).
if gh release view "$RELEASE_TAG" --repo jasonzacmusic/labs-downloads >/dev/null 2>&1; then
  python3 scripts/verify-published-release.py
else
gh release create "$RELEASE_TAG" --repo jasonzacmusic/labs-downloads --title "NSM Flow $VERSION" \
  --notes-file "$DIST/RELEASE_NOTES.md" --prerelease --latest=false \
  "$DIST/NSM-Flow-mac-Apple-Silicon.dmg" "$DIST/NSM-Flow-mac-Intel.dmg" \
  "$DIST/NSM-Flow-windows-x64-setup.exe" "$DIST/NSM-Flow-windows-x64.msi" \
  "$DIST/NSM-Flow-mac-Apple-Silicon.app.tar.gz" "$DIST/NSM-Flow-mac-Apple-Silicon.app.tar.gz.sig" \
  "$DIST/NSM-Flow-mac-Intel.app.tar.gz" "$DIST/NSM-Flow-mac-Intel.app.tar.gz.sig" \
  "$DIST/NSM-Flow-windows-x64-setup.exe.sig" "$DIST/NSM-Flow-$VERSION-SHA256SUMS.txt" \
  "$DIST/NSM-Flow-$VERSION-source.zip" "$DIST/NSM-Flow-$VERSION-complete.zip" \
  "$DIST/provenance-aarch64-apple-darwin.json" "$DIST/provenance-x86_64-apple-darwin.json" \
  "$DIST/provenance-x86_64-pc-windows-msvc.json" "$FEED"
fi
python3 scripts/verify-published-release.py

say "Publishing the verified feed"
cp "$FEED" "$HUB/appcasts/nsm-flow.json"
if ! git -C "$HUB" diff --quiet -- appcasts/nsm-flow.json; then
  ( cd "$HUB" && git add appcasts/nsm-flow.json && git commit -m "appcast: NSM Flow $VERSION" && git push origin HEAD:main )
fi
say "Published"
