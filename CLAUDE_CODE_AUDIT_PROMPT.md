# NSM Flow 0.3.0-alpha.1 — Independent Claude Code Audit and Fix Brief

You are the independent release auditor for **NSM Flow**, a free local-first
speech-to-text desktop app for Nathaniel School of Music. Work directly in:

`/Users/nphmacmini/Documents/New project/nsm-flow`

Do not merely review or describe problems. Inspect the implementation, fix every
safe in-scope blocker you find, run the relevant checks, and leave the working
tree in a release-ready state.

## Product goal

NSM Flow is a free alternative to Wispr Flow for Nathaniel School of Music staff.
The first release targets:

- macOS Apple silicon
- macOS Intel
- Windows x64

Employee login is **not required** for this release. Core recording,
transcription, correction, writing-mode formatting, and paste must work without
sign-in. Any Google sign-in UI must remain optional and must not block local use.

The app is based on the MIT-licensed Handy project. Preserve its license and
attribution. Do not copy proprietary Wispr Flow code, assets, or data.

## Release-candidate changes to audit

1. Musical typing:
   - Unicode accidentals: `♭`, `♯`, `♮`, `𝄪`, `𝄫`
   - Chords such as `B♭maj7`, `E♭m7`, `F♯7`, `G7♭9`, `C♯°7`, `Dø7`
   - Sus, add, power, diminished, augmented, altered, and slash chords
   - Time signatures such as `6/8` and `7/4`
   - Tempo marks such as `♩ = 120` and `♩. = 96`
   - Common note/rest symbols where explicitly dictated
   - Ordinary prose must not be corrupted. For example, “A major problem caused
     a minor delay” must remain prose.

2. India-aware spelling:
   - Indian personal names across regions and communities
   - Indian cities and regions
   - Indian clothing and textiles
   - Indian foods and drinks
   - Indian deities, traditions, temples, shrines, and pilgrimage sites
   - Indian schools, colleges, universities, and institutes
   - Multi-word terms must be corrected conservatively.
   - False corrections are a release blocker. Common English words such as
     “does” must never be changed to “dosa”.
   - The bundled lexicon is
     `src-tauri/resources/lexicons/india-core.txt`.

3. Cross-app writing modes:
   - General, email, prompt, chat/WhatsApp, notes, and music modes must preserve
     intended meaning while formatting appropriately.
   - Music tokens must survive both local correction and optional LLM
     post-processing.

4. Local-first and zero mandatory usage cost:
   - Core transcription must work with local models.
   - No mandatory cloud API, employee account, subscription, or paid service may
     be introduced.
   - Custom vocabulary must work across all supported local transcription
     engines.
   - Any model prompt must remain bounded; do not inject an unbounded lexicon.

## Files that need especially careful inspection

- `src-tauri/src/writing_mode.rs`
- `src-tauri/src/audio_toolkit/text.rs`
- `src-tauri/src/managers/transcription.rs`
- `src-tauri/src/settings.rs`
- `src-tauri/resources/lexicons/india-core.txt`
- `src-tauri/tauri.conf.json`
- `src-tauri/Cargo.toml`
- `package.json`
- `README.md`
- `NSM_FLOW_INTERN_QA_GUIDE.html`
- `.github/workflows/`

Also inspect surrounding call sites, serialization/migrations, model-engine
branches, platform-specific paste paths, and packaging configuration. Do not
limit the audit to the files listed above.

## Required audit questions

1. Does the application compile and pass lint, formatting, translation, Rust,
   frontend, and browser tests?
2. Can settings created by version 0.1 or 0.2 migrate safely to schema 2 without
   duplicating vocabulary or erasing a user's custom words?
3. Does every supported local transcription engine receive the conservative
   custom-vocabulary correction stage?
4. Could Soundex/edit-distance matching introduce damaging false corrections?
5. Are chord symbols tokenized and transformed without breaking normal prose,
   URLs, email addresses, fractions, dates, or slash-separated paths?
6. Is the Unicode music output valid and consistent on macOS and Windows?
7. Are bundled resources included in both macOS and Windows packages?
8. Are the app name, identifier, icons, version, installer names, and update
   metadata internally consistent?
9. Is core no-login use genuinely unblocked?
10. Are there secrets, private customer data, proprietary Wispr data, unsafe
    shell behavior, or license/attribution problems?
11. Does the intern guide accurately distinguish automated checks, installer
    validation, and physical-device testing?
12. Are claims appropriately honest? Never claim “perfect”, “100%”, or
    “five times better” without a measured benchmark.

## Required checks

Use the repository’s documented toolchain and run at least:

```text
bun install --frozen-lockfile
bun run format:check
bun run lint
bun run check:translations
bun run build
bunx playwright test
cd src-tauri && cargo test
cd src-tauri && cargo clippy --all-targets -- -D warnings
git diff --check
```

If the Playwright script or binary differs, use the repository’s actual
configuration. On this Mac, Rust may be located under:

`/Users/nphmacmini/.rustup/toolchains/stable-aarch64-apple-darwin/bin`

Build the local Apple-silicon package if practical. Do not claim that Windows
runtime behavior was physically tested from macOS; distinguish compilation,
installer generation, installer inspection, and a real Windows smoke test.

## Editing and safety boundaries

- You may edit code, tests, documentation, and release configuration in this
  repository to fix in-scope issues.
- Preserve unrelated user changes.
- Do not delete user data or weaken operating-system security settings.
- Do not change macOS Accessibility or Input Monitoring permissions.
- Do not sign in, send messages, contact employees/interns, publish releases,
  push Git commits, merge pull requests, or change repository visibility.
- Do not add mandatory employee authentication.
- Do not add paid APIs or secrets.
- Do not hide failures by weakening tests or disabling functionality.
- Do not turn the curated India lexicon into an uncontrolled giant dictionary.
  Precision is more important than raw entry count.

## Deliverable

Create or update `CLAUDE_CODE_AUDIT_REPORT.md` with:

- release verdict: `PASS`, `PASS WITH PHYSICAL TESTS PENDING`, or `BLOCKED`
- findings ordered by severity
- exact fixes made
- exact commands run and their results
- remaining Mac/Windows physical tests
- installer/publishing blockers, if any
- files changed by your audit

Finish only when all safe in-scope fixes are implemented and the available
automated checks pass. If something genuinely cannot be completed on this Mac,
state the precise blocker and the smallest physical test still required.
