# Contributing to NSM Flow

NSM Flow welcomes fixes, platform reports, translation improvements and measured
speech-recognition results. This is an independent Handy fork maintained by
Nathaniel School of Music. Send NSM Flow issues and pull requests to
[jasonzacmusic/nsm-flow](https://github.com/jasonzacmusic/nsm-flow).

## Before changing code

1. Read [AGENTS.md](AGENTS.md), [BUILD.md](BUILD.md) and relevant existing issues.
2. For a larger feature, describe the problem in an issue before implementing it.
3. Fork the repo, make a focused branch, and keep unrelated changes separate.
4. Run the checks in BUILD.md and include the exact platforms actually tested.
5. Use the [PR template](.github/PULL_REQUEST_TEMPLATE.md), including AI assistance.

Use strict TypeScript, existing React patterns, `cargo fmt`, and explicit Rust
error handling. New visible strings belong in the English i18n source and use
`useTranslation`; see [translation instructions](CONTRIBUTING_TRANSLATIONS.md).
Do not add silent network transmission, default cloud dependence, or credentials
to source. Keep source recognition and optional formatting distinct.

## Useful contributions

- Physical Windows/Linux installation, microphone, shortcut and paste reports
- Indian English and Indian-language benchmarks with consented, shareable audio
- Model-license and download-integrity improvements
- Native-language review of the current English translation fallbacks
- Focused accessibility, packaging and dependency maintenance fixes

The [testing guide](docs/TESTING.md) lists the evidence needed. Synthetic audio,
mocked IPC and successful compilation must not be presented as real-user accuracy.

Use conventional commit messages such as `fix: restore paste after cancellation`.
By submitting code, you license your contribution under [MIT](LICENSE). Preserve
upstream notices and comply with third-party/model licenses. Do not use Nathaniel
branding to imply that a modified fork is an official release.

## Reporting bugs and security problems

Use [bug templates](https://github.com/jasonzacmusic/nsm-flow/issues/new/choose)
for ordinary bugs. Include OS/version/architecture, app version, selected model,
steps, expected behavior and what happened. Attach only sanitized logs and
recordings you have permission to share. Security-sensitive reports follow
[SECURITY.md](SECURITY.md).
