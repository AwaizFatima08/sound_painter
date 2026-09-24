#!/usr/bin/env python3
"""Play Store graphics from existing art (no Gemini call needed).

  store-assets/feature-graphic-1024x500.png   title + tagline over the banner art
  store-assets/icon-512.png                   made by scripts/make_icon.py

Text is set with real fonts (Andika), never drawn by the image model.
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "store-assets"
BOLD = str(ROOT / "assets" / "fonts" / "Andika-Bold.ttf")
REG = str(ROOT / "assets" / "fonts" / "Andika-Regular.ttf")
CREAM = (255, 244, 230)
TEAL = (94, 242, 214)


def shadowed_text(img, xy, text, font, fill, blur=6):
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((xy[0] + 2, xy[1] + 3), text, font=font, fill=(10, 6, 30, 200))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    ImageDraw.Draw(img).text(xy, text, font=font, fill=fill)


def feature():
    src = Image.open(ROOT / "art" / "raw" / "store_feature.png").convert("RGBA")
    w, h = src.size
    target = 1024 / 500
    cw = int(h * target)
    art = src.crop((w - cw, 0, w, h)).resize((1024, 500), Image.LANCZOS)
    # Darken the left side a little so the title reads on any screen.
    shade = Image.new("RGBA", art.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shade)
    for x in range(520):
        a = int(120 * (1 - x / 520) ** 1.4)
        d.line([(x, 0), (x, 500)], fill=(14, 9, 38, a))
    art.alpha_composite(shade)
    shadowed_text(art, (44, 130), "Sound Painter", ImageFont.truetype(BOLD, 70), CREAM)
    shadowed_text(art, (48, 222), "Color the World", ImageFont.truetype(BOLD, 42), TEAL)
    shadowed_text(art, (48, 270), "with Your Voice!", ImageFont.truetype(BOLD, 42), TEAL)
    art.convert("RGB").save(OUT / "feature-graphic-1024x500.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    feature()
    print("store graphics written")
