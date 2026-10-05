#!/usr/bin/env python3
"""Compare immutable GitHub release assets with the exact prepared release."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(dist, version):
    tag = f"nsm-flow-v{version}"
    release = json.loads(subprocess.check_output(["gh", "api", f"repos/jasonzacmusic/labs-downloads/releases/tags/{tag}"], text=True))
    if not release["prerelease"] or release["draft"]:
        raise ValueError("Release must retain the established published alpha audience")
    names = {line.split("  ", 1)[1] for line in (dist / f"NSM-Flow-{version}-SHA256SUMS.txt").read_text().splitlines()}
    names.add(f"NSM-Flow-{version}-SHA256SUMS.txt")
    assets = {asset["name"]: asset for asset in release["assets"]}
    if set(assets) != names:
        raise ValueError("Remote release has missing or unexpected assets; refusing to replace bytes")
    with tempfile.TemporaryDirectory(prefix="nsm-flow-remote-verification-") as temporary:
        for name in sorted(names):
            asset = assets[name]
            local = dist / name
            if asset["size"] != local.stat().st_size:
                raise ValueError(f"Published asset has the wrong size: {name}")
            expected = "sha256:" + sha256(local)
            remote_digest = asset.get("digest")
            if not remote_digest:
                subprocess.run(["gh", "release", "download", tag, "--repo", "jasonzacmusic/labs-downloads", "--pattern", name, "--dir", temporary], check=True, capture_output=True)
                downloaded = Path(temporary) / name
                remote_digest = "sha256:" + sha256(downloaded)
                downloaded.unlink()
            if remote_digest != expected:
                raise ValueError(f"Published bytes differ from prepared bytes: {name}")
    print(f"All {len(names)} immutable published release assets match the verified local bytes")


if __name__ == "__main__":
    try:
        version = json.loads(Path("src-tauri/tauri.conf.json").read_text())["version"]
        verify(Path("dist-release"), version)
    except (OSError, KeyError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"Published release verification failed: {error}")
