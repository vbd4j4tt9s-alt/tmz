"""Usage: python3 make_keyboard_sheet.py <render dir> <out dir>
Puts each view's R148 ("before") and R149 ("after") render side by side with a caption: keyboard_compare_<view>.png, and copies the R149
renders as keyboard_<view>.png. Needs Pillow."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
def font(size):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',):
        if os.path.exists(f): return ImageFont.truetype(f, size)
    return ImageFont.load_default()
CAP = {'runner': 'runner view, Desert spacebar 60 studs ahead', 'overview': 'high view (the owner\'s screenshot angle)',
       'closeup': 'close to the keys', 'long': 'long view: Snow -> Lava, ~1000 studs of track', 'crystal': 'Crystal'}
for view in ('runner', 'overview', 'closeup', 'long', 'crystal'):
    a, b = os.path.join(src, 'before_%s.png' % view), os.path.join(src, 'after_%s.png' % view)
    if not (os.path.exists(a) and os.path.exists(b)): continue
    A, B = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
    w, h = A.size; scale = .5
    A2, B2 = A.resize((int(w * scale), int(h * scale)), Image.LANCZOS), B.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    pad, top = 12, 54
    sheet = Image.new('RGB', (A2.width * 2 + pad * 3, A2.height + top + pad), (24, 26, 32))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), 'R148 (live now)', fill=(235, 235, 235), font=font(20))
    d.text((pad * 2 + A2.width, 8), 'R149', fill=(235, 235, 235), font=font(20))
    d.text((pad, 32), CAP[view], fill=(170, 175, 185), font=font(14))
    sheet.paste(A2, (pad, top)); sheet.paste(B2, (pad * 2 + A2.width, top))
    sheet.save(os.path.join(out, 'keyboard_compare_%s.png' % view))
    B.save(os.path.join(out, 'keyboard_%s.png' % view))
    print('wrote keyboard_compare_%s.png' % view)
