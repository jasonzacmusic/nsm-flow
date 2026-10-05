#!/usr/bin/env python3
"""Bind final packages to an exact source commit and product version."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def digest(path):
    with path.open("rb") as stream:
        checksum = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
        return checksum.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("artifacts", type=Path, nargs="+")
    args = parser.parse_args()
    version = json.loads(Path("src-tauri/tauri.conf.json").read_text())["version"]
    if not args.artifacts or any(not path.is_file() for path in args.artifacts):
        raise SystemExit("Missing final release artifact")
    data = {
        "product": "NSM Flow", "version": version, "target": args.target,
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "artifacts": [{"name": path.name, "sha256": digest(path)} for path in args.artifacts],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
