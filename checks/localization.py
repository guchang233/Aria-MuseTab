"""Audit/translate presentation strings without changing action IDs or resource names."""
from pathlib import Path
import json
import re
import sys
from tree_sitter import Language, Parser
import tree_sitter_swift

ROOT = Path(__file__).resolve().parents[1]
PARSER = Parser(Language(tree_sitter_swift.language()))
UI_CALLS = {"Text", "Button", "Label", "Section", "Toggle", "Picker", "ProgressView", "TextField",
            "LabeledContent", "navigationTitle", "accessibilityLabel", "accessibilityHint", "accessibilityValue",
            "help", "alert", "confirmationDialog", "bridgeFailure", "bridgeError", "message", "presentError",
            "detailRow", "SidebarSectionTitle", "SidebarNavButton"}
UI_CALLS.update({"Menu", "Slider", "Stepper", "DisclosureGroup", "GroupBox", "ContentUnavailableView"})
DISPLAY_NAMES = {"title", "label", "message", "summary", "subtitle", "prompt", "description", "name",
                 "displayName", "compactTitle", "settingsTitle", "errorDescription", "problemName", "detail",
                 "secondaryLine", "emptyStateMessage", "footerText", "accessibilityName", "headerTitle", "warning"}
DISPLAY_NAMES.update({"defaultTitle", "instrumentLabel", "detailText", "categoryTitle", "problemTitle"})


def swift_files():
    for folder in [ROOT / "MuseReaderiOS/MuseReaderiOS", ROOT / "MuseReaderAndroid/Aria/Sources/AriaSkip",
                   ROOT / "MuseReaderAndroid/Aria/Sources/AriaEngine"]:
        for path in folder.rglob("*.swift"):
            if "Shared" not in path.parts and "AndroidPhoneAudit" not in path.name:
                yield path


def visible(node, data):
    parent = node.parent
    while parent:
        if parent.type == "assignment":
            prefix = data[parent.start_byte:node.start_byte].decode()
            if prefix.split("=")[0].strip() in DISPLAY_NAMES: return True
        if parent.type == "value_argument":
            name = parent.child_by_field_name("name")
            if name:
                name = data[name.start_byte:name.end_byte].decode()
                # Symbol names, IDs, paths and engine commands must stay exact.
                if name in {"systemName", "systemImage", "id", "key", "textKind", "path", "fileName", "resource", "forResource"}: return False
                if name in DISPLAY_NAMES: return True
                if name.endswith(("Title", "Label", "Text", "Message", "Description", "Hint")): return True
        if parent.type == "call_expression":
            prefix = data[parent.start_byte:parent.children[0].end_byte].decode()
            called = prefix.split(".")[-1]
            if called in UI_CALLS or called.lower().endswith("error"): return True
            if called in {"addText", "addExpression", "appendingPathComponent", "dispatch", "contains", "hasPrefix", "range", "init"}: return False
        if parent.type in {"property_declaration", "function_declaration"}:
            name = parent.child_by_field_name("name")
            if name and data[name.start_byte:name.end_byte].decode() in DISPLAY_NAMES: return True
            # Don't inherit a view's `body` for its IDs or resource names.
            return False
        parent = parent.parent
    return False


def walk(node):
    yield node
    for child in node.children:
        yield from walk(child)


def inventory():
    result = {}
    for path in swift_files():
        data = path.read_bytes()
        for node in walk(PARSER.parse(data).root_node):
            if node.type != "line_string_literal" or not visible(node, data): continue
            text = data[node.start_byte+1:node.end_byte-1].decode()
            if text.startswith(("https://", "http://")): continue
            if not re.search("[A-Za-z]", text) or re.search("[\u3400-\u9fff]", text): continue
            # Exclude notation/format/brand names and strings made only of interpolations.
            plain = re.sub(r"\\\(.*?\)", "", text)
            if not re.search("[A-Za-z]{2}", plain): continue
            result.setdefault(text, []).append((path, node.start_byte, node.end_byte))
    return result


def main():
    entries = inventory()
    target = ROOT / "checks/zh-Hans.json"
    translations = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
    if "--apply" in sys.argv:
        changes = {}
        for key, locations in entries.items():
            if key not in translations: continue
            for path, start, end in locations:
                changes.setdefault(path, []).append((start, end, ('"' + translations[key] + '"').encode()))
        for path, edits in changes.items():
            data = path.read_bytes()
            for start, end, replacement in sorted(edits, reverse=True): data = data[:start] + replacement + data[end:]
            path.write_bytes(data)
        print(f"Translated {sum(map(len, changes.values()))} occurrences in {len(changes)} files")
    else:
        for key in entries:
            if key not in translations: print(key)
        print(f"COUNT: {len(entries)}")


if __name__ == "__main__": main()
