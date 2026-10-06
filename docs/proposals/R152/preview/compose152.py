"""R152 preview: composes the rendered layers of every FRAME (the world / stage render with its grade and blur, the card under the seed, the
seed card's viewport, the GUI over it) and lays them out (R151's compose.py, extended).
Usage: python3 compose152.py <render dir> <out file> strips|gif|grid|pairs [title] [before render dir (pairs)]
  strips: one row per tag (seed_opening.png, seed_opening_beam.png); gif: every frame, 0.1 s each (seed_opening_king.gif);
  grid: frames in a grid of three (seed_opening_planets.png); pairs: the same frame BEFORE (the R151 tree) and AFTER (seed_opening_assets.png)."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

D, OUT, MODE = sys.argv[1], sys.argv[2], sys.argv[3]
TITLE = sys.argv[4] if len(sys.argv) > 4 else ''
BEFORE = sys.argv[5] if len(sys.argv) > 5 else None


def font(px, bold=True):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)
    except Exception:
        return ImageFont.load_default()


def grade(img, g, blur, scale):
    """Roblox ColorCorrectionEffect, approximately: brightness adds, contrast / saturation scale, tint multiplies."""
    img = img.convert('RGB')
    if g:
        if g['s']:
            img = ImageEnhance.Color(img).enhance(max(0.0, 1 + g['s']))
        if g['c']:
            img = ImageEnhance.Contrast(img).enhance(max(0.0, 1 + g['c']))
        if g['b']:
            add = int(g['b'] * 255)
            img = img.point(lambda v: max(0, min(255, v + add)))
        t = g['tint']
        if t != [255, 255, 255]:
            r, gg, b = img.split()
            img = Image.merge('RGB', (r.point(lambda v: v * t[0] // 255), gg.point(lambda v: v * t[1] // 255), b.point(lambda v: v * t[2] // 255)))
    if blur and blur > .3:
        img = img.filter(ImageFilter.GaussianBlur(blur * .45 * scale))
    return img


def overlay(img, path):
    if os.path.exists(path):
        ov = Image.open(path).convert('RGBA')
        if ov.size != img.size:
            ov = ov.resize(img.size, Image.LANCZOS)
        img.alpha_composite(ov)


def frame(d, m):
    img = grade(Image.open(os.path.join(d, m['name'] + '_world.png')), m['grade'], m['blur'], m['h'] / 720).convert('RGBA')
    for i in range(m.get('under', 0)):
        overlay(img, os.path.join(d, '%s_under%d.png' % (m['name'], i)))
    vp = m.get('vp')
    if vp and os.path.exists(os.path.join(d, m['name'] + '_vp.png')):
        x, y, w, h = vp['rect']
        s = max(1, int(w * vp['scale']))
        card = Image.open(os.path.join(d, m['name'] + '_vp.png')).convert('RGBA').resize((s, s), Image.LANCZOS)
        if vp['alpha'] < 1:
            card.putalpha(card.split()[3].point(lambda v: int(v * vp['alpha'])))
        img.alpha_composite(card, (int(x + w / 2 - s / 2), int(y + h / 2 - s / 2)))
    for i in range(m['guis']):
        overlay(img, os.path.join(d, '%s_gui%d.png' % (m['name'], i)))
    return img.convert('RGB')


meta = json.load(open(os.path.join(D, 'meta.json')))
BG, INK, SUB, GOLD = (18, 16, 26), (240, 236, 255), (170, 166, 196), (255, 220, 140)
NOTE = 'Real scripts on the Roblox mock; drawn with three.js (beams as textured ribbons, particles as sprites, the client-drawn images from the real pattern code), GUI with R150 render_gui.mjs. Approximate: plain materials, stand-in pack art and avatar, stand-in particle textures, no Future lighting.'

if MODE == 'one':  # (checking) one frame at full size: compose152.py <dir> <out.png> one <frame name>
    frame(D, [m for m in meta if m['name'] == sys.argv[4]][0]).save(OUT)
    sys.exit(0)

if MODE == 'gif':
    frames = [frame(D, m).resize((448, 252), Image.LANCZOS) for m in meta]
    pal = [f.quantize(colors=144, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal[0].save(OUT, save_all=True, append_images=pal[1:], duration=100, loop=0, optimize=True)
    print('gif', len(frames), 'frames ->', OUT)
    sys.exit(0)


def header(width, title, note=NOTE):
    return title, note


if MODE == 'strips':
    rows = []
    for m in meta:
        if not rows or rows[-1][0] != m['tag']:
            rows.append((m['tag'], []))
        rows[-1][1].append(m)
    FH, PAD, LABEL = 200, 14, 22
    ordered = []
    for key, items in rows:
        imgs = [frame(D, m) for m in items]
        imgs = [i.resize((int(i.width * FH / i.height), FH), Image.LANCZOS) for i in imgs]
        ordered.append((key, items, imgs))
    width = max(sum(i.width for i in imgs) + PAD * (len(imgs) + 1) for _, _, imgs in ordered)
    width = max(width, 1500)
    height = 100 + sum(FH + LABEL + PAD * 2 + 28 for _ in ordered)
    sheet = Image.new('RGB', (width, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 12), TITLE, font=font(22), fill=INK)
    d.text((PAD, 44), NOTE, font=font(13, False), fill=SUB)
    y = 80
    for key, items, imgs in ordered:
        d.text((PAD, y), key.upper(), font=font(19), fill=GOLD)
        y += 28
        x = PAD
        for m, im in zip(items, imgs):
            d.text((x, y), m['label'], font=font(13), fill=(214, 210, 236))
            sheet.paste(im, (x, y + LABEL))
            x += im.width + PAD
        y += FH + LABEL + PAD * 2
    sheet.crop((0, 0, width, y)).save(OUT, optimize=True)
    print('sheet ->', OUT)
    sys.exit(0)

if MODE == 'grid':
    COLS, FW, PAD, LABEL = 3, 520, 14, 22
    imgs = [frame(D, m) for m in meta]
    imgs = [i.resize((FW, int(i.height * FW / i.width)), Image.LANCZOS) for i in imgs]
    FH = max(i.height for i in imgs)
    rows = (len(imgs) + COLS - 1) // COLS
    width = PAD + COLS * (FW + PAD)
    sheet = Image.new('RGB', (width, 80 + rows * (FH + LABEL + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 12), TITLE, font=font(22), fill=INK)
    d.text((PAD, 44), NOTE[:150] + ('...' if len(NOTE) > 150 else ''), font=font(12, False), fill=SUB)
    for k, (m, im) in enumerate(zip(meta, imgs)):
        x, y = PAD + (k % COLS) * (FW + PAD), 80 + (k // COLS) * (FH + LABEL + PAD)
        d.text((x, y), m['label'], font=font(13), fill=(214, 210, 236))
        sheet.paste(im, (x, y + LABEL))
    sheet.save(OUT, optimize=True)
    print('grid ->', OUT)
    sys.exit(0)

if MODE == 'pairs':
    before = {m['name']: m for m in json.load(open(os.path.join(BEFORE, 'meta.json')))}
    FW, PAD, LABEL = 640, 16, 24
    rows = []
    for m in meta:
        b = before.get(m['name'])
        after = frame(D, m).resize((FW, int(FW * m['h'] / m['w'])), Image.LANCZOS)
        old = frame(BEFORE, b).resize((FW, int(FW * b['h'] / b['w'])), Image.LANCZOS) if b else None
        rows.append((m['label'], old, after))
    FH = max(r[2].height for r in rows)
    width = PAD * 3 + FW * 2
    sheet = Image.new('RGB', (width, 110 + len(rows) * (FH + LABEL + PAD)), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 12), TITLE, font=font(22), fill=INK)
    d.text((PAD, 44), NOTE[:160] + '...', font=font(12, False), fill=SUB)
    d.text((PAD, 80), 'BEFORE (R151)', font=font(17), fill=(200, 196, 220))
    d.text((PAD * 2 + FW, 80), 'AFTER (R152)', font=font(17), fill=GOLD)
    y = 108
    for label, old, after in rows:
        d.text((PAD, y), label, font=font(14), fill=(214, 210, 236))
        if old:
            sheet.paste(old, (PAD, y + LABEL))
        sheet.paste(after, (PAD * 2 + FW, y + LABEL))
        y += FH + LABEL + PAD
    sheet.crop((0, 0, width, y)).save(OUT, optimize=True)
    print('pairs ->', OUT)
    sys.exit(0)
