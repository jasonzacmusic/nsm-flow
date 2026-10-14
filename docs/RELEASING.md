# Maintainer releases

Keep public alpha labels until the physical-device matrix and recognition
benchmarks justify stable claims. Public source availability does not require
rebranding an unfinished feature as ready.

## Desktop builds

```sh
gh workflow run main-build.yml --ref <commit-or-branch> -f build_scope=all-platforms
# Other scopes: apple-silicon, windows-only, linux-only.
```

The workflow builds Apple silicon, Intel, Windows x64 and Ubuntu 22.04 Linux x64.
Linux packages must pass bundled-library checks and isolated Xvfb native launch
checks. Those checks do not prove microphone or Wayland behavior on a real device.
Mac binaries are built/signed/notarized locally with established credentials;
Windows retains the documented unsigned-alpha policy.

For the established Mac/Windows delivery transaction, follow
[RELEASE_ACCEPTANCE.md](../RELEASE_ACCEPTANCE.md) and these existing tools:

```sh
scripts/release-macos.sh aarch64-apple-darwin
scripts/release-macos.sh x86_64-apple-darwin
scripts/publish-update-feed.sh --prepare-only
scripts/publish-update-feed.sh --publish-prepared
```

Read each script's environment/prebuilt requirements first. Do not improvise
credentials, print keys, overwrite published package bytes, or change the pinned
updater key. A lost updater private key requires an explicit recovery plan.

## Public GitHub downloads

Mirror only the exact accepted, checksum-verified Mac/Windows installer bytes
into this repository's matching prerelease. Keep the existing Labs feed and
immutable release available for installed users. Publish new Linux package names,
SHA-256 checksums and source/build provenance with an explicit Linux alpha label.
Do not silently claim Linux automatic updates: the current feed has Mac/Windows
payloads only, so Linux upgrades are manual until signed Linux updater artifacts
are implemented and tested.

Use version-specific release links. `labs-downloads/releases/latest` is shared
with other products and can point to an unrelated release. When adding a packaging
revision, use a distinct prerelease tag and record the application version and
source commit; do not replace prior assets. Verify each public download without
GitHub authentication and compare its hash to the accepted file.

Update README, installation docs, audit evidence, release notes and applicable
catalogue metadata together. Preserve the user's installed official version and
data; do not force-quit an active dictation or unrelated audio session. A source
push, CI dispatch, or mocked test is not proof of a successful installation.
