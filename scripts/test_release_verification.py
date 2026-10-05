import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import base64

spec = importlib.util.spec_from_file_location("verify_release", Path(__file__).with_name("verify-release.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseVerificationTests(unittest.TestCase):
    def test_rejects_changed_bytes_and_mixed_versions(self):
        with tempfile.TemporaryDirectory() as directory:
            dist = Path(directory)
            targets = {
                "aarch64-apple-darwin": ["NSM-Flow-mac-Apple-Silicon.dmg"],
                "x86_64-apple-darwin": ["NSM-Flow-mac-Intel.dmg"],
                "x86_64-pc-windows-msvc": ["NSM-Flow-windows-x64-setup.exe", "NSM-Flow-windows-x64.msi"],
            }
            for target, names in targets.items():
                artifacts = []
                for name in names:
                    data = name.encode()
                    (dist / name).write_bytes(data)
                    artifacts.append({"name": name, "sha256": hashlib.sha256(data).hexdigest()})
                (dist / f"provenance-{target}.json").write_text(json.dumps({"target": target, "version": "0.3.0-alpha.2", "commit": "verified", "artifacts": artifacts}))
            module.verify(dist, "0.3.0-alpha.2", "verified")
            with self.assertRaises(ValueError):
                module.verify(dist, "0.3.0-alpha.3", "verified")
            with self.assertRaises(ValueError):
                module.verify(dist, "0.3.0-alpha.2", "different-commit")
            (dist / "NSM-Flow-mac-Apple-Silicon.dmg").write_bytes(b"changed")
            with self.assertRaises(ValueError):
                module.verify(dist, "0.3.0-alpha.2", "verified")

    def test_prepared_feed_rejects_changed_bytes_and_signature_mismatch(self):
        version = "0.3.0-alpha.2"
        signature = base64.b64encode(b"fixture signature").decode()
        public = base64.b64encode(b"fixture public key").decode()
        with tempfile.TemporaryDirectory() as directory:
            dist = Path(directory)
            names = {
                "NSM-Flow-mac-Apple-Silicon.dmg", "NSM-Flow-mac-Intel.dmg",
                "NSM-Flow-windows-x64-setup.exe", "NSM-Flow-windows-x64.msi",
                "provenance-aarch64-apple-darwin.json", "provenance-x86_64-apple-darwin.json",
                "provenance-x86_64-pc-windows-msvc.json", "nsm-flow.json",
                f"NSM-Flow-{version}-source.zip", f"NSM-Flow-{version}-complete.zip",
            }
            platforms = {
                "darwin-aarch64": "NSM-Flow-mac-Apple-Silicon.app.tar.gz",
                "darwin-x86_64": "NSM-Flow-mac-Intel.app.tar.gz",
                "windows-x86_64": "NSM-Flow-windows-x64-setup.exe",
            }
            names.update(name + suffix for name in platforms.values() for suffix in ("", ".sig"))
            for name in names:
                (dist / name).write_text(signature if name.endswith(".sig") else name)
            feed = {
                "version": version, "pub_date": "2026-10-05T00:00:00Z",
                "platforms": {target: {"signature": signature, "url": f"https://github.com/jasonzacmusic/labs-downloads/releases/download/nsm-flow-v{version}/{name}"} for target, name in platforms.items()},
            }
            (dist / "nsm-flow.json").write_text(json.dumps(feed))
            (dist / "RELEASE_NOTES.md").write_bytes((Path("src/content/release-notes") / f"{version}.md").read_bytes())
            sums = dist / f"NSM-Flow-{version}-SHA256SUMS.txt"
            sums.write_text("".join(f"{hashlib.sha256((dist / name).read_bytes()).hexdigest()}  {name}\n" for name in sorted(names)))
            # Cryptography itself is exercised on real signed archives at release.
            with patch.object(module.subprocess, "run"):
                module.verify_prepared(dist, version, public)
                (dist / "NSM-Flow-mac-Apple-Silicon.app.tar.gz").write_bytes(b"changed after preparation")
                with self.assertRaisesRegex(ValueError, "bytes changed"):
                    module.verify_prepared(dist, version, public)
                feed["platforms"]["darwin-aarch64"]["signature"] = "mismatch"
                (dist / "nsm-flow.json").write_text(json.dumps(feed))
                with self.assertRaisesRegex(ValueError, "disagrees"):
                    module.verify_prepared(dist, version, public)


if __name__ == "__main__":
    unittest.main()
