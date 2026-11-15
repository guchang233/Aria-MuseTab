"""Source checks for the Android community fork. Not an APK build or Swift typecheck."""
import json
from pathlib import Path
import re
import subprocess
import sys

from localization import ROOT, PARSER, walk, swift_files, inventory


def literals_in_properties(data, names):
    result = {}
    for node in walk(PARSER.parse(data).root_node):
        if node.type != "property_declaration": continue
        name = node.child_by_field_name("name")
        if not name: continue
        key = data[name.start_byte:name.end_byte].decode()
        if key not in names: continue
        result.setdefault(key, []).extend(data[n.start_byte:n.end_byte].decode()
            for n in walk(node) if n.type == "line_string_literal")
    return result


def main():
    problems = []
    for path in swift_files():
        data = path.read_bytes()
        new_errors = [n for n in walk(PARSER.parse(data).root_node) if n.type == "ERROR" or n.is_missing]
        relative = path.relative_to(ROOT).as_posix()
        try: old = subprocess.check_output(["git", "-C", str(ROOT), "show", "HEAD:" + relative], stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError: old = b""
        old_errors = [n for n in walk(PARSER.parse(old).root_node) if n.type == "ERROR" or n.is_missing]
        if len(new_errors) > len(old_errors): problems.append("New Swift parse errors: " + relative)
        protected = {"resourceDirectoryName", "templateFileName"}
        if literals_in_properties(old, protected) != literals_in_properties(data, protected):
            problems.append("Template resource path changed: " + relative)
    shared = ROOT / "MuseReaderAndroid/ios-shared-sources.txt"
    for line in shared.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and not (ROOT / "MuseReaderiOS/MuseReaderiOS" / line).is_file():
            problems.append("Missing Android shared source: " + line)
    exemptions = set(json.loads((ROOT / "checks/locale-exemptions.json").read_text(encoding="utf-8")))
    for text in inventory():
        if text not in exemptions: problems.append("Untranslated presentation string: " + text)
    report = {"passed": not problems, "problems": problems, "scope": "source syntax/resources/localization only"}
    output = ROOT / "checks/results"
    output.mkdir(parents=True, exist_ok=True)
    (output / "source-checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if problems: sys.exit(1)


if __name__ == "__main__": main()
