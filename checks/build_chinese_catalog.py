"""Rebuild catalog-label translations from this fork and upstream MuseScore TS files."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
values = {}
for line in (ROOT / "checks/zh-Hans.tsv").read_text(encoding="utf-8").splitlines():
    if "\t" in line:
        key, value = line.split("\t", 1)
        values[key] = value
(ROOT / "checks/zh-Hans.json").write_text(json.dumps(values, ensure_ascii=False, indent=2), encoding="utf-8")
for name in ("instruments_zh_CN.ts", "musescore_zh_CN.ts"):
    for message in ET.parse(ROOT / "share/locale" / name).iter("message"):
        key, unit = message.findtext("source"), message.find("translation")
        if key and unit is not None and unit.text and len(key) < 150 and unit.get("type") not in ("unfinished", "obsolete", "vanished"):
            values.setdefault(key, unit.text)
values.update(json.loads((ROOT / "checks/notation-overrides.json").read_text(encoding="utf-8")))
target = ROOT / "MuseReaderiOS/MuseReaderiOS/Resources/ChineseNotation.json"
target.write_text(json.dumps(values, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Chinese notation labels: {len(values)}")
