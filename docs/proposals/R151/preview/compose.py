"""R151 preview: composes the rendered layers of every FRAME (world / stage render, the post grade and blur, the seed card's viewport,
the GUI overlays) and lays the frames out as strips per tier -> rare_pull.png, or (gif mode) the King scene -> rare_pull_king.gif.
Usage: python3 compose.py <render dir> <out file> strips|gif"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

D, OUT, MODE = sys.argv[1], sys.argv[2], sys.argv[3]
meta = json.load(open(os.path.join(D, 'meta.json')))


def font(px, bold=True):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',):
        try:
            return ImageFont.truetype(p, px)
        except Exception:
            pass
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
            r = r.point(lambda v: v * t[0] // 255)
            gg = gg.point(lambda v: v * t[1] // 255)
            b = b.point(lambda v: v * t[2] // 255)
            img = Image.merge('RGB', (r, gg, b))
    if blur and blur > .3:
        img = img.filter(ImageFilter.GaussianBlur(blur * .45 * scale))
    return img


def frame(m):
    img = grade(Image.open(os.path.join(D, m['name'] + '_world.png')), m['grade'], m['blur'], m['h'] / 720)
    img = img.convert('RGBA')
    vp = m.get('vp')
    if vp and os.path.exists(os.path.join(D, m['name'] + '_vp.png')):
        x, y, w, h = vp['rect']
        s = max(1, int(w * vp['scale']))
        card = Image.open(os.path.join(D, m['name'] + '_vp.png')).convert('RGBA').resize((s, s), Image.LANCZOS)
        if vp['alpha'] < 1:
            a = card.split()[3].point(lambda v: int(v * vp['alpha']))
            card.putalpha(a)
        cx, cy = x + w / 2, y + h / 2
        img.alpha_composite(card, (int(cx - s / 2), int(cy - s / 2)))
    for i in range(m['guis']):
        p = os.path.join(D, '%s_gui%d.png' % (m['name'], i))
        if os.path.exists(p):
            ov = Image.open(p).convert('RGBA')
            if ov.size != img.size:
                ov = ov.resize(img.size, Image.LANCZOS)
            img.alpha_composite(ov)
    return img


if MODE == 'one':  # (debugging) one frame at full size: compose.py <dir> <out.png> one <frame name>
    frame([m for m in meta if m['name'] == sys.argv[4]][0]).convert('RGB').save(OUT)
    sys.exit(0)

if MODE == 'gif':
    frames = [frame(m).convert('RGB').resize((480, 270), Image.LANCZOS) for m in meta]
    pal = [f.quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal[0].save(OUT, save_all=True, append_images=pal[1:], duration=200, loop=0, optimize=True)
    print('gif', len(frames), 'frames ->', OUT)
    sys.exit(0)

# strips: one row per (tier, device); label over every frame
rows = []
for m in meta:
    key = m['tag']
    if not rows or rows[-1][0] != key:
        rows.append((key, []))
    rows[-1][1].append(m)
FH = 180  # every frame scaled to this height
PAD, TITLE, LABEL = 14, 40, 22
ordered = []
for key, items in rows:
    imgs = [frame(m).convert('RGB') for m in items]
    imgs = [i.resize((int(i.width * FH / i.height), FH), Image.LANCZOS) for i in imgs]
    ordered.append((key, items, imgs))
width = max(sum(i.width for i in imgs) + PAD * (len(imgs) + 1) for _, _, imgs in ordered)
height = TITLE + 60 + sum(FH + LABEL + PAD * 2 + 26 for _ in ordered)
sheet = Image.new('RGB', (width, height), (18, 16, 26))
d = ImageDraw.Draw(sheet)
d.text((PAD, 12), 'R151 pull reveals: the suspense, the reveal and the seed, Common to King (desktop 1280x720; Secret / Cosmic / King also phone 844x390)', font=font(22), fill=(240, 236, 255))
d.text((PAD, 44), 'Real scripts on the Roblox mock; world drawn with three.js, GUI with R150 render_gui.mjs. Approximate: plain materials, stand-in pack art and avatar, dot particles, no trails.', font=font(15, False), fill=(170, 166, 196))
y = TITLE + 50
for key, items, imgs in ordered:
    d.text((PAD, y), key.upper(), font=font(20), fill=(255, 220, 140))
    y += 28
    x = PAD
    for m, im in zip(items, imgs):
        d.text((x, y), m['label'], font=font(13), fill=(214, 210, 236))
        sheet.paste(im, (x, y + LABEL))
        x += im.width + PAD
    y += FH + LABEL + PAD * 2
sheet = sheet.crop((0, 0, width, y))
sheet.save(OUT, optimize=True)
print('sheet', sheet.size, '->', OUT)
