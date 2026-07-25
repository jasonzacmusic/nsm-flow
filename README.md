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
- app-aware writing modes for email, WhatsApp, AI prompts, documents, code,
  and music software
- local musical typing that converts spoken accidentals into real Unicode
  notation: B♭, F♯, C♮, B𝄫, and C𝄪
- stronger email formatting with safe paragraph, list, subject, greeting, and
  sign-off rules
- optional local LLM formatting through any OpenAI-compatible server
- Google team identity with PKCE and a localhost callback
- local text history with source-audio storage disabled by default
- safe, review-first migration of vocabulary learned by Wispr Flow

No transcript, recording, or Google token is uploaded to Nathaniel by the
desktop app. Google sign-in stores only the verified name and email locally.

## Status

Version `0.2.0` is an internal Nathaniel alpha. The desktop OAuth client ID,
Apple signing identity, and Windows signing certificate must be supplied by
Nathaniel before trusted employee installers can be distributed. Unsigned CI
artifacts are suitable for internal testing.

Android is intentionally deferred until the desktop push-to-talk workflow and
Indian-name benchmark are stable.

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
