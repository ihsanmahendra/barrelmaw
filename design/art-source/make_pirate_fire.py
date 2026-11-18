"""Makes the 'shouting' pirate: opens his mouth and widens his eye on the generated sprite.
Run: python3 design/art-source/make_pirate_fire.py   (writes prototype/assets/art/pirate_fire.png)"""
from PIL import Image, ImageDraw

SRC = "design/art-source/pirate_cannon_1024.png"
OUT = "prototype/assets/art/pirate_fire.png"
BBOX = (118, 15, 991, 1000)  # same crop as pirate.png so the two textures line up
S = 4  # supersampling factor for smooth edges

im = Image.open(SRC).convert("RGBA")
orig = im.copy()
x0, y0, x1, y1 = 380, 180, 570, 330
patch = im.crop((x0, y0, x1, y1)).resize(((x1 - x0) * S, (y1 - y0) * S), Image.LANCZOS)
d = ImageDraw.Draw(patch)


def P(x, y):
    return ((x - x0) * S, (y - y0) * S)


def ellipse(cx, cy, rx, ry, fill, outline=None, width=0):
    a, b = P(cx - rx, cy - ry), P(cx + rx, cy + ry)
    d.ellipse([a, b], fill=fill, outline=outline, width=width * S)

# Wide eye: bigger white, bigger pupil, highlight.
ellipse(431, 231, 25, 23, (255, 255, 255, 255), (36, 20, 14, 255), 2)
ellipse(441, 232, 11, 11, (92, 40, 22, 255))
ellipse(442, 232, 6, 6, (20, 10, 8, 255))
ellipse(445, 227, 3, 3, (255, 255, 255, 255))
# Raised, angled brow above the wide eye.
d.line([P(404, 212), P(428, 200), P(456, 205)], fill=(40, 30, 28, 255), width=9 * S, joint="curve")

# Open shouting mouth below the mustache.
ellipse(470, 301, 35, 24, (36, 18, 16, 255))
ellipse(470, 301, 33, 22, (94, 18, 26, 255))
d.rounded_rectangle([P(443, 286), P(497, 296)], radius=3 * S, fill=(255, 247, 230, 255))
ellipse(470, 315, 18, 8, (224, 98, 110, 255))

patch = patch.resize((x1 - x0, y1 - y0), Image.LANCZOS)
im.paste(patch, (x0, y0))
# Put the original mustache band back on top so the mouth sits under it.
band = (400, 250, 530, 286)
im.paste(orig.crop(band), (band[0], band[1]))
# Keep everything outside the sprite's own silhouette transparent.
alpha = orig.split()[3]
im.putalpha(alpha)
crop = im.crop(BBOX)
w = 512
h = round(crop.size[1] * w / crop.size[0])
crop.resize((w, h), Image.LANCZOS).save(OUT)
print("saved", OUT, w, h)
# Preview of the face for checking.
bg = Image.new("RGBA", im.size, (120, 200, 230, 255))
bg.alpha_composite(im)
bg.crop((300, 150, 600, 380)).resize((600, 460), Image.LANCZOS).save("/tmp/face_fire.png")
