"""R151 treadmill polish: the five belt images as PNGs, for the owner to upload if he prefers uploaded images to the ones each client draws.
Usage: python3 make_belt_textures.py <out dir> [--alpha <out.txt>]
This is the SAME pattern code as src/ReplicatedStorage/TreadmillBeltArt151.lua (same Park-Miller random numbers, same sizes, same distance
profiles, same rounding), so the PNGs equal what the game draws at run time with EditableImage (tests/run_treadmills.sh checks every byte).
White with an alpha channel: the game tints each layer per biome (Texture.Color3).
  slats   64 x 64    one soft seam per tile and two rivets (every level)
  circuit 256 x 256  thin traces with 45-degree bends and round pads (Snow / Crystal / Storm light lines)
  crust   128 x 128  cooling-lava plates with transparent cracks (Lava)
  veins   256 x 256  soft wavy lines (Desert ripples, Lava veins, Crystal light)
  stream  128 x 256  columns of falling digits (Storm, top level)
--alpha writes "name w h" then the alpha bytes as hex, one image per line (the format the test compares with the game's own output).
Upload (optional): Studio > View > Asset Manager > Bulk Import the five PNGs (or Create > Decals on the website), copy each asset id into
TreadmillLook151.Images (e.g. slats='rbxassetid://123'), publish. An uploaded id wins over the drawn image on every client."""
import math, os, sys
from PIL import Image

SIZES = {'slats': (64, 64), 'circuit': (256, 256), 'crust': (128, 128), 'veins': (256, 256), 'stream': (128, 256)}


def rng(seed):
    s = [seed % 2147483647]
    if s[0] <= 0:
        s[0] += 2147483646

    def u():
        s[0] = (s[0] * 16807) % 2147483647
        return s[0] / 2147483647

    def integer(a, b):
        return a + math.floor(u() * (b - a + 1))
    return u, integer


def lmod(a, b):
    """Luau's float a % b (a - floor(a / b) * b), bit for bit (Python's % rounds differently in the last bit)."""
    return a - math.floor(a / b) * b


def clamp01(x):
    return 0 if x < 0 else (1 if x > 1 else x)


def profile(d, hw, gr, ga):
    core = clamp01(hw + .5 - d) * 255
    over = d - hw
    if over < 0:
        over = 0
    g = 1 - over / gr
    if g < 0:
        g = 0
    glow = ga * g * g
    return glow if glow > core else core


class Canvas:
    def __init__(self, w, h):
        self.W, self.H, self.A = w, h, bytearray(w * h)

    def put(self, x, y, v):
        v = math.floor(v + .5)
        if v <= 0:
            return
        if v > 255:
            v = 255
        i = (y % self.H) * self.W + (x % self.W)
        if self.A[i] < v:
            self.A[i] = v


def segment(c, x0, y0, x1, y1, hw, gr, ga):
    R = hw + gr + 1
    dx, dy = x1 - x0, y1 - y0
    len2 = dx * dx + dy * dy
    for py in range(math.floor(min(y0, y1) - R), math.ceil(max(y0, y1) + R) + 1):
        for px in range(math.floor(min(x0, x1) - R), math.ceil(max(x0, x1) + R) + 1):
            cx, cy = px + .5, py + .5
            t = 0
            if len2 > 0:
                t = clamp01(((cx - x0) * dx + (cy - y0) * dy) / len2)
            ex, ey = cx - (x0 + t * dx), cy - (y0 + t * dy)
            c.put(px, py, profile(math.sqrt(ex * ex + ey * ey), hw, gr, ga))


def ring(c, x, y, r, hw, gr, ga):
    R = r + hw + gr + 1
    for py in range(math.floor(y - R), math.ceil(y + R) + 1):
        for px in range(math.floor(x - R), math.ceil(x + R) + 1):
            ex, ey = px + .5 - x, py + .5 - y
            c.put(px, py, profile(abs(math.sqrt(ex * ex + ey * ey) - r), hw, gr, ga))


def slats(w, h):
    c = Canvas(w, h)
    for y in range(h):
        yc = y + .5
        d = min(yc, h - yc) * 256 / h
        v = 0
        if d <= 5:
            v = 235
        elif d <= 16:
            v = 235 * (1 - (d - 5) / 11) ** 2
        if v > 0:
            for x in range(w):
                c.put(x, y, v)
    r = 7 / 256 * w
    for cx in (22 / 256 * w, w - 22 / 256 * w):
        cy = h / 2
        for py in range(math.floor(cy - r - 1), math.ceil(cy + r + 1) + 1):
            for px in range(math.floor(cx - r - 1), math.ceil(cx + r + 1) + 1):
                ex, ey = px + .5 - cx, py + .5 - cy
                c.put(px, py, clamp01(r + .5 - math.sqrt(ex * ex + ey * ey)) * 200)
    return c


DIRS = [(1, 0), (0, 1), (0, 1), (-1, 0), (0, -1), (1, 1)]


def circuit(w, h):
    c = Canvas(w, h)
    _, integer = rng(151)
    cell = w / 8
    segs, pads = [], []
    for _ in range(9):
        x, y = integer(0, 7) * cell + cell / 2, integer(0, 7) * cell + cell / 2
        pads.append((x, y))
        for _ in range(integer(2, 4)):
            d = DIRS[integer(1, 6) - 1]
            n = integer(1, 3)
            nx, ny = x + d[0] * cell * n, y + d[1] * cell * n
            segs.append((x, y, nx, ny))
            x, y = nx, ny
        pads.append((x, y))
    for s in segs:
        segment(c, s[0], s[1], s[2], s[3], 1.6, 5, 110)
    for p in pads:
        ring(c, p[0], p[1], 5.5, 1.3, 5, 110)
    return c


def crust(w, h):
    c = Canvas(w, h)
    u, _ = rng(5)
    seeds = []
    for _ in range(22):
        sx = u() * w
        sy = u() * h
        seeds.append((sx, sy))
    for y in range(h):
        Y = y + .5
        for x in range(w):
            X = x + .5
            d0 = d1 = math.inf
            i0 = 0
            x0 = y0 = x1 = y1 = 0
            for i, s in enumerate(seeds, 1):
                dx = lmod(X - s[0] + w / 2, w) - w / 2
                dy = lmod(Y - s[1] + h / 2, h) - h / 2
                d = dx * dx + dy * dy
                if d < d0:
                    d1, x1, y1 = d0, x0, y0
                    d0, i0, x0, y0 = d, i, dx, dy
                elif d < d1:
                    d1, x1, y1 = d, dx, dy
            sep = math.sqrt((x1 - x0) ** 2 + (y1 - y0) ** 2)
            if sep <= 0:
                sep = 1
            edge = (d1 - d0) / (2 * sep)
            shade = 205 + ((i0 - 1) * 37) % 50
            v = 0
            if edge >= 2.2:
                v = shade
            elif edge > 1.1:
                v = shade * (edge - 1.1) / 1.1
            c.put(x, y, v)
    return c


def veins(w, h):
    c = Canvas(w, h)
    for y in range(h):
        yc = y + .5
        t = 2 * math.pi * yc / h
        for i in range(6):
            base = i * w / 6 + 20 * w / 512
            amp = (26 + 10 * (i % 3)) * w / 512
            k = 1 + i % 2
            e = 10 * w / 512
            xc = base + amp * math.sin(t * k) + e * math.sin(t * 3 + i)
            slope = (amp * math.cos(t * k) * k + e * math.cos(t * 3 + i) * 3) * 2 * math.pi / h
            f = 1 / math.sqrt(1 + slope * slope)
            hw = 1.6 if i % 2 == 1 else 1.1
            R = (hw + 4 + 1) / f
            for px in range(math.floor(xc - R), math.floor(xc + R) + 1):
                c.put(px, y, profile(abs(px + .5 - xc) * f, hw, 4, 120))
    return c


FONT = {'0': (7, 5, 5, 5, 7), '1': (2, 6, 2, 2, 7), '2': (7, 1, 7, 4, 7), '3': (7, 1, 7, 1, 7), '4': (5, 5, 7, 1, 1), '5': (7, 4, 7, 1, 7),
        '6': (7, 4, 7, 5, 7), '7': (7, 1, 1, 1, 1), '8': (7, 5, 7, 5, 7), '9': (7, 5, 7, 1, 7)}


def stream(w, h):
    c = Canvas(w, h)
    _, integer = rng(9)
    scale, pitch = 3, 18
    for col in range(8):
        x0 = col * 16 + 3
        head = integer(0, h - 1)
        length = integer(7, 14)
        for j in range(math.floor(h / pitch)):
            fade = 1 - j / length
            if fade > 0:
                glyph = FONT[str(integer(0, 9))]
                v = 255 * (.25 + .75 * fade)
                y0 = (head - j * pitch) % h
                for gy in range(5):
                    row = glyph[gy]
                    for gx in range(3):
                        if math.floor(row / 2 ** (2 - gx)) % 2 == 1:
                            for sy in range(scale):
                                for sx in range(scale):
                                    c.put(x0 + gx * scale + sx, y0 + gy * scale + sy, v)
    return c


PATTERNS = {'slats': slats, 'circuit': circuit, 'crust': crust, 'veins': veins, 'stream': stream}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    lines = []
    for name, fn in PATTERNS.items():
        w, h = SIZES[name]
        c = fn(w, h)
        img = Image.new('RGBA', (w, h), (255, 255, 255, 0))
        img.putalpha(Image.frombytes('L', (w, h), bytes(c.A)))
        img.save(os.path.join(out, name + '.png'), optimize=True)
        lines.append('%s %d %d %s' % (name, w, h, bytes(c.A).hex()))
        print('wrote', name + '.png', (w, h))
    if '--alpha' in sys.argv:
        open(sys.argv[sys.argv.index('--alpha') + 1], 'w').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
