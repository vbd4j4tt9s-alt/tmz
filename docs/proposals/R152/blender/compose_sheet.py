"""Usage: python3 compose_sheet.py <cells dir (verity_pack.py's before_/after_ front, side, profile, held PNGs)> <out png>

Puts the eight renders of verity_pack.py on one labelled sheet: BEFORE (R151, a stand-in) over AFTER (R152, the mesh the game bakes), four views each."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

cells, out = sys.argv[1], sys.argv[2]
VIEWS = [('front', 'FRONT', 'flat faces carry the face'),
         ('side', "OWNER'S SIDE ANGLE", 'about 62 degrees round'),
         ('profile', 'PROFILE', 'straight from the side'),
         ('held', 'HELD', 'the carry layout, a blocky R15 stand-in')]
ROWS = [('before', 'BEFORE', 'R151: the standard pouch copied and painted yellow', (255, 128, 112),
         ['STAND-IN (the real mesh is an uploaded asset,', 'not available offline): the repo\'s chip-bag', 'stand-in, a puffy 1.0 deep belly, plus the', 'embossed relief the owner described: rings in', 'the corners, a frame along the edges, bars.', 'The face bends round the curve.']),
        ('after', 'AFTER', 'R152: a clean flat pouch, generated at run time', (255, 235, 90),
         ['The REAL mesh VerityPouch151 bakes (3,546', 'vertices, 7,088 triangles), dumped to OBJ.', 'Front and back are two exact planes, no relief,', 'rounded long edges, a crimped seal at each end,', 'the seal and strips a little darker yellow.', 'The face is crisp on both sides.'])]
BG = (17, 20, 32)
CELL = 640
LEFT, TOP, GAP = 470, 150, 14


def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


W = LEFT + 4 * CELL + 3 * GAP + 20
H = TOP + 2 * CELL + GAP + 150
sheet = Image.new('RGB', (W, H), BG)
d = ImageDraw.Draw(sheet)
d.text((20, 18), 'Verity pack: a clean flat pouch, before and after', font=font(40), fill=(255, 255, 255))
d.text((20, 70), 'The pack is the yellow pouch, its seal and strips, and Verity\'s face as two Decals (Front and Back). Nothing else: no relief, no leftover design.', font=font(21, False), fill=(190, 198, 215))
for ci, (key, title, sub) in enumerate(VIEWS):
    x = LEFT + ci * (CELL + GAP)
    d.text((x + 6, TOP - 52), title, font=font(26), fill=(255, 255, 255))
    d.text((x + 6, TOP - 22), sub, font=font(17, False), fill=(160, 170, 190))
for ri, (row, label, sub, color, notes) in enumerate(ROWS):
    y = TOP + ri * (CELL + GAP)
    d.text((20, y + 12), label, font=font(40), fill=color)
    d.text((20, y + 64), sub, font=font(17, False), fill=(205, 212, 228))
    for k, line in enumerate(notes):
        d.text((20, y + 112 + k * 24), line, font=font(16, False), fill=(150, 160, 182))
    for ci, (key, _, _) in enumerate(VIEWS):
        im = Image.open(os.path.join(cells, '%s_%s.png' % (row, key))).convert('RGB').resize((CELL, CELL), Image.LANCZOS)
        sheet.paste(im, (LEFT + ci * (CELL + GAP), y))
y = TOP + 2 * CELL + GAP + 18
for k, line in enumerate([
        'Same camera, lights and picture in both rows. The picture is a drawn smiley (the real one, rbxassetid://102712963740896, cannot be downloaded here), projected along the face over the whole',
        'Front / Back of the pouch exactly like a Roblox Decal on a MeshPart: a curved surface bends it (before), a flat one keeps it crisp (after).',
        'Held: the flat pouch is 0.56 of the standard pouch\'s depth (width, height, frame and pivot are the standard pouch\'s), so its near face sits about 0.22 studs further from the hands than a standard pack\'s.',
        'Rendered with Blender 4.5 (Cycles, CPU). Regenerate: docs/proposals/R152/tools/dump_verity_pouch.py, then blender/verity_pack.py, then blender/compose_sheet.py (see verity_pack.md).']):
    d.text((20, y + k * 28), line, font=font(17, False), fill=(175, 184, 205))
sheet.save(out)
print('sheet ->', out, sheet.size)
