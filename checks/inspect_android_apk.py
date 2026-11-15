# SPDX-License-Identifier: GPL-3.0-or-later
"""Check shipped offline resources. AAR input checks the worker module only."""
import hashlib
import io
import json
from pathlib import Path
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "extensions/omr"))
from prepare_models import DIGESTS


def inspect(path):
    with zipfile.ZipFile(path) as archive:
        names = set(archive.namelist())
        for name, expected in DIGESTS.items():
            digest = hashlib.sha256()
            with archive.open("assets/omr-models/" + name) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise ValueError("Packaged model hash mismatch: " + name)
        for name in ["bootstrap.imy", "stdlib-common.imy", "stdlib-arm64-v8a.imy",
                     "requirements-common.imy", "requirements-arm64-v8a.imy"]:
            if archive.getinfo("assets/chaquopy/" + name).file_size == 0:
                raise ValueError("Empty Python resource: " + name)
        with zipfile.ZipFile(io.BytesIO(archive.read("assets/chaquopy/app.imy"))) as python:
            for name in ["aria_conversion.pyc", "aria_midi.pyc", "aria_omr_runtime.pyc", "homr/main.pyc"]:
                if name not in python.namelist():
                    raise ValueError("Missing offline module: " + name)
        if path.suffix.lower() == ".aar":
            print("PASS: worker AAR offline resources (not an installable App)")
            return
        required = ["lib/arm64-v8a/libaria_engine.so", "lib/arm64-v8a/libAriaSkip.so",
                    "lib/arm64-v8a/libQt6Core_arm64-v8a.so",
                    "assets/ios/Legal/GPL-3.0.txt", "assets/ios/Legal/Andromr-AGPL-3.0.txt"]
        for name in required:
            if name not in names:
                raise ValueError("Missing App resource: " + name)
        if not any("assets/ios/ScoreTemplates.bundle/" in name and name.endswith((".mscz", ".mscx")) for name in names):
            raise ValueError("Missing score templates")
        chinese = json.loads(archive.read("assets/ios/ChineseNotation.json"))
        if chinese.get("Piano") != "钢琴" or len(chinese) < 8000:
            raise ValueError("Missing/incomplete notation translations")
        bank = "assets/ios/MuseScore_General.sf2"
        with archive.open(bank) as stream:
            header = stream.read(12)
        if header[:4] != b"RIFF" or header[8:12] != b"sfbk" or archive.getinfo(bank).file_size < 100_000_000:
            raise ValueError("Missing SoundFont or unexpanded LFS pointer")
        native = [name for name in names if name.startswith("lib/") and name.endswith(".so")]
        if {name.split("/")[1] for name in native} != {"arm64-v8a"}:
            raise ValueError("Unexpected native architectures")
        for name in native:
            with archive.open(name) as stream:
                header = stream.read(20)
            if header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[18:20], "little") != 183:
                raise ValueError("Expected AArch64 ELF: " + name)
        print(f"PASS: APK offline assets and {len(native)} AArch64 libraries; runtime testing still required")


if __name__ == "__main__":
    inspect(Path(sys.argv[1]))
