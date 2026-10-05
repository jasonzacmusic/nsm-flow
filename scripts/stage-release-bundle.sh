#!/bin/bash
# Assemble the publishable extras that sit next to the four installers:
# a SHA256SUMS file and the "complete" zip (source + docs + installers).
#
# These have to be regenerated whenever an installer changes. A stale
# SHA256SUMS is worse than none: someone who checksums a fresh download and
# compares it against last release's file concludes the download is corrupt.
#
# Expects dist-release/ to already hold the four final-named installers:
#   NSM-Flow-mac-Apple-Silicon.dmg   (signed + notarized by release-macos.sh)
#   NSM-Flow-mac-Intel.dmg           (signed + notarized by release-macos.sh)
#   NSM-Flow-windows-x64-setup.exe   (from the GitHub Actions Windows job)
#   NSM-Flow-windows-x64.msi         (from the GitHub Actions Windows job)
#
# Usage: scripts/stage-release-bundle.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DIST="$ROOT/dist-release"

VERSION=$(python3 -c "import json;print(json.load(open('src-tauri/tauri.conf.json'))['version'])")
BUNDLE="NSM-Flow-$VERSION"

INSTALLERS=(
  NSM-Flow-mac-Apple-Silicon.dmg
  NSM-Flow-mac-Intel.dmg
  NSM-Flow-windows-x64-setup.exe
  NSM-Flow-windows-x64.msi
  NSM-Flow-mac-Apple-Silicon.app.tar.gz
  NSM-Flow-mac-Apple-Silicon.app.tar.gz.sig
  NSM-Flow-mac-Intel.app.tar.gz
  NSM-Flow-mac-Intel.app.tar.gz.sig
  NSM-Flow-windows-x64-setup.exe.sig
)

for f in "${INSTALLERS[@]}"; do
  [ -f "$DIST/$f" ] || { echo "ERROR missing installer: $DIST/$f" >&2; exit 1; }
done

# Refuse to bundle a Mac DMG that never made it through notarization — that is
# the exact failure this release set out to fix.
for f in NSM-Flow-mac-Apple-Silicon.dmg NSM-Flow-mac-Intel.dmg; do
  xcrun stapler validate "$DIST/$f" >/dev/null 2>&1 \
    || { echo "ERROR $f has no notarization ticket; run scripts/release-macos.sh first" >&2; exit 1; }
done

python3 scripts/verify-release.py
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "ERROR commit the verified source before staging a release" >&2; exit 1; }

# Source archive straight from git, so it matches a commit rather than whatever
# happens to be in the working tree.
SOURCE_ZIP="$DIST/NSM-Flow-$VERSION-source.zip"
rm -f "$SOURCE_ZIP"
git archive --format=zip --prefix="NSM-Flow-$VERSION/" -o "$SOURCE_ZIP" HEAD
echo "source     $(basename "$SOURCE_ZIP") @ $(git rev-parse --short HEAD)"

cp "src/content/release-notes/$VERSION.md" "$DIST/RELEASE_NOTES.md"

# Checksums over everything a person can download individually.
SUMS="$DIST/NSM-Flow-$VERSION-SHA256SUMS.txt"
: > "$SUMS"
( cd "$DIST" && shasum -a 256 "${INSTALLERS[@]}" "NSM-Flow-$VERSION-source.zip" provenance-*.json nsm-flow.json >> "$SUMS" )

# The complete bundle: everything above plus the docs, for anyone who wants one
# download. Its own checksum goes into SHA256SUMS afterwards.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/nsm-flow-bundle.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/$BUNDLE"/{Installers,Source,Documents,Checksums}
for f in "${INSTALLERS[@]}"; do cp "$DIST/$f" "$STAGE/$BUNDLE/Installers/"; done
cp "$SOURCE_ZIP" "$STAGE/$BUNDLE/Source/"
cp "$DIST/RELEASE_NOTES.md" "$DIST/nsm-flow.json" "$DIST"/provenance-*.json "$STAGE/$BUNDLE/Documents/"
for d in README.md BUILD.md NOTICE.md LICENSE RELEASE_ACCEPTANCE.md NSM_FLOW_INTERN_QA_GUIDE.html \
         CLAUDE_CODE_AUDIT_REPORT.md CLAUDE_CODE_AUDIT_PROMPT.md; do
  [ -f "$d" ] && cp "$d" "$STAGE/$BUNDLE/Documents/"
done

{
  echo "NSM Flow $VERSION"
  echo "commit:    $(git rev-parse HEAD)"
  echo "branch:    $(git rev-parse --abbrev-ref HEAD)"
  echo "mac:       signed Developer ID Application: Jason Zachariah (R3UNCZH45H), notarized and stapled"
  echo "windows:   UNSIGNED — SmartScreen will warn; verify the SHA-256 below before running"
} > "$STAGE/$BUNDLE/Documents/VERSION_AND_PROVENANCE.txt"

( cd "$STAGE/$BUNDLE" && find Installers Source Documents -type f -print0 \
    | sort -z | xargs -0 shasum -a 256 > Checksums/BUNDLE-CONTENTS-SHA256.txt )

COMPLETE="$DIST/NSM-Flow-$VERSION-complete.zip"
rm -f "$COMPLETE"
( cd "$STAGE" && zip -q -r "$COMPLETE" "$BUNDLE" )
( cd "$DIST" && shasum -a 256 "$(basename "$COMPLETE")" >> "$SUMS" )

echo
echo "staged in $DIST:"
( cd "$DIST" && ls -la )
echo
cat "$SUMS"
