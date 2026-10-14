# NSM Flow

**Free, open-source voice dictation with local speech recognition and Indian vocabulary support.**

Speak into your microphone and paste the result into the app you are using.
NSM Flow is a desktop app from Nathaniel School of Music, built on
[Handy](https://github.com/cjpais/Handy). It runs speech models on your computer;
no subscription, account, or paid API is required for dictation.

**Public alpha: 0.3.0-alpha.3.** macOS and Windows downloads are available now.
Linux packaging is being verified; see the [audit](docs/AUDIT-2026-10-14.md) for
actual evidence and remaining device tests. This is desktop software, not an
iOS, Android, or browser app.

## Download and install

| Computer                             | Download                                                                                                                                                                                                                                                          | Status                               |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| Mac with Apple silicon (M1 or newer) | [DMG](https://github.com/jasonzacmusic/labs-downloads/releases/download/nsm-flow-v0.3.0-alpha.3/NSM-Flow-mac-Apple-Silicon.dmg)                                                                                                                                   | Signed and Apple notarized           |
| Intel Mac                            | [DMG](https://github.com/jasonzacmusic/labs-downloads/releases/download/nsm-flow-v0.3.0-alpha.3/NSM-Flow-mac-Intel.dmg)                                                                                                                                           | Signed and Apple notarized           |
| Windows x64                          | [Setup EXE](https://github.com/jasonzacmusic/labs-downloads/releases/download/nsm-flow-v0.3.0-alpha.3/NSM-Flow-windows-x64-setup.exe) · [MSI](https://github.com/jasonzacmusic/labs-downloads/releases/download/nsm-flow-v0.3.0-alpha.3/NSM-Flow-windows-x64.msi) | Unsigned alpha; SmartScreen may warn |
| Linux x64                            | [Build instructions](BUILD.md#linux)                                                                                                                                                                                                                              | Packaged alpha pending verification  |

Read the **[installation guide](docs/INSTALLATION.md)** for setup, model choice,
permissions, checksums, and troubleshooting. Download checksums from the
[matching release](https://github.com/jasonzacmusic/labs-downloads/releases/tag/nsm-flow-v0.3.0-alpha.3).
The links above use a specific release because `labs-downloads/releases/latest`
can point to a different Nathaniel product.

## Indian names and music

- A bundled India vocabulary covers names, places, food, clothing, institutions,
  and music terms. Add your own words in Settings.
- Multilingual Whisper models support multiple Indian languages; choose a model
  that supports your language. English-only Parakeet models cannot transcribe Hindi.
- Spoken music notation becomes compact text, including B♭, F♯, B♭maj7, G7♭9,
  Dø7, A/C♯, 6/8, and ♩ = 120.
- Writing modes adapt formatting for email, WhatsApp, notes, prompts, code, and
  music software. Rules run locally; an optional LLM can perform further cleanup.

Indian vocabulary support means spelling hints and corrections. It does not
mean we trained a new speech model or proved equal accuracy across every Indian
accent, language, or code-switched sentence. Help measure those results with the
[testing guide](docs/TESTING.md).

## Privacy and AI

Speech recognition runs locally after you download a model. Text history is
stored locally; source audio retention defaults to immediate deletion after
processing. History controls let you clear stored text or turn retention off.
Temporary audio and logs can still contain sensitive data; local storage is not
encrypted by this app.

The default optional formatter points to a local server and falls back to local
rules when no LLM model is configured. If you select a cloud provider or a remote
custom server, **transcript text is sent there** and provider charges may apply.
Google team sign-in is optional and requires an administrator-configured OAuth
client. It is unnecessary for public dictation.

Model downloads and update checks use the network. You can disable update checks
for offline use; upgrades require your approval and wait for active dictation to
finish. Read the [privacy guide](docs/PRIVACY.md) and
[model/license guide](docs/MODELS.md) before selecting optional services.

## Open source and contributing

Application source, including NSM additions, is licensed under [MIT](LICENSE).
The retained Handy attribution is in [NOTICE.md](NOTICE.md). Downloaded model
weights and bundled dependencies have their own licenses; some catalog models
have noncommercial or custom terms. MIT does not relicense those weights or grant
rights to imply Nathaniel endorsement of a fork.

- [Build from source](BUILD.md)
- [Contribute code or documentation](CONTRIBUTING.md)
- [Report a bug](https://github.com/jasonzacmusic/nsm-flow/issues/new/choose)
- [Security reporting](SECURITY.md)
- [Complete audit and improvement priorities](docs/AUDIT-2026-10-14.md)
- [Maintainer release process](docs/RELEASING.md)

`package.json` uses `private: true` to prevent accidental npm publication. It does
not restrict the public GitHub source or the MIT license.
