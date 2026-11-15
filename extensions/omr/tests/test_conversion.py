import json
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from aria_midi import convert, parse
from aria_conversion import merge_pages


def vlq(value):
    result = [value & 127]
    while value >= 128:
        value >>= 7; result.insert(0, (value & 127) | 128)
    return bytes(result)


def fixture(path):
    track = b"\x00\xff\x51\x03\x0f\x42\x40"  # 60 BPM
    track += b"\x00\xff\x58\x04\x03\x02\x18\x08"  # 3/4
    track += b"\x00\xc0\x00\x00\x90\x3c\x60"  # piano, C4
    track += vlq(480) + b"\x90\x40\x60"  # E4 overlaps C4
    track += vlq(480) + b"\x80\x40\x00\x00\x90\x43\x60"  # G4
    track += vlq(480) + b"\x80\x43\x00"
    track += vlq(480) + b"\x90\x3c\x00\x00\xff\x2f\x00"  # zero-velocity note off
    path.write_bytes(b"MThd" + struct.pack(">IHHH", 6, 0, 1, 480) + b"MTrk" + struct.pack(">I", len(track)) + track)
    return path


def test_midi_preserves_overlapping_notes_tempo_meter_and_barline_ties(tmp_path):
    source = fixture(tmp_path / "source.mid")
    output = tmp_path / "result.musicxml"
    convert(source, output)
    root = ET.parse(output).getroot()
    assert root.findtext("part/measure/attributes/time/beats") == "3"
    assert root.find("part/measure/direction/sound").get("tempo") == "60.0"
    assert root.findtext("part-list/score-part/midi-instrument/midi-program") == "1"
    bars = root.findall("part/measure")
    assert len(bars) == 2
    c_notes = [n for n in root.iter("note") if n.findtext("pitch/step") == "C"]
    assert [n.findtext("duration") for n in c_notes] == ["1440", "480"]
    assert [n.find("tie").get("type") for n in c_notes] == ["start", "stop"]
    assert len(set(n.findtext("voice") for n in root.iter("note"))) == 2
    assert sorted(n.findtext("pitch/step") for n in root.iter("note") if n.find("pitch") is not None) == ["C", "C", "E", "G"]


def test_truncated_midi_is_rejected(tmp_path):
    source = fixture(tmp_path / "source.mid")
    source.write_bytes(source.read_bytes()[:-8])
    with pytest.raises(ValueError, match="不完整"): parse(source)


def xml(path, name="Piano", pitch="C"):
    path.write_text(f'<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>{name}</part-name></score-part></part-list><part id="P1"><measure number="1"><attributes><divisions>480</divisions></attributes><note><pitch><step>{pitch}</step><octave>4</octave></pitch><duration>480</duration></note></measure></part></score-partwise>', encoding="utf-8")
    return path


def test_pdf_pages_merge_without_losing_notes_or_part_identity(tmp_path):
    pages = [xml(tmp_path / "one.xml"), xml(tmp_path / "two.xml", pitch="G")]
    output = tmp_path / "merged.musicxml"
    result = merge_pages(pages, output)
    root = ET.parse(output).getroot()
    assert result["outputs"] == [str(output)]
    assert [m.get("number") for m in root.findall("part/measure")] == ["1", "2"]
    assert root.find("part/measure[@number='2']/print").get("new-page") == "yes"
    assert [n.findtext("pitch/step") for n in root.iter("note")] == ["C", "G"]


def test_ambiguous_pdf_parts_are_kept_separate(tmp_path):
    pages = [xml(tmp_path / "piano.xml"), xml(tmp_path / "violin.xml", name="Violin")]
    output = tmp_path / "merged.musicxml"
    result = merge_pages(pages, output)
    assert result["outputs"] == [str(p) for p in pages]
    assert not output.exists()
