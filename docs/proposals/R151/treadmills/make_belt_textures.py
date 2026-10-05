"""R151 treadmill look PROPOSAL: the belt textures (tileable, white on transparent, so one image serves every biome through
Texture.Color3). Usage: python3 make_belt_textures.py <out dir>   (writes slats.png, circuit.png, crust.png, veins.png, stream.png)
These five PNGs are what would be uploaded (Studio > Asset Manager > Import) if the owner approves; the previews draw these exact files.
  slats    belt seams: one soft bright seam per tile plus two rivets (scrolls like a real treadmill belt)
  circuit  thin traces with 45-degree bends and round pads (the light lines of the ice / tech reference)
  crust    dark cooling-lava plates (Voronoi cells) with transparent cracks: over the Lava belt's glowing Neon it reads as flowing lava
  veins    soft wavy bright lines (sun ripples, molten veins, prism light)
  stream   columns of falling digits, bright head, fading tail (the "matrix" reference, used on the top levels)"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def save(img, name):
    img.save(os.path.join(out, name), optimize=True)
    print('wrote', name, img.size)


def tile_draw(size, fn):
    """Draw with wrap-around: fn(draw, dx, dy) is called for the 9 offsets so shapes crossing an edge reappear on the other side."""
    img = Image.new('L', size, 0)
    d = ImageDraw.Draw(img)
    for dx in (-size[0], 0, size[0]):
        for dy in (-size[1], 0, size[1]):
            fn(d, dx, dy)
    return img


def white(alpha):
    img = Image.new('RGBA', alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


# slats: 256 x 256, one seam across (V wraps), soft falloff, two rivets near each end of the seam
W = 256
a = Image.new('L', (W, W), 0)
px = a.load()
for y in range(W):
    dy = min(y, W - y)  # distance to the seam at y = 0
    v = 0
    if dy <= 5:
        v = 235
    elif dy <= 16:
        v = int(235 * (1 - (dy - 5) / 11) ** 2)
    for x in range(W):
        px[x, y] = v
d = ImageDraw.Draw(a)
for cx in (22, W - 22):
    for cy in (W // 2,):
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=200)
save(white(a), 'slats.png')

# circuit: 512 x 512 traces on an 8 x 8 grid of cells, wrap-around
random.seed(151)
W = 512
cell = W // 8
segs, pads = [], []
for i in range(9):
    x, y = random.randrange(8) * cell + cell // 2, random.randrange(8) * cell + cell // 2
    pads.append((x, y))
    for _ in range(random.randint(2, 4)):
        dirn = random.choice([(1, 0), (0, 1), (0, 1), (-1, 0), (0, -1), (1, 1)])
        n = random.randint(1, 3)
        nx, ny = x + dirn[0] * cell * n, y + dirn[1] * cell * n
        segs.append((x, y, nx, ny))
        x, y = nx, ny
    pads.append((x, y))


def circuit(dr, dx, dy):
    for (x0, y0, x1, y1) in segs:
        dr.line([x0 + dx, y0 + dy, x1 + dx, y1 + dy], fill=255, width=5)
    for (x, y) in pads:
        dr.ellipse([x + dx - 11, y + dy - 11, x + dx + 11, y + dy + 11], outline=255, width=5)


a = tile_draw((W, W), circuit)
glow = a.filter(ImageFilter.GaussianBlur(5)).point(lambda v: int(v * .7))
a = Image.composite(a, glow, a)
save(white(a), 'circuit.png')

# crust: 512 x 512 Voronoi plates (wrapped distance), cracks transparent with a soft rim
random.seed(5)
W = 512
seeds = [(random.random() * W, random.random() * W) for _ in range(22)]
small = 256  # computed at 256 and scaled up (smooth)
k = W / small
a = Image.new('L', (small, small), 0)
px = a.load()
for y in range(small):
    for x in range(small):
        X, Y = x * k + k / 2, y * k + k / 2
        ds = []
        for i, (sx, sy) in enumerate(seeds):
            ddx = (X - sx + W / 2) % W - W / 2  # wrapped offsets
            ddy = (Y - sy + W / 2) % W - W / 2
            ds.append((ddx * ddx + ddy * ddy, i, ddx, ddy))
        ds.sort()
        (d0, i0, x0, y0), (d1, i1, x1, y1) = ds[0], ds[1]
        sep = math.hypot(x1 - x0, y1 - y0) or 1
        edge = (d1 - d0) / (2 * sep)  # distance to the border between the two nearest plates
        shade = 205 + (i0 * 37) % 50  # each plate a slightly different shade
        v = 0 if edge < 3.5 else (shade if edge > 7 else int(shade * (edge - 3.5) / 3.5))
        px[x, y] = v
a = a.resize((W, W), Image.BICUBIC)
save(white(a), 'crust.png')

# veins: 512 x 512 wavy lines (periodic in both directions), with a soft glow
W = 512


def veins(dr, dx, dy):
    for i in range(6):
        base = i * W / 6 + 20
        amp = 26 + 10 * (i % 3)
        pts = []
        for s in range(0, W + 1, 8):
            x = base + amp * math.sin(2 * math.pi * s / W * (1 + i % 2)) + 10 * math.sin(2 * math.pi * s / W * 3 + i)
            pts.append((x + dx, s + dy))
        dr.line(pts, fill=255, width=6 if i % 2 else 4, joint='curve')


a = tile_draw((W, W), veins)
glow = a.filter(ImageFilter.GaussianBlur(7)).point(lambda v: min(255, int(v * 1.2)))
a = Image.composite(a, glow, a)
save(white(a), 'veins.png')

# stream: 256 x 512 columns of digits; each column has a bright head and a fading tail, wrapping in V
random.seed(9)
W, H = 256, 512
font = None
for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
    if os.path.exists(f):
        font = ImageFont.truetype(f, 26)
        break
a = Image.new('L', (W, H), 0)
d = ImageDraw.Draw(a)
cols = 8
for c in range(cols):
    x = c * W // cols + 6
    head = random.randrange(H)
    length = random.randint(7, 14)
    step = 30
    for j in range(H // step):
        y = (head - j * step) % H
        fade = max(0, 1 - j / length)
        if fade <= 0:
            continue
        ch = random.choice('0123456789')
        v = int(255 * (0.25 + 0.75 * fade))
        for yy in (y, y - H):
            d.text((x, yy), ch, fill=v, font=font)
save(white(a), 'stream.png')
