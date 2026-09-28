# NSM Flow

Free, local-first voice dictation for the Nathaniel School of Music team.

Hold the shortcut, speak, and release. NSM Flow transcribes on the computer and
pastes the result into the active app. It is built for English with Indian names
and music terminology, and it changes its writing mode for email, WhatsApp,
AI prompts, documents, and code.

## MVP features

- macOS and Windows desktop apps built with Tauri, Rust, and React
- push-to-talk by default (`Fn` on macOS, `Ctrl+Space` on Windows)
- fully local Whisper-family and Parakeet speech recognition
- seeded NSM vocabulary including Inchara, Chitra, Chandana, Arnabi,
  Melakarta, Konnakol, Nathaniel School of Music, and NSM
- a versioned, conservative India lexicon covering spellings for cities,
  clothing, food, deities and sacred names, temples, schools, colleges,
  universities, institutes, and names from across the country
- app-aware writing modes for email, WhatsApp, AI prompts, documents, code,
  and music software
- local musical typing that converts spoken accidentals into real Unicode
  notation: B♭, F♯, C♮, B𝄫, and C𝄪
- compact chord typing for extensions, alterations, suspensions, diminished
  and half-diminished chords, slash chords, time signatures, tempo marks, and
  explicit note/rest symbols: B♭maj7, G7♭9, Dø7, A/C♯, 6/8, and ♩ = 120
- stronger email formatting with safe paragraph, list, subject, greeting, and
  sign-off rules
- optional local LLM formatting through any OpenAI-compatible server
- Google team identity with PKCE and a localhost callback
- local text history with source-audio storage disabled by default
- safe, review-first migration of vocabulary learned by Wispr Flow

No transcript, recording, or Google token is uploaded to Nathaniel by the
desktop app. Google sign-in stores only the verified name and email locally.

## Downloads

Nathaniel Labs keeps stable URLs for the newest public alpha:

- [Mac — Apple silicon](https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-mac-Apple-Silicon.dmg)
- [Mac — Intel](https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-mac-Intel.dmg)
- [Windows — Setup EXE](https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-windows-x64-setup.exe)
- [Windows — MSI](https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-windows-x64.msi)
- [Complete installer and QA bundle](https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-0.3.0-alpha.1-complete.zip)
- [SHA-256 checksums](https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-0.3.0-alpha.1-SHA256SUMS.txt)

### Installing on macOS

Open the disk image and drag NSM Flow to Applications. The app is signed with
Nathaniel School of Music's Apple Developer ID and notarized by Apple, so it
opens normally — no "damaged" warning and no right-click workaround.

On first launch macOS asks for **microphone** access (to hear you) and
**accessibility** access (to send the transcribed text to whatever app you are
typing in). Both are required; the app walks you through them.

### Installing on Windows

Windows installers are **not yet code-signed**, so SmartScreen shows
"Windows protected your PC" the first time you run one. To install anyway:
click **More info**, then **Run anyway**. Verify the download against the
SHA-256 checksums above first if you want to be certain the file is intact.
See [`WINDOWS_SIGNING.md`](WINDOWS_SIGNING.md) for what it would take to remove
that warning.

Use the Setup EXE unless you specifically need the MSI for managed deployment.
The Setup EXE also offers a portable install that keeps all data in a `Data`
folder next to the app.

## Status

Version `0.3.0-alpha.1` is a free Nathaniel Labs public alpha. Employee login is
optional and is not required for local dictation.

- **macOS** — signed and notarized. Verified end to end from a quarantined
  download: Gatekeeper reports `source=Notarized Developer ID`.
- **Windows** — unsigned. Every user sees a SmartScreen warning until Nathaniel
  buys a code-signing certificate; see [`WINDOWS_SIGNING.md`](WINDOWS_SIGNING.md).
  Nothing else about the Windows build is blocked by this.
- **Automatic updates** — live. The app checks a signed feed and can install the
  next version itself on both platforms.
- **Google sign-in** — still needs a desktop OAuth client ID from Nathaniel.
  Dictation works fully without it.

Accuracy against real accents, and cross-app paste behaviour, still need the
intern test matrix on physical Mac and Windows computers before this is
described as fully proven.

Android is intentionally deferred until the desktop push-to-talk workflow and
Indian-name benchmark are stable.

## Releasing

Installers are built by GitHub Actions and signed on a Mac that holds the
Developer ID:

```text
gh workflow run main-build.yml --ref <branch> -f build_scope=all-platforms
gh run download <run-id>
PREBUILT_APP="nsm-flow-alpha-aarch64-apple-darwin/macos/NSM Flow.app" \
  scripts/release-macos.sh aarch64-apple-darwin
PREBUILT_APP="nsm-flow-alpha-x86_64-apple-darwin/macos/NSM Flow.app" \
  scripts/release-macos.sh x86_64-apple-darwin
scripts/stage-release-bundle.sh
NSM_FLOW_ONLY=1 ~/Documents/Claude/labs-downloads/publish.sh
scripts/publish-update-feed.sh
```

`release-macos.sh` refuses to continue unless the signing identity and the
notarytool keychain profile are both present, and it checks the Gatekeeper
verdict at the end rather than assuming success.

`publish-update-feed.sh` signs each artifact with the updater key and publishes
the feed that installed copies check. The updater trusts a minisign signature,
not the installer's own code signature, and the matching public key is pinned in
`tauri.conf.json` — so a feed signed with any other key is rejected. The private
key lives only in the macOS login Keychain (`nsm-pass get nsm-flow-updater-key`);
**if it is lost, no existing installation can ever be updated again.**

## Development

The source is available for audit and internal collaboration. See
[`BUILD.md`](BUILD.md) for platform dependencies and build details.

Useful checks:

```text
bun install
bun run build
bun run lint
bun run format:check
cd src-tauri && cargo fmt --check && cargo test
```

Google sign-in is enabled at build time with
`NSM_FLOW_GOOGLE_CLIENT_ID`. An optional
`NSM_FLOW_ALLOWED_EMAIL_DOMAIN` restricts sign-in to a Google Workspace
domain. Client IDs are public identifiers; no OAuth client secret is bundled.

The vocabulary migration utility reads only Wispr Flow's local `Dictionary`
table in read-only mode. It excludes dictation history, recordings, snippets,
URLs, email addresses, phone-like numbers, and long message text.

## Open-source foundation

NSM Flow began as a fork of
[Handy](https://github.com/cjpais/Handy), whose application code is MIT
licensed. The original Handy name, logo, and visual identity are not used.
The retained MIT license and copyright notice apply to the upstream code.

Additional technical inspiration came from
[OpenWhispr](https://github.com/HeroTools/open-whispr),
[OpenLess](https://github.com/Open-Less/openless), and
[FreeFlow](https://github.com/zachlatta/freeflow).

NSM Flow application additions are developed for Nathaniel School of Music.
