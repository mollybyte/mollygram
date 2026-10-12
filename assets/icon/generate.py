#!/usr/bin/env python3
"""Generates every app icon from the brand artwork.

Usage (from the repository root):

    pip install cairosvg pillow
    python3 assets/icon/generate.py

Outputs:
  assets/icon/mollygram-1024.png      macOS master (squircle on the 1024 grid, with shadow)
  assets/icon/mollygram-flat-1024.png full-bleed master for Windows and Linux
  assets/icon/mollygram.icns          macOS icon file
  assets/icon/mollygram.ico           Windows icon file
  assets/icon/linux/<size>.png        Linux hicolor sizes
and copies the sets into the Flutter projects (packages/app, prototype).

The artwork itself (gradient, bubble, "m") matches docs/assets/icon.svg.
Only the outer shape differs: macOS gets Apple's continuous-corner squircle
with the standard 100 px margin and drop shadow.
"""

from __future__ import annotations

import io
import math
import shutil
from pathlib import Path

import cairosvg
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "icon"

CANVAS = 1024
# macOS Big Sur+ icon grid: 824x824 body centred on a 1024 canvas.
MAC_BODY = 824
MAC_MARGIN = (CANVAS - MAC_BODY) // 2
# Superellipse exponent close to Apple's continuous corners.
SQUIRCLE_N = 5.0

# Artwork in the 100-unit space of docs/assets/icon.svg; its tile is 6..94.
BUBBLE = (
    "M50 22c-17.7 0-31 11.6-31 26.5 0 8 3.8 15 10 19.9-.5 4.3-2.6 8.2-6 11 "
    "6.4.3 12-1.6 16.2-4.9 3.4 1 7 1.5 10.8 1.5 17.7 0 31-11.6 31-26.5S67.7 22 50 22z"
)
LETTER = "M36 58V45.5a7 7 0 0 1 14 0V58M50 45.5a7 7 0 0 1 14 0V58"
TILE_X, TILE_SIZE = 6.0, 88.0


def squircle_path(x: float, y: float, size: float, steps: int = 720) -> str:
    r = size / 2
    cx, cy = x + r, y + r
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        px = cx + r * math.copysign(abs(c) ** (2 / SQUIRCLE_N), c)
        py = cy + r * math.copysign(abs(s) ** (2 / SQUIRCLE_N), s)
        pts.append(f"{px:.2f},{py:.2f}")
    return "M" + " L".join(pts) + " Z"


def artwork_svg(body_x: float, body_size: float) -> str:
    """The tile, scaled so the 88-unit tile fills body_size at body_x."""
    scale = body_size / TILE_SIZE
    offset = body_x - TILE_X * scale
    shape = squircle_path(body_x, body_x, body_size)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
  <defs>
    <linearGradient id="g" x1="0" y1="{body_x}" x2="0" y2="{body_x + body_size}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FF6E9C"/>
      <stop offset="1" stop-color="#D42A63"/>
    </linearGradient>
    <linearGradient id="hl" x1="0" y1="{body_x}" x2="0" y2="{body_x + body_size * 0.5}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <path d="{shape}" fill="url(#g)"/>
  <path d="{shape}" fill="url(#hl)"/>
  <g transform="translate({offset:.3f} {offset:.3f}) scale({scale:.5f})">
    <path fill="#FFFFFF" d="{BUBBLE}"/>
    <path fill="none" stroke="#D6336C" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round" d="{LETTER}"/>
  </g>
</svg>"""


def render(svg: str) -> Image.Image:
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=CANVAS, output_height=CANVAS)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def with_shadow(art: Image.Image) -> Image.Image:
    """Apple template shadow: black, 30%, 10 px down, 20 px blur."""
    alpha = art.getchannel("A")
    shadow = Image.new("RGBA", art.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda a: a * 0.3))
    shadow = shadow.transform(art.size, Image.AFFINE, (1, 0, 0, 0, 1, -10))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    return Image.alpha_composite(shadow, art)


def resized(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def write_appiconset(master: Image.Image, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        resized(master, size).save(dest / f"app_icon_{size}.png", optimize=True)


def main() -> None:
    mac = with_shadow(render(artwork_svg(MAC_MARGIN, MAC_BODY)))
    mac.save(OUT / "mollygram-1024.png", optimize=True)

    # Windows and Linux icons have no system mask: fill the canvas with a small inset.
    flat = render(artwork_svg(CANVAS * 0.03, CANVAS * 0.94))
    flat.save(OUT / "mollygram-flat-1024.png", optimize=True)

    mac.save(OUT / "mollygram.icns", sizes=[(s, s) for s in (16, 32, 64, 128, 256, 512, 1024)])
    flat.save(OUT / "mollygram.ico", sizes=[(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 128, 256)])

    linux = OUT / "linux"
    linux.mkdir(exist_ok=True)
    for size in (16, 24, 32, 48, 64, 128, 256, 512):
        resized(flat, size).save(linux / f"{size}.png", optimize=True)

    for project in ("packages/app", "prototype"):
        write_appiconset(mac, ROOT / project / "macos/Runner/Assets.xcassets/AppIcon.appiconset")

    win = ROOT / "packages/app/windows/runner/resources/app_icon.ico"
    shutil.copyfile(OUT / "mollygram.ico", win)

    linux_icon = ROOT / "packages/app/linux/runner/resources/app_icon.png"
    linux_icon.parent.mkdir(exist_ok=True)
    resized(flat, 256).save(linux_icon, optimize=True)

    print("Icons written to", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
