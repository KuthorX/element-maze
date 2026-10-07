"""Sound effects for Guide The Ball ("Event Frame": bubble-chamber film).

Every effect layers at least two sources: notes rendered from Serum 2 / Vital presets
(the "SFX sources" spec in compose.py, sliced from its stems) plus numpy synthesis, then
enveloped and filtered here. Glass = Serum 2 Kinderjoy; ticks and shutter = Vital Ceramic;
thuds = Vital Super Nice Pluck; held chime = Vital
Crescendo Bells. Short, dry, mono, clean onsets.

Each entry: name -> (render function, peak dBFS). Peaks set the relative mix.
"""
from __future__ import annotations

import json
import os

import numpy as np
import soundfile as sf

from synth import (SR, bandpass, exp_env, fade_out, fm_bell, highpass, lowpass, midi_hz,
                   noise, place, sine, t_axis)

RNG_SEED = 7
ONSET_DB = -40.0  # a slice starts this far below its own peak (preset latency/attack)


class Sources:
    """Slices of the rendered SFX-source stems, addressed by label (see compose.py)."""

    def __init__(self, work: str):
        with open(os.path.join(work, "sfx_slots.json")) as f:
            meta = json.load(f)
        self.slot_sec = float(meta["slot_seconds"])
        self.slots = meta["slots"]
        self.stems: dict[str, np.ndarray] = {}
        for part in {p for p, _ in self.slots.values()}:
            x, sr = sf.read(os.path.join(work, "sfx_stems", f"{part}.wav"), always_2d=True)
            if sr != SR:
                raise ValueError(f"{part}: sample rate {sr} != {SR}")
            self.stems[part] = x.mean(axis=1)

    def get(self, label: str, dur: float, offset: float = 0.0) -> np.ndarray:
        part, slot = self.slots[label]
        x = self.stems[part]
        s = int(slot * self.slot_sec * SR)
        window = x[s:s + int(self.slot_sec * SR)]
        peak = np.max(np.abs(window))
        if peak <= 0:
            raise ValueError(f"source {label} is silent")
        onset = int(np.argmax(np.abs(window) > peak * 10 ** (ONSET_DB / 20)))
        start = max(0, onset - int(0.001 * SR)) + int(offset * SR)
        out = window[start:start + int(dur * SR)].copy() / peak
        k = int(0.001 * SR)
        out[:k] *= np.linspace(0, 1, k)  # click-free onset
        return out


def _click(rng, dur=0.012, lo=1800.0, hi=6000.0, decay=0.0025) -> np.ndarray:
    return bandpass(noise(dur, rng), lo, hi) * exp_env(dur, decay, attack=0.0003)


def _buf(dur: float) -> np.ndarray:
    return np.zeros(int(dur * SR))


def _shape(x: np.ndarray, decay: float) -> np.ndarray:
    """Exponential tail so long preset rings end inside the file."""
    return x * np.exp(-t_axis(len(x) / SR)[:len(x)] / decay)


def launch(src: Sources, rng) -> np.ndarray:
    """Collimator release: a ceramic latch tick, a rising run of ceramic ticks and a
    particle chirp."""
    out = _buf(0.4)
    place(out, src.get("tick_lo", 0.05) * 0.8, 0.0)
    place(out, _shape(src.get("tick_rise", 0.3), 0.07) * 0.55, 0.01)
    t = t_axis(0.26)
    f = 330 * (1 + 2.2 * (1 - np.exp(-t / 0.08)))
    place(out, sine(f, 0.26) * exp_env(0.26, 0.08, attack=0.004) * 0.5, 0.008)
    return fade_out(lowpass(out, 9000), 0.02)


def wall_hit(src: Sources, rng) -> np.ndarray:
    """Struck glass on D5 (pitched in-game along D Dorian) with a ceramic tick."""
    out = _shape(src.get("glass_d5", 0.45), 0.16) * 0.8
    place(out, fm_bell(midi_hz(74), 0.45, ratio=3.01, index=1.2, decay=0.1) * 0.25, 0.0)
    place(out, src.get("tick_hi", 0.03) * 0.35, 0.0)
    return fade_out(highpass(lowpass(out, 8000), 380), 0.03)  # drop the preset's low layer


def fizz(src: Sources, rng) -> np.ndarray:
    """Boiling zone: a burst of ceramic micro-ticks and bubble pops over a swelling hiss."""
    dur = 0.6
    out = _buf(dur)
    out += bandpass(noise(dur, rng), 2500, 7000) * np.sin(np.pi * t_axis(dur) / dur) ** 2 * 0.12
    place(out, src.get("tick_fizz", 0.55) * 0.55, 0.02)
    for _ in range(14):
        d = rng.uniform(0.012, 0.03)
        t = t_axis(d)
        pop = sine(rng.uniform(900, 2400) * (1 + 1.5 * t / d), d) * exp_env(d, d / 3, attack=0.0005)
        place(out, pop * rng.uniform(0.2, 0.45), rng.uniform(0.0, dur - 0.05))
    return fade_out(lowpass(out, 9000), 0.06)


def goal(src: Sources, rng) -> np.ndarray:
    """Shutter exposes the frame: ceramic shutter clicks and a rising glass fifth D5-A5."""
    out = _buf(0.95)
    place(out, src.get("tick_shutter", 0.12) * 0.7, 0.0)
    place(out, _shape(src.get("glass_goal", 0.9), 0.3) * 0.85, 0.02)
    return fade_out(highpass(lowpass(out, 9000), 300), 0.08)


def out_of_balls(src: Sources, rng) -> np.ndarray:
    """The chamber powers down: falling glass, a sub thud, a sine and a hum that sag."""
    dur = 1.3
    t = t_axis(dur)
    out = _buf(dur)
    place(out, lowpass(_shape(src.get("glass_fall", 1.2), 0.45), 2500) * 0.5, 0.0)
    f = 220 * np.exp(-t / 0.9) + 55
    out += sine(f, dur) * np.exp(-t / 0.5) * 0.35
    place(out, _shape(src.get("thud_power", 0.8), 0.3) * 0.55, 0.0)
    hum = sine(73.4 * (1 - 0.25 * t / dur), dur) + 0.3 * sine(146.8 * (1 - 0.25 * t / dur), dur)
    out += hum * np.minimum(1, t / 0.02) * np.exp(-t / 0.45) * 0.3
    return highpass(fade_out(lowpass(out, 3500), 0.12), 35)


def target_met(src: Sources, rng) -> np.ndarray:
    """Frame complete: shutter, a glass arpeggio up Dm9, then a held D/A chime."""
    out = _buf(1.9)
    place(out, src.get("tick_shutter", 0.12) * 0.7, 0.0)
    place(out, _shape(src.get("glass_arp", 1.4), 0.5) * 0.75, 0.08)
    place(out, _shape(src.get("chime_hold", 1.4), 0.6) * 0.55, 0.5)
    for k, n in enumerate([62, 65, 69, 72, 76]):
        place(out, fm_bell(midi_hz(n), 0.6, ratio=3.0, index=0.8, decay=0.2) * 0.12, 0.08 + k * 0.09)
    return fade_out(lowpass(out, 9000), 0.2)


def ui_click(src: Sources, rng) -> np.ndarray:
    """Scanning-table key: a dry ceramic tick with a faint tone."""
    out = src.get("tick_mid", 0.04) * 0.8
    out += 0.25 * sine(1760, 0.04) * exp_env(0.04, 0.006)
    return fade_out(out, 0.006)


def ui_hover(src: Sources, rng) -> np.ndarray:
    """Lighter, higher tick for hovering a wall."""
    out = src.get("tick_hi", 0.025) * 0.8 + _click(rng, 0.025, 3000, 8000, 0.0018) * 0.3
    return fade_out(out, 0.004)


def ui_confirm(src: Sources, rng) -> np.ndarray:
    """Round start / replay: two rising glass ticks (A5 -> D6)."""
    out = _buf(0.3)
    place(out, _shape(src.get("glass_confirm", 0.3), 0.08) * 0.7, 0.0)
    for k in range(2):
        place(out, _click(rng, 0.01, 2000, 6000, 0.002) * 0.3, k * 0.07)
    return fade_out(highpass(lowpass(out, 9000), 380), 0.02)


def rotate(src: Sources, rng) -> np.ndarray:
    """Ratchet tick when a wall turns one step."""
    out = src.get("tick_lo", 0.022) * 0.7 + _click(rng, 0.022, 1000, 4000, 0.002) * 0.4
    return fade_out(out, 0.004)


def empty(src: Sources, rng) -> np.ndarray:
    """Dry fire: a muffled sub thud and a dull click."""
    out = _shape(src.get("thud_d2", 0.1), 0.03) * 0.8
    out += _click(rng, 0.1, 200, 1200, 0.01) * 0.5
    return highpass(fade_out(lowpass(out, 2000), 0.015), 40)


SFX = {
    "launch": (launch, -1.0),
    "wall_hit": (wall_hit, -3.0),
    "fizz": (fizz, -5.0),
    "goal": (goal, -1.0),
    "out_of_balls": (out_of_balls, -2.0),
    "target_met": (target_met, -1.5),
    "ui_click": (ui_click, -8.0),
    "ui_hover": (ui_hover, -15.0),
    "ui_confirm": (ui_confirm, -6.0),
    "rotate": (rotate, -14.0),
    "empty": (empty, -6.0),
}


def render_all(work: str) -> dict[str, tuple[np.ndarray, float]]:
    src = Sources(work)
    out = {}
    for name, (fn, peak) in SFX.items():
        rng = np.random.default_rng(RNG_SEED + len(name))
        x = fn(src, rng)
        out[name] = (fade_out(x - np.mean(x), 0.003), peak)  # no DC, ends at zero
    return out
