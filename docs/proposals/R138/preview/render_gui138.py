"""R138 copy (tutorial preview): draws colour emoji with Noto Color Emoji next to the DejaVu stand-in font.
R137 copy for the Index preview: also pastes PNGs into ViewportFrame slots ('VP:<card>' items) from IMGDIR
(env var), as <card>.png, fitted and centred. Otherwise as polish_R124/tests/render_gui.py:
Draw a dump_gui.luau JSON (real GUI from the mock) with Pillow. APPROXIMATION: DejaVu Sans Bold stands in for
Gotham/Fredoka, no real text metrics, no images (pack pictures are simple stand-ins built by the preview script).
Usage: python3 render_gui.py IN.json OUT.png [scale] [background r,g,b] [crop x,y,w,h]"""
import json, math, os, re, sys
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
K = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
BG = tuple(int(v) for v in sys.argv[4].split(',')) if len(sys.argv) > 4 else (60, 120, 70)
CROP = [float(v) for v in sys.argv[5].split(',')] if len(sys.argv) > 5 else None
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
fonts = {}
def font(px):
    px = max(6, int(round(px)))
    if px not in fonts: fonts[px] = ImageFont.truetype(BOLD, px)
    return fonts[px]

def lerp(a, b, t): return a + (b - a) * t
def sample(keys, t):
    if not keys: return None
    t = min(1, max(0, t))
    for i in range(len(keys) - 1):
        t0, v0 = keys[i]; t1, v1 = keys[i + 1]
        if t0 <= t <= t1:
            u = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            if isinstance(v0, list): return [lerp(v0[j], v1[j], u) for j in range(3)]
            return lerp(v0, v1, u)
    return keys[-1][1] if t > keys[0][0] else keys[0][1]

def fill_layer(w, h, base, alpha, grad):
    """RGBA patch w x h: base colour/alpha, modulated by a UIGradient (colour multiplies, transparency combines)."""
    img = Image.new('RGBA', (w, h))
    if not grad:
        img.paste((int(base[0]), int(base[1]), int(base[2]), int(255 * (1 - alpha))), (0, 0, w, h)); return img
    rot = math.radians(grad.get('rot', 0)); dx, dy = math.cos(rot), math.sin(rot)
    ox = grad['off'][0]; cols = grad.get('color'); alps = grad.get('alpha')
    px = img.load(); step = max(1, int(max(w, h) / 160))
    for y in range(0, h, step):
        for x in range(0, w, step):
            u = ((x / max(1, w - 1) - .5) * dx + (y / max(1, h - 1) - .5) * dy) + .5 - ox
            c = sample(cols, u) if cols else [255, 255, 255]
            a = sample(alps, u) if alps else 0
            col = (int(base[0] * c[0] / 255), int(base[1] * c[1] / 255), int(base[2] * c[2] / 255),
                   int(255 * (1 - alpha) * (1 - (a or 0))))
            for yy in range(y, min(h, y + step)):
                for xx in range(x, min(w, x + step)): px[xx, yy] = col
    return img

def rounded_mask(w, h, r, width=None):
    m = Image.new('L', (w, h), 0); d = ImageDraw.Draw(m)
    r = max(0, min(r, min(w, h) / 2))
    if width: d.rounded_rectangle((0, 0, w - 1, h - 1), radius=r, outline=255, width=max(1, int(round(width))))
    else: d.rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
    return m

def rich_runs(s, rich, color):
    if not rich: return [(s, color)]
    runs = []; pos = 0
    for m in re.finditer(r'<font color="#([0-9A-Fa-f]{6})">(.*?)</font>', s):
        if m.start() > pos: runs.append((re.sub('<[^>]+>', '', s[pos:m.start()]), color))
        h = m.group(1); runs.append((m.group(2), [int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)])); pos = m.end()
    if pos < len(s): runs.append((re.sub('<[^>]+>', '', s[pos:]), color))
    return runs

def clean(s):
    return s.replace('\ufe0f', '')

EMOJI = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', 109)
_emoji = {}
def is_emoji(ch):
    o = ord(ch)
    return o >= 0x1F000 or o in (0x23F3, 0x231B, 0x2705, 0x2B50, 0x26A1, 0x2728)
def emoji_img(ch, px):
    key = (ch, int(px))
    if key not in _emoji:
        im = Image.new('RGBA', (160, 140)); ImageDraw.Draw(im).text((8, 4), ch, font=EMOJI, embedded_color=True)
        box = im.getbbox(); im = im.crop(box) if box else im
        s = px / max(1, im.height); _emoji[key] = im.resize((max(1, int(im.width * s)), max(1, int(px))), Image.LANCZOS)
    return _emoji[key]
def pieces(word):
    out = []; cur = ''
    for ch in word:
        if is_emoji(ch):
            if cur: out.append(('t', cur)); cur = ''
            out.append(('e', ch))
        else: cur += ch
    if cur: out.append(('t', cur))
    return out
def word_len(f, size, wd):
    return sum(f.getlength(t) if k == 't' else size * 1.08 for k, t in pieces(wd))

def draw_text(canvas, it, k):
    t = it['text']; x, y, w, h = it['x'] * k, it['y'] * k, it['w'] * k, it['h'] * k
    runs = [(clean(s), c) for s, c in rich_runs(t['s'], t['rich'], t['color']) if clean(s)]
    if not runs: return
    size = (t['max'] if t['scaled'] and t.get('max') else (h * .8 if t['scaled'] else t['size'])) * k
    words = []
    for s, c in runs:
        for i, wd in enumerate(s.split(' ')):
            if wd: words.append((wd, c))
    while True:
        f = font(size); lines = [[]]; lw = 0; space = f.getlength(' ')
        for wd, c in words:
            ww = word_len(f, size, wd)
            if lines[-1] and lw + space + ww > w: lines.append([]); lw = 0
            lines[-1].append((wd, c, ww)); lw += (space if len(lines[-1]) > 1 else 0) + ww
        lh = size * 1.15
        if (len(lines) * lh <= h * 1.05 and max(sum(p[2] for p in l) + space * (len(l) - 1) for l in lines) <= w * 1.02) or size <= 7 or not t['scaled'] and len(lines) == 1:
            break
        size -= 1
    total = len(lines) * lh
    ty = y + (h - total) / 2 if t['y'] == 'Center' else (y if t['y'] == 'Top' else y + h - total)
    d = ImageDraw.Draw(canvas)
    stroke = None
    for st in it['strokes']:
        if st['mode'] != 'Border': stroke = (st['color'], st['t'], st['alpha'])
    if not stroke and t['strokeAlpha'] < 1: stroke = (t['stroke'], max(1, size / 14), t['strokeAlpha'])
    for line in lines:
        lw = sum(p[2] for p in line) + font(size).getlength(' ') * (len(line) - 1)
        tx = x + (w - lw) / 2 if t['x'] == 'Center' else (x if t['x'] == 'Left' else x + w - lw)
        for wd, c, ww in line:
            fill = (int(c[0]), int(c[1]), int(c[2]), int(255 * (1 - t['alpha'])))
            kw = {}
            if stroke: kw = {'stroke_width': max(1, int(round(stroke[1] * (1 if stroke[1] > 2 else k)))), 'stroke_fill': (*[int(v) for v in stroke[0]], int(255 * (1 - stroke[2])))}
            px = tx
            for kind, piece in pieces(wd):
                if kind == 't':
                    d.text((px, ty + lh / 2), piece, font=font(size), fill=fill, anchor='lm', **kw); px += font(size).getlength(piece)
                else:
                    em = emoji_img(piece, size * .98)
                    if t['alpha'] < 1: canvas.alpha_composite(em, (int(px + size * .04), int(ty + lh / 2 - em.height / 2)))
                    px += size * 1.08
            tx += ww + font(size).getlength(' ')
        ty += lh

def put(dst, patch, ox, oy):
    # alpha_composite the visible part of patch at (ox, oy); nothing when it lies outside dst.
    x0, y0 = max(0, ox), max(0, oy); x1, y1 = min(dst.width, ox + patch.width), min(dst.height, oy + patch.height)
    if x1 <= x0 or y1 <= y0: return False
    dst.alpha_composite(patch.crop((x0 - ox, y0 - oy, x1 - ox, y1 - oy)), (x0, y0)); return True

def render(data, k):
    W, H = data['canvas']; canvas = Image.new('RGBA', (int(W * k), int(H * k)), (*BG, 255))
    for it in data['items']:
        x, y, w, h = it['x'] * k, it['y'] * k, it['w'] * k, it['h'] * k
        if w < 1 or h < 1: continue
        pad = int(max([s['t'] * k for s in it['strokes']] + [0]) + 2)
        pw, ph = int(w) + 2 * pad, int(h) + 2 * pad
        patch = Image.new('RGBA', (pw, ph))
        if it['bgA'] < 1 and it['bg']:
            body = fill_layer(int(w), int(h), it['bg'], it['bgA'], it['grad'])
            patch.paste(body, (pad, pad), rounded_mask(int(w), int(h), it['r'] * k))
        for st in it['strokes']:
            if st['mode'] != 'Border' and it['text']: continue
            t = st['t'] * k
            if t <= 0 or st['alpha'] >= 1: continue
            ow, oh = int(w + 2 * t), int(h + 2 * t)
            band = fill_layer(ow, oh, st['color'], st['alpha'], st['grad'])
            patch.alpha_composite(Image.composite(band, Image.new('RGBA', (ow, oh)), rounded_mask(ow, oh, it['r'] * k + t, t)), (int(pad - t), int(pad - t)))
        if it['n'].startswith('VP:') and os.environ.get('IMGDIR'):
            f = os.path.join(os.environ['IMGDIR'], it['n'][3:] + '.png')
            if os.path.exists(f):
                pic = Image.open(f).convert('RGBA'); s = min(w / pic.width, h / pic.height) * .96
                pic = pic.resize((max(1, int(pic.width * s)), max(1, int(pic.height * s))), Image.LANCZOS)
                patch.alpha_composite(pic, (int(pad + (w - pic.width) / 2), int(pad + (h - pic.height) / 2)))
        if it['rot']:
            patch = patch.rotate(-it['rot'], resample=Image.BICUBIC, expand=True)
        cx, cy = x + w / 2, y + h / 2
        ox, oy = int(cx - patch.width / 2), int(cy - patch.height / 2)
        if it['clip']:
            c = [v * k for v in it['clip']]; layer = Image.new('RGBA', canvas.size)
            if not put(layer, patch, ox, oy): continue
            m = Image.new('L', canvas.size, 0); ImageDraw.Draw(m).rectangle((c[0], c[1], c[0] + c[2], c[1] + c[3]), fill=255)
            layer.putalpha(Image.composite(layer.getchannel('A'), m, m)); canvas.alpha_composite(layer)
        else:
            put(canvas, patch, ox, oy)
        if it['text']:
            if it['clip']:
                c = [v * k for v in it['clip']]; layer = Image.new('RGBA', canvas.size); draw_text(layer, it, k)
                m = Image.new('L', canvas.size, 0); ImageDraw.Draw(m).rectangle((c[0], c[1], c[0] + c[2], c[1] + c[3]), fill=255)
                layer.putalpha(Image.composite(layer.getchannel('A'), m, m)); canvas.alpha_composite(layer)
            else: draw_text(canvas, it, k)
    return canvas

img = render(json.load(open(SRC)), K)
if CROP: img = img.crop(tuple(int(v * K) for v in (CROP[0], CROP[1], CROP[0] + CROP[2], CROP[1] + CROP[3])))
img.convert('RGB').save(OUT)
print('wrote', OUT, img.size)
