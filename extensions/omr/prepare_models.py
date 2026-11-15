# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage hash-pinned offline models, reusing the project-local cache when available."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import urllib.request
import zipfile

HERE = Path(__file__).resolve().parent
DIGESTS = {
    "segnet_308_int8.tflite": "a7caace11bcd3df8aaa6addfa89eb994a8bdade34f977430742e8565e7f0acb7",
    "encoder_414_int8.tflite": "42f98864b83caa25e8da59bbfdf0f864d1860c3c13ac2a62e1e9e9fdaaba0a2c",
    "decoder_414_int8.onnx": "694a48cae3bc5cbf4f179c70833bd0a58233fe1adf53fe0154b6b6377542f957",
}


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""): result.update(chunk)
    return result.hexdigest()


def prepare(destination):
    manifest = json.loads((HERE / "models.json").read_text(encoding="utf-8"))
    cache = HERE.parents[1] / ".local/omr-models"
    cache.mkdir(parents=True, exist_ok=True)
    destination = Path(destination) / "omr-models"
    destination.mkdir(parents=True, exist_ok=True)
    inventory = {"revision": manifest["revision"], "models": []}
    for model in manifest["models"]:
        name = model["file"]; expected = DIGESTS[name]; file = cache / name
        if not file.is_file() or digest(file) != expected:
            archive = cache / model["archive"]
            if not archive.is_file() or digest(archive) != model["sha256"]:
                partial = archive.with_suffix(".partial")
                urllib.request.urlretrieve(manifest["release"] + model["archive"], partial)
                if digest(partial) != model["sha256"]: raise ValueError("模型下载校验失败：" + name)
                partial.replace(archive)
            with zipfile.ZipFile(archive) as zipped:
                candidates = [entry for entry in zipped.infolist() if Path(entry.filename).name == name]
                if len(candidates) != 1 or candidates[0].file_size > 512 * 1024 * 1024: raise ValueError("模型压缩包无效")
                with zipped.open(candidates[0]) as source, file.with_suffix(".partial").open("wb") as output:
                    shutil.copyfileobj(source, output)
                file.with_suffix(".partial").replace(file)
        if digest(file) != expected: raise ValueError("模型内容校验失败：" + name)
        shutil.copy2(file, destination / name)
        inventory["models"].append({"file": name, "sha256": expected})
    (destination / "verified.json").write_text(json.dumps(inventory, indent=2), encoding="utf-8")


if __name__ == "__main__": prepare(sys.argv[1])
