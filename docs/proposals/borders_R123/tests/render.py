"""PIL approximation of the R123 rarity borders on a 104 px inventory card.
Reads borders.txt (from dump.luau: the real GardenCardMotion instances) and writes ../borders_sheet.png.
Usage: python3 render.py borders.txt OUT.png [font.ttf]"""
import sys, math
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
FONT = sys.argv[3] if len(sys.argv) > 3 else None
K = 4  # pixels per Roblox offset unit
CARD = 104; RADIUS = 8
SHEET = (20, 46, 35); TILE = (37, 76, 57); WELL = (14, 33, 25)
ORDER = ['Common', 'Uncommon', 'Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
# GardenTheme.Rarities lettering (Color, or the middle of the Fill gloss) + outline.
TEXT = {'Common': ((213, 224, 210), (19, 31, 28)), 'Uncommon': ((151, 228, 154), (19, 31, 28)), 'Rare': ((131, 199, 255), (19, 31, 28)),
        'Legendary': ((255, 200, 70), (62, 32, 8)), 'Mythic': ((250, 70, 80), (58, 8, 17)), 'Secret': ((255, 255, 255), (0, 0, 0)),
        'Cosmic': ((172, 159, 242), (255, 255, 255)), 'King': ((255, 226, 130), (105, 57, 9))}
NOTE = {'Common': 'thin grey-green line', 'Uncommon': 'green line', 'Rare': 'blue double line', 'Legendary': 'gold, slow shine sweep',
        'Mythic': 'crimson, pulsing glow', 'Secret': 'black/white, silver shimmer', 'Cosmic': 'violet, edge sparkles',
        'King': 'gold, gem corners, glow'}
FRUIT = {'Common': (150, 200, 90), 'Uncommon': (110, 200, 120), 'Rare': (90, 160, 240), 'Legendary': (255, 190, 60), 'Mythic': (230, 60, 70),
         'Secret': (60, 60, 70), 'Cosmic': (130, 100, 230), 'King': (255, 215, 90)}

def col(s): return tuple(int(x) for x in s.split(','))
def font(size):
    return ImageFont.truetype(FONT, size) if FONT else ImageFont.load_default()

def parse():
    poses = {}
    for line in open(SRC):
        p = line.rstrip('\n').split(';')
        if len(p) < 4: continue
        poses.setdefault(p[0], {}).setdefault(p[1], []).append(p[2:])
    return poses

def gradient(spec):
    if not spec or not spec[0]: return None
    keys = [(float(k.split(':')[0]), col(k.split(':')[1])) for k in spec[0].split(' ')]
    return keys, float(spec[1]), float(spec[2])

def sample(keys, t):
    t = min(1, max(0, t))
    for (a, ca), (b, cb) in zip(keys, keys[1:]):
        if a <= t <= b:
            u = 0 if b == a else (t - a) / (b - a)
            return tuple(int(ca[i] + (cb[i] - ca[i]) * u) for i in range(3))
    return keys[-1][1]

def ring(img, ox, oy, x0, y0, x1, y1, r, th, color, alpha, grad=None):
    """UIStroke in Border mode: drawn outside the frame rect (x0..x1 in offset units), rounded radius r."""
    if alpha <= 0 or th <= 0: return
    pad = th
    W = int((x1 - x0 + 2 * pad) * K) + 2; H = int((y1 - y0 + 2 * pad) * K) + 2
    mask = Image.new('L', (W, H), 0); d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, W - 2, H - 2], radius=int((r + pad) * K), fill=255)
    d.rounded_rectangle([int(pad * K), int(pad * K), int((x1 - x0 + pad) * K) - 1, int((y1 - y0 + pad) * K) - 1], radius=int(r * K), fill=0)
    layer = Image.new('RGBA', (W, H), color + (0,))
    if grad:
        keys, rot, off = grad
        ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        px = layer.load()
        for y in range(H):
            for x in range(W):
                u, v = x / W - .5, y / H - .5
                t = (u * ca + v * sa) / (abs(ca) * .5 + abs(sa) * .5 or 1) * .5 + .5 - off * .5
                c = sample(keys, t); m = tuple(int(c[i] * color[i] / 255) for i in range(3))
                px[x, y] = m + (0,)
    a = mask.point(lambda v: int(v * alpha))
    layer.putalpha(a)
    img.alpha_composite(layer, (int(ox + (x0 - pad) * K), int(oy + (y0 - pad) * K)))

def diamond(img, cx, cy, size, fill, alpha=1.0, edge=None):
    s = size * K / 2 * 1.0
    pts = [(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)]
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=fill + (int(255 * alpha),))
    if edge: d.polygon([(cx, cy - s - K), (cx + s + K, cy), (cx, cy + s + K), (cx - s - K, cy)], outline=edge + (255,), width=K)
    img.alpha_composite(layer)

def text(d, xy, s, size, fill, outline=None, anchor='la'):
    f = font(size * K)
    if outline: d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=max(1, K // 2), stroke_fill=outline)
    else: d.text(xy, s, font=f, fill=fill, anchor=anchor)

def card(img, ox, oy, rarity, items, scale_note=True):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([ox, oy, ox + CARD * K - 1, oy + CARD * K - 1], radius=RADIUS * K, fill=TILE + (230,))
    # Picture placeholder (the 3D item view): a fruit with a leaf.
    fx, fy = ox + 52 * K, oy + 34 * K
    d.ellipse([fx - 22 * K, fy - 20 * K, fx + 22 * K, fy + 22 * K], fill=FRUIT[rarity] + (255,))
    d.ellipse([fx - 12 * K, fy - 12 * K, fx - 2 * K, fy - 4 * K], fill=(255, 255, 255, 90))
    d.ellipse([fx + 2 * K, fy - 28 * K, fx + 16 * K, fy - 18 * K], fill=(110, 200, 90, 255))
    # Count badge, traits and the name (rarity lettering) in the card's own layout.
    d.rounded_rectangle([ox + 4 * K, oy + 4 * K, ox + 32 * K, oy + 20 * K], radius=6 * K, fill=(0, 0, 0, 160))
    text(d, (ox + 18 * K, oy + 12 * K), 'x3', 9, (255, 255, 255), anchor='mm')
    text(d, (ox + 52 * K, oy + 66 * K), 'Big', 8, (204, 224, 255), anchor='mm')
    fill, outline = TEXT[rarity]
    text(d, (ox + 52 * K, oy + 84 * K), 'Melon (2.4kg)', 10, fill, outline, anchor='mm')
    for it in items:
        kind = it[0]
        if kind == 'stroke':
            c, th, tr = col(it[1]), float(it[2]), float(it[3]); g = gradient(it[4:7]) if len(it) > 4 else None
            ring(img, ox, oy, 0, 0, CARD, CARD, RADIUS, th, c, 1 - tr, g)
        elif kind in ('Glow', 'InnerLine'):
            pos = [float(v) for v in it[1].split(',')]; inset = pos[1]; r = float(it[2])
            c, th, tr = col(it[3]), float(it[4]), float(it[5]); g = gradient(it[6:9]) if len(it) > 6 and it[6] else None
            ring(img, ox, oy, inset, inset, CARD - inset, CARD - inset, r, th, c, 1 - tr, g)
        elif kind == 'gem':
            pos = [float(v) for v in it[1].split(',')]; size = float(it[2])
            cx = ox + (pos[0] * CARD + pos[1]) * K; cy = oy + (pos[2] * CARD + pos[3]) * K
            diamond(img, cx, cy, size, col(it[3]), 1, col(it[4])); diamond(img, cx, cy, float(it[6]), col(it[5]))
        elif kind == 'sparkle':
            pos = [float(v) for v in it[1].split(',')]; size = float(it[2]); tr = float(it[3])
            cx = ox + (pos[0] * CARD + pos[1]) * K; cy = oy + (pos[2] * CARD + pos[3]) * K
            diamond(img, cx, cy, size, (255, 255, 255), 1 - tr)

poses = parse()
COLS, GAP, TOP = 4, 46, 70
cw = CARD * K; cell_w = cw + GAP * K // 2; cell_h = cw + 40 * K
animated = ['Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
small_rows = len(animated)
W = COLS * cell_w + GAP * K // 2
BEFORE_H = 30 * K + (cw + 40 * K) // 2
H = TOP * K + 2 * cell_h + 60 * K + small_rows * (cw + 16 * K) // 2 + 20 * K + BEFORE_H
img = Image.new('RGBA', (W, H), SHEET + (255,))
d = ImageDraw.Draw(img)
text(d, (W // 2, 22 * K), 'R123 rarity borders on the inventory card (no emblems)', 15, (255, 255, 255), anchor='mm')
text(d, (W // 2, 44 * K), 'PIL approximation of the real GardenCardMotion instances (dump.luau), 104 px card shown at 2x', 9, (204, 224, 255), anchor='mm')
for i, r in enumerate(ORDER):
    ox = GAP * K // 2 + (i % COLS) * cell_w; oy = TOP * K + (i // COLS) * cell_h
    card(img, ox, oy, r, poses['motion-a'][r])
    fill, outline = TEXT[r]
    text(d, (ox + cw // 2, oy + cw + 14 * K), r, 12, fill, outline, anchor='mm')
    text(d, (ox + cw // 2, oy + cw + 29 * K), NOTE[r], 8, (204, 224, 255), anchor='mm')
# Motion strip: two moments in the loop + the static pose (FastMode / ReducedMotion / low effects).
y0 = TOP * K + 2 * cell_h + 10 * K
text(d, (W // 2, y0), 'animated rarities: t = 5.2 s   |   t = 6.0 s   |   static (FastMode / ReducedMotion / low)', 10, (255, 255, 255), anchor='mm')
small = Image.new('RGBA', (3 * cell_w, small_rows * (cw + 16 * K)), SHEET + (255,))
for j, r in enumerate(animated):
    for k, pose in enumerate(['motion-a', 'motion-b', 'static']):
        card(small, k * cell_w + GAP * K // 4, j * (cw + 16 * K) + 8 * K, r, poses[pose][r])
small = small.resize((small.width // 2, small.height // 2), Image.LANCZOS)
img.alpha_composite(small, ((W - small.width) // 2, y0 + 14 * K))
for j, r in enumerate(animated):
    fill, outline = TEXT[r]
    text(d, ((W - small.width) // 2 - 8 * K, y0 + 14 * K + j * small.height // small_rows + small.height // small_rows // 2), r, 10, fill, outline, anchor='rm')
# Before (R122): every rarity had the same 1.2 px accent line (shine on Legendary+) plus a 12 px corner emblem.
ACCENT = {'Common': (154, 176, 152), 'Uncommon': (80, 159, 108), 'Rare': (67, 129, 218), 'Legendary': (227, 158, 36), 'Mythic': (222, 42, 52),
          'Secret': (180, 184, 192), 'Cosmic': (158, 148, 218), 'King': (247, 178, 46)}
yb = y0 + 14 * K + small.height + 14 * K
text(d, (W // 2, yb), 'before (R122): same 1.2 px accent line + corner emblem (marker; see emblems_R122)', 9, (204, 224, 255), anchor='mm')
strip = Image.new('RGBA', (8 * (cw + 10 * K), cw + 40 * K), SHEET + (255,))
for i, r in enumerate(ORDER):
    ox = i * (cw + 10 * K) + 5 * K
    card(strip, ox, 6 * K, r, [['stroke', '%d,%d,%d' % ACCENT[r], '1.2', '0.18']])
    sd = ImageDraw.Draw(strip); ex, ey = ox + (CARD - 9) * K, 6 * K + 8 * K
    sd.ellipse([ex - 6 * K, ey - 6 * K, ex + 6 * K, ey + 6 * K], fill=ACCENT[r] + (255,), outline=(255, 255, 255, 255), width=K)
    fill, outline = TEXT[r]; text(sd, (ox + cw // 2, 6 * K + cw + 16 * K), r, 12, fill, outline, anchor='mm')
strip = strip.resize((strip.width * W // strip.width // 1, strip.height * W // strip.width), Image.LANCZOS) if strip.width > W else strip
img.alpha_composite(strip, ((W - strip.width) // 2, yb + 10 * K))
img = img.crop((0, 0, W, min(H, yb + 10 * K + strip.height + 6 * K)))
img.convert('RGB').resize((W // 2, H // 2), Image.LANCZOS).save(OUT)
print('wrote', OUT, W // 2, H // 2)
