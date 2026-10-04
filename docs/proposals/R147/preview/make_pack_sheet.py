"""Usage: python3 make_pack_sheet.py <dir with the rendered scene PNGs> <out dir>
Composes verity_pack.png: the Void pack (left) and the Verity pack (right), front and three-quarter views, from render_pack.mjs's output.
Approximate renders (three.js) of the real parts, not Roblox screenshots: the pouch body is a stand-in and the particles / light are not drawn."""
import sys
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
BG = (23, 27, 40)

def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()

def load(name):
    return Image.open('%s/%s.png' % (src, name)).convert('RGB')

def panel(name, size):
    img = load(name)
    w = size
    return img.resize((w, int(img.height * w / img.width)), Image.LANCZOS)

W = 340
cols = [('void', 'Void pack', ['black-violet body, galaxy, crimson eye,', 'purple halo (unchanged)'], (214, 190, 255)),
        ('verity', 'Verity pack', ["Verity's face on a square card, both sides", 'your Verity picture (rbxassetid://102712963740896) goes here', '(a gold smiley is drawn as a stand-in) + gold sparkles'], (255, 230, 150)),
        ('verity_gold', 'Gold Verity pack', ['same card: picture tinted warm,', 'a thin gold rim (a Gold coat)'], (255, 205, 80))]
rows = [('front', 'front'), ('angle', 'three-quarter')]
tiles = {(c[0], r[0]): panel('%s_%s' % (c[0], r[0]), W) for c in cols for r in rows}
h = tiles[('void', 'front')].height
gap, top, cap = 10, 74, 118
sheet = Image.new('RGB', (len(cols) * W + (len(cols) + 1) * gap, top + len(rows) * (h + gap) + cap + gap), (10, 12, 20))
d = ImageDraw.Draw(sheet)
d.text((sheet.width // 2, 12), 'Void pack vs Verity pack (the Verity pack is just her face)', font=font(28), fill=(255, 255, 255), anchor='ma')
d.text((sheet.width // 2, 46), 'three.js preview of the real parts; the picture and the particles are stand-ins', font=font(16, False), fill=(190, 198, 215), anchor='ma')
for ci, (key, title, lines, colour) in enumerate(cols):
    x = gap + ci * (W + gap)
    for ri, (view, _) in enumerate(rows):
        sheet.paste(tiles[(key, view)], (x, top + ri * (h + gap)))
    y = top + len(rows) * (h + gap)
    d.text((x + W // 2, y + 2), title, font=font(26), fill=colour, anchor='ma')
    for li, line in enumerate(lines):
        d.text((x + W // 2, y + 38 + li * 22), line, font=font(14, False), fill=(205, 212, 225), anchor='ma')
sheet.save(out + '/verity_pack.png')
print('wrote verity_pack.png', sheet.size)
