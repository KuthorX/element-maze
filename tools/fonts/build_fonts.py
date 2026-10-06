#!/usr/bin/env python3
"""Build the subset fonts shipped in fonts/.

Run this again whenever i18n/translations.csv gets new Chinese text, so that the
CJK subsets cover every character:

    python3 tools/fonts/build_fonts.py --src /path/to/font-sources

The whole game uses one typeface, Fusion Pixel 12px (monospaced, zh_hans build), drawn as
LED dots by shaders/dot_matrix.gdshader. Put the full font in the source folder:
    fusion-pixel-12px-monospaced-zh_hans.ttf   https://github.com/TakWolf/fusion-pixel-font/releases
Missing sources are skipped and the existing file in fonts/ is kept.
Requires: fonttools (pip install fonttools).
"""
from __future__ import annotations

import argparse
import csv
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = os.path.join(ROOT, "fonts")
CSV = os.path.join(ROOT, "i18n", "translations.csv")
# Text that is shown untranslated (language toggle) and must be covered too.
EXTRA_TEXT = "中文EN×·—●○/"
LATIN = "U+0020-007E,U+00A0-00FF,U+2013-2014,U+2018-201D,U+2026,U+00D7,U+2009,U+2022,U+00B7"
CJK_PUNCT = "U+3000-303F,U+FF01-FF5E"


def collect_text() -> str:
    chars: set[str] = set(EXTRA_TEXT)
    with open(CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            for col, value in row.items():
                if col != "keys" and value:
                    chars.update(value)
    return "".join(sorted(c for c in chars if not c.isspace()))


def build(src: str, out: str, unicodes: str, text: str = "", weight: float | None = None) -> None:
    if not os.path.exists(src):
        print(f"skip {os.path.basename(out)}: source {src} not found", file=sys.stderr)
        return
    font = TTFont(src)
    if "fvar" in font:
        axes = {"wght": weight or 400}
        if any(a.axisTag == "opsz" for a in font["fvar"].axes):
            axes["opsz"] = 72
        font = instancer.instantiateVariableFont(font, axes)
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(text=text, unicodes=subset.parse_unicodes(unicodes))
    sub.subset(font)
    font.save(out)
    print(f"wrote {os.path.relpath(out, ROOT)} ({os.path.getsize(out) // 1024} KB)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True, help="folder with the full source fonts")
    args = ap.parse_args()
    text = collect_text()
    s = lambda name: os.path.join(args.src, name)  # noqa: E731
    o = lambda name: os.path.join(FONTS, name)  # noqa: E731
    build(s("fusion-pixel-12px-monospaced-zh_hans.ttf"), o("FusionPixel-12px-zh_hans-subset.ttf"),
          f"{LATIN},{CJK_PUNCT},U+25CF,U+25CB", text)


if __name__ == "__main__":
    main()
