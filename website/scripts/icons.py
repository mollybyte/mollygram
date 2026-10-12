#!/usr/bin/env python3
"""Writes the site icons into website/public from the app icon masters.

Run from the repository root after assets/icon/generate.py changes the art:

    python3 website/scripts/icons.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / "assets" / "icon"
OUT = ROOT / "website" / "public"

# Full-bleed master: browsers and iOS round the corners themselves.
flat = Image.open(ICON / "mollygram-flat-1024.png").convert("RGBA")
for name, size in [("apple-touch-icon.png", 180), ("icon-192.png", 192), ("icon-512.png", 512)]:
    flat.resize((size, size), Image.LANCZOS).save(OUT / name, optimize=True)

# Tab icon: the rounded tile, small sizes only.
tile = Image.open(ICON / "linux" / "256.png").convert("RGBA")
tile.save(OUT / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
