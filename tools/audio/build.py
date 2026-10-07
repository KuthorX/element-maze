#!/usr/bin/env python3
"""Render every sound in the game with the offline audiokit toolchain.

    arch -arm64 /tmp/audiokit/venv/bin/python tools/audio/build.py            # all
    arch -arm64 /tmp/audiokit/venv/bin/python tools/audio/build.py --no-render  # reuse renders

1. compose.py writes MIDI + render specs into WORK (default /tmp/element-maze-audio).
2. Each spec is rendered by /tmp/audiokit/render.py under the shared render lock
   (Vital / Serum 2 presets, MS Basic.sf3 via fluidsynth, numpy voices, pedalboard FX).
   Music loops come out seamless (tail folded onto the start), -18 LUFS, <= -1 dBTP.
3. sfx.py layers the rendered source notes with numpy synthesis into audio/sfx/*.wav
   (16-bit mono); the loops become audio/music/*.mp3 (LAME CBR 128 kbps, gapless header).
Never plays audio and never opens a window. Needs lame and ffmpeg on PATH.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(__file__))
import compose  # noqa: E402
import sfx  # noqa: E402
from synth import SR, peak_normalize  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
RENDER = ["lockf", "-t", "3600", "/tmp/audiokit/render.lock", "arch", "-arm64",
          "/tmp/audiokit/venv/bin/python", "/tmp/audiokit/render.py"]
MUSIC = ("scanning_table", "exposure")


def write_wav(path: str, x: np.ndarray) -> None:
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype(np.int16)
    wavfile.write(path, SR, pcm)


def measure(path: str) -> tuple[float, float]:
    """Integrated LUFS and true peak (dBTP) via ffmpeg's ebur128 meter."""
    res = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
                          "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True, check=True)
    lufs = float(re.findall(r"I:\s+(-?[\d.]+) LUFS", res.stderr)[-1])
    peak = float(re.findall(r"Peak:\s+(-?[\d.inf]+) dBFS", res.stderr)[-1])
    return lufs, peak


def render(work: str) -> None:
    for spec in compose.write_all(work):
        print(f"render {os.path.basename(spec)}", flush=True)
        subprocess.run(RENDER + [spec], check=True)


def build_sfx(work: str) -> None:
    os.makedirs(SFX_DIR, exist_ok=True)
    for name, (x, peak) in sfx.render_all(work).items():
        path = os.path.join(SFX_DIR, f"{name}.wav")
        write_wav(path, peak_normalize(x, peak))
        lufs, tp = measure(path)
        print(f"sfx   {name:13s} {len(x) / SR:5.2f}s peak {peak:+.1f} dBFS  {lufs:6.1f} LUFS  {tp:+.1f} dBTP")


def build_music(work: str) -> None:
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name in MUSIC:
        wav = os.path.join(work, f"{name}.wav")
        out = os.path.join(MUSIC_DIR, f"{name}.mp3")
        subprocess.run(["lame", "--quiet", "-b", "128", "--cbr", "-q", "2", wav, out], check=True)
        lufs, tp = measure(out)
        print(f"music {name:13s} {lufs:.1f} LUFS  {tp:+.1f} dBTP (mp3)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default="/tmp/element-maze-audio")
    ap.add_argument("--no-render", action="store_true", help="reuse existing renders in --work")
    args = ap.parse_args()
    if not args.no_render:
        render(args.work)
    build_sfx(args.work)
    build_music(args.work)


if __name__ == "__main__":
    main()
