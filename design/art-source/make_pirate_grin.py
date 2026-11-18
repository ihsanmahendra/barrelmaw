"""Makes the 'grinning' pirate (big hit lands): a wide toothy smile with a gold tooth and happy
squinting eye on the generated sprite. Run: python3 design/art-source/make_pirate_grin.py
Writes prototype/assets/art/pirate_grin.png (same crop as pirate.png)."""
from PIL import Image, ImageDraw
import math

SRC = "design/art-source/pirate_cannon_1024.png"
OUT = "prototype/assets/art/pirate_grin.png"
BBOX = (118, 15, 991, 1000)
S = 4

im = Image.open(SRC).convert("RGBA")
orig = im.copy()
x0, y0, x1, y1 = 380, 180, 570, 330
patch = im.crop((x0, y0, x1, y1)).resize(((x1 - x0) * S, (y1 - y0) * S), Image.LANCZOS)
d = ImageDraw.Draw(patch)


def P(x, y):
    return ((x - x0) * S, (y - y0) * S)


def ellipse(cx, cy, rx, ry, fill, outline=None, width=0):
    d.ellipse([P(cx - rx, cy - ry), P(cx + rx, cy + ry)], fill=fill, outline=outline, width=width * S)


# Happy squinting eye: cover the open eye with skin, then draw an upward arc and a cheek lift.
skin = orig.getpixel((420, 252))[:3] + (255,)
ellipse(431, 231, 24, 21, skin)
arc = [P(412 + i * 1.6, 233 - 11 * math.sin(math.pi * i / 24.0)) for i in range(25)]
d.line(arc, fill=(36, 20, 14, 255), width=5 * S, joint="curve")
d.line([P(406, 216), P(430, 207), P(456, 211)], fill=(40, 30, 28, 255), width=8 * S, joint="curve")

# Wide grin under the mustache.
top, bottom = [], []
for i in range(0, 49):
    x = 432 + i * 1.6
    t = (x - 470) / 38.0
    k = max(0.0, 1.0 - t * t)
    top.append(P(x, 290 + 3.0 * k))
    bottom.append(P(x, 290 + 22.0 * (k ** 0.7)))
outline = top + bottom[::-1]
d.polygon(outline, fill=(36, 18, 16, 255))
inner_top, inner_bottom = [], []
for i in range(2, 47):
    x = 432 + i * 1.6
    t = (x - 470) / 38.0
    k = max(0.0, 1.0 - t * t)
    inner_top.append(P(x, 291.5 + 3.0 * k))
    inner_bottom.append(P(x, 290 + 20.0 * (k ** 0.7)))
d.polygon(inner_top + inner_bottom[::-1], fill=(94, 18, 26, 255))
# Teeth row with a gold tooth.
for i in range(2, 47):
    x = 432 + i * 1.6
    t = (x - 470) / 38.0
    k = max(0.0, 1.0 - t * t)
    ty = 291.5 + 3.0 * k
    d.line([P(x, ty), P(x, ty + 8.0 * (k ** 0.5))], fill=(255, 247, 230, 255), width=int(1.7 * S))
d.rounded_rectangle([P(481, 293), P(491, 303)], radius=2 * S, fill=(247, 196, 54, 255), outline=(150, 100, 20, 255), width=S)
ellipse(470, 309, 14, 5, (224, 98, 110, 255))

patch = patch.resize((x1 - x0, y1 - y0), Image.LANCZOS)
im.paste(patch, (x0, y0))
band = (400, 250, 530, 288)
im.paste(orig.crop(band), (band[0], band[1]))
im.putalpha(orig.split()[3])
crop = im.crop(BBOX)
w = 512
h = round(crop.size[1] * w / crop.size[0])
crop.resize((w, h), Image.LANCZOS).save(OUT)
print("saved", OUT, w, h)
bg = Image.new("RGBA", im.size, (120, 200, 230, 255))
bg.alpha_composite(im)
bg.crop((300, 150, 600, 380)).resize((600, 460), Image.LANCZOS).save("/tmp/face_grin.png")
