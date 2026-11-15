# SPDX-License-Identifier: GPL-3.0-or-later
"""SMF 0/1 -> quantized MusicXML; no network or native dependencies.

MIDI lacks notation semantics. Keep tempo/meter/program events, quantize to a
32nd-note grid, preserve overlaps in separate voices, and tie across barlines.
"""
from collections import defaultdict
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

DIVISIONS = 480
GRID = 60


class Reader:
    def __init__(self, data): self.data, self.pos = data, 0
    def read(self, n):
        if n < 0 or self.pos + n > len(self.data): raise ValueError("MIDI 数据不完整")
        result = self.data[self.pos:self.pos+n]; self.pos += n
        return result
    def vlq(self):
        value = 0
        for _ in range(4):
            b = self.read(1)[0]; value = (value << 7) | (b & 127)
            if b < 128: return value
        raise ValueError("MIDI 时间数据无效")


def parse(path):
    source = Reader(Path(path).read_bytes())
    if source.read(4) != b"MThd": raise ValueError("不是标准 MIDI 文件")
    length = struct.unpack(">I", source.read(4))[0]
    if length < 6: raise ValueError("MIDI 文件头无效")
    fmt, tracks, ticks = struct.unpack(">HHH", source.read(6)); source.read(length-6)
    if fmt not in (0, 1) or not 0 < ticks < 0x8000: raise ValueError("暂不支持 MIDI 格式 2 或 SMPTE 时基")
    groups = defaultdict(list); meters = {0: (4, 4)}; tempos = {0: 500000}; names = {}; programs = {}
    def q(t): return max(0, round(t * DIVISIONS / ticks / GRID) * GRID)
    for track_index in range(tracks):
        if source.read(4) != b"MTrk": raise ValueError("MIDI 轨道标记无效")
        track = Reader(source.read(struct.unpack(">I", source.read(4))[0]))
        tick = 0; running = None; active = defaultdict(list); track_name = f"轨道 {track_index + 1}"
        while track.pos < len(track.data):
            tick += track.vlq(); status = track.read(1)[0]
            if status < 128:
                if running is None: raise ValueError("MIDI running status 无效")
                track.pos -= 1; status = running
            if status == 255:
                kind = track.read(1)[0]; payload = track.read(track.vlq())
                if kind == 3: track_name = payload.decode("utf-8", errors="replace")
                if kind == 0x51 and len(payload) == 3: tempos[q(tick)] = int.from_bytes(payload, "big")
                if kind == 0x58 and len(payload) >= 2:
                    if 0 < payload[0] <= 32 and payload[1] <= 6: meters[q(tick)] = (payload[0], 2 ** payload[1])
                if kind == 0x2F: break
                continue
            if status in (0xF0, 0xF7): track.read(track.vlq()); running = None; continue
            if not 0x80 <= status <= 0xEF: raise ValueError("不支持的 MIDI 事件")
            running = status; kind, channel = status >> 4, status & 15
            values = track.read(1 if kind in (0xC, 0xD) else 2)
            group = (track_index, channel); names[group] = track_name
            if kind == 0xC: programs.setdefault(group, values[0] + 1)
            if kind == 9 and values[1] > 0: active[(channel, values[0])].append(tick)
            if kind == 8 or (kind == 9 and values[1] == 0):
                starts = active[(channel, values[0])]
                if starts:
                    start = q(starts.pop(0)); end = max(start + GRID, q(tick))
                    groups[group].append((start, end, values[0]))
        for (channel, pitch), starts in active.items():
            for onset in starts:
                start = q(onset); groups[(track_index, channel)].append((start, max(start + GRID, q(tick)), pitch))
    if not any(groups.values()): raise ValueError("MIDI 中没有可播放音符")
    return groups, meters, tempos, names, programs


def child(parent, tag, text=None, **attrs):
    value = ET.SubElement(parent, tag, attrs)
    if text is not None: value.text = str(text)
    return value


def convert(source, destination):
    groups, meters, tempos, names, programs = parse(source)
    # A performance MIDI can have more than four independent overlapping durations.
    # Preserve every note in additional staves instead of dropping notes or rejecting it.
    expanded = {}; expanded_names = {}; expanded_programs = {}
    for group, notes in groups.items():
        events = defaultdict(list)
        for start, stop, pitch in notes: events[(start, stop)].append(pitch)
        lanes = []; lane_ends = []
        for (start, stop), pitches in sorted(events.items()):
            lane = next((i for i, old_end in enumerate(lane_ends) if old_end <= start), len(lane_ends))
            if lane == len(lanes): lanes.append([]); lane_ends.append(0)
            lanes[lane].extend((start, stop, pitch) for pitch in pitches); lane_ends[lane] = stop
        for offset in range(0, len(lanes), 4):
            key = (*group, offset // 4)
            expanded[key] = [note for lane in lanes[offset:offset+4] for note in lane]
            suffix = f" · 谱表 {offset // 4 + 1}" if len(lanes) > 4 else ""
            expanded_names[key] = names.get(group, "MIDI") + suffix
            expanded_programs[key] = programs.get(group, 1)
    groups, names, programs = expanded, expanded_names, expanded_programs
    end = max(n[1] for notes in groups.values() for n in notes)
    bars = []; position = 0; current_meter = None
    while position < end:
        meter = meters[max(t for t in meters if t <= position)]
        duration = DIVISIONS * 4 * meter[0] // meter[1]
        later = [t for t in meters if position < t < position + duration]
        stop = min(later) if later else position + duration
        bars.append((position, stop, meter, meter != current_meter))
        position = stop; current_meter = meter
        if len(bars) > 20000: raise ValueError("MIDI 曲谱过长")
    root = ET.Element("score-partwise", version="4.0")
    child(child(root, "work"), "work-title", Path(source).stem)
    part_list = child(root, "part-list")
    for part_index, (group, notes) in enumerate(sorted(groups.items()), 1):
        identifier = f"P{part_index}"
        meta = child(part_list, "score-part", id=identifier)
        child(meta, "part-name", names.get(group, f"声部 {part_index}"))
        instrument = child(meta, "score-instrument", id=f"{identifier}-I1"); child(instrument, "instrument-name", names.get(group, "MIDI"))
        midi = child(meta, "midi-instrument", id=f"{identifier}-I1")
        child(midi, "midi-channel", group[1] + 1); child(midi, "midi-program", programs.get(group, 1))
        part = child(root, "part", id=identifier)
        events = defaultdict(list)
        for start, stop, pitch in notes: events[(start, stop)].append(pitch)
        voices = []; ends = []
        for (start, stop), pitches in sorted(events.items()):
            index = next((i for i, old_end in enumerate(ends) if old_end <= start), len(ends))
            if index == len(voices): voices.append([]); ends.append(0)
            voices[index].append((start, stop, sorted(set(pitches)))); ends[index] = stop
        if len(voices) > 4:
            raise ValueError("此 MIDI 的重叠节奏超过 4 个声部，请先拆分轨道后导入")
        for number, (bar_start, bar_end, meter, changed) in enumerate(bars, 1):
            measure = child(part, "measure", number=str(number))
            if number == 1 or changed:
                attributes = child(measure, "attributes"); child(attributes, "divisions", DIVISIONS)
                time = child(attributes, "time"); child(time, "beats", meter[0]); child(time, "beat-type", meter[1])
                if number == 1:
                    clef = child(attributes, "clef"); bass = sum(n[2] for n in notes)/len(notes) < 60
                    child(clef, "sign", "F" if bass else "G"); child(clef, "line", 4 if bass else 2)
            if part_index == 1:
                for tick, tempo in sorted(tempos.items()):
                    if bar_start <= tick < bar_end:
                        direction = child(measure, "direction"); dtype = child(direction, "direction-type")
                        metronome = child(dtype, "metronome"); child(metronome, "beat-unit", "quarter")
                        child(metronome, "per-minute", round(60000000 / tempo, 3))
                        child(direction, "offset", tick - bar_start); child(direction, "sound", tempo=str(60000000 / tempo))
            for vi, events_in_voice in enumerate(voices, 1):
                if vi > 1: child(child(measure, "backup"), "duration", bar_end - bar_start)
                cursor = bar_start
                for start, stop, pitches in events_in_voice:
                    if stop <= bar_start or start >= bar_end: continue
                    begin, finish = max(start, bar_start), min(stop, bar_end)
                    if begin > cursor:
                        rest = child(measure, "note"); child(rest, "rest"); child(rest, "duration", begin-cursor); child(rest, "voice", vi)
                    for chord_index, pitch in enumerate(pitches):
                        note = child(measure, "note")
                        if chord_index: child(note, "chord")
                        step, alter = [("C",0),("C",1),("D",0),("D",1),("E",0),("F",0),("F",1),("G",0),("G",1),("A",0),("A",1),("B",0)][pitch % 12]
                        value = child(note, "pitch"); child(value, "step", step)
                        if alter: child(value, "alter", alter)
                        child(value, "octave", pitch//12-1); child(note, "duration", finish-begin)
                        if start < bar_start: child(note, "tie", type="stop")
                        if stop > bar_end: child(note, "tie", type="start")
                        child(note, "voice", vi)
                        if start < bar_start or stop > bar_end:
                            notations = child(note, "notations")
                            if start < bar_start: child(notations, "tied", type="stop")
                            if stop > bar_end: child(notations, "tied", type="start")
                    cursor = finish
                if cursor < bar_end:
                    rest = child(measure, "note"); child(rest, "rest"); child(rest, "duration", bar_end-cursor); child(rest, "voice", vi)
    ET.indent(root)
    ET.ElementTree(root).write(destination, encoding="utf-8", xml_declaration=True)
    return str(destination)
