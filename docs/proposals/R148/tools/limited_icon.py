"""R148: the LIMITED tab icon, drawn with Pillow (96x96 RGBA).

A glossy purple cut gem set in a gold eight-point star with a small purple "LIMITED" ribbon across the bottom, in the weight of
the other Index tab logos (dark navy outline about 3 px, faceted light from the top left, white glints, transparent corners).
Everything is drawn at 4x and reduced with premultiplied alpha, so the edges are smooth and carry no dark fringe.

    python3 limited_icon.py OUT.png        # draws the icon (96x96) and writes it
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = 96
S = 4                      # supersampling
N = OUT * S
NAVY = (22, 16, 48)        # outline colour (the other logos use a near-black navy)
LIGHT = np.array([-0.62, -0.78])  # towards the light: up and to the left (screen y grows downwards)

GOLD = [(0.0, (128, 66, 8)), (0.30, (206, 122, 14)), (0.55, (250, 176, 30)), (0.78, (255, 218, 78)), (1.0, (255, 247, 176))]
PURPLE = [(0.0, (52, 18, 108)), (0.30, (104, 40, 168)), (0.55, (156, 66, 214)), (0.78, (204, 120, 242)), (1.0, (244, 200, 255))]
TABLE = [(0.0, (238, 178, 255)), (0.38, (196, 108, 238)), (0.72, (146, 58, 208)), (1.0, (96, 32, 170))]
RIBBON = [(0.0, (74, 20, 112)), (0.35, (122, 38, 156)), (0.65, (170, 62, 196)), (1.0, (222, 128, 232))]
RIBBON_TAIL = [(0.0, (48, 12, 82)), (0.5, (86, 24, 120)), (1.0, (130, 44, 160))]


def ramp(stops, t):
    t = min(1.0, max(0.0, t))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            u = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return tuple(c0[i] + (c1[i] - c0[i]) * u for i in range(3))
    return stops[-1][1]


def canvas():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


def pts(points):
    return [(x * S, y * S) for x, y in points]


def poly_mask(points):
    m = Image.new('L', (N, N), 0)
    ImageDraw.Draw(m).polygon(pts(points), fill=255)
    return m


def round_mask(mask, radius):
    """Round a mask's corners (blur then threshold)."""
    r = radius * S
    return mask.filter(ImageFilter.GaussianBlur(r)).point(lambda v: 255 if v > 127 else 0).filter(ImageFilter.GaussianBlur(S * .5))


def grow(mask, px):
    """Round dilation by px (96-scale pixels)."""
    r = px * S
    return mask.filter(ImageFilter.GaussianBlur(r * .62)).point(lambda v: 255 if v > 18 else 0).filter(ImageFilter.GaussianBlur(S * .45))


def paint(img, mask, color):
    layer = Image.new('RGBA', (N, N), (*[int(round(c)) for c in color], 255))
    layer.putalpha(mask)
    img.alpha_composite(layer)


def paint_gradient(img, mask, stops, top, bottom, angle=None):
    """Fill the mask with a ramp along the vertical (or along `angle`, radians) between y=top..bottom (96-scale)."""
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float32)
    if angle is None:
        t = (ys / S - top) / max(1e-6, bottom - top)
    else:
        t = ((xs / S) * math.cos(angle) + (ys / S) * math.sin(angle) - top) / max(1e-6, bottom - top)
    t = np.clip(t, 0, 1)
    xp = [s[0] for s in stops]
    out = np.zeros((N, N, 4), np.uint8)
    for c in range(3):
        out[..., c] = np.interp(t, xp, [s[1][c] for s in stops]).astype(np.uint8)
    out[..., 3] = 255
    layer = Image.fromarray(out, 'RGBA')
    layer.putalpha(mask)
    img.alpha_composite(layer)


def facet(img, points, color, clip=None):
    m = poly_mask(points)
    if clip is not None:
        m = Image.fromarray(np.minimum(np.array(m), np.array(clip)))
    paint(img, m, color)


def shade(centroid, center, bias=0.0, power=1.0):
    d = np.array([centroid[0] - center[0], centroid[1] - center[1]])
    n = np.linalg.norm(d)
    if n < 1e-6:
        return 0.6
    b = float(np.dot(d / n, LIGHT))      # -1..1
    t = (b + 1) / 2
    return min(1.0, max(0.0, (t ** power) + bias))


def edge_tone(a, b, center, gain=1.0, bias=0.0):
    """Tone 0..1 of a facet whose outer edge runs a->b: its outward normal against the light."""
    ex, ey = b[0] - a[0], b[1] - a[1]
    n = np.array([ey, -ex])
    mid = np.array([(a[0] + b[0]) / 2 - center[0], (a[1] + b[1]) / 2 - center[1]])
    if np.dot(n, mid) < 0:
        n = -n
    n = n / (np.linalg.norm(n) + 1e-9)
    d = float(np.dot(n, LIGHT))            # -1..1
    x = .5 + .5 * d * gain
    return min(1.0, max(0.0, x + bias))


def star_points(cx, cy, r_out, r_in, n=8, start=-90.0):
    pts_ = []
    for i in range(n * 2):
        a = math.radians(start + i * 180.0 / n)
        r = r_out if i % 2 == 0 else r_in
        pts_.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts_


def glint(img, cx, cy, r, color=(255, 255, 255), thin=.2):
    """A four-point sparkle."""
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    p = []
    for i in range(8):
        a = math.radians(-90 + i * 45)
        rr = r if i % 2 == 0 else r * thin
        p.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts(p), fill=255)
    paint(img, m, color)


def draw():
    img = canvas()
    cx, cy = 48.0, 45.0

    # ---- gold eight-point star -------------------------------------------------------------------------------------------------
    outer = star_points(cx, cy, 44.0, 31.5)
    star = round_mask(poly_mask(outer), 1.4)
    paint(img, grow(star, 2.7), NAVY)
    paint_gradient(img, star, GOLD, 4, 90)
    # faceted bevel: each tip splits into a lit and a shaded half
    for i in range(8):
        tip = outer[i * 2]
        left = outer[(i * 2 - 1) % 16]
        right = outer[(i * 2 + 1) % 16]
        for side, valley in (('l', left), ('r', right)):
            tri = [(cx, cy), tip, valley]
            tone = .06 + .90 * edge_tone(tip, valley, (cx, cy), gain=1.25)
            facet(img, tri, ramp(GOLD, tone), clip=star)
    # light rim along the upper-left edges of the star
    rim = Image.new('L', (N, N), 0)
    rd = ImageDraw.Draw(rim)
    for i in range(16):
        a, b = outer[i], outer[(i + 1) % 16]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if shade(mid, (cx, cy)) > .62:
            rd.line(pts([a, b]), fill=255, width=int(1.5 * S))
    inner_clip = Image.fromarray(np.array(star.filter(ImageFilter.MinFilter(int(3 * S) | 1))))
    rim = Image.fromarray(np.minimum(np.array(rim.filter(ImageFilter.GaussianBlur(S * .4))), np.array(star)))
    layer = Image.new('RGBA', (N, N), (255, 250, 196, 255))
    layer.putalpha(rim.point(lambda v: int(v * .75)))
    img.alpha_composite(layer)
    # dark inner crease between facets (keeps the star faceted at small sizes)
    crease = Image.new('L', (N, N), 0)
    cd = ImageDraw.Draw(crease)
    for i in range(8):
        tip = outer[i * 2]
        cd.line(pts([(cx, cy), tip]), fill=255, width=int(1.1 * S))
    crease = Image.fromarray(np.minimum(np.array(crease.filter(ImageFilter.GaussianBlur(S * .3))), np.array(star)))
    layer = Image.new('RGBA', (N, N), (120, 62, 8, 255))
    layer.putalpha(crease.point(lambda v: int(v * .55)))
    img.alpha_composite(layer)

    # ---- the purple gem (an octagonal brilliant seen from above) ---------------------------------------------------------------
    gx, gy = cx, cy - 2.5
    R, RT = 26.5, 12.2
    ang = [math.radians(22.5 + 45 * i) for i in range(8)]
    girdle = [(gx + R * math.cos(a), gy + R * math.sin(a)) for a in ang]
    table = [(gx + RT * math.cos(a), gy + RT * math.sin(a)) for a in ang]
    gem_mask = round_mask(poly_mask(girdle), .9)
    # a soft gold glow ring so the gem sits on the star
    paint(img, grow(gem_mask, 4.2), (150, 82, 10))
    paint(img, grow(gem_mask, 3.2), (255, 205, 60))
    paint(img, grow(gem_mask, 2.8), NAVY)
    paint_gradient(img, gem_mask, PURPLE, gy - R, gy + R)
    for i in range(8):
        a0, a1 = girdle[i], girdle[(i + 1) % 8]
        t0, t1 = table[i], table[(i + 1) % 8]
        # crown facets: the kite next to the girdle edge, then the triangle against the table
        tone_a = .04 + .92 * edge_tone(a0, a1, (gx, gy), gain=1.3)
        tone_b = .10 + .80 * edge_tone(a0, t1, (gx, gy), gain=1.0, bias=.04)
        facet(img, [a0, a1, t1], ramp(PURPLE, tone_a), clip=gem_mask)
        facet(img, [a0, t1, t0], ramp(PURPLE, tone_b), clip=gem_mask)
    # table
    table_mask = poly_mask(table)
    ta = math.atan2(.9, .5)
    proj = gx * math.cos(ta) + gy * math.sin(ta)
    paint_gradient(img, table_mask, TABLE, proj - RT * 1.05, proj + RT * 1.05, angle=ta)
    # facet edges (thin, dark violet)
    edges = Image.new('L', (N, N), 0)
    ed = ImageDraw.Draw(edges)
    for i in range(8):
        ed.line(pts([girdle[i], table[i]]), fill=255, width=int(.9 * S))
        ed.line(pts([girdle[(i + 1) % 8], table[i]]), fill=255, width=int(.7 * S))
        ed.line(pts([table[i], table[(i + 1) % 8]]), fill=255, width=int(.9 * S))
    edges = Image.fromarray(np.minimum(np.array(edges.filter(ImageFilter.GaussianBlur(S * .25))), np.array(gem_mask)))
    layer = Image.new('RGBA', (N, N), (46, 14, 96, 255))
    layer.putalpha(edges.point(lambda v: int(v * .70)))
    img.alpha_composite(layer)
    # light edges on the lit crown facets
    lit = Image.new('L', (N, N), 0)
    ld = ImageDraw.Draw(lit)
    for i in range(8):
        a0, a1 = girdle[i], girdle[(i + 1) % 8]
        mid = ((a0[0] + a1[0]) / 2, (a0[1] + a1[1]) / 2)
        if shade(mid, (gx, gy)) > .6:
            ld.line(pts([a0, a1]), fill=255, width=int(1.3 * S))
    lit = Image.fromarray(np.minimum(np.array(lit.filter(ImageFilter.GaussianBlur(S * .35))), np.array(gem_mask)))
    layer = Image.new('RGBA', (N, N), (246, 214, 255, 255))
    layer.putalpha(lit.point(lambda v: int(v * .8)))
    img.alpha_composite(layer)
    # table: a dark violet ring (the table edge) and a bright glossy highlight
    ring = Image.new('L', (N, N), 0)
    ImageDraw.Draw(ring).line(pts(table + [table[0]]), fill=255, width=int(1.1 * S), joint='curve')
    layer = Image.new('RGBA', (N, N), (60, 20, 116, 255))
    layer.putalpha(ring.filter(ImageFilter.GaussianBlur(S * .2)).point(lambda v: int(v * .55)))
    img.alpha_composite(layer)
    gloss = Image.new('L', (N, N), 0)
    gd = ImageDraw.Draw(gloss)
    gd.polygon(pts([(gx - 9.5, gy - 3.0), (gx - 4.2, gy - 9.8), (gx + 1.5, gy - 9.2), (gx - 4.4, gy - 2.6)]), fill=255)
    gloss = gloss.filter(ImageFilter.GaussianBlur(S * .55))
    layer = Image.new('RGBA', (N, N), (255, 255, 255, 255))
    layer.putalpha(gloss.point(lambda v: int(v * .92)))
    img.alpha_composite(layer)
    # a curved shine across the upper-left crown
    shine = Image.new('L', (N, N), 0)
    sd = ImageDraw.Draw(shine)
    arc_box = [(gx - R * .80) * S, (gy - R * .80) * S, (gx + R * .80) * S, (gy + R * .80) * S]
    sd.arc(arc_box, 200, 252, fill=255, width=int(1.7 * S))
    shine = shine.filter(ImageFilter.GaussianBlur(S * .35))
    layer = Image.new('RGBA', (N, N), (255, 240, 255, 255))
    layer.putalpha(Image.fromarray(np.minimum(np.array(shine), np.array(gem_mask))).point(lambda v: int(v * .85)))
    img.alpha_composite(layer)
    glint(img, gx - 14.5, gy - 15.5, 5.2, (255, 255, 255))
    glint(img, gx + 11.0, gy + 6.5, 2.8, (255, 236, 255))

    # ---- the LIMITED ribbon ----------------------------------------------------------------------------------------------------
    ry0, ry1 = 66.0, 82.0
    tail_l = [(5.0, 70.5), (23.0, 70.5), (23.0, 87.0), (5.0, 87.0), (10.2, 78.7)]
    tail_r = [(91.0, 70.5), (73.0, 70.5), (73.0, 87.0), (91.0, 87.0), (85.8, 78.7)]
    for tail in (tail_l, tail_r):
        m = round_mask(poly_mask(tail), .5)
        paint(img, grow(m, 2.6), NAVY)
        paint_gradient(img, m, RIBBON_TAIL, 70, 87)
    # the fold shadow where the ribbon crosses over the tails
    for sign, x in ((1, 19.5), (-1, 76.5)):
        fold = [(x, ry1 - .5), (x + sign * 4.2, ry1 - .5), (x + sign * 4.2, 87.0)]
        m = poly_mask([(x - sign * 0.0, ry1 - .5), (x + sign * 4.5, ry1 + 4.5), (x, ry1 + 4.5)])
        paint(img, m, (30, 8, 56))
    band = [(14.0, ry0 + 1.5), (30.0, ry0 - .5), (48.0, ry0 - 1.6), (66.0, ry0 - .5), (82.0, ry0 + 1.5),
            (82.0, ry1 + 1.5), (66.0, ry1 + 3.2), (48.0, ry1 + 4.4), (30.0, ry1 + 3.2), (14.0, ry1 + 1.5)]
    bm = poly_mask(band)
    paint(img, grow(bm, 2.6), NAVY)
    paint_gradient(img, bm, RIBBON, ry0 - 2, ry1 + 4)
    # gold edge lines top and bottom of the ribbon
    for k, (ya, yb) in enumerate(((ry0 + 1.3, ry0 + 3.3), (ry1 - .6, ry1 + 1.0))):
        top_line = Image.new('L', (N, N), 0)
        dd = ImageDraw.Draw(top_line)
        curve = []
        for j in range(0, 41):
            x = 15 + j * (66 / 40)
            sag = -1.6 * (1 - ((x - 48) / 34) ** 2) if k == 0 else 4.0 * (1 - ((x - 48) / 34) ** 2) - 0.5
            curve.append((x, (ya + yb) / 2 + sag + (1.6 if k == 0 else 0)))
        dd.line(pts(curve), fill=255, width=int(1.1 * S), joint='curve')
        top_line = Image.fromarray(np.minimum(np.array(top_line.filter(ImageFilter.GaussianBlur(S * .25))), np.array(bm)))
        layer = Image.new('RGBA', (N, N), (255, 214, 72, 255))
        layer.putalpha(top_line.point(lambda v: int(v * .95)))
        img.alpha_composite(layer)
    # the word
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int(8.4 * S))
    except OSError:
        font = ImageFont.load_default()
    txt = 'LIMITED'
    tw = ImageDraw.Draw(img).textlength(txt, font=font)
    tx, ty = 48 * S - tw / 2, (ry0 + ry1) / 2 * S + 2.0 * S
    tl = Image.new('L', (N, N), 0)
    ImageDraw.Draw(tl).text((tx, ty), txt, font=font, fill=255, anchor='lm', stroke_width=int(S * .9), stroke_fill=255)
    shadow = Image.new('RGBA', (N, N), (40, 8, 70, 255))
    shadow.putalpha(tl)
    img.alpha_composite(shadow)
    tl2 = Image.new('L', (N, N), 0)
    ImageDraw.Draw(tl2).text((tx, ty), txt, font=font, fill=255, anchor='lm')
    gold = Image.new('RGBA', (N, N), (255, 226, 96, 255))
    gold.putalpha(tl2)
    img.alpha_composite(gold)
    # sparkles on the star
    glint(img, 79.0, 14.0, 6.0)
    glint(img, 16.5, 17.0, 3.4, (255, 250, 220))
    glint(img, 84.5, 55.0, 2.6, (255, 250, 220))

    # premultiplied reduction
    small = img.convert('RGBa').resize((OUT, OUT), Image.LANCZOS).convert('RGBA')
    return small


if __name__ == '__main__':
    draw().save(sys.argv[1] if len(sys.argv) > 1 else 'limited.png')
