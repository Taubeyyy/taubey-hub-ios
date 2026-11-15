"""Draws the app icon in the Nyra look of the script menu and the dashboard:
the brand tile's magenta gradient (light top left, deep bottom right), a soft
leaf of light across it, a little grain, and the classic T built from two
bars - the same T as the dashboard's and the menu's logo.

    python tools/make_icon.py

Writes ios/Taubey/Assets.xcassets/AppIcon.appiconset/icon.png (1024 px, the
single size Xcode 14+ needs), the sign-in logo (Logo.imageset/logo.png) and
the catalog's Contents.json files.
"""
import json
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "ios", "Taubey", "Assets.xcassets")
ICON_DIR = os.path.join(ASSETS, "AppIcon.appiconset")
LOGO_DIR = os.path.join(ASSETS, "Logo.imageset")
S = 1024

LIGHT = (238, 106, 226)   # accent2
MID = (194, 31, 179)      # accent
DEEP = (122, 11, 115)     # accent3
INK = (20, 6, 22)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient():
    """140 degrees, as the CSS of the dashboard's mark: light, mid at 52%, deep."""
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = (x * 0.64 + y * 0.77) / (S * 1.41)
            t = max(0.0, min(1.0, t))
            c = lerp(LIGHT, MID, t / 0.52) if t < 0.52 else lerp(MID, DEEP, (t - 0.52) / 0.48)
            # the far corner sinks towards ink, so the tile has depth
            if t > 0.8:
                c = lerp(c, INK, (t - 0.8) / 0.2 * 0.55)
            px[x, y] = c
    return img


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(LOGO_DIR, exist_ok=True)
    img = gradient().convert("RGBA")

    # a leaf of light across the top, blurred like the menu's leaves
    leaf = Image.new("L", (S, S), 0)
    ImageDraw.Draw(leaf).ellipse((-260, -420, 980, 330), fill=120)
    leaf = leaf.rotate(-14, resample=Image.BICUBIC).filter(ImageFilter.GaussianBlur(90))
    white = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    white.putalpha(leaf)
    img.alpha_composite(white)

    # grain: faint light and dark specks, the frosted glass of the menu
    rnd = random.Random(1337)
    grain = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gp = grain.load()
    for y in range(S):
        for x in range(S):
            v = rnd.random()
            if v < 0.5:
                gp[x, y] = (0, 0, 0, int((0.5 - v) * 34))
            else:
                gp[x, y] = (255, 255, 255, int((v - 0.5) * 26))
    img.alpha_composite(grain)

    # the classic T: two rounded bars, white, with a soft shadow under them
    bar_w, bar_h = 470, 118
    stem_w, stem_h = 124, 470
    top = 268
    left = (S - bar_w) // 2
    t_mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(t_mask)
    d.rounded_rectangle((left, top, left + bar_w, top + bar_h), radius=34, fill=255)
    sx = (S - stem_w) // 2
    d.rounded_rectangle((sx, top + 40, sx + stem_w, top + 40 + stem_h), radius=34, fill=255)

    shadow = Image.new("RGBA", (S, S), (40, 0, 36, 0))
    shadow.putalpha(ImageChops.offset(t_mask, 0, 22).point(lambda a: int(a * 0.55)).filter(ImageFilter.GaussianBlur(26)))
    img.alpha_composite(shadow)
    letter = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    letter.putalpha(t_mask)
    img.alpha_composite(letter)

    out = img.convert("RGB")
    out.save(os.path.join(ICON_DIR, "icon.png"))
    out.save(os.path.join(LOGO_DIR, "logo.png"))

    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)
    print("icon and logo written")


if __name__ == "__main__":
    main()
