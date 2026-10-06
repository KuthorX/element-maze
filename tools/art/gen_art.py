#!/usr/bin/env python3
"""Procedural "Event Frame" art for Guide The Ball: a frame of bubble-chamber film.

Re-run from the repo root:  python3 tools/art/gen_art.py
Writes PNGs into images/art/. Deterministic (fixed seeds). Requires Pillow.
Everything with motion (tracks, boiling, grain) is drawn live in Godot; these are the
static parts.
"""
from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "images", "art")
SS = 4  # supersampling for crisp anti-aliased edges

TRACK_WHITE = (238, 238, 230)
AMBER = (240, 160, 64)
CHAMBER = (24, 26, 27)


def save(img: Image.Image, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name), optimize=True)
    print("wrote", name, img.size)


def canvas(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def finish(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def ring(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, width: float, fill) -> None:
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], outline=fill, width=max(1, int(width * SS)))


def disc(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=fill)


def make_ball() -> None:
    """The ball: a solid amber disc with a hard-edged square highlight (one pixel-font pixel, x8)."""
    s, c, r = 128, 64, 50
    img, d = canvas(s, s)
    disc(d, c, c, r, AMBER + (255,))
    ring(d, c, c, r - 1, 2, (196, 120, 40, 255))
    hx, hy, k = c - 30, c - 30, 12
    d.rectangle([hx * SS, hy * SS, (hx + k) * SS, (hy + k) * SS], fill=(255, 236, 200, 255))
    save(finish(img, s, s), "ball.png")


def make_plate() -> None:
    """Energy wall: a single white outline, nothing inside, 56x252 (collider 42x235)."""
    w, h = 56, 252
    x0, y0, x1, y1 = 7, 8, w - 7, h - 8
    img, d = canvas(w, h)
    d.rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], outline=TRACK_WHITE + (255,), width=3 * SS)
    save(finish(img, w, h), "plate.png")


def make_collimator() -> None:
    """Beam entry (the launcher): two outlined collimator jaws around the ball's start, chevron at the mouth.

    220x220; the ball (radius 51) starts at x=90, y=110 between the jaws.
    """
    w, h = 220, 220
    cy = h / 2
    img, d = canvas(w, h)
    for ya, yb in ((cy - 100, cy - 60), (cy + 60, cy + 100)):
        d.rectangle([10 * SS, ya * SS, 150 * SS, yb * SS], outline=TRACK_WHITE + (255,), width=3 * SS)
    # chevron at the mouth shows the launch direction
    pts = [(170, cy - 26), (196, cy), (170, cy + 26)]
    d.line([(x * SS, y * SS) for x, y in pts], fill=TRACK_WHITE + (255,), width=5 * SS, joint="curve")
    save(finish(img, w, h), "collimator.png")


def make_reticle() -> None:
    """Goal: a scanning-table reticle in grease-pencil amber; ring radius 85 = goal collider. 300px."""
    s, c = 300, 150
    img, d = canvas(s, s)
    ring(d, c, c, 85, 3.5, AMBER + (255,))
    for i in range(48):
        a = i / 48 * math.tau
        r0, r1 = (62, 72) if i % 4 == 0 else (66, 70)
        d.line([((c + math.cos(a) * r0) * SS, (c + math.sin(a) * r0) * SS),
                ((c + math.cos(a) * r1) * SS, (c + math.sin(a) * r1) * SS)], fill=AMBER + (220,), width=int(1.6 * SS))
    for k in range(4):
        a = k * math.pi / 2
        d.line([((c + math.cos(a) * 96) * SS, (c + math.sin(a) * 96) * SS),
                ((c + math.cos(a) * 128) * SS, (c + math.sin(a) * 128) * SS)], fill=AMBER + (255,), width=int(3 * SS))
    d.line([((c - 9) * SS, c * SS), ((c + 9) * SS, c * SS)], fill=AMBER + (255,), width=2 * SS)
    d.line([(c * SS, (c - 9) * SS), (c * SS, (c + 9) * SS)], fill=AMBER + (255,), width=2 * SS)
    save(finish(img, s, s), "reticle.png")


def make_icon() -> None:
    """App icon: a curling track ending in the bubble, on chamber black."""
    s = 256
    img, d = canvas(s, s)
    d.rectangle([0, 0, s * SS, s * SS], fill=CHAMBER + (255,))
    x, y, a = 26.0, 222.0, -0.75
    rnd = random.Random(2)
    for i in range(52):
        x += math.cos(a) * 3.0
        y += math.sin(a) * 3.0
        a += 0.012 + i * 0.0006
        disc(d, x, y, 2.4 + rnd.uniform(-0.6, 0.6), TRACK_WHITE + (255,))
    disc(d, x + 16, y - 10, 38, (205, 212, 214, 60))
    ring(d, x + 16, y - 10, 38, 5, TRACK_WHITE + (255,))
    disc(d, x + 2, y - 24, 6, (255, 255, 252, 240))
    save(finish(img, s, s), "icon.png")


if __name__ == "__main__":
    make_ball()
    make_plate()
    make_collimator()
    make_reticle()
    make_icon()
