#!/usr/bin/env python3
"""Compose the app icon from existing art (no Gemini call needed).

Pip (joyful pose) over glowing rainbow ribbons on a deep purple gradient.
Writes:
  store-assets/icon-512.png                     Play Store icon (full bleed)
  art/icon/foreground.png, art/icon/background.png   layers for Android adaptive icons
"""
import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
S = 1024
RAINBOW = [(255, 92, 122), (255, 168, 76), (255, 222, 89), (104, 230, 140), (84, 190, 255), (170, 120, 255)]


def background():
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.sqrt((xx - S * 0.5) ** 2 + (yy - S * 0.42) ** 2) / (S * 0.75)
    d = np.clip(d, 0, 1)[..., None]
    inner = np.array([92, 52, 170], float)
    outer = np.array([22, 15, 52], float)
    return Image.fromarray((inner * (1 - d) + outer * d).astype(np.uint8), "RGB").convert("RGBA")


def ribbons(scale=1.0):
    """Rainbow bands sweeping in an S-curve, with a soft glow."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    band = 26 * scale
    for i, col in enumerate(RAINBOW):
        pts = []
        for k in range(121):
            t = k / 120
            x = S * (0.02 + 0.96 * t)
            y = S * (0.62 + 0.20 * math.sin(t * math.pi * 1.6 + 0.4) - 0.14 * t) + (i - 2.5) * band
            pts.append((x, y))
        d.line(pts, fill=col + (255,), width=int(band + 2), joint="curve")
    glow = layer.filter(ImageFilter.GaussianBlur(22))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(glow)
    out.alpha_composite(layer)
    return out


def pip(height):
    im = Image.open(ROOT / "assets" / "images" / "pip_high.webp").convert("RGBA")
    w = int(im.width * height / im.height)
    return im.resize((w, height), Image.LANCZOS)


def place_center(canvas, im, cy):
    canvas.alpha_composite(im, ((S - im.width) // 2, int(cy - im.height / 2)))


def main():
    out_dir = ROOT / "store-assets"
    out_dir.mkdir(exist_ok=True)
    icon = background()
    icon.alpha_composite(ribbons())
    place_center(icon, pip(int(S * 0.72)), S * 0.5)
    icon.convert("RGB").resize((512, 512), Image.LANCZOS).save(out_dir / "icon-512.png")

    # Adaptive icon layers: the launcher crops to a circle/squircle showing
    # the central ~61% (66 dp safe zone of 108 dp), so the foreground is smaller.
    art = ROOT / "art" / "icon"
    art.mkdir(parents=True, exist_ok=True)
    bg = background()
    bg.alpha_composite(ribbons(0.8))
    bg.convert("RGB").save(art / "background.png")
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    place_center(fg, pip(int(S * 0.5)), S * 0.5)
    fg.save(art / "foreground.png")
    print("icon written")


if __name__ == "__main__":
    main()
