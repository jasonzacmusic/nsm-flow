#!/usr/bin/env python3
"""Reject stale/mixed-platform release bytes before signing an updater feed."""
import hashlib
import json
import base64
from datetime import datetime
from pathlib import Path
import subprocess
import sys
import tempfile


def verify(dist, version, commit):
    expected = {
        "aarch64-apple-darwin": {"NSM-Flow-mac-Apple-Silicon.dmg"},
        "x86_64-apple-darwin": {"NSM-Flow-mac-Intel.dmg"},
        "x86_64-pc-windows-msvc": {"NSM-Flow-windows-x64-setup.exe", "NSM-Flow-windows-x64.msi"},
    }
    for target, names in expected.items():
        manifest = json.loads((dist / f"provenance-{target}.json").read_text())
        if manifest["version"] != version or manifest["commit"] != commit or manifest["target"] != target:
            raise ValueError(f"Stale or mismatched provenance for {target}")
        if {item["name"] for item in manifest["artifacts"]} != names:
            raise ValueError(f"Missing/unexpected artifacts for {target}")
        for item in manifest["artifacts"]:
            with (dist / item["name"]).open("rb") as stream:
                checksum = hashlib.sha256()
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    checksum.update(chunk)
                actual = checksum.hexdigest()
            if actual != item["sha256"]:
                raise ValueError(f"Artifact changed after verification: {item['name']}")


def verify_prepared(dist, version, public_key):
    """Validate the exact prepared bytes without regenerating any release file."""
    feed = json.loads((dist / "nsm-flow.json").read_text())
    base = f"https://github.com/jasonzacmusic/labs-downloads/releases/download/nsm-flow-v{version}/"
    platforms = {
        "darwin-aarch64": "NSM-Flow-mac-Apple-Silicon.app.tar.gz",
        "darwin-x86_64": "NSM-Flow-mac-Intel.app.tar.gz",
        "windows-x86_64": "NSM-Flow-windows-x64-setup.exe",
    }
    if feed["version"] != version or set(feed["platforms"]) != set(platforms):
        raise ValueError("Prepared feed has the wrong version or platform set")
    datetime.fromisoformat(feed["pub_date"].replace("Z", "+00:00"))
    with tempfile.TemporaryDirectory(prefix="nsm-flow-signatures-") as temporary:
        key = Path(temporary) / "public.pub"
        key.write_bytes(base64.b64decode(public_key, validate=True))
        for target, name in platforms.items():
            entry = feed["platforms"][target]
            signature = (dist / f"{name}.sig").read_text().strip()
            if entry["url"] != base + name or entry["signature"].strip() != signature:
                raise ValueError(f"Prepared feed disagrees with signed artifact: {target}")
            detached = Path(temporary) / f"{target}.minisig"
            detached.write_bytes(base64.b64decode(signature, validate=True))
            subprocess.run(["minisign", "-Vm", str(dist / name), "-p", str(key), "-x", str(detached)], check=True, capture_output=True)
    expected = {
        "NSM-Flow-mac-Apple-Silicon.dmg", "NSM-Flow-mac-Intel.dmg",
        "NSM-Flow-windows-x64-setup.exe", "NSM-Flow-windows-x64.msi",
        "provenance-aarch64-apple-darwin.json", "provenance-x86_64-apple-darwin.json",
        "provenance-x86_64-pc-windows-msvc.json", "nsm-flow.json",
        f"NSM-Flow-{version}-source.zip", f"NSM-Flow-{version}-complete.zip",
    }
    expected.update(name + suffix for name in platforms.values() for suffix in ("", ".sig"))
    checksums = {}
    for line in (dist / f"NSM-Flow-{version}-SHA256SUMS.txt").read_text().splitlines():
        digest, name = line.split("  ", 1)
        if name in checksums or Path(name).name != name:
            raise ValueError("Duplicate or unsafe checksum filename")
        checksums[name] = digest
    if set(checksums) != expected:
        raise ValueError("Prepared checksums have missing or unexpected release files")
    for name, expected_digest in checksums.items():
        digest = hashlib.sha256()
        with (dist / name).open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected_digest:
            raise ValueError(f"Prepared release bytes changed: {name}")
    if (dist / "RELEASE_NOTES.md").read_bytes() != (Path("src/content/release-notes") / f"{version}.md").read_bytes():
        raise ValueError("Prepared release notes differ from the verified source")


if __name__ == "__main__":
    try:
        config = json.loads(Path("src-tauri/tauri.conf.json").read_text())
        verify(Path("dist-release"), config["version"], subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip())
        if "--prepared" in sys.argv:
            verify_prepared(Path("dist-release"), config["version"], config["plugins"]["updater"]["pubkey"])
    except (OSError, KeyError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"Release verification failed: {error}")
    print("Every platform matches this version, source commit and final artifact hash")
