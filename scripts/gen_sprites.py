"""gen_sprites.py — build placeholder pixel-art sprites as $readmemh .mem files.

Player : 3 forms (horse, motorcycle, benz) x 8 directions, 32x32, 4-bit palette index
         -> assets/sprite_mem/player.mem   addr = {form[1:0], dir[2:0], row[4:0], col[4:0]}
Items  : 4 frames (moto token, benz token, star, sparkle), 32x32
         -> assets/sprite_mem/item.mem     addr = {frame[1:0], row[4:0], col[4:0]}
Preview sheets go to assets/preview/.

Each sprite is drawn facing up at 4x resolution, rotated by 45 deg steps, downsampled
and quantised to the shared 16-colour palette (index 0 = transparent).
Replace the draw_* functions with real artwork later; the .mem layout stays the same.

Usage:  python scripts/gen_sprites.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_MEM = ROOT / "assets" / "sprite_mem"
OUT_PREV = ROOT / "assets" / "preview"

PALETTE = [  # RGB444 -> RGB888 (index 0 = transparent)
    0x000, 0x112, 0x345, 0x667, 0xBBC, 0xFFF, 0xD44, 0xF83,
    0xFD6, 0x485, 0x7B8, 0x47B, 0x8CE, 0x853, 0xCA8, 0x957,
]
RGB = [(((c >> 8) & 0xF) * 17, ((c >> 4) & 0xF) * 17, (c & 0xF) * 17) for c in PALETTE]
C = {name: RGB[i] + (255,) for i, name in enumerate(
    ["_", "ink", "asphalt", "grey", "silver", "white", "red", "orange",
     "yellow", "grassd", "grassl", "blue", "glass", "brown", "skin", "plum"])}

# colours allowed in sprites (no grass greens, so edges don't blend into green fringes)
SPRITE_COLORS = [1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15]

S = 128          # draw resolution
N = 32           # sprite size


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def draw_horse():
    im = canvas(); d = ImageDraw.Draw(im)
    # legs (hooves peeking out)
    for (x, y) in [(40, 36), (80, 36), (40, 92), (80, 92)]:
        d.ellipse([x, y, x + 9, y + 14], fill=C["ink"])
    d.ellipse([34, 30, 94, 116], fill=C["brown"])                 # body
    d.polygon([(64, 120), (56, 108), (72, 108)], fill=C["ink"])   # tail
    d.ellipse([50, 4, 78, 44], fill=C["brown"])                   # head / neck
    d.ellipse([52, 2, 58, 12], fill=C["ink"]); d.ellipse([70, 2, 76, 12], fill=C["ink"])  # ears
    d.rectangle([61, 10, 67, 44], fill=C["ink"])                  # mane
    d.ellipse([40, 56, 88, 84], fill=C["blue"])                   # rider shoulders
    d.ellipse([54, 58, 74, 78], fill=C["ink"])                    # rider head (hair)
    return im


def draw_bike():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([56, 4, 72, 36], 6, fill=C["ink"])        # front wheel
    d.rounded_rectangle([56, 92, 72, 124], 6, fill=C["ink"])      # rear wheel
    d.rounded_rectangle([50, 28, 78, 100], 10, fill=C["red"])     # body
    d.rectangle([32, 32, 96, 39], fill=C["grey"])                 # handlebar
    d.ellipse([30, 30, 38, 42], fill=C["ink"]); d.ellipse([90, 30, 98, 42], fill=C["ink"])
    d.ellipse([60, 8, 68, 14], fill=C["yellow"])                  # headlight
    d.ellipse([38, 52, 90, 80], fill=C["blue"])                   # rider shoulders
    d.ellipse([52, 50, 76, 76], fill=C["yellow"])                 # helmet
    d.rectangle([56, 52, 72, 58], fill=C["ink"])                  # visor
    return im


def draw_benz():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([28, 4, 100, 124], 18, fill=C["silver"])  # body
    d.rounded_rectangle([36, 30, 92, 50], 6, fill=C["glass"])     # windshield
    d.rounded_rectangle([38, 50, 90, 94], 6, fill=C["grey"])      # roof
    d.rounded_rectangle([38, 94, 90, 108], 5, fill=C["glass"])    # rear window
    d.rectangle([32, 6, 46, 13], fill=C["yellow"]); d.rectangle([82, 6, 96, 13], fill=C["yellow"])
    d.rectangle([32, 116, 46, 121], fill=C["red"]); d.rectangle([82, 116, 96, 121], fill=C["red"])
    d.rectangle([22, 44, 28, 54], fill=C["ink"]); d.rectangle([100, 44, 106, 54], fill=C["ink"])  # mirrors
    return im


def token(bg, draw_icon):
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([16, 16, 112, 112], fill=C["white"])
    d.ellipse([24, 24, 104, 104], fill=bg)
    draw_icon(d)
    return im


def draw_item_moto():
    def icon(d):
        d.ellipse([34, 64, 58, 88], outline=C["white"], width=7)
        d.ellipse([70, 64, 94, 88], outline=C["white"], width=7)
        d.polygon([(46, 76), (64, 50), (82, 76)], outline=C["white"], width=7)
    return token(C["blue"], icon)


def draw_item_benz():
    def icon(d):
        d.rounded_rectangle([34, 56, 94, 82], 8, fill=C["white"])
        d.rounded_rectangle([46, 42, 82, 60], 6, fill=C["white"])
        d.ellipse([40, 76, 54, 90], fill=C["ink"]); d.ellipse([74, 76, 88, 90], fill=C["ink"])
    return token(C["grey"], icon)


def draw_item_star():
    im = canvas(); d = ImageDraw.Draw(im)
    import math
    pts = []
    for k in range(10):
        r = 52 if k % 2 == 0 else 22
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((64 + r * math.cos(a), 66 + r * math.sin(a)))
    d.polygon(pts, fill=C["yellow"], outline=C["orange"], width=5)
    return im


def draw_sparkle():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(64, 4), (74, 54), (124, 64), (74, 74), (64, 124), (54, 74), (4, 64), (54, 54)],
              fill=C["yellow"])
    d.polygon([(64, 28), (70, 58), (100, 64), (70, 70), (64, 100), (58, 70), (28, 64), (58, 58)],
              fill=C["white"])
    for (x, y) in [(20, 20), (100, 20), (20, 100), (100, 100)]:
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=C["orange"])
    return im


def quantize(im):
    """RGBA 32x32 -> list of palette indices (row-major)."""
    out = []
    px = im.load()
    for yy in range(N):
        for xx in range(N):
            r, g, b, a = px[xx, yy]
            if a < 128:
                out.append(0); continue
            best = min(SPRITE_COLORS,
                       key=lambda i: (RGB[i][0] - r) ** 2 + (RGB[i][1] - g) ** 2 + (RGB[i][2] - b) ** 2)
            out.append(best)
    return out


def to_sprite(im, angle_deg=0):
    if angle_deg:
        im = im.rotate(-angle_deg, resample=Image.BICUBIC, expand=False)   # clockwise
    return quantize(im.resize((N, N), Image.BOX))


def idx_image(idx, scale=4):
    im = Image.new("RGBA", (N, N))
    im.putdata([RGB[i] + (0 if i == 0 else 255,) for i in idx])
    return im.resize((N * scale, N * scale), Image.NEAREST)


def write_mem(path, frames, depth):
    flat = [v for f in frames for v in f]
    flat += [0] * (depth - len(flat))
    path.write_text("\n".join(f"{v:X}" for v in flat) + "\n")


def main():
    OUT_MEM.mkdir(parents=True, exist_ok=True)
    OUT_PREV.mkdir(parents=True, exist_ok=True)

    forms = [("horse", draw_horse), ("motorcycle", draw_bike), ("benz", draw_benz)]
    player_frames = []
    sheet = Image.new("RGBA", (8 * 132, 3 * 132), (40, 52, 60, 255))
    for fi, (_, fn) in enumerate(forms):
        base = fn()
        for di in range(8):                       # 0=N,1=NE,...,7=NW (clockwise)
            spr = to_sprite(base, 45 * di)
            player_frames.append(spr)
            sheet.alpha_composite(idx_image(spr), (di * 132 + 2, fi * 132 + 2))
    write_mem(OUT_MEM / "player.mem", player_frames, 1 << 15)
    sheet.save(OUT_PREV / "player_sheet.png")

    items = [draw_item_moto(), draw_item_benz(), draw_item_star(), draw_sparkle()]
    item_frames = [to_sprite(i) for i in items]
    write_mem(OUT_MEM / "item.mem", item_frames, 1 << 12)
    isheet = Image.new("RGBA", (4 * 132, 132), (40, 52, 60, 255))
    for k, f in enumerate(item_frames):
        isheet.alpha_composite(idx_image(f), (k * 132 + 2, 2))
    isheet.save(OUT_PREV / "item_sheet.png")
    print("wrote", OUT_MEM / "player.mem", "and", OUT_MEM / "item.mem")


if __name__ == "__main__":
    main()
