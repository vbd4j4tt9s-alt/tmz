"""Compose docs/proposals/R149/zfight.png from render_zfight.mjs's view<i>_before/after.png and views.json.
Usage: python3 make_zfight_sheet.py <render dir> <views.json> <out.png>"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

src, views_path, out = sys.argv[1:4]
views = json.load(open(views_path))['views']
TW, TH = 640, 360
PAD, HEAD, LAB = 14, 92, 34


def font(size, bold=False):
    for name in (['DejaVuSans-Bold.ttf'] if bold else []) + ['DejaVuSans.ttf']:
        for d in ('/usr/share/fonts/truetype/dejavu', '/usr/share/fonts/dejavu', '/usr/share/fonts'):
            p = os.path.join(d, name)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


W = PAD * 3 + TW * 2
H = HEAD + len(views) * (LAB + TH + PAD) + 40
sheet = Image.new('RGB', (W, H), (24, 28, 36))
d = ImageDraw.Draw(sheet)
d.text((PAD, 12), 'R149 z-fighting in the shop / market: before (R148) and after', fill=(255, 255, 255), font=font(26, True))
d.text((PAD, 50), 'Magenta = two visible surfaces in (nearly) one plane, flickering; fixed in R149.   Orange = inside a fruit model '
       '(plant art files, routed).', fill=(210, 215, 225), font=font(15))
y = HEAD
for i, v in enumerate(views):
    nb = len(v['before']['polys']); na = len(v['after']['polys'])
    ours_b = sum(1 for p in v['before']['polys'] if p['kind'] == 'ours'); ours_a = sum(1 for p in v['after']['polys'] if p['kind'] == 'ours')
    d.text((PAD, y + 6), '%d. %s' % (i + 1, v['name']), fill=(255, 236, 170), font=font(19, True))
    d.text((PAD + TW + PAD, y + 9), 'flagged near this view: %d -> %d   (fixed by R149: %d -> %d)' % (nb, na, ours_b, ours_a), fill=(200, 205, 215), font=font(15))
    for k, which in enumerate(('before', 'after')):
        im = Image.open(os.path.join(src, 'view%d_%s.png' % (i, which))).convert('RGB').resize((TW, TH), Image.LANCZOS)
        x = PAD + k * (TW + PAD)
        sheet.paste(im, (x, y + LAB))
        tag = 'BEFORE (R148)' if which == 'before' else 'AFTER (R149)'
        tw = d.textlength(tag, font=font(15, True))
        d.rectangle([x + 8, y + LAB + 8, x + 20 + tw, y + LAB + 32], fill=(0, 0, 0))
        d.text((x + 14, y + LAB + 11), tag, fill=(255, 255, 255), font=font(15, True))
    y += LAB + TH + PAD
d.text((PAD, H - 32), 'Approximate three.js render of the real MarketLayout / map builders on the Roblox mock (no Roblox materials or lighting). '
       'Overlays: docs/proposals/R149/tools/zfight.py.', fill=(160, 166, 178), font=font(13))
sheet.save(out, optimize=True)
print('wrote', out, sheet.size)
