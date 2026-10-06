"""R153 garden fronts: composes render_base_area.mjs output (before_<view>.png / after_<view>.png) into docs/proposals/R153/garden_front.png.
Usage: python3 make_garden_front.py <render out dir> <garden_views.json> <docs/proposals/R153 dir>"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT, VIEWS, DOCS = sys.argv[1:4]
V = {v['name']: v for v in json.load(open(VIEWS))['views']}
BG, INK, SUB = (27, 29, 35), (238, 240, 245), (170, 176, 190)
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
T1, T2, T3 = (ImageFont.truetype(F % '-Bold', 28), ImageFont.truetype(F % '', 18), ImageFont.truetype(F % '-Bold', 16))
BEFORE, AFTER = (150, 60, 60), (40, 140, 90)
TITLE = 'Garden fronts: the welcome mat and the base-coloured curbs are gone'
SUBT = ('The owner asked to remove the ground design for the side gardens. BEFORE (R152): a base-coloured welcome-mat disc on every side spur and a '
        'base-coloured curb along both sides of every spur. AFTER (R153): plain cobblestone spurs; the cream street curbs run flush to each spur.')


def wrap(d, text, width, f):
    lines, cur = [], ''
    for w in text.split():
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur); cur = w
    return lines + [cur] if cur else lines


gap, W, cw, ch = 14, 1294, 640, 360
dd = ImageDraw.Draw(Image.new('RGB', (W, 10)))
cap = wrap(dd, SUBT, W - 2 * gap, T2)
names = ['top3', 'top5', 'obl3']
H = 58 + 24 * len(cap) + 8 + len(names) * (ch + 24 + gap)
im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
d.text((gap, 12), TITLE, font=T1, fill=INK)
y = 52
for line in cap:
    d.text((gap, y), line, font=T2, fill=SUB); y += 24
y += 8
for n in names:
    d.text((gap, y), V[n]['caption'], font=T2, fill=SUB); y += 24
    for i, (label, pre, colour) in enumerate((('BEFORE (R152)', 'before', BEFORE), ('AFTER (R153)', 'after', AFTER))):
        x = gap + i * (cw + gap)
        im.paste(Image.open(os.path.join(OUT, '%s_%s.png' % (pre, n))).convert('RGB').resize((cw, ch), Image.LANCZOS), (x, y))
        w = d.textlength(label, font=T3)
        d.rectangle([x + 8, y + 8, x + 8 + w + 12, y + 36], fill=colour); d.text((x + 14, y + 11), label, font=T3, fill=INK)
    y += ch + gap
im.save(os.path.join(DOCS, 'garden_front.png'), optimize=True)
print('wrote garden_front.png', im.size)
