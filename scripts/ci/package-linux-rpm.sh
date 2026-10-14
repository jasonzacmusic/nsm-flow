#!/usr/bin/env bash
# Package the already-built DEB payload using the distribution's RPM tools.
# No native compilation, stripping, or change to application files is allowed.
set -euo pipefail
bundle_dir="${1:?Pass the directory containing deb/ and rpm/}"
bundle_dir="$(realpath "$bundle_dir")"
if ! command -v rpmbuild >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y rpm
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,payload}
debs=("$bundle_dir"/deb/*.deb)
test "${#debs[@]}" -eq 1
dpkg-deb -x "${debs[0]}" "$work/payload"
version="$(dpkg-deb -f "${debs[0]}" Version)"
# RPM uses ~ for a prerelease; the executable still reports the app's version.
rpm_version="${version/-alpha./~alpha.}"
tar -czf "$work/SOURCES/payload.tar.gz" -C "$work/payload" .
python3 - "$work" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1]); payload = root / 'payload'
paths = sorted(p for p in payload.rglob('*') if p.is_file() or p.is_symlink())
with (root / 'SOURCES/files.txt').open('w') as stream:
    for path in paths:
        name = '/' + path.relative_to(payload).as_posix()
        if any(c in name for c in ('"', '\n', '%', '\\')):
            raise ValueError('Unsupported RPM filename')
        stream.write('"' + name + '"\n')
PY
cat > "$work/SPECS/nsm-flow.spec" <<SPEC
%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}
%global _binary_payload w6.gzdio
Name: nsm-flow
Version: $rpm_version
Release: 1
Summary: Free local voice dictation with Indian vocabulary support
License: MIT
URL: https://github.com/jasonzacmusic/nsm-flow
BuildArch: x86_64
Source0: payload.tar.gz
Source1: files.txt

%description
NSM Flow is an open-source desktop dictation alpha. Application source is MIT;
bundled dependencies retain the licenses in THIRD_PARTY_NOTICES.txt.

%prep
%build
%install
mkdir -p %{buildroot}
tar -xzf %{SOURCE0} -C %{buildroot}

%files -f %{SOURCE1}
%defattr(-,root,root,-)
SPEC
rpmbuild -bb --define "_topdir $work" "$work/SPECS/nsm-flow.spec"
packages=("$work"/RPMS/x86_64/*.rpm)
test "${#packages[@]}" -eq 1
rpm -Kv "${packages[0]}"
mkdir -p "$bundle_dir/rpm"
# Only the newly generated bundle directory is changed, never user data.
rm -f "$bundle_dir"/rpm/*.rpm
cp "${packages[0]}" "$bundle_dir/rpm/NSM-Flow-linux-x64.rpm"
