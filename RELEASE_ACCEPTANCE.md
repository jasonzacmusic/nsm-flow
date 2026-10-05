# NSM Flow release acceptance

Use the regular signed app and existing alpha delivery channel. Preserve settings, models, history and rollback packages.

Before publishing:

- Run frontend build, lint, formatting, unit tests and browser IPC-contract tests.
- Run native Rust tests and Clippy. Review dependency advisories against each shipped platform's dependency tree.
- Build Mac installers locally; sign, notarize and staple both the app and DMG with existing credentials. Windows retains its existing unsigned installer policy, with a signed updater payload.
- Verify each platform's version, source commit and final hashes with `scripts/verify-release.py`.
- Package the stapled apps with `COPYFILE_DISABLE=1`. Run the release archive checker, then verify the extracted app's signature, ticket and Gatekeeper assessment.
- Run `scripts/publish-update-feed.sh --prepare-only` to create the complete signed release set. Inspect it before publication. Never overwrite a published version.
- Publish the exact prepared bytes with `scripts/publish-update-feed.sh --publish-prepared`. This verifies signatures, checksums and immutable remote asset hashes without regenerating archives. Verify the live feed after GitHub Pages deploys.

Hands-on acceptance on the installed Mac app:

- Start and stop from the actual configured shortcut. Speak a normal paragraph, Indian names and a musical question; check interim text, final transcription and paste into a disposable document.
- Cancel a recording and cancel during transcription; confirm no late paste and that the next recording works.
- Check microphone denial/disconnection, a missing model and download cancellation; confirm visible recovery and successful retry.
- Verify local-only operation without cloud sign-in. Test OS-vault migration/replacement/removal using a disposable fixture, preserving any existing real credentials.
- Test transcript expiry and confirmed deletion using disposable history only; retain saved entries during automatic expiry.
- Upgrade an older supported installation using its actual update UI. Verify installed version, Gatekeeper, retained data and a working transcription afterward.

Microphone and Accessibility permission changes require Jason's approval at the actual OS prompt. Do not bypass TCC or grant broader access. Windows installation and package-content checks run in the existing Windows workflow; actual Windows audio/shortcut acceptance needs an available Windows device.

Record each result as passed, failed or unverified. A prepared installer, mock IPC test or synthetic audio fixture does not prove physical microphone quality. Shared catalogue changes go through Labs Platform. A browser edition is a separate product surface and requires genuine browser inference and device testing before it can be called complete.

The new NSM privacy and recovery labels use explicit English fallbacks in other locales, following the existing NSM translation policy. Key coverage passing does not mean native speakers have reviewed these new translations.
