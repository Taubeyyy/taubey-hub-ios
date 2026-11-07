"""Draws the app icon: the hub's accent as a soft glow on ink, a bold T.

    python tools/make_icon.py

Writes ios/Taubey/Assets.xcassets/AppIcon.appiconset/icon.png (1024 px, the
single size Xcode 14+ needs) and the catalog's Contents.json files.
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "ios", "Taubey", "Assets.xcassets")
ICON_DIR = os.path.join(ASSETS, "AppIcon.appiconset")
S = 1024

INK = (8, 8, 13)
ACCENT = (124, 92, 255)
PINK = (255, 56, 216)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    img = Image.new("RGB", (S, S), INK)

    # two glows, accent top left, pink bottom right
    glow = Image.new("RGB", (S, S), INK)
    d = ImageDraw.Draw(glow)
    d.ellipse((-200, -260, 760, 700), fill=ACCENT)
    d.ellipse((420, 460, 1260, 1300), fill=PINK)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img = Image.blend(img, glow, 0.55)

    # the letter, white with a faint shadow
    font = None
    for name in ("arialbd.ttf", "seguibl.ttf", "segoeuib.ttf", "DejaVuSans-Bold.ttf"):
        try:
            font = ImageFont.truetype(name, 720)
            break
        except OSError:
            continue
    if font is None:
        font = ImageFont.load_default()

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    box = ld.textbbox((0, 0), "T", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x, y = (S - w) / 2 - box[0], (S - h) / 2 - box[1] - 10
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x, y + 18), "T", font=font, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    ld.text((x, y), "T", font=font, fill=(255, 255, 255, 255))

    img = img.convert("RGBA")
    img.alpha_composite(shadow)
    img.alpha_composite(layer)
    img.convert("RGB").save(os.path.join(ICON_DIR, "icon.png"))

    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)
    print("icon written")


if __name__ == "__main__":
    main()
