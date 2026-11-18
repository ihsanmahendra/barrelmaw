"""Bakes one barrel image per game color from the original SpriteCook barrel (props_sheet_1024.png).
Wood is colorized (keeping the original shading), iron bands stay neutral, and a cylinder shade, a
glossy highlight and a darker outline are added. Run from the repo root:
  python3 design/art-source/make_barrels.py     -> prototype/assets/art/barrel_atlas.png
The atlas is 5 columns x 2 rows of equal tiles in PALETTE order, so every barrel is drawn from one
texture (one batch) no matter how many colors are on screen."""
from PIL import Image, ImageFilter
import numpy as np

SRC = "design/art-source/props_sheet_1024.png"
OUT = "prototype/assets/art/"
PALETTE = {"R": "ef476f", "O": "f78c4a", "Y": "ffd166", "G": "06d6a0", "B": "4cc9f0",
           "P": "9b5de5", "K": "3d405b", "W": "f8f9fa", "N": "a47148", "S": "ff9ecb"}

sheet = Image.open(SRC).convert("RGBA").crop((0, 0, 545, 1024))
a = np.array(sheet.split()[3]) > 10
ys, xs = np.where(a)
sheet = sheet.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
scale = 256.0 / sheet.size[1]
sheet = sheet.resize((round(sheet.size[0] * scale), 256), Image.LANCZOS)
W, H = sheet.size
base = np.array(sheet).astype(np.float32) / 255.0
alpha = base[..., 3]
lum = 0.299 * base[..., 0] + 0.587 * base[..., 1] + 0.114 * base[..., 2]


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


wood = smooth(lum, 0.50, 0.66)            # 1 on pale wood, 0 on dark iron bands
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
cx = (W - 1) / 2.0
side = np.abs(xx - cx) / (W / 2.0)         # 0 center .. 1 edge
cyl = 1.0 - 0.34 * np.clip(side, 0, 1) ** 2.2   # darker toward the edges, like a rounded barrel


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def bake(hexcol):
    col = hex_rgb(hexcol)
    t = np.clip((lum - 0.62) / (0.97 - 0.62), 0, 1)      # shading already in the generated wood
    t = (t ** 0.9)[..., None]
    dark, mid, light = col * 0.50, col * 0.98, np.minimum(1.0, col * 1.05 + 0.20)
    wood_rgb = np.where(t < 0.55, dark + (mid - dark) * (t / 0.55), mid + (light - mid) * ((t - 0.55) / 0.45))
    wood_rgb = wood_rgb * cyl[..., None]
    # Glossy vertical highlight on the left-center of the staves.
    gloss = np.exp(-(((xx - W * 0.30) / (W * 0.045)) ** 2)) * smooth(yy, H * 0.18, H * 0.30) * (1 - smooth(yy, H * 0.84, H * 0.95))
    wood_rgb = wood_rgb + (gloss[..., None] * 0.30 * wood[..., None])
    # Iron bands: keep neutral, a touch brighter and bluer for contrast.
    iron = np.clip(base[..., :3] * 1.18 + np.array([0.0, 0.01, 0.04]), 0, 1)
    out = wood_rgb * wood[..., None] + iron * (1 - wood[..., None])
    # Darker outline from the alpha edge.
    soft = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2))
    edge = np.clip(1.0 - np.array(soft).astype(np.float32) / 255.0 * 1.35, 0, 1)
    out = out * (1 - 0.55 * edge[..., None]) + (col * 0.28)[None, None, :] * (0.55 * edge[..., None])
    rgba = np.dstack([np.clip(out, 0, 1), alpha])
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    tiles = [bake(h) for h in PALETTE.values()]
    atlas = Image.new("RGBA", (W * 5, H * 2), (0, 0, 0, 0))
    for i, im in enumerate(tiles):
        atlas.alpha_composite(im, ((i % 5) * W, (i // 5) * H))
    atlas.save(OUT + "barrel_atlas.png")
    print("atlas", atlas.size, "tile", W, "x", H, "order", list(PALETTE.values()))
