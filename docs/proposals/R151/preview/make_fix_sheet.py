"""Usage: python3 make_fix_sheet.py <render dir> <out dir> [before revision]
Puts the R151 views of the keyboard preview (docs/proposals/R149/preview/run_keyboard_preview.sh <scratch> <before> r151) side by side, before (the
build the owner played, with the REAL Top-face SurfaceGui layout: only one label per strip is inside its canvas, letters a quarter turn off, the
spacebar name along the track) and after (R151), and writes <out dir>/keyboard_fix.png. Needs Pillow."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
before_rev = sys.argv[3] if len(sys.argv) > 3 else 'R150'
os.makedirs(out, exist_ok=True)


def font(size):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


VIEWS = [
    ('letters', 'Letters on every key: a runner reads QWERTYUIOP / ASDFGHJKL / ZXCVBNM left to right (R150 showed one column, sideways)'),
    ('dent', 'The press: 1.15 studs deep (was .47). His soles are level with the pressed key; the keys around him stand 1.2 above'),
    ('bar', 'The Forest spacebar from the safe zone: the name runs across the track, parallel to the SAFE ZONE line (R150: along it)'),
]
W, H = 640, 360
pad, top, cap = 14, 56, 40
rows = [v for v in VIEWS if os.path.exists(os.path.join(src, 'before_%s.png' % v[0])) and os.path.exists(os.path.join(src, 'after_%s.png' % v[0]))]
sheet = Image.new('RGB', (W * 2 + pad * 3, top + len(rows) * (H + cap + pad) + pad), (24, 26, 32))
d = ImageDraw.Draw(sheet)
d.text((pad, 10), 'R150 build (%s), as the owner played it' % before_rev, fill=(235, 235, 235), font=font(20))
d.text((pad * 2 + W, 10), 'R151', fill=(235, 235, 235), font=font(20))
d.text((pad, 34), "three.js stand-in for the keycap mesh, plain lighting: a layout preview of the real scripts' output, not a screenshot",
       fill=(150, 156, 168), font=font(13))
y = top
for name, caption in rows:
    d.text((pad, y + 4), caption, fill=(190, 196, 208), font=font(14))
    a = Image.open(os.path.join(src, 'before_%s.png' % name)).convert('RGB').resize((W, H), Image.LANCZOS)
    b = Image.open(os.path.join(src, 'after_%s.png' % name)).convert('RGB').resize((W, H), Image.LANCZOS)
    sheet.paste(a, (pad, y + cap))
    sheet.paste(b, (pad * 2 + W, y + cap))
    y += H + cap + pad
sheet.save(os.path.join(out, 'keyboard_fix.png'))
print('wrote', os.path.join(out, 'keyboard_fix.png'), sheet.size)
