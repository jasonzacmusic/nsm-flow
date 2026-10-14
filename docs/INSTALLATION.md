# Install NSM Flow

NSM Flow is a free desktop alpha. Use the downloads in the [README](../README.md)
or the [NSM Flow releases page](https://github.com/jasonzacmusic/nsm-flow/releases).
An ordinary user does not need Git, Rust, Bun, a Google account, or an API key.
The installer does not include the large speech models: allow internet access and
several GB of free space for the first model download.

## macOS

1. In **Apple menu → About This Mac**, check whether the machine has an Apple
   chip or an Intel processor. Download the matching DMG.
2. Open the DMG and drag **NSM Flow** to **Applications**. Launch that copy.
3. Allow **Microphone** access. In **System Settings → Privacy & Security →
   Accessibility**, enable NSM Flow so it can paste into other apps. Restart NSM
   Flow normally if macOS requests it.
4. Download a speech model, select your microphone and language, and check the
   shortcut shown in Settings. New macOS settings use **Fn** for push-to-talk;
   existing installations keep their chosen shortcut.
5. Open a disposable TextEdit document, hold the shortcut, speak a sentence,
   and release. Wait for transcription and check the pasted text.

Official Mac installers are Developer ID signed and Apple notarized. If macOS
reports a damaged or unidentified app, verify the download and use the correct
release. Do not disable Gatekeeper or remove quarantine as a routine workaround.

The configured minimum is macOS 10.15, but that is a build setting, not evidence
of testing on every old macOS version. Apple silicon needs macOS 11 or later.
Current releases were built on recent macOS toolchains; older OS acceptance and
physical Intel Mac audio testing remain part of the alpha test matrix.

## Windows

1. Download the **x64 Setup EXE** on a 64-bit Windows PC. Prefer Windows 10/11;
   Windows ARM64 native installers are not published in this release.
2. Verify the SHA-256 checksum below. Official Windows alpha installers are
   currently unsigned. If SmartScreen blocks it, check **More info** for the
   exact file you downloaded before deciding to **Run anyway**. An organization
   may prohibit unsigned apps; do not bypass its policy.
3. Follow Setup, then launch NSM Flow. Setup also offers portable mode, which
   stores app data in a `Data` folder beside the app; provider credentials remain
   in the OS credential vault and do not travel with that folder.
4. In **Settings → Privacy & security → Microphone**, allow microphone access
   for desktop apps. Download a model and select the correct microphone.
5. The initial shortcut is **Ctrl+Space**. Change it if it conflicts with another
   app. Test by dictating into a blank Notepad document.

Use the MSI for managed installation. WebView2 is required by Tauri; Setup may
need internet access to provision it. Test standard-user installation on your
actual PC. Admin-elevated apps can block paste from a non-elevated dictation app;
use ordinary apps for the first test.

## Linux

Linux alpha packages and supported distributions are listed in the README once
package verification passes. The initial target is **x86_64 Linux with glibc**.
Prefer **X11** for the first test. Wayland compositors restrict global shortcuts,
active-window detection, and simulated paste; behavior varies by desktop.
Linux hides the recording overlay by default.

For a published Debian/Ubuntu package:

```sh
sudo apt install ./NSM-Flow-linux-x64.deb
nsm-flow
```

For a published Fedora/RPM package:

```sh
sudo dnf install ./NSM-Flow-linux-x64.rpm
nsm-flow
```

For a published AppImage:

```sh
chmod +x NSM-Flow-linux-x64.AppImage
./NSM-Flow-linux-x64.AppImage
```

An AppImage still needs a compatible glibc, desktop environment, audio stack and
some system libraries; it is not a guarantee for all Linux distributions. If
FUSE is unavailable, try `./NSM-Flow-linux-x64.AppImage --appimage-extract-and-run`.
Ubuntu 22.04 uses `libfuse2`; Ubuntu 24.04 uses `libfuse2t64`. Install required
GTK layer-shell and OpenBLAS libraries through your distribution's package
manager when needed. ARM Linux and musl distributions are not release targets.

Launch without the GTK layer-shell overlay if your compositor has problems:

```sh
HANDY_NO_GTK_LAYER_SHELL=1 nsm-flow
```

Start with **Ctrl+Space** and a blank text editor. Under Wayland, a desktop
shortcut can call `nsm-flow --toggle-transcription`; confirm paste behavior on
that compositor. See [BUILD.md](../BUILD.md) if a package is unavailable for your
system. Do not manually copy a bare binary without its resources and libraries.

## Pick the first model

- For Indian English, try multilingual **Whisper Small** first; compare Medium
  or Large v3 Turbo if your hardware can run them comfortably.
- For Hindi, Tamil, Kannada, Telugu, Malayalam or another Indian language, choose
  a multilingual model with that language in its supported list. Set the language
  explicitly where the model allows it. English-only models cannot do this.
- For fast English dictation, compare an English Parakeet model. It has separate
  model-license terms.
- Large models need more RAM, storage and processing time. Published catalog
  speed/accuracy scores are upstream estimates, not NSM Indian-accent benchmarks.

Turn **Translate to English** off when you want transcription in the original
language. Add names and specialist terms to your vocabulary. No local LLM server
is needed for normal dictation. Cloud formatting is optional and may cost money.

## Verify a download

Download the checksum file from the **same release** as your installer. Compare
the result for the exact filename; do not compare against a different version.

macOS/Linux:

```sh
shasum -a 256 NSM-Flow-mac-Apple-Silicon.dmg
# On Linux, sha256sum also works.
```

Windows PowerShell:

```powershell
Get-FileHash .\NSM-Flow-windows-x64-setup.exe -Algorithm SHA256
```

A checksum detects changed bytes. It is not a substitute for an installer code
signature: Windows remains unsigned. The updater has separate signed payloads.

## Common problems

| Symptom                                    | What to check                                                                                       |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Nothing records                            | Microphone permission, selected input, physical mute, model download completed                      |
| Shortcut does nothing                      | Shortcut conflicts, macOS Accessibility, Linux compositor restrictions                              |
| Text appears in history but does not paste | Focus a normal text field; check permissions and app elevation; test a different editor             |
| Names or Indian-language words are wrong   | Use a suitable multilingual model, choose language, add vocabulary, compare raw vs formatted output |
| Very slow transcription                    | Try a smaller model; verify a usable CPU/GPU backend and available RAM                              |
| No tray icon on Linux                      | Desktop indicator support; launch `nsm-flow --no-tray` and keep its window open                     |
| Optional formatting fails                  | Run your local server or disable it; check provider/model configuration without sharing API keys    |

Use **Check for updates** and read the release notes before approving an update.
If Linux has no matching updater payload, download its next package manually.
Quit normally before reinstalling; keep your settings/models and the old installer
for rollback. App uninstall does not necessarily erase saved local transcripts.
Use the app's confirmed history deletion controls when that is your intention.

Report reproducible problems with the [testing guide](TESTING.md). Include the
app version, OS, architecture, model, microphone and target app. Do not post
private recordings, student data, logs containing transcripts, or credentials.
