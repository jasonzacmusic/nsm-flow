# NSM Flow 0.3.0-alpha.1 — Independent Audit Report

**Auditor:** Claude Code (independent pass, working directory `nsm-flow`, branch
`agent/musical-typing-qa`)
**Date:** 2026-07-25

## Verdict: **PASS WITH PHYSICAL TESTS PENDING**

Every automated check in the required list passes cleanly, the app compiles and
runs, and no code changes were needed to reach that state. The one real
release blocker found is **not a code defect** — it's a publishing gap: the
public download links in `README.md` and `NSM_FLOW_INTERN_QA_GUIDE.html`
currently 404 because no NSM Flow installer has been uploaded to the
`jasonzacmusic/labs-downloads` release yet. That upload, plus real hands-on
testing on a physical Mac and a physical Windows machine, are the only things
standing between this alpha and a trustworthy release. See "Installer /
Publishing Blockers" and "Remaining Physical Tests" below.

---

## Findings, ordered by severity

### 1. BLOCKER (publishing, not code) — Download links in README and intern guide are dead

`README.md` and `NSM_FLOW_INTERN_QA_GUIDE.html` both link to:

```
https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-mac-Apple-Silicon.dmg
https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-mac-Intel.dmg
https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-windows-x64-setup.exe
https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-windows-x64.msi
https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-0.3.0-alpha.1-complete.zip
https://github.com/jasonzacmusic/labs-downloads/releases/latest/download/NSM-Flow-0.3.0-alpha.1-SHA256SUMS.txt
```

I verified all six with `curl -L`: **every one returns HTTP 404.** The
`labs-downloads` release ("downloads", published 2026-07-06) only contains
assets for other Nathaniel Labs apps (Chorale, GrabIt, MIDI Piano Visualizer,
NSMPhotos, Sangam, Shruti, SocialCommandCentre) — no NSM Flow installer has
ever been uploaded.

**This means the entire intern QA guide is currently unusable as written**:
step one of "Start from a clean, known setup" sends every tester to a dead
link. It also means the README's public-facing download section is
currently a dead-link page.

**Why I did not fix this myself:** creating the real installers requires
running the full macOS (Apple silicon + Intel) and Windows build/sign
pipeline and uploading to `labs-downloads`, which is a publish action outside
my authorized scope ("do not... publish releases"). I did build and verify
the Apple-silicon `.app`/`.dmg` locally (see "What I verified by building"
below) to confirm the pipeline itself works, but that artifact is unsigned
and local-only — it is not what should be linked from a public README.

**What Jason needs to do:** run `main-build.yml` with `build_scope:
all-platforms` (or the equivalent signed release workflow), then run
`labs-downloads`'s `publish.sh` to upload the resulting DMGs/EXE/MSI/ZIP/
checksums under exactly the filenames above. Until that happens, the README
and intern guide should not be circulated publicly, since Jason's own hard
rule is "never ship a dead link."

### 2. Low — `chord_quality_symbol` compaction is unconditional outside Code mode, by design

`src-tauri/src/writing_mode.rs`'s `CHORD_QUALITY` regex (letter + extension
word, e.g. "B seven", "A nine") is **not** gated by writing mode or a
music-context heuristic — only the plain major/minor triad (`SIMPLE_TRIAD`)
and slash chords are gated. This is a deliberate, documented, and tested
design choice (see the doc comment at `writing_mode.rs:72-74` and the test
`chord_compaction_stays_safe_in_ordinary_prose`), but I probed it with cases
outside the existing test suite to check for real prose corruption:

| Input                                   | Output                                 |
| --------------------------------------- | -------------------------------------- |
| "Meet me at gate B 7 before boarding."  | "Meet me at gate B7 before boarding."  |
| "Take vitamin B seven daily."           | "Take vitamin B7 daily."               |
| "Room A 7 is down the hall."            | "Room A7 is down the hall."            |
| "She scored a B 9 on the physics quiz." | "She scored a B9 on the physics quiz." |

None of these change the sentence's meaning — they compact `"B seven"` into
`"B7"`, which is arguably the more standard way to write those things anyway
(vitamin B7, gate B7, room A7). This is **not** the kind of corruption the
brief's example ("a major problem... a minor delay") warns about, since that
case is already correctly protected (plain major/minor requires an
unambiguous chord-word neighbor or `Music` mode to compact — verified by
existing tests). I'm flagging this only as a documented, intentional
trade-off worth knowing about, not a blocker: it only fires for single
letters A–G immediately followed by 6/7/9/11/13 (spelled or digit), which is
a narrow surface. No fix applied.

### 3. Informational — Linux packaging in `tauri.conf.json` still says "Handy"

`src-tauri/tauri.conf.json`'s `bundle.linux.deb/rpm/appimage.files` still
install libraries under `/usr/lib/Handy`, and `.github/workflows/build.yml`'s
Linux smoke tests hard-code that same path (`usr/bin/handy`,
`usr/lib/Handy/...`). This is leftover from the Handy fork. **I did not
change it** because (a) Linux is explicitly not a target platform for this
release (macOS Apple silicon, macOS Intel, Windows x64 only, per the brief),
and (b) the Linux CI audit steps in `build.yml` hard-code the same paths, so
changing one without the other would break Linux CI for no in-scope benefit.
Worth a follow-up if/when Linux becomes a supported platform.

### 4. No issues found — everything else in the required audit questions

- **Q1 (compiles/lints/tests):** Pass — see "Commands run" below.
- **Q2 (0.1/0.2 → schema 2 migration):** `apply_settings_migrations` correctly
  migrates a frozen, real v0.9.0-era settings fixture
  (`settings::tests::frozen_v0_9_store_parses_strictly_and_migrates_once`) —
  vocabulary is deduplicated case-insensitively via a `HashSet<String>` of
  lowercased words before extending (`settings.rs:1224-1235`), so re-running
  migration on an already-migrated store is a no-op (also asserted in the
  same test). No duplication, no erasure of user words.
- **Q3 (every engine gets vocabulary correction):** `transcribe()` in
  `managers/transcription.rs` calls `post_process_transcription_text()`
  **once**, after the engine `match` block, unconditionally for every engine
  variant (TranscribeCpp, Parakeet, Moonshine, MoonshineStreaming,
  SenseVoice, GigaAM, Canary, Cohere) and for the streaming path
  (`finalize_stream`). Only TranscribeCpp additionally gets a _bounded_
  initial-decoder prompt (see Q4).
- **Q4 (Soundex/edit-distance false corrections):** `text.rs`'s
  `find_best_match` disables the Soundex phonetic boost from rescuing a
  visibly-distant spelling at the default conservative threshold (`< 0.5`):
  it hard-caps Levenshtein score at 0.20 (short words) / 0.30 (longer words)
  before Soundex can apply its 0.3× multiplier. Verified directly:
  `test_large_lexicon_does_not_turn_ordinary_words_into_food` confirms "does"
  is never turned into "dosa" even with `dosa`/`idli`/`kurta`/`Kota` in the
  lexicon at the real default threshold (0.18). The whisper initial prompt is
  also hard-capped at `MAX_CUSTOM_WORD_PROMPT_CHARS = 1_200` chars
  (`transcription.rs:1604`), so the India lexicon (533 lines) can never
  produce an unbounded model prompt — the full fuzzy-correction lexicon is
  applied post-hoc instead, per the doc comment at `transcription.rs:1390-1393`.
- **Q5 (chords vs. prose/URLs/emails/fractions/dates/paths):** Musical-note
  and chord regexes require single-letter A–G word boundaries plus explicit
  musical keywords/extensions; ordinary text, URLs, emails, and slash paths
  don't match the note/chord patterns (they don't contain a bare A–G letter
  followed by a recognized musical word). `SLASH_CHORD` only fires on
  "X over/slash Y" phrasing, not on literal `/` characters, so it can't
  misfire on real slash-separated text. The custom-word corrector separately
  guards musical commands via `is_spoken_music_command`/
  `is_spoken_accidental_in_note_context` so Soundex can't turn "F sharp" into
  a name like "Sharifa" (tested).
- **Q6 (Unicode music output validity):** All accidental/chord/note-duration
  glyphs are real Unicode codepoints (♭ U+266D, ♯ U+266F, ♮ U+266E, 𝄪
  U+1D12A, 𝄫 U+1D12B, and the SMP note/rest glyphs). These are plain Rust
  `&str` literals emitted through `String`/`format!`, with no
  platform-specific encoding path, so behavior is identical on macOS and
  Windows (both consume UTF-8 → UTF-16 for paste through the existing,
  unmodified paste pipeline).
- **Q7 (bundled resources in both packages):** Confirmed directly by building
  the macOS Apple-silicon `.app` (see below) — `india-core.txt`,
  `silero_vad_v4.onnx`, `gigaam_vocab.txt`, and all sound/tray assets are
  present under `Contents/Resources/resources/`, driven by
  `"resources": ["resources/**/*"]` in `tauri.conf.json`, which applies
  identically to the Windows bundle (not built on this Mac; see "Remaining
  Physical Tests").
- **Q8 (name/identifier/icon/version consistency):** `package.json`,
  `src-tauri/Cargo.toml`, and `src-tauri/tauri.conf.json` all read
  `0.3.0-alpha.1`; the built app's `Info.plist` confirms
  `CFBundleName=NSM Flow`, `CFBundleIdentifier=com.nathanielschool.nsmflow`,
  `CFBundleShortVersionString=0.3.0-alpha.1`. The Windows binary-name check in
  `build.yml` (`nsm-flow.exe`) matches the Cargo package name (`nsm-flow`).
  Updater is disabled (`plugins.updater.endpoints: []`, empty `pubkey`,
  `update_checks_enabled` defaults to `false`), so there's no
  update-metadata mismatch to worry about. (See Finding 3 for the one
  Linux-only naming leftover, out of scope for this release.)
- **Q9 (no-login use unblocked):** `onboarding_completed` is derived purely
  from whether a model has been selected (`settings.rs`); the onboarding flow
  in `App.tsx` only ever gates on accessibility/microphone permissions and
  model selection — there is no sign-in step in the flow at all. Google
  sign-in (`team_auth.rs`) is entirely opt-in, reads its client ID from an
  env var / build-time `option_env!`, and is invoked only from
  `TeamSettings.tsx`, never from the onboarding path or the core
  record/transcribe/paste pipeline.
- **Q10 (secrets/proprietary data/unsafe shell/license):** No secrets, keys,
  or tokens found in the reviewed diff or repo; `post_process_api_keys` are
  redacted in `Debug` output (tested). No Wispr Flow proprietary code —
  `scripts/import_wispr_dictionary.py` only reads a local SQLite DB in
  `mode=ro`, restricted to `Dictionary` rows with `source in
{manual, user_edits}`, and explicitly excludes emails, URLs, snippets, and
  long numbers before ever touching NSM Flow. `LICENSE`/`NOTICE.md` correctly
  preserve the upstream Handy MIT copyright and clarify the Handy name/logo
  are not reused.
- **Q11 (intern guide accuracy):** The guide's structure correctly separates
  install/setup (human, physical) from the per-app-mode test matrix (human,
  physical, with repetition counts) — it does not claim any of this was
  automated. No inflated claims were found in the guide text itself (the one
  "100% working" mention is explicitly framed as _"a release target, not an
  assumption"_). Its only defect is Finding 1 (dead download links), which is
  a data problem, not a mischaracterization of what's automated vs. physical.
- **Q12 (honest claims):** No "perfect"/"100%"/"5x better" claims found
  anywhere in README, the intern guide, or code comments in the reviewed
  diff.

---

## Exact fixes made

**None were needed.** I made one temporary, reverted change during
verification: I added a scratch `#[test]` to `writing_mode.rs` to probe
chord-compaction behavior outside the existing test matrix (Finding 2), ran
it, recorded the output above, and removed it. `git status`/`git diff` are
clean — the working tree is byte-identical to how I found it.

---

## Commands run and results

All run from `/Users/nphmacmini/Documents/New project/nsm-flow` with
`PATH="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$PATH"`
exported for the Rust steps.

| Command                                                                              | Result                                                                    |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| `bun install --frozen-lockfile`                                                      | Pass — "Checked 372 installs across 445 packages (no changes)"            |
| `bun run format:check` (prettier + `cargo fmt -- --check`)                           | Pass                                                                      |
| `bun run lint` (ESLint)                                                              | Pass, no output/errors                                                    |
| `bun run check:translations`                                                         | Pass — 23 languages, all 399 keys present                                 |
| `bun run build` (`tsc && vite build`)                                                | Pass — built in 1.69s                                                     |
| `bunx playwright test`                                                               | Pass — 2/2 tests                                                          |
| `cd src-tauri && cargo test`                                                         | Pass — **152/152** unit tests, 0 failed                                   |
| `cd src-tauri && cargo clippy --all-targets -- -D warnings`                          | Pass — zero warnings                                                      |
| `git diff --check`                                                                   | Pass — no whitespace/conflict-marker issues                               |
| `CMAKE_POLICY_VERSION_MINIMUM=3.5 bun run tauri build --target aarch64-apple-darwin` | Pass — built, ad-hoc signed, bundled `.app` and `.dmg` in 4m03s           |
| `"NSM Flow.app/Contents/MacOS/nsm-flow" --list-devices`                              | Pass — `metal` (Apple M4 Pro, 49152MB) and `cpu` devices listed, no crash |
| `curl` against all 6 README/QA-guide download URLs                                   | **All 404** — see Finding 1                                               |

## What I verified by building (macOS Apple silicon)

Built at
`src-tauri/target/aarch64-apple-darwin/release/bundle/macos/NSM Flow.app`
(and a matching `.dmg` next to it). Confirmed:

- App launches headlessly (`--list-devices`) without touching Core Audio
  device state — safe to run alongside the live REAPER session on this Mac
  (verified `pgrep -x REAPER` before running, and the command never calls
  into audio I/O).
- `Info.plist` name/identifier/version match `tauri.conf.json` exactly.
- `Contents/Resources/resources/lexicons/india-core.txt`,
  `resources/models/silero_vad_v4.onnx`, and `resources/models/gigaam_vocab.txt`
  are all present and bundled correctly.
- Ad-hoc code signature applied (`codesign -dv` shows `flags=0x10002(adhoc,runtime)`),
  consistent with `signingIdentity: "-"` in `tauri.conf.json` and the "do not
  claim fully proven until signed" language already in `README.md`.

This is a **compiled and locally-inspected** verification only — it is not a
notarized, signed, or distributable build, and it was not installed via a
DMG double-click/Gatekeeper flow.

---

## Remaining Mac/Windows physical tests

These cannot be completed from this session and require the intern matrix on
real hardware once real installers exist (see Finding 1):

- **macOS (Apple silicon):** Gatekeeper/unsigned-app warning flow from a
  double-clicked DMG (not just a locally-built `.app`), accessibility +
  microphone permission prompts, `Fn` push-to-talk end-to-end with real
  speech, all six writing-mode targets (Mail, WhatsApp, Claude/ChatGPT,
  Notes/Pages, REAPER/MuseScore, Terminal), quit/reopen persistence.
- **macOS (Intel):** Everything above, plus confirming the x86_64 build
  actually compiles and links (not attempted on this Apple-silicon Mac —
  `main-build.yml`'s `additional-platforms` job targets
  `x86_64-apple-darwin` on a `macos-latest` runner).
- **Windows x64:** Full install (Setup EXE and MSI), SmartScreen flow,
  `Ctrl+Space` push-to-talk, microphone permission prompt, the same
  writing-mode matrix on Windows apps (Outlook, WhatsApp, Notepad, Word). I
  did not build or run anything Windows-side on this Mac — the Windows leg of
  `build.yml` (VC++ redist staging, ONNX Runtime DLL staging, NSIS/MSI
  installer content audits) has never executed for this branch and its
  results are unverified.
- **Musical typing and India-lexicon spot checks with a real human voice**
  (not just the regex/fuzzy-match unit tests) — accents, background noise,
  and real Whisper/Parakeet transcription errors are exactly the kind of
  input the unit tests can't simulate.

## Installer / publishing blockers

- **Blocking:** No NSM Flow installer of any kind has been uploaded to
  `jasonzacmusic/labs-downloads`. The README and intern guide's download
  links are dead until Jason runs the real build-and-publish flow (see
  Finding 1 for the exact steps).
- **Not yet attempted this session:** Intel Mac build, Windows x64 build, and
  the signed/notarized release path (`sign-binaries: true` in `build.yml`,
  which needs `APPLE_ID`/`APPLE_TEAM_ID`/`AZURE_CLIENT_ID` secrets — the
  README already correctly states these must come from Nathaniel before
  installers are trusted without an unsigned-app warning).

---

## Files changed by this audit

None. The working tree is identical to `HEAD` (`bfa1d80`). This report file
(`CLAUDE_CODE_AUDIT_REPORT.md`) is the only new file.

---

## Post-audit Indian-English benchmark addendum

**Trigger:** a real 20.58-second Indian-English Parakeet benchmark recording
correctly transcribed every tested Indian name, city, food, and temple, but
emitted **"Kanjivram Sari"** instead of the preferred **"Kanjeevaram saree"**
for one textile term. This addendum reviews the follow-up patch, scoped to
exactly three uncommitted items: `src-tauri/src/audio_toolkit/text.rs`, the
new `src-tauri/resources/lexicons/india-aliases.tsv`, and formatting-only
diffs in this report.

### What the patch does

`apply_custom_words` gained a phrase-alias pass that runs before the existing
fuzzy n-gram matcher. It reads `india-aliases.tsv` (compiled in via
`include_str!`, same pattern already used for `india-core.txt`) as literal
"heard phrase → preferred phrase" pairs. An alias only fires when: (1) the
transcript contains one of the exact heard phrases (`Kanjivram Sari`,
`Kanjivram saree`, `Kanjivaram Sari`, `Kanjivaram saree`, `Kanjeevaram Sari`),
compared via the same punctuation-stripped/lowercased key used elsewhere in
this file, **and** (2) the user's own custom-word vocabulary already contains
the preferred canonical phrase (`Kanjeevaram saree`), matched
case-insensitively. Generic single words like "sari" are never touched — only
the five specific multi-word phrases in the TSV.

### What I reviewed and fixed

- **Correctness / gating:** confirmed the alias only activates when the
  preferred phrase is present in `custom_words`; without it, the phrase
  passes through unchanged (real benchmark behavior for any user who hasn't
  added "Kanjeevaram saree" as a custom word is unaffected).
- **Boundary safety:** the alias loop reuses the existing
  punctuation-boundary guard (`extract_punctuation`) so a comma between words
  (e.g. "Kanjivram, Sari") correctly blocks the multi-word match, same as the
  pre-existing fuzzy-match n-gram logic.
- **Punctuation/casing:** prefix/suffix punctuation is preserved from the
  first/last matched word, and `preserve_case_pattern` (already used
  elsewhere in the file) sets the output case from the original first word.
- **No generic global rewrite:** verified the TSV only contains full
  multi-word phrases, not single common words, so it cannot rewrite ordinary
  English usage of "sari" on its own.
- **Formatting-only diff:** confirmed the `CLAUDE_CODE_AUDIT_REPORT.md`
  changes are pure Prettier reflow (table alignment, `*emphasis*` →
  `_emphasis_`), including one line that looks unindented
  (`{manual, user_edits}`) — that's Prettier's own canonical output for a
  list-item paragraph continuation (CommonMark "lazy continuation"; still
  renders correctly inside the bullet). Confirmed via `bun run format:check`.
- **Fix applied (perf/thread safety):** the alias n-gram loop was running
  unconditionally for every word position — up to 6 string allocations per
  word — even when the enabled-alias list is empty, which is true for every
  user who hasn't added the exact preferred phrase as a custom word (the
  common case). Added an `if !enabled_india_aliases.is_empty()` guard around
  that loop so it's skipped entirely unless the feature is actually active
  for that user. `INDIA_CORE_ALIAS_KEYS` remains a `once_cell::sync::Lazy`,
  built once and shared read-only across threads, consistent with the
  existing `INDIA_CORE_LEXICON`/other statics in this codebase.
- **Tests added** (`src-tauri/src/audio_toolkit/text.rs`): case-insensitive
  gate (`test_india_alias_gate_is_case_insensitive`), no rewrite of the bare
  word "sari" when only the phrase-specific alias is enabled
  (`test_india_alias_does_not_rewrite_generic_word_alone`), no cross-comma
  merge (`test_india_alias_does_not_cross_punctuation_boundary`), and
  trailing-punctuation preservation
  (`test_india_alias_preserves_trailing_punctuation`).

### Exact tests run and results

| Command                                                 | Result                                 |
| ------------------------------------------------------- | -------------------------------------- |
| `cargo test --lib audio_toolkit::text`                  | Pass — 48/48 (44 pre-existing + 4 new) |
| `cargo test --lib` (full backend suite)                 | Pass — **158/158**, 0 failed           |
| `cargo clippy --all-targets -- -D warnings`             | Pass — zero warnings                   |
| `bun run format:check` (Prettier + `cargo fmt --check`) | Pass                                   |
| `bun run lint` (ESLint)                                 | Pass, no output/errors                 |
| `bun run check:translations`                            | Pass — 23 languages, all keys present  |

### Real benchmark before/after (the triggering case)

|                                                                | Text                                                  |
| -------------------------------------------------------------- | ----------------------------------------------------- |
| Real Parakeet output (20.58s Indian-English clip)              | "...the **Kanjivram Sari** tomorrow..."               |
| With `Kanjeevaram saree` added as a custom word, alias applied | "...the **Kanjeevaram saree** tomorrow..."            |
| Without that custom word present                               | unchanged — "Kanjivram Sari" passes through as before |

This is confirmed at the unit-test level
(`test_known_india_asr_phrase_uses_preferred_spelling`,
`test_india_alias_requires_the_preferred_custom_word`) using the literal
wording from the real benchmark transcript. I did not re-run the full audio
pipeline against the original 20.58s recording in this session — see
limits below.

### Remaining physical-test limits

- This review is code- and unit-test-level. It does not replay the original
  20.58-second audio file through the live Parakeet pipeline in this session
  to confirm the end-to-end (audio → transcription → correction) output
  matches the table above; the unit tests substitute the exact real-world
  wording but bypass the audio/model stage.
- No new physical-hardware testing was done on Windows or a second physical
  Mac for this change, consistent with the pending physical-test gaps
  already recorded above.
- This addendum makes no "100%"/"perfect" claim: the alias list currently
  covers five known spelling variants for one term family; other
  never-observed misrecognitions of other Indian-English phrases are not
  covered by this patch and would need their own reported cases.
