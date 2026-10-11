"""R152: docs/proposals/R152/keepers_roundtrip.png - every keeper's approved R151 three-quarter panel beside the same view rendered
from the game's decoded mesh data (render_roundtrip.py). Plain Python 3 + Pillow.
Usage: python3 compose_roundtrip.py RENDER_DIR OUT_PNG
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SHEETS = os.path.abspath(os.path.join(HERE, '..', '..', 'R151', 'keepers'))
REN, OUT = sys.argv[1], sys.argv[2]
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
INK, MUTED, PAPER = (28, 32, 40), (92, 98, 112), (247, 248, 250)
ROWS = [('Stage1', 'timber_golem', 'Timber Golem'), ('Stage6', 'jungle_king', 'Jungle King'), ('Stage2', 'sand_snake', 'Sand Snake'),
        ('Stage3', 'ice_fang', 'Ice Fang'), ('Stage4', 'lava_dragon', 'Lava Dragon'), ('Stage5', 'crystal_knight', 'Crystal Knight'),
        ('Stage7', 'storm_colossus', 'Storm Colossus'), ('Darkened', 'the_darkened', 'The Darkened')]
PW, PH, GAP, COLS = 480, 360, 12, 2
CELL_W, CELL_H = 2 * PW + GAP, PH + 44
W = COLS * CELL_W + (COLS + 1) * 24
HEAD = 144
H = HEAD + (len(ROWS) // COLS) * (CELL_H + 18) + 20


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def tag(d, xy, text):
    f = font(15, True)
    bb = d.textbbox(xy, text, font=f)
    d.rounded_rectangle((bb[0] - 7, bb[1] - 5, bb[2] + 7, bb[3] + 5), 6, fill=(255, 255, 255))
    d.text(xy, text, font=f, fill=INK)


img = Image.new('RGB', (W, H), PAPER)
d = ImageDraw.Draw(img)
d.text((24, 16), 'R152 keepers: approved model vs what the game builds', font=font(32, True), fill=INK)
d.text((24, 60), 'Left: the approved R151 rev 6 sheet (three-quarter view, studs on). Right: the same view rendered from the mesh data the game decodes '
       'and bakes', font=font(17), fill=MUTED)
d.text((24, 84), '(KeeperMeshData152 -> KeeperMeshes152.Decode on the mock), with the game\'s colour formula and no stud texture. Same pose frame, camera, '
       'light and ground.', font=font(17), fill=MUTED)
d.text((24, 108), 'The flames on the dragon\'s back, the lightning under the colossus\'s cloud and the Darkened\'s wisps on the left are effects (particles in game), not meshes.', font=font(17), fill=MUTED)
for i, (key, sheet, name) in enumerate(ROWS):
    x = 24 + (i % COLS) * (CELL_W + 24)
    y = HEAD + (i // COLS) * (CELL_H + 18)
    d.text((x, y), name, font=font(20, True), fill=INK)
    approved = Image.open(os.path.join(SHEETS, 'keeper_%s.png' % sheet)).convert('RGB').crop((504, 150, 984, 510))
    img.paste(approved, (x, y + 34))
    tag(d, (x + 12, y + 44), 'Approved (R151)')
    dec = Image.open(os.path.join(REN, 'decoded_%s.png' % key)).convert('RGB').resize((PW, PH), Image.LANCZOS)
    img.paste(dec, (x + PW + GAP, y + 34))
    tag(d, (x + PW + GAP + 12, y + 44), 'Decoded game data')
img.save(OUT, optimize=True)
print('wrote', OUT, img.size)
