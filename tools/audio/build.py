#!/usr/bin/env python3
"""Render every sound in the game.

    python3 tools/audio/build.py            # SFX + music
    python3 tools/audio/build.py --sfx      # SFX only

Writes audio/sfx/*.wav (16-bit mono) and audio/music/*.mp3 (LAME, 128 kbps, gapless
header). Music is gain-matched to MUSIC_LUFS with ffmpeg's ebur128 meter.
Requires numpy, scipy, ffmpeg and lame on PATH.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(__file__))
import music  # noqa: E402
import sfx  # noqa: E402
from synth import SR, peak_normalize  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
MUSIC_LUFS = -18.0
MUSIC_PEAK_CEILING_DB = -1.5


def write_wav(path: str, x: np.ndarray) -> None:
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype(np.int16)
    wavfile.write(path, SR, pcm)


def measure_lufs(path: str) -> float:
    res = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128",
                          "-f", "null", "-"], capture_output=True, text=True, check=True)
    found = re.findall(r"I:\s+(-?[\d.]+) LUFS", res.stderr)
    return float(found[-1])


def build_sfx() -> None:
    os.makedirs(SFX_DIR, exist_ok=True)
    for name, (x, peak) in sfx.render_all().items():
        write_wav(os.path.join(SFX_DIR, f"{name}.wav"), peak_normalize(x, peak))
        print(f"sfx  {name:13s} {len(x) / SR:5.2f}s peak {peak:+.1f} dBFS")


def build_music() -> None:
    os.makedirs(MUSIC_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, fn in music.TRACKS.items():
            x = fn()
            wav = os.path.join(tmp, f"{name}.wav")
            x = peak_normalize(x, -6.0)
            write_wav(wav, x)
            gain_db = MUSIC_LUFS - measure_lufs(wav)
            x = x * 10 ** (gain_db / 20)
            peak_db = 20 * np.log10(np.max(np.abs(x)))
            if peak_db > MUSIC_PEAK_CEILING_DB:
                print(f"warn {name}: peak {peak_db:.1f} dBFS above ceiling, limiting gain")
                x *= 10 ** ((MUSIC_PEAK_CEILING_DB - peak_db) / 20)
            write_wav(wav, x)
            out = os.path.join(MUSIC_DIR, f"{name}.mp3")
            subprocess.run(["lame", "--quiet", "-b", "128", "--cbr", "-q", "2", wav, out], check=True)
            print(f"music {name:13s} {len(x) / SR:6.2f}s {measure_lufs(wav):.1f} LUFS")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sfx", action="store_true", help="only render sound effects")
    ap.add_argument("--music", action="store_true", help="only render music")
    args = ap.parse_args()
    if not args.music:
        build_sfx()
    if not args.sfx:
        build_music()


if __name__ == "__main__":
    main()
