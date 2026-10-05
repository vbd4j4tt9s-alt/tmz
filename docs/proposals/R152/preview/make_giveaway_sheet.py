"""R152 preview: composes the sheet docs/proposals/R152/void_giveaway.png from the views render_giveaway.mjs wrote.
Usage: python3 make_giveaway_sheet.py <render dir> <out png>"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

D, OUT = sys.argv[1], sys.argv[2]
W = 1800
BG = (18, 14, 30)
INK = (232, 220, 255)
DIM = (160, 146, 196)


def font(px, bold=True):
    p = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    try:
        return ImageFont.truetype(p, px)
    except Exception:
        return ImageFont.load_default()


def load(name):
    p = os.path.join(D, name + '.png')
    return Image.open(p).convert('RGB') if os.path.exists(p) else None


def fit(img, w, h):
    s = min(w / img.width, h / img.height)
    return img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)


panels = [
    ('wide', [('open_hub_wide', 'The middle of the hub from above: the free Void Pack pedestal stands in the plaza where the fountain was (X 0, Z -392), south of the market and Verity. 13 of 500 claimed.', 1800, 760)]),
    ('row', [('open_plaza', 'A player coming from the market (Verity on the left): the pack hovers over the cradle, the number hangs above it.', 892, 636),
             ('open_close', 'Close-up: "487 / 500 LEFT" with the small title FREE VOID PACK, the pack turning, its violet glow and sparks riding on it.', 892, 636)]),
    ('row', [('open_stone', 'The stone: obsidian footing, dark purple column with the lettering on all four faces, violet studs, four glowing pylons, the cradle with four prongs.', 892, 636),
             ('open_dusk', 'The same at dusk: the violet glow (pedestal studs, cradle, the pack\'s own light and particles).', 892, 636)]),
    ('row', [('empty_close', 'All 500 claimed: "0 / 500 LEFT", the sign says ALL CLAIMED, the lettering says ALL CLAIMED, the prompt is off for ever.', 892, 636),
             ('open_plan', 'Plan (the sign left out): the 16-stud footing in the 21-stud plaza; the benches that stood round the fountain are 17 studs out, the dais of Verity is below.', 892, 636)]),
]
head = 96
rows = []
for kind, items in panels:
    cells = []
    for name, caption, w, h in items:
        img = load(name)
        if img is None:
            img = Image.new('RGB', (w, h), (60, 40, 60))
        cells.append((fit(img, w, h), caption, w, h))
    rows.append(cells)
cap_h = 74
height = head + sum(max(c[3] for c in cells) + cap_h + 8 for cells in rows) + 10
sheet = Image.new('RGB', (W, height), BG)
dr = ImageDraw.Draw(sheet)
dr.text((24, 18), 'R152: FREE VOID PACK pedestal (preview: approximate)', font=font(34), fill=INK)
dr.text((24, 62), 'The owner\'s real hub (place file) with the real start-up builders, the real VoidGiveaway152 server and VoidGiveawayClient152 client on the Roblox mock; plain materials, stand-in pack mesh, no trees / benches.', font=font(16, False), fill=DIM)
y = head
for cells in rows:
    x = 0
    rh = max(c[3] for c in cells)
    for img, caption, w, h in cells:
        sheet.paste(img, (x + (w - img.width) // 2, y))
        # caption, wrapped
        words = caption.split(' ')
        line, ty = '', y + rh + 6
        f = font(15, False)
        for word in words:
            t = (line + ' ' + word).strip()
            if dr.textlength(t, font=f) > w - 24:
                dr.text((x + 12, ty), line, font=f, fill=INK)
                ty += 20
                line = word
            else:
                line = t
        dr.text((x + 12, ty), line, font=f, fill=INK)
        x += w + (W - sum(c[2] for c in cells)) // max(1, len(cells)) if len(cells) > 1 else w
    y += rh + cap_h + 8
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
