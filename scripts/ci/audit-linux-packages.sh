#!/usr/bin/env bash
# Check the exact packaged runtime, without build-library paths.
set -euo pipefail

# The runtime smoke test launches the packaged NSM Flow binary, which links
# GTK (via tao) even for the headless --list-devices path and therefore
# needs a display to start. CI runners are headless, so provide a virtual
# X server via xvfb-run.
if ! command -v xvfb-run >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y xvfb
fi

BUNDLE_DIR="${NSM_BUNDLE_DIR:?Set NSM_BUNDLE_DIR to the directory containing deb/rpm/appimage}"

require_pattern() {
  local listing="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -Eq "$pattern" "$listing"; then
    echo "ERROR: missing ${label} (${pattern}) in ${listing}" >&2
    cat "$listing" >&2
    exit 1
  fi
}

require_path() {
  local path="$1"
  local label="$2"
  if [ ! -e "$path" ]; then
    echo "ERROR: missing ${label}: ${path}" >&2
    find "$(dirname "$path")" -maxdepth 2 -type f 2>/dev/null >&2 || true
    exit 1
  fi
}

smoke_binary() {
  local root="$1"
  local label="$2"
  # Run under a virtual X server: NSM Flow initializes GTK on startup even
  # on the headless --list-devices path, which fails without a display.
  HANDY_NO_GTK_LAYER_SHELL=1 \
  LD_LIBRARY_PATH="${root}/usr/lib/Handy:${root}/usr/lib" \
    xvfb-run -a "${root}/usr/bin/nsm-flow" --list-devices >/tmp/handy-package-smoke.log || {
      cat /tmp/handy-package-smoke.log >&2
      echo "ERROR: ${label} packaged binary failed to launch" >&2
      return 1
    }
  cat /tmp/handy-package-smoke.log
  grep -q 'kind=cpu' /tmp/handy-package-smoke.log
  echo "${label} --list-devices smoke passed"
}

if compgen -G "${BUNDLE_DIR}/deb/*.deb" > /dev/null; then
  for deb in "${BUNDLE_DIR}"/deb/*.deb; do
    echo "Auditing deb package: ${deb}"
    listing="$(mktemp)"
    dpkg-deb -c "$deb" > "$listing"
    require_pattern "$listing" 'usr/bin/nsm-flow$' "NSM Flow binary"
    require_pattern "$listing" 'usr/lib/Handy/libtranscribe\.so\.[0-9]+$' "transcribe runtime library (SONAME)"
    require_pattern "$listing" 'usr/lib/Handy/libggml-cpu.*\.so' "ggml CPU backend module"
    if [[ "${NSM_LINUX_PLATFORM:-ubuntu-22.04}" == *"ubuntu-22.04"* && "${NSM_LINUX_TARGET:-x86_64-unknown-linux-gnu}" == "x86_64-unknown-linux-gnu" ]]; then
      require_pattern "$listing" 'usr/lib/Handy/libonnxruntime\.so\.[0-9]+$' "ONNX Runtime library (SONAME)"
    fi
    # Handy's libs must stay out of the ldconfig-scanned /usr/lib
    # (issue #1639): app-private libs belong in /usr/lib/Handy only.
    # `[^/]+` excludes the Handy/ subdir, so only direct hits match.
    if grep -Eq 'usr/lib/[^/]+\.so' "$listing"; then
      echo "ERROR: libraries installed directly into /usr/lib (issue #1639):" >&2
      grep -E 'usr/lib/[^/]+\.so' "$listing" >&2
      exit 1
    fi
    root="$(mktemp -d)"
    dpkg-deb -x "$deb" "$root"
    smoke_binary "$root" "deb"
    rm -rf "$root" "$listing"
  done
fi

if compgen -G "${BUNDLE_DIR}/rpm/*.rpm" > /dev/null; then
  if ! command -v rpm >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y rpm
  fi
  for rpm_pkg in "${BUNDLE_DIR}"/rpm/*.rpm; do
    echo "Auditing rpm package: ${rpm_pkg}"
    listing="$(mktemp)"
    if ! rpm -qpl "$rpm_pkg" > "$listing" 2>&1; then
      cat "$listing" >&2
      echo "ERROR: RPM package query failed" >&2
      exit 1
    fi
    require_pattern "$listing" '/usr/bin/nsm-flow$' "NSM Flow binary"
    require_pattern "$listing" '/usr/lib/Handy/libtranscribe\.so\.[0-9]+$' "transcribe runtime library (SONAME)"
    require_pattern "$listing" '/usr/lib/Handy/libggml-cpu.*\.so' "ggml CPU backend module"
    if [[ "${NSM_LINUX_PLATFORM:-ubuntu-22.04}" == *"ubuntu-22.04"* && "${NSM_LINUX_TARGET:-x86_64-unknown-linux-gnu}" == "x86_64-unknown-linux-gnu" ]]; then
      require_pattern "$listing" 'usr/lib/Handy/libonnxruntime\.so\.[0-9]+$' "ONNX Runtime library (SONAME)"
    fi
    # Same /usr/lib pollution guard as the deb audit (issue #1639).
    if grep -Eq 'usr/lib/[^/]+\.so' "$listing"; then
      echo "ERROR: libraries installed directly into /usr/lib (issue #1639):" >&2
      grep -E 'usr/lib/[^/]+\.so' "$listing" >&2
      exit 1
    fi
    root="$(mktemp -d)"
    rpm_path="$(realpath "$rpm_pkg")"
    echo "Extracting RPM into ${root}"
    # Read the complete payload before cpio exits at its TRAILER!!! record.
    # A pipe can give rpm2cpio SIGPIPE on valid trailing archive padding.
    archive="$(mktemp)"
    rpm2cpio "$rpm_path" > "$archive"
    (cd "$root" && cpio -idm --no-preserve-owner < "$archive")
    rm -f "$archive"
    echo "Launching RPM binary"
    smoke_binary "$root" "rpm"
    rm -rf "$root" "$listing"
  done
fi

if compgen -G "${BUNDLE_DIR}/appimage/*.AppImage" > /dev/null; then
  for appimage in "${BUNDLE_DIR}"/appimage/*.AppImage; do
    echo "Auditing AppImage package: ${appimage}"
    workdir="$(mktemp -d)"
    cp "$appimage" "${workdir}/Handy.AppImage"
    chmod +x "${workdir}/Handy.AppImage"
    (
      cd "$workdir"
      ./Handy.AppImage --appimage-extract >/dev/null
      require_path "squashfs-root/usr/bin/nsm-flow" "AppImage NSM Flow binary"
      # The SONAME (libtranscribe.so.N) is the name the loader
      # resolves; the bare .so alias may or may not be present.
      if ! find "squashfs-root/usr/lib" -name 'libtranscribe.so*' | grep -q .; then
        echo "ERROR: missing AppImage transcribe runtime library" >&2
        find "squashfs-root/usr/lib" -maxdepth 1 -type f >&2
        exit 1
      fi
      if ! find "squashfs-root/usr/lib" -name 'libggml-cpu*.so*' | grep -q .; then
        echo "ERROR: missing AppImage ggml CPU backend module" >&2
        find "squashfs-root/usr/lib" -maxdepth 1 -type f >&2
        exit 1
      fi
      smoke_binary "$(pwd)/squashfs-root" "AppImage"
    )
    rm -rf "$workdir"
  done
fi

