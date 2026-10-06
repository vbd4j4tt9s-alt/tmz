"""R153 trampoline preview: compose render_base_area.mjs output (before_<view>.png / after_<view>.png) into docs/proposals/R153/trampoline.png.
Usage: python3 make_trampoline_sheet.py <render out dir> <trampoline_views.json> <docs/proposals/R153 dir>
  rows: the Lava garden nook from above (BEFORE R152 | AFTER), the nook from the garden walk (before | after), the trampoline up close and a bounce (after)."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT, VIEWS, DOCS = sys.argv[1:4]
V = {v['name']: v for v in json.load(open(VIEWS))['views']}
BG, INK, SUB = (27, 29, 35), (238, 240, 245), (170, 176, 190)
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'


def font(n, bold=False):
    return ImageFont.truetype(F % ('-Bold' if bold else ''), n)


T1, T2, T3 = font(28, True), font(18), font(16, True)
BEFORE, AFTER = (150, 60, 60), (40, 140, 90)


def wrap(d, text, width, f):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur:
        lines.append(cur)
    return lines


def tag(d, xy, text, fill):
    x, y = xy; w = d.textlength(text, font=T3)
    d.rectangle([x, y, x + w + 12, y + 28], fill=fill); d.text((x + 6, y + 3), text, font=T3, fill=INK)


def sheet(path, title, captions, rows):
    gap, W = 14, 1294
    dd = ImageDraw.Draw(Image.new('RGB', (W, 10)))
    caps = [wrap(dd, c, W - 2 * gap, T2) for c in captions]
    H = 58 + sum(24 * len(c) + 6 for c in caps) + 8
    for r in rows:
        H += (720 if len(r) == 1 else 360) + gap
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    d.text((gap, 12), title, font=T1, fill=INK)
    y = 52
    for c in caps:
        for line in c:
            d.text((gap, y), line, font=T2, fill=SUB); y += 24
        y += 6
    y += 8
    for r in rows:
        w, h = (1280, 720) if len(r) == 1 else (640, 360)
        for i, (label, png, colour) in enumerate(r):
            x = gap + i * (w + gap)
            p = os.path.join(OUT, png)
            if os.path.exists(p):
                im.paste(Image.open(p).convert('RGB').resize((w, h), Image.LANCZOS), (x, y))
            else:
                d.rectangle([x, y, x + w, y + h], outline=SUB); d.text((x + 20, y + 20), 'missing ' + png, font=T2, fill=SUB)
            tag(d, (x + 8, y + 8), label, colour)
        y += h + gap
    im.save(path, optimize=True)
    print('wrote', path, im.size)


def pair(view):
    return [('BEFORE (R152)', 'before_%s.png' % view, BEFORE), ('AFTER (R153)', 'after_%s.png' % view, AFTER)]


sheet(os.path.join(DOCS, 'trampoline.png'), 'R153: the garden nooks\' benches become a trampoline',
      [V['nook_top']['caption'], V['nook']['caption'], V['closeup']['caption'] + ' ' + V['bounce']['caption'],
       'Preview by R151\'s three.js renderer on the real built hub (an approximation: no Roblox lighting, materials or bloom). The same pair stands in the Desert nook at x = +312.'],
      [pair('nook_top'), pair('nook'), [('AFTER (R153): up close', 'after_closeup.png', AFTER), ('AFTER (R153): a bounce', 'after_bounce.png', AFTER)]])
