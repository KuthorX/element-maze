"""Sound effects for Guide The Ball ("Event Frame": bubble-chamber film).

Palette of sounds: glass and instrument clicks. Tracks are written by bubbles, walls are
magnets that "ring", the goal is a camera shutter exposing the frame. Everything short,
dry, mono, never harsh (no energy above ~9 kHz except shutter clicks).

Each entry: name -> (render function, peak dBFS). Peaks set the relative mix.
"""
from __future__ import annotations

import numpy as np

from synth import (SR, bandpass, exp_env, fade_out, fm_bell, highpass, lowpass,
                   midi_hz, noise, place, sine, t_axis)

RNG_SEED = 7
D5 = 74  # wall-hit base note; the game shifts pitch along D Dorian from here


def _click(rng, dur=0.012, lo=1800.0, hi=6000.0, decay=0.0025) -> np.ndarray:
    return bandpass(noise(dur, rng), lo, hi) * exp_env(dur, decay, attack=0.0003)


def launch(rng) -> np.ndarray:
    """Collimator release: a dry latch click, then a short rising particle chirp."""
    dur = 0.32
    out = np.zeros(int(dur * SR))
    place(out, _click(rng, 0.02, 600, 3000, 0.004) * 0.9, 0.0)
    t = t_axis(0.26)
    f = 330 * (1 + 2.2 * (1 - np.exp(-t / 0.08)))  # 330 -> ~1050 Hz
    chirp = sine(f, 0.26) * exp_env(0.26, 0.09, attack=0.004)
    chirp += 0.25 * sine(f * 2, 0.26) * exp_env(0.26, 0.05, attack=0.004)
    place(out, chirp * 0.7, 0.008)
    return fade_out(out, 0.01)


def wall_hit(rng) -> np.ndarray:
    """A magnet plate rings like struck glass. Pitched in-game by multiplier and speed."""
    f = midi_hz(D5)
    tone = fm_bell(f, 0.42, ratio=3.01, index=1.6, decay=0.13, index_decay=0.02)
    tone += 0.35 * fm_bell(f * 2.0, 0.42, ratio=1.41, index=0.8, decay=0.06)
    tick = _click(rng, 0.008, 2500, 7000, 0.0015) * 0.5
    out = tone * 0.8
    place(out, tick, 0.0)
    return fade_out(out, 0.02)


def fizz(rng) -> np.ndarray:
    """Boiling zone: a cluster of tiny bubble pops over a hiss that swells and falls."""
    dur = 0.6
    out = np.zeros(int(dur * SR))
    hiss = bandpass(noise(dur, rng), 2500, 7000) * np.sin(np.pi * t_axis(dur) / dur) ** 2
    out += hiss * 0.18
    for _ in range(26):
        start = rng.uniform(0.0, dur - 0.05)
        f0 = rng.uniform(900, 2600)
        d = rng.uniform(0.012, 0.03)
        t = t_axis(d)
        pop = sine(f0 * (1 + 1.5 * t / d), d) * exp_env(d, d / 3, attack=0.0005)
        place(out, pop * rng.uniform(0.25, 0.6), start)
    return fade_out(out, 0.05)


def goal(rng) -> np.ndarray:
    """Shutter exposes the frame: two mechanical clicks and an amber rising fifth."""
    dur = 0.9
    out = np.zeros(int(dur * SR))
    place(out, _click(rng, 0.018, 1200, 6500, 0.003), 0.0)
    place(out, _click(rng, 0.018, 900, 5000, 0.004) * 0.7, 0.07)
    place(out, fm_bell(midi_hz(74), 0.7, ratio=2.0, index=1.2, decay=0.25) * 0.45, 0.02)
    place(out, fm_bell(midi_hz(81), 0.75, ratio=2.0, index=1.2, decay=0.3) * 0.5, 0.12)
    return fade_out(out, 0.05)


def out_of_balls(rng) -> np.ndarray:
    """The chamber powers down: a falling sine and a magnet hum that sags and stops."""
    dur = 1.3
    t = t_axis(dur)
    f = 220 * np.exp(-t / 0.9) + 55
    body = sine(f, dur) * np.exp(-t / 0.5)
    hum = (sine(73.4 * (1 - 0.25 * t / dur), dur) + 0.3 * sine(146.8 * (1 - 0.25 * t / dur), dur))
    hum *= np.minimum(1, t / 0.02) * np.exp(-t / 0.45)
    out = 0.6 * body + 0.5 * hum
    place(out, _click(rng, 0.03, 300, 1500, 0.008) * 0.6, 0.0)
    return lowpass(fade_out(out, 0.1), 3000)


def target_met(rng) -> np.ndarray:
    """Frame complete: shutter, then a glass arpeggio up Dm9 (D F A C E), ending on a
    held fifth (D A)."""
    dur = 1.9
    out = np.zeros(int(dur * SR))
    place(out, _click(rng, 0.018, 1200, 6500, 0.003), 0.0)
    place(out, _click(rng, 0.018, 900, 5000, 0.004) * 0.7, 0.06)
    for k, n in enumerate([62, 65, 69, 72, 76]):
        place(out, fm_bell(midi_hz(n), 1.2, ratio=3.0, index=1.0, decay=0.35) * 0.4, 0.08 + k * 0.09)
    hold = fm_bell(midi_hz(74), 1.4, ratio=2.0, index=0.6, decay=0.6) * 0.35
    hold += fm_bell(midi_hz(81), 1.4, ratio=2.0, index=0.6, decay=0.6) * 0.3
    place(out, hold, 0.5)
    return fade_out(out, 0.15)


def ui_click(rng) -> np.ndarray:
    """Scanning-table key: a short dry tick with a faint tone."""
    out = _click(rng, 0.03, 1500, 5000, 0.004)
    out += 0.4 * sine(1760, 0.03) * exp_env(0.03, 0.006)
    return fade_out(out, 0.004)


def ui_hover(rng) -> np.ndarray:
    """Lighter, higher tick for hovering a wall."""
    tick = _click(rng, 0.02, 3000, 8000, 0.0018)
    return fade_out(tick + 0.25 * sine(2637, 0.02) * exp_env(0.02, 0.004)[:len(tick)], 0.003)


def ui_confirm(rng) -> np.ndarray:
    """Round start / replay: two rising ticks (A5 -> D6)."""
    out = np.zeros(int(0.2 * SR))
    for k, n in enumerate([81, 86]):
        tone = sine(midi_hz(n), 0.09) * exp_env(0.09, 0.025)
        place(out, tone * 0.6, k * 0.07)
        place(out, _click(rng, 0.01, 2000, 6000, 0.002) * 0.4, k * 0.07)
    return fade_out(out, 0.01)


def rotate(rng) -> np.ndarray:
    """Ratchet tick when a wall turns one step."""
    return fade_out(_click(rng, 0.015, 1000, 4000, 0.002), 0.003)


def empty(rng) -> np.ndarray:
    """Dry fire: no ball left in the collimator."""
    out = _click(rng, 0.05, 200, 1200, 0.01)
    out += 0.5 * sine(110, 0.05) * exp_env(0.05, 0.012)
    return highpass(fade_out(out, 0.01), 60)


SFX = {
    "launch": (launch, -2.0),
    "wall_hit": (wall_hit, -3.0),
    "fizz": (fizz, -5.0),
    "goal": (goal, -2.0),
    "out_of_balls": (out_of_balls, -2.0),
    "target_met": (target_met, -1.5),
    "ui_click": (ui_click, -8.0),
    "ui_hover": (ui_hover, -15.0),
    "ui_confirm": (ui_confirm, -6.0),
    "rotate": (rotate, -14.0),
    "empty": (empty, -6.0),
}


def render_all() -> dict[str, tuple[np.ndarray, float]]:
    out = {}
    for name, (fn, peak) in SFX.items():
        rng = np.random.default_rng(RNG_SEED + len(name))
        out[name] = (fn(rng), peak)
    return out
