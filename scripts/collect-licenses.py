#!/usr/bin/env python3
"""Collect license texts for the target's resolved Cargo graph and frontend.

The inventory is evidence, not a legal opinion. OS libraries, downloaded models,
and native libraries embedded by sys crates need their own applicable notices.
"""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def collect(target):
    metadata = json.loads(subprocess.check_output([
        "cargo", "metadata", "--manifest-path", str(ROOT / "src-tauri/Cargo.toml"),
        "--locked", "--format-version", "1", "--filter-platform", target,
    ], text=True))
    packages = {p["id"]: p for p in metadata["packages"]}
    graph = {n["id"]: n["dependencies"] for n in metadata["resolve"]["nodes"]}
    pending = [metadata["resolve"]["root"]]
    seen = set()
    while pending:
        current = pending.pop()
        if current not in seen:
            seen.add(current)
            pending.extend(graph.get(current, []))
    return sorted((packages[k] for k in seen), key=lambda p: (p["name"], p["version"]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    packages = collect(args.target)
    # Linux source is intended to remain permissively licensed. Catch the known
    # GPL-only Hyprland dependency rather than silently relabeling its binary.
    forbidden = [p["name"] for p in packages
                 if (p.get("license") or "").startswith("GPL-")]
    if forbidden:
        raise SystemExit("GPL-only packages require a licensing review: " + ", ".join(forbidden))
    chunks = ["NSM Flow third-party license collection\nTarget: " + args.target,
              "Application MIT license:\n" + (ROOT / "LICENSE").read_text(),
              (ROOT / "NOTICE.md").read_text()]
    for package in packages:
        directory = Path(package["manifest_path"]).parent
        texts = []
        for path in sorted(directory.iterdir()):
            if path.is_file() and path.name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE", "COPYRIGHT")):
                texts.append(path.name + "\n" + path.read_text(errors="replace"))
        chunks.append("\n".join([
            package["name"] + " " + package["version"],
            "Declared license: " + (package.get("license") or "see upstream license files"),
            "Source: " + (package.get("repository") or "https://crates.io/crates/" + package["name"]),
            *texts,
        ]))
    # Include transitive frontend notices, not only direct package dependencies.
    frontend = ROOT / "node_modules"
    if frontend.exists():
        for manifest in sorted(frontend.glob("**/package.json")):
            if "/.cache/" in str(manifest):
                continue
            package = json.loads(manifest.read_text())
            texts = []
            for path in sorted(manifest.parent.iterdir()):
                if path.is_file() and path.name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE", "COPYRIGHT")):
                    texts.append(path.name + "\n" + path.read_text(errors="replace"))
            if texts:
                chunks.append("\n".join(["Frontend: " + package.get("name", "unknown") + " " + package.get("version", ""), *texts]))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(chunks) + "\n")
    print(f"Collected {len(packages)} target Cargo packages and frontend license texts into {args.output}")


if __name__ == "__main__":
    main()
