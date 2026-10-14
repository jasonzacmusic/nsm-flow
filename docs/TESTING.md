# Cross-platform and Indian-recognition testing

Public alpha status means testers can install it; it does not establish universal
OS compatibility or accent accuracy. Record **pass**, **fail**, or **unverified**
for each actual machine. Share only recordings and text you have permission to use.

## Device matrix

| Target            | Essential coverage                                                                              |
| ----------------- | ----------------------------------------------------------------------------------------------- |
| Apple silicon Mac | Recent supported macOS; real mic and Accessibility prompts; TextEdit, browser and WhatsApp      |
| Intel Mac         | Physical Intel Mac; older and current macOS; CPU inference and paste                            |
| Windows x64       | Windows 10/11; standard user; EXE, portable and MSI; clean machine without developer runtimes   |
| Linux x64         | Ubuntu 22.04/24.04 X11; DEB and AppImage; Fedora RPM; Wayland recorded separately by compositor |

For each machine record OS build, CPU, RAM, app version/hash, model and quantization,
microphone, audio sample conditions, shortcut, desktop/compositor and target app.
Windows ARM64, Linux ARM64/musl and mobile are outside the published target matrix.

## Functional checks

1. Fresh install, first launch, model download, cancellation and successful retry.
2. Skip sign-in; dictate offline after downloading the model.
3. Hold/release the actual shortcut; verify text into an ordinary blank editor.
4. Repeat with browser fields, email and chat; check focus and Unicode notation.
5. Cancel while recording and processing; confirm no late paste and a working retry.
6. Deny mic access or disconnect it; verify the error and recovery.
7. Confirm text retention off, expiry, saved-entry behavior and confirmed deletion
   using disposable entries; relaunch and check settings survive.
8. Test an approved upgrade from the prior supported alpha, retain settings/models,
   and dictate after restart. Linux manual package upgrades are a separate test.
9. Test laptop sleep, changed audio devices and a second display without forcing
   a recording/playback session to quit.

## Indian English benchmark

Use multiple consenting speakers from different regions, devices and noise levels.
A starting set should contain ordinary English, Indian personal/place names,
Indian music terms and connected prose. Include confusable spellings and phrases
that should **not** be corrected. Keep NSM staff names separate from general names
so the school-specific seed list does not inflate results.

Measure raw recognition and final vocabulary/formatted output separately. Fix the
reference transcript before running the model; report normalization rules. Track:

- Word error rate: `(substitutions + deletions + insertions) / reference words`
- Name/term accuracy: exact accepted spellings divided by tested names/terms
- Chord/pitch semantic errors, including enharmonic and major/minor mistakes
- Processing time after release, total latency and successful paste rate

Compare multilingual Whisper Small/Medium/Turbo with a supported Parakeet model
on the same audio/hardware. Report speaker count, utterance count and failures;
do not extrapolate a small seeded test into “all Indian accents supported”.

## Indian-language and code-switching tests

Test each advertised language independently using a multilingual model, with
translation disabled. Check original script, language selection/auto-detection,
English names within Indian-language sentences and language-switch boundaries.
The India lexicon is not a replacement for a suitable speech model. Passing Hindi
does not establish Tamil, Kannada, Telugu, Malayalam, Bengali or Marathi accuracy.

## Report format

Use a GitHub bug template. Supply environment, exact steps, expected vs actual
output, selected model, raw vs formatted text, and whether it reproduces offline.
Never attach production student data or provider credentials. The existing
`NSM_FLOW_INTERN_QA_GUIDE.html` is a historical supplement; this current guide
controls new public platform reports.
