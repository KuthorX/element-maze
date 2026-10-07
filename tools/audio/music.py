"""Two seamless loops in D Dorian for Guide The Ball.

Concept: the scanning table of a bubble-chamber lab. A magnet hum drone, cold sine pads,
a film-transport tick, and "bubble tracks": runs of glass notes that spiral down through
the chord with gaps that shrink as they go, the way a slowing particle leaves denser
bubbles. Everything is rendered into a buffer of exactly the loop length; note tails and
reverb wrap around, so the loop point has no seam.
"""
from __future__ import annotations

import numpy as np

from synth import (SR, bandpass, exp_env, fm_bell, lowpass, midi_hz, noise, pan, place,
                   sine, stereo_reverb, t_axis)

# D Dorian chord voicings (MIDI), pads sit around octave 4.
CHORDS = {
    "Dm9": [50, 57, 60, 64, 65],
    "Fmaj7": [53, 57, 60, 64],
    "G69": [55, 59, 62, 64, 69],
    "Em7": [52, 59, 62, 67],
    "Cmaj9": [48, 55, 59, 62, 64],
    "Bm7b5": [47, 57, 62, 65],
    "Asus7": [45, 55, 62, 64],
}


def _loop_filter(x: np.ndarray, fn) -> np.ndarray:
    """Apply a causal filter as if the signal had been looping forever."""
    n = len(x)
    y = fn(np.concatenate([x, x, x]))
    return y[n:2 * n]


def _drone(n: int, root: int, level: float) -> np.ndarray:
    """Magnet hum: root sine plus fifth and octave, breathing at whole cycles per loop."""
    loop_sec = n / SR
    t = np.arange(n) / SR
    out = np.zeros(n)
    for mult, amp, cycles in ((1.0, 1.0, 3), (1.5, 0.25, 5), (2.0, 0.35, 4)):
        f = midi_hz(root) * mult
        f = round(f * loop_sec) / loop_sec  # whole periods per loop
        lfo = 0.65 + 0.35 * np.sin(2 * np.pi * cycles * t / loop_sec)
        out += amp * lfo * np.sin(2 * np.pi * f * t)
    return pan(out * level, 0.0)


def _pad_note(note: int, dur: float, detune: float = 0.12) -> np.ndarray:
    f = midi_hz(note)
    t = t_axis(dur)
    tone = sum(np.sin(2 * np.pi * f * (1 + d * detune / 100) * t) for d in (-1, 0, 1)) / 3
    tone += 0.12 * np.sin(2 * np.pi * 2 * f * t)
    att, rel = min(1.2, dur / 3), min(1.6, dur / 2)
    env = np.minimum(1, t / att) * np.minimum(1, (dur - t) / rel).clip(0)
    return tone * env


def _pads(n: int, prog: list[str], bars_per: int, bar_sec: float, level: float) -> np.ndarray:
    out = np.zeros((n, 2))
    for k, name in enumerate(prog):
        start = k * bars_per * bar_sec
        dur = bars_per * bar_sec + 1.2  # overlap into the next chord
        for i, note in enumerate(CHORDS[name]):
            p = -0.5 + i / max(1, len(CHORDS[name]) - 1)
            place(out, pan(_pad_note(note, dur) * level, p * 0.6), start, wrap=True)
    return out


def _bubble(note: int, vel: float, rng) -> np.ndarray:
    dur = 0.25 + 0.5 * vel
    b = fm_bell(midi_hz(note), dur, ratio=3.5, index=1.4 * vel + 0.3, decay=0.12 + 0.25 * vel)
    return b * vel


def _track(out: np.ndarray, chord: list[int], start: float, beat: float, rng,
           level: float, length: int) -> None:
    """One bubble track: spiral down through chord tones two octaves up; gaps shrink."""
    tones = sorted({n + 12 * o for n in chord for o in (1, 2)})
    tones = [n for n in tones if 64 <= n <= 93]
    idx = len(tones) - 1 - int(rng.integers(0, 3))
    gap = beat * rng.choice([1.0, 0.75])
    t = start
    p = rng.uniform(-0.7, 0.7)
    drift = rng.choice([-1, 1]) * 0.08
    for k in range(length):
        vel = 0.9 * (1 - k / (length + 1)) + 0.1
        place(out, pan(_bubble(tones[idx % len(tones)], vel, rng) * level, np.clip(p, -1, 1)), t, wrap=True)
        t += gap
        gap = max(beat / 4, gap * 0.72)
        idx -= int(rng.integers(1, 3))
        p += drift
        if idx < 0:
            break


def _ticks(n: int, beat: float, every: int, level: float, rng, accent_every: int) -> np.ndarray:
    """Film-transport tick: a tiny band-passed click on the beat grid."""
    out = np.zeros((n, 2))
    beats = int(round(n / SR / beat))
    for b in range(0, beats, every):
        acc = 1.0 if b % accent_every == 0 else 0.55
        click = bandpass(noise(0.02, rng), 2500, 6500) * exp_env(0.02, 0.003, attack=0.0004)
        place(out, pan(click * level * acc, 0.35 if b % 2 else -0.35), b * beat, wrap=True)
    return out


def _hiss(n: int, level: float, rng) -> np.ndarray:
    raw = rng.uniform(-1, 1, (n, 2))
    return _loop_filter(raw, lambda x: bandpass(x, 3000, 9000)) * level


def _bass(out: np.ndarray, roots: list[int], bars: range, bar_sec: float, beat: float,
          bars_per: int, level: float) -> None:
    """Soft muted pulse on eighth notes (sine + gentle 2nd harmonic, low-passed)."""
    for bar in bars:
        root = roots[(bar // bars_per) % len(roots)]
        for e in range(8):
            accent = 1.0 if e in (0, 3, 6) else 0.55
            d = beat * 0.45
            f = midi_hz(root)
            tone = (sine(f, d) + 0.3 * sine(2 * f, d)) * exp_env(d, 0.09, attack=0.004)
            place(out, pan(tone * level * accent, 0.0), bar * bar_sec + e * beat / 2, wrap=True)


def exposure(seed: int = 11) -> np.ndarray:
    """Gameplay loop: 90 BPM, 32 bars of 4/4 (85.3 s)."""
    rng = np.random.default_rng(seed)
    bpm, bars = 90, 32
    beat = 60 / bpm
    bar_sec = 4 * beat
    n = int(round(bars * bar_sec * SR))
    prog = ["Dm9", "Fmaj7", "G69", "Em7", "Dm9", "Cmaj9", "Bm7b5", "Asus7"] * 2
    out = _drone(n, 38, 0.16)
    out += _pads(n, prog, 2, bar_sec, 0.07)
    out += _ticks(n, beat, 1, 0.05, rng, 4)
    out += _hiss(n, 0.012, rng)
    roots = [38, 41, 43, 40, 38, 36, 35, 33]
    _bass(out, roots, range(8, 28), bar_sec, beat, 2, 0.16)
    for bar in range(bars):
        chord = CHORDS[prog[bar // 2]]
        dense = 8 <= bar < 24
        if bar % 2 == 0 or (dense and rng.random() < 0.6):
            start = bar * bar_sec + beat * rng.choice([0, 0.5, 1, 2, 2.5])
            _track(out, chord, start, beat, rng, 0.2, int(rng.integers(4, 9 if dense else 6)))
        for _ in range(int(rng.integers(1, 4 if dense else 2))):  # stray single bubbles
            note = rng.choice(chord) + 24
            place(out, pan(_bubble(note, rng.uniform(0.25, 0.5), rng) * 0.14, rng.uniform(-0.8, 0.8)),
                  bar * bar_sec + beat / 2 * int(rng.integers(0, 8)), wrap=True)
    return _finish(out)


def scanning_table(seed: int = 5) -> np.ndarray:
    """Title loop: 60 BPM, 16 bars of 4/4 (64 s). Sparse, mostly drone and pads."""
    rng = np.random.default_rng(seed)
    bpm, bars = 60, 16
    beat = 60 / bpm
    bar_sec = 4 * beat
    n = int(round(bars * bar_sec * SR))
    prog = ["Dm9", "Fmaj7", "Em7", "Asus7"]
    out = _drone(n, 38, 0.2)
    out += _pads(n, prog, 4, bar_sec, 0.085)
    out += _ticks(n, beat, 2, 0.035, rng, 4)
    out += _hiss(n, 0.016, rng)
    motif = [74, 69, 72, 76, 74, 69, 65, 67]  # D A C E D A F G: slow scanning melody
    for bar in range(bars):
        chord = CHORDS[prog[bar // 4]]
        note = motif[bar % len(motif)]
        place(out, pan(_bubble(note, 0.55, rng) * 0.22, -0.2 + 0.4 * (bar % 2)), bar * bar_sec, wrap=True)
        if bar % 4 == 2:
            _track(out, chord, bar * bar_sec + 2 * beat, beat, rng, 0.17, 6)
    return _finish(out)


def _finish(out: np.ndarray) -> np.ndarray:
    wet = _loop_filter(out, lambda x: stereo_reverb(x, 0.55, room=0.86, damp=0.4) - x)
    mixed = out + wet
    return _loop_filter(mixed, lambda x: lowpass(x, 11000))


TRACKS = {
    "scanning_table": scanning_table,
    "exposure": exposure,
}
