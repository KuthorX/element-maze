"""Small numpy synthesis toolkit shared by sfx.py and music.py.

Everything is mono float64 at SR unless a function says otherwise. Stereo buffers are
shape (n, 2).
"""
from __future__ import annotations

import numpy as np
from scipy import signal

SR = 44100


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(round(dur * SR))) / SR


def midi_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def exp_env(dur: float, decay: float, attack: float = 0.002) -> np.ndarray:
    """Fast linear attack, exponential decay (decay = time constant in seconds)."""
    t = t_axis(dur)
    env = np.exp(-t / decay)
    a = max(1, int(attack * SR))
    env[:a] *= np.linspace(0.0, 1.0, a)
    return fade_out(env, 0.004)


def adsr(dur: float, a: float, d: float, s: float, r: float) -> np.ndarray:
    n = int(round(dur * SR))
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    ns = max(0, n - na - nd - nr)
    env = np.concatenate([
        np.linspace(0, 1, na, endpoint=False),
        np.linspace(1, s, nd, endpoint=False),
        np.full(ns, s),
        np.linspace(s, 0, nr),
    ])
    return np.pad(env, (0, max(0, n - len(env))))[:n]


def fade_out(x: np.ndarray, sec: float) -> np.ndarray:
    n = min(len(x), max(1, int(sec * SR)))
    y = x.copy()
    y[-n:] *= np.linspace(1.0, 0.0, n)
    return y


def sine(freq, dur: float, phase: float = 0.0) -> np.ndarray:
    """freq may be a scalar or a per-sample array (then it is integrated)."""
    n = int(round(dur * SR))
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * np.arange(n) / SR + phase)
    ph = 2 * np.pi * np.cumsum(np.asarray(freq)[:n]) / SR
    return np.sin(ph + phase)


def fm_bell(freq: float, dur: float, ratio: float = 3.5, index: float = 2.0,
            decay: float = 0.4, index_decay: float | None = None) -> np.ndarray:
    """Two-operator FM: glassy, cold. Modulation index decays faster than the tone."""
    t = t_axis(dur)
    idx_env = index * np.exp(-t / (index_decay or decay * 0.35))
    mod = np.sin(2 * np.pi * freq * ratio * t) * idx_env
    car = np.sin(2 * np.pi * freq * t + mod)
    return car * exp_env(dur, decay)


def noise(dur: float, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, int(round(dur * SR)))


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, cutoff, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, cutoff, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Equal-power pan, p in [-1, 1]."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def place(buf: np.ndarray, x: np.ndarray, start: float, wrap: bool = False) -> None:
    """Add x into buf at time `start`. With wrap=True the tail folds onto the start
    (used for seamless loops)."""
    i = int(round(start * SR))
    n = len(buf)
    if not wrap:
        end = min(n, i + len(x))
        if end > i:
            buf[i:end] += x[: end - i]
        return
    pos = 0
    while pos < len(x):
        j = (i + pos) % n
        take = min(len(x) - pos, n - j)
        buf[j:j + take] += x[pos:pos + take]
        pos += take


def reverb(x: np.ndarray, room: float = 0.82, damp: float = 0.35, seed: int = 1) -> np.ndarray:
    """Schroeder/Freeverb-style mono reverb (4 combs + 2 allpasses). Returns the wet signal."""
    combs = [1116, 1188, 1277, 1356]
    rng = np.random.default_rng(seed)
    combs = [c + int(rng.integers(0, 23)) for c in combs]
    out = np.zeros_like(x)
    for d in combs:
        out += _comb(x, d, room, damp)
    out /= len(combs)
    for d in (556, 441):
        out = _allpass(out, d, 0.5)
    return out


def _comb(x: np.ndarray, delay: int, fb: float, damp: float) -> np.ndarray:
    """Feedback comb with a one-pole lowpass in the loop (Freeverb), as one IIR filter:
    Y = z^-D X + fb z^-D H(z) Y with H = (1-d) / (1 - d z^-1)."""
    b = np.zeros(delay + 2)
    b[delay], b[delay + 1] = 1.0, -damp
    a = np.zeros(delay + 1)
    a[0], a[1] = 1.0, -damp
    a[delay] += -fb * (1 - damp)
    return signal.lfilter(b, a, x)


def _allpass(x: np.ndarray, delay: int, g: float) -> np.ndarray:
    b = np.zeros(delay + 1)
    a = np.zeros(delay + 1)
    b[0], b[-1] = -g, 1.0
    a[0], a[-1] = 1.0, -g
    return signal.lfilter(b, a, x)


def stereo_reverb(x: np.ndarray, mix: float, room: float = 0.82, damp: float = 0.35) -> np.ndarray:
    mono = x.mean(axis=1)
    wl = reverb(mono, room, damp, seed=1)
    wr = reverb(mono, room, damp, seed=2)
    return x + mix * np.stack([wl, wr], axis=1)


def peak_normalize(x: np.ndarray, peak_db: float) -> np.ndarray:
    peak = np.max(np.abs(x))
    if peak == 0:
        return x
    return x * (10 ** (peak_db / 20) / peak)
