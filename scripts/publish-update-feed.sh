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
# Usage: scripts/publish-update-feed.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DIST="$ROOT/dist-release"
HUB="${LABS_DOWNLOADS:-$HOME/Documents/Claude/labs-downloads}"
TAURI="$ROOT/node_modules/.bin/tauri"
RELEASE_BASE="https://github.com/jasonzacmusic/labs-downloads/releases/latest/download"

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

VERSION=$(python3 -c "import json;print(json.load(open('src-tauri/tauri.conf.json'))['version'])")

# ---------------------------------------------------------------- preflight --
say "Preflight"
[ -x "$TAURI" ] || { echo "ERROR tauri CLI missing — run: bun install" >&2; exit 1; }
[ -d "$HUB/.git" ] || { echo "ERROR labs-downloads checkout not found at $HUB" >&2; exit 1; }

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
  tar -czf "$TARBALL" -C "$APPDIR" "NSM Flow.app"
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
NOTES=$(python3 - <<'PY'
import pathlib, re

FALLBACK = "See the Nathaniel Labs downloads page for what changed."
version_re = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")  # README.md and friends must not match

notes = [
    f for f in pathlib.Path("src/content/release-notes").glob("*.md")
    if version_re.match(f.stem)
]
if not notes:
    print(FALLBACK)
else:
    newest = max(notes, key=lambda f: tuple(int(x) for x in version_re.match(f.stem).groups()))
    heads = [
        line[3:].strip()
        for line in newest.read_text().splitlines()
        if line.startswith("## ")
    ]
    print("; ".join(heads[:3]) if heads else FALLBACK)
PY
)

PUB_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FEED="$HUB/appcasts/nsm-flow.json"
mkdir -p "$HUB/appcasts"
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
say "Uploading update artifacts"
gh release upload downloads \
  "$DIST/NSM-Flow-mac-Apple-Silicon.app.tar.gz" \
  "$DIST/NSM-Flow-mac-Apple-Silicon.app.tar.gz.sig" \
  "$DIST/NSM-Flow-mac-Intel.app.tar.gz" \
  "$DIST/NSM-Flow-mac-Intel.app.tar.gz.sig" \
  "$DIST/NSM-Flow-windows-x64-setup.exe.sig" \
  --repo jasonzacmusic/labs-downloads --clobber

say "Publishing the feed"
( cd "$HUB" \
  && git pull --rebase --autostash -q origin main \
  && git add appcasts/nsm-flow.json \
  && git commit -q -m "appcast: NSM Flow $VERSION" \
  && git push -q origin main ) || echo "(feed unchanged)"

say "Done"
cat "$FEED"
