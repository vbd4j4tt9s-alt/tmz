"""Rough PNG renders of the shop from test_shop.luau frame dumps (JSON lines).
Draws every GuiObject rect with its colour, UIGradient, UICorner, UIStroke, rotation, clipping and text
(Fredoka One). ViewportFrames (3D previews) are drawn as placeholders. The game world is a flat backdrop.
Usage: python3 render_shop.py dumps.jsonl OUTDIR [font.ttf] [reference.png ...]"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

SCALE = 2
FONT = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].endswith('.ttf') else None
_fonts = {}


def font(px):
    px = max(6, int(round(px)))
    if px not in _fonts:
        _fonts[px] = ImageFont.truetype(FONT, px) if FONT else ImageFont.load_default()
    return _fonts[px]


def interp(keys, t):
    """keys: [[time, value], ...] (value scalar or rgb list); t: numpy array."""
    times = np.array([k[0] for k in keys], dtype=float)
    vals = np.array([k[1] for k in keys], dtype=float)
    if vals.ndim == 1:
        return np.interp(t, times, vals)
    return np.stack([np.interp(t, times, vals[:, i]) for i in range(vals.shape[1])], axis=-1)


def gradient_t(w, h, rot):
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    u = (xs + .5) / max(w, 1) - .5
    v = (ys + .5) / max(h, 1) - .5
    r = math.radians(rot)
    c, s = math.cos(r), math.sin(r)
    span = abs(c) * .5 + abs(s) * .5
    return np.clip((u * c + v * s) / max(span, 1e-6) * .5 + .5, 0, 1)


def round_mask(w, h, radius):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=max(0, min(radius, min(w, h) / 2)), fill=255)
    return np.array(m, dtype=float) / 255


def node_layer(n):
    """RGBA layer for one node (unrotated), plus pad offset for the outer stroke."""
    w, h = int(round(n['w'] * SCALE)), int(round(n['h'] * SCALE))
    if w <= 0 or h <= 0:
        return None, 0
    st = n.get('st')
    pad = int(math.ceil(st['t'] * SCALE)) + 1 if st and st['tr'] < 1 else 0
    W, H = w + pad * 2, h + pad * 2
    out = np.zeros((H, W, 4), dtype=float)
    radius = n.get('cr', 0) * SCALE
    bt = n.get('bt', 0)
    if n.get('bg') is not None and bt < 1:
        rgb = np.ones((h, w, 3)) * np.array(n['bg'], dtype=float)
        alpha = np.ones((h, w)) * (1 - bt)
        g = n.get('g')
        if g:
            t = gradient_t(w, h, g.get('r', 0))
            if g.get('c'):
                rgb = rgb * interp(g['c'], t) / 255.0
            if g.get('t'):
                alpha = alpha * (1 - interp(g['t'], t))
        alpha = alpha * round_mask(w, h, radius)
        out[pad:pad + h, pad:pad + w, :3] = rgb
        out[pad:pad + h, pad:pad + w, 3] = alpha * 255
    img = Image.fromarray(out.astype(np.uint8), 'RGBA')
    if pad:
        ol = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        th = max(1, int(round(st['t'] * SCALE)))
        col = tuple(st['c']) + (int(255 * (1 - st['tr'])),)
        o = pad - th / 2
        ImageDraw.Draw(ol).rounded_rectangle([o, o, W - 1 - o, H - 1 - o], radius=radius + th / 2, outline=col, width=th)
        img = Image.alpha_composite(img, ol)
    if n.get('vp'):
        d = ImageDraw.Draw(img)
        x0, y0 = pad + w * .2, pad + h * .15
        if n['n'] == 'MechPackPreview':
            d.rounded_rectangle([pad + w * .3, pad + h * .12, pad + w * .7, pad + h * .9], radius=w * .06, fill=(84, 70, 170, 255), outline=(10, 10, 20, 255), width=max(1, SCALE * 2))
            d.rounded_rectangle([pad + w * .36, pad + h * .2, pad + w * .64, pad + h * .42], radius=w * .03, fill=(120, 240, 255, 255))
            d.text((pad + w * .5, pad + h * .66), '3D', font=font(h * .16), fill=(255, 255, 255, 230), anchor='mm', stroke_width=SCALE, stroke_fill=(0, 0, 0))
        else:
            d.ellipse([pad + w * .3, pad + h * .25, pad + w * .7, pad + h * .7], fill=(255, 255, 255, 70))
            d.text((pad + w * .5, pad + h * .48), '3D', font=font(h * .2), fill=(255, 255, 255, 170), anchor='mm')
    tx = n.get('tx')
    if tx:
        d = ImageDraw.Draw(img)
        fs = n['fs'] * SCALE
        f = font(fs)
        lines = tx.split('\n')
        ts = n.get('ts')
        sw = int(round(ts['t'] * SCALE)) if ts and ts['tr'] < 1 else (SCALE if n.get('tst', 1) < .5 else 0)
        sc = tuple(ts['c']) if ts else (8, 13, 24)
        lh = fs * 1.12
        total = lh * len(lines)
        ya = n.get('ya', 'Center')
        y = pad + (0 if ya == 'Top' else (h - total if ya == 'Bottom' else (h - total) / 2))
        xa = n.get('xa', 'Center')
        for line in lines:
            if xa == 'Left':
                x, anchor = pad, 'lm'
            elif xa == 'Right':
                x, anchor = pad + w, 'rm'
            else:
                x, anchor = pad + w / 2, 'mm'
            d.text((x, y + lh / 2), line, font=f, fill=tuple(n.get('tc') or [255, 255, 255]), anchor=anchor, stroke_width=sw, stroke_fill=sc)
            y += lh
    return img, pad


def render(dump, out_path, reference=None):
    sw, sh = dump['sw'], dump['sh']
    L, T, R, B = dump['inset']
    canvas = Image.new('RGBA', (sw * SCALE, sh * SCALE), (0, 0, 0, 255))
    # Flat stand-in for the game world: sky and sand.
    t = np.linspace(0, 1, sh * SCALE)[:, None, None]
    sky = np.array([150, 190, 230]) * (1 - t) + np.array([240, 205, 150]) * t
    canvas = Image.fromarray(np.concatenate([np.broadcast_to(sky, (sh * SCALE, sw * SCALE, 3)), np.full((sh * SCALE, sw * SCALE, 1), 255)], axis=2).astype(np.uint8), 'RGBA')
    d = ImageDraw.Draw(canvas)
    # Roblox top bar buttons (approximate).
    for i, wd in enumerate([44, 100, 44, 44]):
        x = 12 + sum([44, 100, 44, 44][:i]) + i * 8 + L
        d.rounded_rectangle([x * SCALE, 8 * SCALE, (x + wd) * SCALE, 52 * SCALE], radius=22 * SCALE, fill=(25, 27, 32, 235))
    # Menu backdrop (MenuBackdrop: rgb 8,13,30 at 60%).
    shade = Image.new('RGBA', canvas.size, (8, 13, 30, 153))
    canvas = Image.alpha_composite(canvas, shade)
    # Native thumb controls (drawn under our gui, like TouchGui).
    c = dump.get('controls')
    if c:
        d = ImageDraw.Draw(canvas)
        for key in ('j', 'b'):
            x, y, w, h = c[key]
            x, y = x + L, y + T
            d.ellipse([x * SCALE, y * SCALE, (x + w) * SCALE, (y + h) * SCALE], outline=(255, 255, 255, 200), width=3 * SCALE, fill=(255, 255, 255, 40))
    for n in dump['nodes']:
        if n['w'] <= 0 or n['h'] <= 0:
            continue
        clip = n.get('clip')
        if clip and (clip[2] <= 0 or clip[3] <= 0):
            continue
        img, pad = node_layer(n)
        if img is None:
            continue
        cx, cy = (n['x'] + n['w'] / 2 + L) * SCALE, (n['y'] + n['h'] / 2 + T) * SCALE
        if abs(n.get('rot', 0)) > .01:
            img = img.rotate(-n['rot'], resample=Image.BICUBIC, expand=True)
        x0, y0 = int(round(cx - img.width / 2)), int(round(cy - img.height / 2))
        # Clip box in canvas pixels.
        bx0, by0, bx1, by1 = 0, 0, canvas.width, canvas.height
        if clip:
            bx0, by0 = max(bx0, int((clip[0] + L) * SCALE)), max(by0, int((clip[1] + T) * SCALE))
            bx1, by1 = min(bx1, int(math.ceil((clip[0] + clip[2] + L) * SCALE))), min(by1, int(math.ceil((clip[1] + clip[3] + T) * SCALE)))
        sx0, sy0 = max(x0, bx0), max(y0, by0)
        sx1, sy1 = min(x0 + img.width, bx1), min(y0 + img.height, by1)
        if sx1 <= sx0 or sy1 <= sy0:
            continue
        canvas.alpha_composite(img, (sx0, sy0), (sx0 - x0, sy0 - y0, sx1 - x0, sy1 - y0))
    canvas = canvas.convert('RGB')
    if reference:
        ref = Image.open(reference).convert('RGB')
        ref = ref.resize((canvas.width, int(ref.height * canvas.width / ref.width)))
        sheet = Image.new('RGB', (canvas.width, canvas.height + ref.height + 40 * SCALE), (20, 20, 24))
        sheet.paste(canvas, (0, 0))
        sheet.paste(ref, (0, canvas.height + 40 * SCALE))
        dd = ImageDraw.Draw(sheet)
        dd.text((10 * SCALE, canvas.height + 8 * SCALE), 'Reference (another game, layout only)', font=font(18 * SCALE), fill=(255, 255, 255))
        canvas = sheet
    canvas.save(out_path, optimize=True)


def compare(outdir, pairs, path):
    """Our render (left) next to the reference screenshot (right), one row per pair."""
    rows = []
    for ours, ref in pairs:
        a = Image.open(ours).convert('RGB')
        b = Image.open(ref).convert('RGB')
        h = 520
        a = a.resize((int(a.width * h / a.height), h))
        b = b.resize((int(b.width * h / b.height), h))
        rows.append((a, b))
    W = max(a.width + b.width for a, b in rows) + 30
    H = sum(520 + 50 for _ in rows) + 10
    sheet = Image.new('RGB', (W, H), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    y = 10
    for a, b in rows:
        d.text((10, y), 'Steal A Pack R120 (offline render)', font=font(26), fill=(255, 255, 255))
        d.text((a.width + 20, y), 'Reference (layout/style only)', font=font(26), fill=(200, 200, 200))
        sheet.paste(a, (10, y + 36))
        sheet.paste(b, (a.width + 20, y + 36))
        y += 570
    sheet.save(path, optimize=True)
    print('wrote', path)


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    refs = [a for a in sys.argv[3:] if a.endswith('.png')]
    os.makedirs(outdir, exist_ok=True)
    wanted = None if not os.environ.get('ONLY') else set(os.environ['ONLY'].split(','))
    for line in open(src):
        dump = json.loads(line)
        slug = dump['screen'].lower().replace(' ', '_') + ('' if dump['tag'] == 'open' else '_' + dump['tag'])
        if wanted and slug not in wanted:
            continue
        path = os.path.join(outdir, slug + '.png')
        render(dump, path)
        print('wrote', path)
    if len(refs) == 5:
        names = ['phone_844x390', 'phone_844x390_passes', 'phone_844x390_speed', 'phone_844x390_speedbundles', 'phone_844x390_money']
        pairs = [(os.path.join(outdir, n + '.png'), r) for n, r in zip(names, refs)]
        if all(os.path.exists(p) for p, _ in pairs):
            compare(outdir, pairs[:3], os.path.join(outdir, 'compare_phone_1.png'))
            compare(outdir, pairs[3:], os.path.join(outdir, 'compare_phone_2.png'))


if __name__ == '__main__':
    main()
