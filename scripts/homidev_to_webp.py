#!/usr/bin/env python3
"""Make the app's picture files from owner-approved homidev cutouts.

asset-integrate.sh copies approved originals into assets/homidev/ (registered
in assets/ASSET-REGISTER.md). The app uses small WebP files named by word:
assets/images/obj_<word>.webp, or assets/images/<name>.webp when the name
already has a prefix (animal_cow, badge_animals). The job -> name mapping lives in
docs/asset-requests/*/approved-images.json.

  python3 scripts/homidev_to_webp.py
"""
import json
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent

for mapping in sorted(ROOT.glob('docs/asset-requests/*/approved-images.json')):
    for job, word in json.loads(mapping.read_text()).items():
        im = Image.open(ROOT / 'assets' / 'homidev' / f'{job}_cutout.png').convert('RGBA')
        bb = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
        pad = 12
        im = im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(im.width, bb[2] + pad), min(im.height, bb[3] + pad)))
        im.thumbnail((768, 768), Image.LANCZOS)
        name = word if '_' in word else f'obj_{word}'
        im.save(ROOT / 'assets' / 'images' / f'{name}.webp', quality=90, method=6)
        print(name, im.size)
