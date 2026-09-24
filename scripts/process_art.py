#!/usr/bin/env python3
"""Turn art/raw/*.png (Gemini output) into app-ready assets/images/.

- Characters, objects, badges and avatars are drawn on white: the white that
  connects to the image border becomes transparent, edges are un-mixed from
  white so they don't leave a halo on the dark app backgrounds, then the image
  is cropped and scaled.
- Backgrounds are scaled to 1920x1080 WebP.
- store_* images are left for scripts/make_store_assets.py.

  python3 scripts/process_art.py
"""
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "art" / "raw"
OUT = ROOT / "assets" / "images"

CUTOUT_MAX = 768
BG_SIZE = (1920, 1080)


def cutout(src: Image.Image) -> Image.Image:
    rgb = np.asarray(src.convert("RGB")).astype(np.float32)
    dist = (255 - rgb).max(axis=2)  # 0 = pure white, 255 = far from white

    # "Outside" = everything the border can reach without crossing the dark
    # plum outline. That includes soft glows (kept, as translucent colour) but
    # not the cream belly or white eye highlights enclosed by the outline.
    not_outline = dist < 150
    labels, _ = ndimage.label(not_outline)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    outside = np.isin(labels, border[border > 0])

    alpha = np.ones(dist.shape, np.float32)
    alpha[outside] = np.clip((dist[outside] - 6) / 90.0, 0, 1)
    # Slightly soften the outline's outer edge.
    edge = ndimage.binary_dilation(outside, iterations=1) & ~outside
    alpha[edge] = np.minimum(alpha[edge], 0.9)

    # Un-mix white: c = a*fg + (1-a)*255  =>  fg = (c - (1-a)*255) / a
    a3 = alpha[..., None]
    fg = np.where(a3 > 0.02, (rgb - (1 - a3) * 255) / np.maximum(a3, 0.02), 0)
    out = np.dstack([np.clip(fg, 0, 255), alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")

    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        pad = 12
        bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                min(img.width, bbox[2] + pad), min(img.height, bbox[3] + pad))
        img = img.crop(bbox)
    img.thumbnail((CUTOUT_MAX, CUTOUT_MAX), Image.LANCZOS)
    return img


def circle_cutout(src: Image.Image) -> Image.Image:
    """Avatars and badges are filled circles: cut along the circle itself.

    Background-guessing fails here because a white animal (bunny) inside the
    circle touches the white page with no outline between them.
    """
    rgb = np.asarray(src.convert("RGB")).astype(np.float32)
    ink = (255 - rgb).max(axis=2) > 24
    ys, xs = np.nonzero(ink)
    # Robust extent: ignore a few stray pixels.
    x0, x1 = np.percentile(xs, [0.2, 99.8])
    y0, y1 = np.percentile(ys, [0.2, 99.8])
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = min(x1 - x0, y1 - y0) / 2
    yy, xx = np.mgrid[0:rgb.shape[0], 0:rgb.shape[1]]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    alpha = np.clip(r - d + 0.5, 0, 1)  # 1 px anti-aliased edge
    out = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA").crop((int(cx - r - 2), int(cy - r - 2), int(cx + r + 2), int(cy + r + 2)))
    img.thumbnail((CUTOUT_MAX, CUTOUT_MAX), Image.LANCZOS)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for f in sorted(RAW.glob("*.png")):
        name = f.stem
        if name.startswith("store_"):
            continue
        src = Image.open(f)
        if name.startswith("bg_"):
            im = src.convert("RGB").resize(BG_SIZE, Image.LANCZOS)
            im.save(OUT / f"{name}.webp", quality=82, method=6)
        elif name.startswith(("avatar_", "badge_")):
            circle_cutout(src).save(OUT / f"{name}.webp", quality=90, method=6)
        else:
            cutout(src).save(OUT / f"{name}.webp", quality=90, method=6)
        print("processed", name)


if __name__ == "__main__":
    main()
