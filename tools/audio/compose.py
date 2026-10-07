"""Score for Guide The Ball ("Event Frame"): writes MIDI files and audiokit render specs.

Two seamless loops in D Dorian plus one "SFX sources" spec whose stems are layered into
the sound effects by sfx.py. Nothing here renders audio; build.py hands the specs to
/tmp/audiokit/render.py (Vital / Serum 2 / MS Basic soundfont / numpy voices).

Preset pitch quirks (from the audiokit catalog, checked against our renders):
  Serum 2 Kinderjoy sounds two octaves up, Serum 2 "Club - Muted" bass two octaves down
  (measured: D2 written gave 18 Hz), Vital Ceramic about three octaves up, Vital Super Nice
  Pluck about three octaves down. Serum 2 Tetris measured at written pitch in this context.
  Tracks are written at sounding pitch and corrected with the spec's "transpose".
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

AUDIOKIT = "/tmp/audiokit"
sys.path.insert(0, AUDIOKIT)
import midi_io  # noqa: E402  (shared audiokit helper, read-only)

VITAL = os.path.expanduser("~/Music/Vital")
SERUM = "/Library/Audio/Presets/Xfer Records/Serum 2 Presets/Presets/Factory"
PRESETS = {
    "dark_space": ("serum2", f"{SERUM}/Pad/PD - Dark Space.SerumPreset"),
    "kinderjoy": ("serum2", f"{SERUM}/Bell/BL - Kinderjoy.SerumPreset"),
    "tetris": ("serum2", f"{SERUM}/Synth/SY - Tetris.SerumPreset"),
    "muted_bass": ("serum2", f"{SERUM}/Bass/Synth/BA - Club - Muted.SerumPreset"),
    "analog_pad": ("vital", f"{VITAL}/In The Mix/Presets/Analog Pad.vital"),
    "ceramic": ("vital", f"{VITAL}/Databroth/Presets/Factory Presets/Ceramic.vital"),
    "crescendo": ("vital", f"{VITAL}/Level 8/Presets/Factory Presets/Crescendo Bells.vital"),
    "sub_pluck": ("vital", f"{VITAL}/Mr Bill/Presets/Super Nice Pluck.vital"),
}
OCTAVE_FIX = {"kinderjoy": -24, "ceramic": -36, "sub_pluck": 36, "muted_bass": 24}
DRUM_CH = 9
KICK, STICK, HAT = 36, 37, 42

# D Dorian voicings (sounding MIDI notes).
CHORDS = {
    "Dm9": [50, 57, 60, 64, 65],
    "Fmaj7": [53, 57, 60, 64],
    "G69": [55, 59, 62, 64, 69],
    "Em7": [52, 59, 62, 67],
    "Cmaj9": [48, 55, 59, 62, 64],
    "Bm7b5": [47, 57, 62, 65],
    "Asus7": [45, 55, 62, 64],
}
ROOTS = {"Dm9": 38, "Fmaj7": 41, "G69": 43, "Em7": 40, "Cmaj9": 36, "Bm7b5": 35, "Asus7": 33}


def instrument(key: str) -> dict:
    kind, path = PRESETS[key]
    if not os.path.exists(path):
        raise FileNotFoundError(f"preset missing: {path}")
    return {"type": kind, "preset": path}


def reverb(room: float, wet: float) -> dict:
    return {"type": "Reverb", "room_size": room, "wet_level": wet, "dry_level": 1.0 - wet / 2,
            "damping": 0.45}


def bubble_track(chord: list[int], start: float, beat: float, length: int,
                 rng: np.random.Generator) -> list[tuple]:
    """A run of glass notes spiralling down the chord with shrinking gaps, the way a
    slowing particle leaves denser bubbles."""
    tones = sorted({n + 12 * o for n in chord for o in (1, 2)})
    tones = [n for n in tones if 64 <= n <= 93]
    idx = len(tones) - 1 - int(rng.integers(0, 3))
    gap = beat * float(rng.choice([1.0, 0.75]))
    t, notes = start, []
    for k in range(length):
        vel = int(30 + 80 * (1 - k / (length + 1)))
        notes.append((t, max(gap, beat / 4) * 0.9, tones[idx % len(tones)], vel))
        t += gap
        gap = max(beat / 4, gap * 0.72)
        idx -= int(rng.integers(1, 3))
        if idx < 0:
            break
    return notes


def to_beats(notes: list[tuple], beat: float, ch: int = 0) -> list[tuple]:
    """(start_s, dur_s, pitch, vel) -> midi_io tuples in beats."""
    return [(s / beat, d / beat, int(p), int(np.clip(v, 1, 127)), ch) for s, d, p, v in notes]


# --- title: "Scanning Table" -----------------------------------------------------------

def scanning_table(rng: np.random.Generator) -> tuple[dict, float]:
    """60 BPM, 16 bars. Idle lab: pad, low drone, one glass note per bar, a bubble track
    on bar 3 of each chord, film-transport tick on every other beat."""
    beat, bars = 1.0, 16
    bar = 4 * beat
    prog = ["Dm9", "Fmaj7", "Em7", "Asus7"]
    pad, drone, motif, bubbles, ticks = [], [], [], [], []
    for k, name in enumerate(prog):
        s = k * 4 * bar
        pad += [(s, 4 * bar - 0.1, n, 72) for n in CHORDS[name]]
        drone.append((s, 4 * bar - 0.1, ROOTS[name], 80))
    line = [74, 69, 72, 76, 74, 69, 65, 67]  # D A C E D A F G
    for b in range(bars):
        motif.append((b * bar - 0.12 if b else 0.0, 2.5, line[b % 8] - 12, 70))
        if b % 4 == 2:
            bubbles += bubble_track(CHORDS[prog[b // 4]], b * bar + 2 * beat, beat, 6, rng)
    for i in range(0, bars * 4, 2):
        ticks.append((i * beat, 0.05, 86 if i % 4 == 0 else 83, 90 if i % 8 == 0 else 55))
    return _song("scanning_table", 60, bars * bar, [
        ("pad_dark_space", pad, "dark_space", -6, 0.0, [reverb(0.85, 0.3)]),
        ("drone_analog_pad", drone, "analog_pad", -5, 0.0, []),
        ("motif_crescendo", motif, "crescendo", -8, -0.15, [reverb(0.9, 0.35)]),
        ("bubbles_kinderjoy", bubbles, "kinderjoy", -9, 0.2,
         [{"type": "LowpassFilter", "cutoff_frequency_hz": 6500}, reverb(0.85, 0.35)]),
        ("bubbles_fm", bubbles, "synth:bell", -18, -0.25, [reverb(0.85, 0.4)]),
        ("tick_ceramic", ticks, "ceramic", -15, 0.3, [reverb(0.5, 0.12)]),
    ], beat)


# --- gameplay: "Exposure" --------------------------------------------------------------

LEAD = [  # (bar offset, beat in bar, beats, sounding pitch) over Dm9 Fmaj7 G69 Em7
    (0, 0, 1.5, 81), (0, 1.5, .5, 79), (0, 2, 1, 77), (0, 3, 1, 76), (1, 0, 3, 74),
    (2, 0, 1.5, 84), (2, 1.5, .5, 81), (2, 2, 1, 79), (2, 3, 1, 77), (3, 0, 2, 76),
    (3, 2, 1, 77), (3, 3, 1, 79),
    (4, 0, 1.5, 81), (4, 1.5, .5, 83), (4, 2, 2, 86), (5, 0, 1, 83), (5, 1, 1, 81),
    (5, 2, 2, 79), (6, 0, 1.5, 76), (6, 1.5, .5, 79), (6, 2, 1, 83), (6, 3, 1, 81),
    (7, 0, 1, 79), (7, 1, 1, 76), (7, 2, 2, 74),
]


def _rhythm(b: int, beat: float, bar: float, prog: list[str]) -> tuple[list, list]:
    """Bass pulse and soft kit for bar b of the B/C sections."""
    bass, drums = [], []
    root = ROOTS[prog[b // 2]]
    for e in range(8):
        accent = e in (0, 3, 6)
        bass.append((b * bar + e * beat / 2, beat * 0.42, root + (12 if e == 7 else 0),
                     100 if accent else 62))
    full = b < 24
    if full:
        drums.append((b * bar, 0.1, KICK, 92))
        drums.append((b * bar + 1.5 * beat, 0.1, KICK, 60))
        drums.append((b * bar + 2 * beat, 0.1, STICK, 70))
    for e in range(8):
        drums.append((b * bar + e * beat / 2, 0.05, HAT, (58 if e % 2 == 0 else 36) if full else 40))
    return bass, drums


def exposure(rng: np.random.Generator) -> tuple[dict, float]:
    """90 BPM, 32 bars. A (1-8) pad, tick, bubbles; B (9-16) + bass pulse and soft kit;
    C (17-24) + glide lead; D (25-32) thins out (bass and kit stop at 28) into the loop."""
    beat, bars = 60 / 90, 32
    bar = 4 * beat
    prog = ["Dm9", "Fmaj7", "G69", "Em7", "Dm9", "Cmaj9", "Bm7b5", "Asus7"] * 2
    pad, drone, bubbles, ticks, bass, drums, lead, glass = [], [], [], [], [], [], [], []
    for k in range(0, bars, 2):
        name = prog[k // 2]
        pad += [(k * bar, 2 * bar - 0.08, n, 70) for n in CHORDS[name]]
        drone.append((k * bar, 2 * bar - 0.08, ROOTS[name], 75))
    for b in range(bars):
        chord = CHORDS[prog[b // 2]]
        dense = 8 <= b < 24
        if b % 2 == 0 or (dense and rng.random() < 0.5):
            start = b * bar + beat * float(rng.choice([0, 0.5, 1, 2, 2.5]))
            bubbles += bubble_track(chord, start, beat, int(rng.integers(4, 8 if dense else 6)), rng)
        if b < 8 or b >= 28:
            if b % 2 == 0:
                glass.append((b * bar - 0.1 if b else 0.0, 2.2, chord[-1] + 12, 64))
        if 8 <= b < 28:
            bs, dr = _rhythm(b, beat, bar, prog)
            bass += bs
            drums += dr
        for i in range(4):
            ticks.append((b * bar + i * beat, 0.04, 86 if i == 0 else 83, 85 if i == 0 else 50))
    for ob, bt, d, p in LEAD:
        lead.append(((16 + ob) * bar + bt * beat, d * beat * 0.95, p, 88))
    return _song("exposure", 90, bars * bar, [
        ("pad_dark_space", pad, "dark_space", -7, 0.0, [reverb(0.8, 0.28)]),
        ("drone_analog_pad", drone, "analog_pad", -8, 0.0, []),
        ("glass_crescendo", glass, "crescendo", -11, -0.2, [reverb(0.9, 0.35)]),
        ("bubbles_kinderjoy", bubbles, "kinderjoy", -11, 0.2,
         [{"type": "LowpassFilter", "cutoff_frequency_hz": 6500}, reverb(0.8, 0.3)]),
        ("bubbles_fm", bubbles, "synth:bell", -20, -0.25, [reverb(0.8, 0.35)]),
        ("tick_ceramic", ticks, "ceramic", -17, 0.3, [reverb(0.4, 0.1)]),
        ("bass_muted", bass, "muted_bass", -10, 0.0,
         [{"type": "HighpassFilter", "cutoff_frequency_hz": 40},
          {"type": "LowpassFilter", "cutoff_frequency_hz": 1800}]),
        ("kit_msbasic", drums, "gm_drums", -4, 0.0, [reverb(0.4, 0.12)]),
        ("lead_tetris", lead, "tetris", 6, 0.1,
         [{"type": "LowpassFilter", "cutoff_frequency_hz": 5000},
          {"type": "Delay", "delay_seconds": beat * 0.75, "feedback": 0.25, "mix": 0.18},
          reverb(0.8, 0.25)]),
    ], beat)


# --- SFX sources ----------------------------------------------------------------------

SFX_SLOT = 3.0  # seconds between source notes, so tails never overlap


def sfx_sources() -> tuple[dict, dict]:
    """One note group per slot; sfx.py slices stems by slot. Returns (parts, slot map)."""
    parts = {"glass": [], "tick": [], "thud": [], "chime": []}
    slots: dict[str, tuple[str, int]] = {}

    def add(label: str, part: str, notes: list[tuple]) -> None:
        slot = len([v for v in slots.values() if v[0] == part])
        base = slot * SFX_SLOT
        parts[part] += [(base + s, d, p, v) for s, d, p, v in notes]
        slots[label] = (part, slot)

    add("glass_d5", "glass", [(0, 0.4, 74, 100)])
    add("glass_goal", "glass", [(0, 0.5, 74, 95), (0.1, 0.6, 81, 105)])
    add("glass_arp", "glass", [(0.08 + k * 0.09, 0.5, n, 80 + 6 * k)
                               for k, n in enumerate([62, 65, 69, 72, 76])])
    add("glass_confirm", "glass", [(0, 0.08, 81, 90), (0.07, 0.12, 86, 100)])
    add("chime_hold", "chime", [(0.0, 1.0, 62, 90), (0.0, 1.0, 69, 85)])
    add("tick_hi", "tick", [(0, 0.03, 88, 100)])
    add("tick_mid", "tick", [(0, 0.03, 81, 100)])
    add("tick_lo", "tick", [(0, 0.03, 74, 100)])
    add("tick_shutter", "tick", [(0, 0.03, 69, 110), (0.07, 0.03, 64, 90)])
    rng = np.random.default_rng(3)
    add("tick_fizz", "tick", [(float(s), 0.02, int(rng.integers(76, 96)), int(rng.integers(40, 100)))
                              for s in np.sort(rng.uniform(0, 0.5, 18))])
    add("tick_rise", "tick", [(0.028 * k, 0.03, n, 70 + 10 * k) for k, n in enumerate([76, 81, 86, 91])])
    add("glass_fall", "glass", [(0.13 * k, 0.4, n, 90 - 12 * k) for k, n in enumerate([69, 65, 62, 57])])
    add("thud_d2", "thud", [(0, 0.15, 38, 110)])
    add("thud_power", "thud", [(0, 0.6, 38, 100)])
    return parts, slots


def write_sfx_spec(work: str) -> dict:
    parts, slots = sfx_sources()
    keys = {"glass": "kinderjoy", "tick": "ceramic", "thud": "sub_pluck",
            "chime": "crescendo"}
    order = list(parts)
    midi = os.path.join(work, "sfx_sources.mid")
    midi_io.write_midi(midi, [to_beats(parts[p], 1.0) for p in order], bpm=60)
    tracks = [{"name": p, "midi": midi, "track": i, "instrument": instrument(keys[p]),
               "transpose": OCTAVE_FIX.get(keys[p], 0)} for i, p in enumerate(order)]
    spec = {"out": os.path.join(work, "sfx_sources_mix.wav"), "lufs": -18, "tail": 3,
            "stems_dir": os.path.join(work, "sfx_stems"), "png": True, "tracks": tracks}
    with open(os.path.join(work, "sfx_sources.json"), "w") as f:
        json.dump(spec, f, indent=1)
    with open(os.path.join(work, "sfx_slots.json"), "w") as f:
        json.dump({"slot_seconds": SFX_SLOT, "slots": slots}, f, indent=1)
    return spec


# --- spec writer ----------------------------------------------------------------------

_WORK = {"dir": None}


def _song(name: str, bpm: float, length: float, parts: list, beat: float) -> tuple[dict, float]:
    work = _WORK["dir"]
    midi = os.path.join(work, f"{name}.mid")
    midi_io.write_midi(midi, [to_beats(p[1], beat, DRUM_CH if p[2] == "gm_drums" else 0)
                              for p in parts], bpm=bpm)
    tracks = []
    for i, (label, _notes, key, gain, pan, fx) in enumerate(parts):
        if key.startswith("synth:"):
            inst = {"type": "synth", "voice": key.split(":")[1], "release": 0.6}
        elif key == "gm_drums":
            inst = {"type": "fluidsynth", "program": 0, "bank": 0, "gain": 0.5}  # ch 10 = GM kit
        else:
            inst = instrument(key)
        tracks.append({"name": label, "midi": midi, "track": i, "instrument": inst,
                       "transpose": OCTAVE_FIX.get(key, 0), "gain_db": gain, "pan": pan, "fx": fx})
    spec = {"out": os.path.join(work, f"{name}.wav"), "lufs": -18, "ceiling_dbtp": -1.0,
            "loop": length, "length": length, "tail": 8, "png": True,
            "stems_dir": os.path.join(work, f"{name}_stems"),
            "master_fx": [{"type": "Compressor", "threshold_db": -20, "ratio": 1.8,
                           "attack_ms": 30, "release_ms": 250},
                          {"type": "LowpassFilter", "cutoff_frequency_hz": 12000}],
            "tracks": tracks}
    with open(os.path.join(work, f"{name}.json"), "w") as f:
        json.dump(spec, f, indent=1)
    return spec, length


def write_all(work: str) -> list[str]:
    os.makedirs(work, exist_ok=True)
    _WORK["dir"] = work
    scanning_table(np.random.default_rng(5))
    exposure(np.random.default_rng(11))
    write_sfx_spec(work)
    return [os.path.join(work, f"{n}.json") for n in ("scanning_table", "exposure", "sfx_sources")]


if __name__ == "__main__":
    for path in write_all(sys.argv[1] if len(sys.argv) > 1 else "/tmp/element-maze-audio"):
        print(path)
