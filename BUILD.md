# Build NSM Flow from source

For ready-made installers, use the [installation guide](docs/INSTALLATION.md).
This page is for contributors building the public MIT-licensed application.

## Common prerequisites

Install Git, stable [Rust](https://rustup.rs/), [Bun](https://bun.sh/), CMake and
the [Tauri platform prerequisites](https://v2.tauri.app/start/prerequisites/).
Build on the target OS. Windows/Linux cross-compilation from a Mac is not the
supported packaging route.

```sh
git clone https://github.com/jasonzacmusic/nsm-flow.git
cd nsm-flow
bun install --frozen-lockfile
bun run tauri dev
```

The Silero VAD resource is already tracked. Speech recognition models are chosen
and downloaded in the app; no paid API or OAuth setup is required.

## macOS

Install Xcode Command Line Tools (`xcode-select --install`) and CMake. Apple
silicon builds use Metal. Full Xcode with the macOS 26 SDK is needed for the
optional Apple Intelligence bridge; CLT-only builds use the documented stub.

```sh
bun run tauri build -- --bundles app,dmg
```

Intel builds need a compatible ONNX Runtime library:

```sh
brew install onnxruntime
ORT_LIB_LOCATION="$(brew --prefix onnxruntime)/lib" \
ORT_PREFER_DYNAMIC_LINK=1 bun run tauri dev
```

A redistributable Intel package must bundle its ONNX Runtime dylib in
`Contents/Frameworks` and pass `otool -L` checks; linking to your Homebrew prefix
alone does not make a portable installer. The maintainer workflow uses ONNX
Runtime 1.24.2 and signs/notarizes using existing approved credentials. Community
builds are not signed by Nathaniel's identity.

## Windows

Use Visual Studio 2022 C++ desktop build tools and the Windows SDK, CMake, Rust's
MSVC toolchain, and the LunarG Vulkan SDK. Open a new developer terminal after
installing them so `VULKAN_SDK` and compiler tools are available.

```powershell
bun install --frozen-lockfile
bun run tauri dev
bun run tauri build -- --bundles nsis,msi
```

For equivalent distributed binaries, follow `.github/workflows/build.yml`: use
the official baseline ONNX Runtime 1.24.2 dynamic libraries, SPIRV-Headers, and
stage the matching Visual C++/OpenMP runtimes with `HANDY_VC_REDIST_DIRS`.
Copying just `nsm-flow.exe` will omit needed resources and DLLs. These upstream
`HANDY_*` environment names are retained internally for compatibility.

For native-build path-limit errors, use a short per-shell target path:

```powershell
$env:CARGO_TARGET_DIR = "C:\nsm-flow-target"
```

The public alpha is unsigned; no signing command is required for local builds.
Do not configure Nathaniel release keys in a fork.

## Linux

The initial packaged target is Ubuntu 22.04 x86_64, with DEB, RPM and AppImage
output. Newer distributions must be checked independently. On Ubuntu/Debian:

```sh
sudo apt update
sudo apt install build-essential cmake pkg-config patchelf libssl-dev \
  libasound2-dev libopenblas-dev libgtk-3-dev libwebkit2gtk-4.1-dev \
  libappindicator3-dev librsvg2-dev libgtk-layer-shell-dev \
  libx11-dev libxtst-dev libxrandr-dev libvulkan-dev glslc spirv-headers rpm cpio
bun install --frozen-lockfile
bun run tauri dev
bun run tauri build -- --bundles deb,rpm,appimage
```

The exact maintainer environment is `.github/workflows/build.yml`. Ubuntu 22.04
release builds dynamically link the official ONNX Runtime 1.24.2 and bundle its
SONAME library. Linux transcribe/ggml CPU and Vulkan backend modules must be
packaged together. Existing `/usr/lib/Handy` private library paths and the
`HANDY_NO_GTK_LAYER_SHELL` environment name remain implementation details.

Before distributing RPM output, package the verified DEB payload with the
system RPM tools. The pinned Tauri packager's RPM metadata is incompatible with
the Ubuntu 22.04 extractor; this helper preserves every native file and disables
stripping:

```sh
bash scripts/ci/package-linux-rpm.sh src-tauri/target/release/bundle
NSM_BUNDLE_DIR=src-tauri/target/release/bundle bash scripts/ci/audit-linux-packages.sh
```

The audit requires a DEB reference, RPM digest validation and identical file
contents/permissions, then launches each packaged runtime in Xvfb. Follow the
workflow's library staging and AppImage postprocessing as well.

Install the built package with your package manager; for example:

```sh
sudo apt install ./src-tauri/target/release/bundle/deb/*.deb
```

DEB packages are for Debian-family systems. RPM packages are for compatible
RPM-family systems. Extracting a DEB and copying its libraries into arbitrary
system directories is not a supported universal installation method.

If AppImage bundling fails on a rolling distribution, first build just a DEB or
RPM appropriate to that distribution. See the workflow's AppImage postprocessing
and package checks before distributing any community-built AppImage.

## Checks

```sh
bun run build
bun run lint
bun run format:check
bun run check:translations
bun run test:unit
bun run test:playwright
python3 -m unittest discover -s scripts -p 'test_*.py'
cd src-tauri
cargo test --locked
cargo clippy --locked --all-targets
```

Playwright tests use mocked desktop IPC. They verify frontend contracts, not
microphone capture, native permissions, GPU compatibility, or physical-device
accuracy. Release those claims only after the [device matrix](docs/TESTING.md).

## Optional team sign-in

`NSM_FLOW_GOOGLE_CLIENT_ID` configures a desktop OAuth client at build time.
`NSM_FLOW_ALLOWED_EMAIL_DOMAIN` optionally restricts the returned profile's
verified email domain. Client IDs are public identifiers; never bundle a client
secret. Public users can skip sign-in and use dictation immediately.
