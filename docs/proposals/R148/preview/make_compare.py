"""Usage: python3 make_compare.py <reference frame> <our runner's-eye render> <out.png>
Puts the reference game's frame (+1 Speed Keyboard Escape, Candy & Chocolate) beside the R148 runner's-eye preview, same width."""
import sys
from PIL import Image, ImageDraw, ImageFont

ref, ours, out = sys.argv[1:4]
def font(size):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf', size)
    except OSError:
        return ImageFont.load_default()
a, b = Image.open(ref).convert('RGB'), Image.open(ours).convert('RGB')
h = 640
a = a.resize((int(a.width * h / a.height), h), Image.LANCZOS)
b = b.resize((int(b.width * h / b.height), h), Image.LANCZOS)
gap, cap = 12, 54
sheet = Image.new('RGB', (a.width + b.width + gap * 3, h + cap + gap), (12, 12, 16))
sheet.paste(a, (gap, cap)); sheet.paste(b, (a.width + gap * 2, cap))
d = ImageDraw.Draw(sheet)
d.text((gap + a.width // 2, 14), 'reference game', font=font(26), fill=(255, 236, 161), anchor='ma')
d.text((a.width + gap * 2 + b.width // 2, 14), 'R148 (three.js preview of the real script output)', font=font(26), fill=(255, 236, 161), anchor='ma')
sheet.save(out)
