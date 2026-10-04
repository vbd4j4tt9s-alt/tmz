"""Usage: python3 make_sheet.py <dir with the rendered scene PNGs> <out dir>
Composes verity_plant.png (seed, 33%, 66%, 100%), verity_growth.png (eight growth stages) and verity_coats.png (plain / Gold /
Diamond seed and plant) from render_verity.mjs's output. Approximate renders (three.js), not Roblox screenshots."""
import sys
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
BG = (23, 40, 33)
def font(size, bold=True):
    for name in ('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf',):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()

def load(name):
    return Image.open('%s/%s.png' % (src, name)).convert('RGB')

def panel(name, caption, sub, size):
    img = load(name)
    w, h = size
    img = img.resize((w, int(img.height * w / img.width)), Image.LANCZOS)
    cap = 74
    tile = Image.new('RGB', (w, max(h, img.height) + cap), BG)
    tile.paste(img, (0, 0))
    d = ImageDraw.Draw(tile)
    d.text((w // 2, img.height + 8), caption, font=font(26), fill=(255, 236, 161), anchor='ma')
    d.text((w // 2, img.height + 42), sub, font=font(18, False), fill=(205, 222, 210), anchor='ma')
    return tile

NOTE = ('STAND-IN smiley: two oval eyes + a wide smile drawn here. The game puts Verity\'s own picture (rbxassetid://102712963740896) '
        'on the ball as a Decal, front and back, unaltered.')

def sheet(tiles, gap=10, title=None):
    top = 64 if title else 0
    foot = 40
    W = sum(t.width for t in tiles) + gap * (len(tiles) + 1)
    H = max(t.height for t in tiles) + gap * 2 + top + foot
    s = Image.new('RGB', (W, H), (10, 20, 15))
    d = ImageDraw.Draw(s)
    if title:
        d.text((W // 2, 18), title, font=font(30), fill=(255, 255, 255), anchor='ma')
    d.text((W // 2, H - foot + 8), NOTE, font=font(16, False), fill=(255, 214, 120), anchor='ma')
    x = gap
    for t in tiles:
        s.paste(t, (x, top + gap))
        x += t.width + gap
    return s

# The seed shot is a close-up (the seed is 1.3 studs; the plant frames are 84 studs away).
main = [panel('seed_None', 'Verity seed', 'a small yellow ball with her face, 1.3 studs', (450, 675)),
        panel('plant_033', 'Growing: 33%', 'ball 6.6 studs, leaves 77%', (450, 675)),
        panel('plant_066', 'Growing: 66%', 'ball 16.4 studs', (450, 675)),
        panel('plant_100', 'Fully grown: 100%', 'ball 22 studs, leaves at its bottom', (450, 675))]
sheet(main, title='Verity: the seed is a small Verity ball; it grows into a giant one (three.js preview of the real parts)').save(out + '/verity_plant.png')

stages = [('plant_000', '0%', 'ball 1.3'), ('plant_010', '10%', 'ball 1.9'), ('plant_020', '20%', 'ball 3.4'), ('plant_033', '33%', 'ball 6.6'),
          ('plant_045', '45%', 'ball 10.1'), ('plant_066', '66%', 'ball 16.4'), ('plant_085', '85%', 'ball 20.7'), ('plant_100', '100%', 'ball 22')]
sheet([panel(n, c, s, (300, 450)) for n, c, s in stages], gap=6, title='Verity growth stages (same camera)').save(out + '/verity_growth.png')

coats = [panel('seed_None', 'Seed', 'plain', (300, 450)), panel('seed_Gold', 'Seed', 'Gold', (300, 450)), panel('seed_Diamond', 'Seed', 'Diamond', (300, 450))]
plants = [panel('plant_100', 'Plant', 'plain', (300, 450)), panel('plant_Gold', 'Plant', 'Gold', (300, 450)), panel('plant_Diamond', 'Plant', 'Diamond', (300, 450))]
sheet(coats + plants, gap=6, title='Verity coats').save(out + '/verity_coats.png')
print('wrote verity_plant.png, verity_growth.png, verity_coats.png')
