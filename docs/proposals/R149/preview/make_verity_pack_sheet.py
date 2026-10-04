"""Usage: python3 make_verity_pack_sheet.py <dir with the rendered scene PNGs (before_*.png, after_*.png)> <out png>
Composes verity_pack.png: the Verity pack BEFORE (R148, as it is live) and AFTER (R149), and AFTER in a Gold coat, each in a front, side, back
and in-hand view and as a hotbar-sized picture, from render_verity_pack.mjs's output. Approximate renders (three.js) of the real parts built by
the real modules on the Roblox mock, not Roblox screenshots: the Verity picture is a STAND-IN smiley (the image cannot be downloaded here) and the
approved pouch mesh is not available offline (BEFORE draws it as a rounded pouch with a SIMULATED vertex-colour print)."""
import sys
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
BG = (16, 19, 30)

def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()

def load(name):
    return Image.open('%s/%s.png' % (src, name)).convert('RGB')

TW, TH = 270, 324
LABEL = 365
views = [('front', 'front'), ('side', 'side: is anything standing off the pack?'), ('back', 'back'), ('hand', 'in hand, seen from above'), ('hotbar', 'hotbar slot, 72 px (and x3)')]
rows = [('before', 'verity', 'BEFORE (R148, live)', (255, 120, 100),
         ['the approved pouch (one MeshPart) painted', 'yellow: its print is in vertex colours, which', 'Color only multiplies - yellow x navy = a black', 'panel, x orange = brown sticks; two plates with', 'the face stand off the curved pouch; gold fx']),
        ('after', 'verity', 'AFTER (R149)', (255, 240, 90),
         ['plain parts, every one 255,255,0 SmoothPlastic', '(seal and tear strips too); the face is a Decal on', 'the face block\'s own Front and Back: no plate,', 'no step from the side, nothing in front of it;', 'no sparkles, no glow, no light']),
        ('after', 'verity_gold', 'AFTER, Gold coat', (255, 205, 80),
         ['a Gold / Diamond coat (mutation) paints every', 'part like any pack (Gold metal; Diamond glass at', '.10 transparency); the face Decals stay on top', '(white, untinted)'])]
gap, top = 8, 120
sheet = Image.new('RGB', (LABEL + len(views) * (TW + gap) + gap, top + len(rows) * (TH + 44 + gap) + 46), BG)
d = ImageDraw.Draw(sheet)
d.text((sheet.width // 2, 12), 'Verity pack: pure yellow with her face, before and after', font=font(30), fill=(255, 255, 255), anchor='ma')
d.text((sheet.width // 2, 52), 'three.js preview of the parts the real modules build on the Roblox mock. The face is a STAND-IN smiley (the Roblox image cannot be downloaded here); the', font=font(15, False), fill=(190, 198, 215), anchor='ma')
d.text((sheet.width // 2, 72), 'approved pouch mesh is not available offline, so BEFORE draws it as a rounded pouch with a SIMULATED vertex-colour print (pale crimps, navy panel, orange', font=font(15, False), fill=(190, 198, 215), anchor='ma')
d.text((sheet.width // 2, 92), 'sticks) multiplied by the part colour, which reproduces the black panel in the live screenshots. Particles / light of the old art are not drawn.', font=font(15, False), fill=(190, 198, 215), anchor='ma')
for ri, (pre, key, title, colour, lines) in enumerate(rows):
    y = top + ri * (TH + 44 + gap)
    d.text((14, y + 4), title, font=font(22), fill=colour)
    for li, line in enumerate(lines):
        d.text((14, y + 40 + li * 20), line, font=font(12, False), fill=(205, 212, 225))
    for ci, (view, caption) in enumerate(views):
        x = LABEL + gap + ci * (TW + gap)
        img = load('%s_%s_%s' % (pre, key, view))
        if view == 'hotbar':
            tile = Image.new('RGB', (TW, TH), (37, 43, 68))
            big = img.resize((216, 216), Image.NEAREST)
            tile.paste(big, ((TW - 216) // 2, 16))
            tile.paste(img, ((TW - 72) // 2, 16 + 216 + 14))
        else:
            tile = img.resize((TW, TH), Image.LANCZOS)
        sheet.paste(tile, (x, y))
        d.text((x + TW // 2, y + TH + 6), caption if ri == 0 else '', font=font(14, False), fill=(190, 198, 215), anchor='ma')
d.text((LABEL + gap, sheet.height - 32), 'Same camera in every row. Side view: the face is the pack\'s own surface, flush from the side - no floating panel.', font=font(15), fill=(255, 240, 90))
sheet.save(out)
print('wrote', out, sheet.size)
