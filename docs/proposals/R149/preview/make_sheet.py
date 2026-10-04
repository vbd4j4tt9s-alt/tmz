"""Usage: python3 make_sheet.py <dir with rain.png blizzard.png snowbiome.png tiles.png stats.json> <out.png>
2 x 2 sheet (960 x 540 panels) with a caption on each: the R149 weather preview."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1:3]
stats = json.load(open(os.path.join(src, 'stats.json')))
panels = [
    ('rain', 'Rain: drops fall from the cloud height to the ground; splashes + ripples; none on the track',
     '%d streaks, %d splash dots, %d ripples in view' % (stats['rain']['drops'], stats['rain']['sprays'], stats['rain']['ripples'])),
    ('blizzard', 'Blizzard 35 s in: snow patches faded in, none on the garden beds',
     '%d flakes, %d patch discs' % (stats['blizzard']['flakes'], stats['blizzard']['patches'])),
    ('snowbiome', 'Snow biome: permanent patches above the R148 key tops (edge drifts, border patches, dust)',
     '%d discs; the spacebar zone and the keys under the runner stay clean' % stats['snowbiome']['patches']),
    ('tiles', 'Top view: emitter tiles on the 50-stud world grid, cut back from the track (pink)',
     '%d tiles emitting around the player (yellow); the beds and the grid never move with the camera' % stats['tiles']['tiles']),
]
W, H, BAR = 960, 540, 48
sheet = Image.new('RGB', (W * 2, (H + BAR) * 2), (24, 26, 32))
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
except Exception:
    font = ImageFont.load_default()
d = ImageDraw.Draw(sheet)
for i, (name, caption, sub) in enumerate(panels):
    x, y = (i % 2) * W, (i // 2) * (H + BAR)
    im = Image.open(os.path.join(src, name + '.png')).convert('RGB').resize((W, H), Image.LANCZOS)
    sheet.paste(im, (x, y + BAR))
    d.text((x + 12, y + 6), caption, fill=(238, 241, 246), font=font)
    d.text((x + 12, y + 26), sub, fill=(160, 170, 186), font=font)
sheet.save(out, optimize=True)
print('wrote', out, sheet.size)
