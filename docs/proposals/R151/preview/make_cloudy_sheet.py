"""R151 Cloudy sky: put the Clear / Cloudy renders on one sheet (docs/proposals/R151/cloudy.png).
Usage: python3 make_cloudy_sheet.py <render dir> <views.json> <out.png> <clear scene.json> <cloudy scene.json>
<render dir> holds clear_<view>.png / cloudy_<view>.png from render_cloudy.mjs; the two scene files (the "SCENE" lines of cloudy_scene.luau) carry the REAL palette
numbers ("look") and the lights, which the captions quote. The pictures are approximate (three.js: no Roblox lighting model, bloom or colour grade)."""
import json, sys
from PIL import Image, ImageDraw, ImageFont

src, views_file, out, clear_file, cloudy_file = sys.argv[1:6]
views = json.load(open(views_file))['views']
look = {}
lights = {}
for name, f in (('clear', clear_file), ('cloudy', cloudy_file)):
    scene = json.load(open(f))
    look[name] = scene['look']
    lights[name] = [l for l in scene.get('lights', []) if not l.get('off')]
W, H = 760, 428
pad, head, cap = 18, 74, 52


def font(size, bold=False):
    for name in (['DejaVuSans-Bold.ttf'] if bold else ['DejaVuSans.ttf']):
        try:
            return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/' + name, size)
        except OSError:
            pass
    return ImageFont.load_default()


F_TITLE, F_HEAD, F_CAP, F_SMALL = font(24, True), font(22, True), font(16), font(14)
sheet_w = pad * 3 + W * 2
sheet_h = head + 40 + len(views) * (H + cap + pad) + 150
sheet = Image.new('RGB', (sheet_w, sheet_h), (28, 32, 40))
d = ImageDraw.Draw(sheet)
d.text((pad, 14), 'R151 default sky: Clear <-> Cloudy. Cloudy only dims the light, so the lamps and lanterns glow warm', font=F_TITLE, fill=(240, 244, 250))
d.text((pad, 46), 'The Cloudy hub below is the real sky state, the real lamp / lantern code and the real palette numbers; the pictures are an approximate three.js render.', font=F_CAP, fill=(170, 180, 196))


def rgb(c):
    return 'rgb(%d, %d, %d)' % tuple(c)


y = head
for i, (label, colr) in enumerate((('CLEAR (the default sky, as before)', (255, 214, 120)), ('CLOUDY (the new other half; desktop tier)', (140, 200, 255)))):
    d.text((pad + i * (W + pad), y), label, font=F_HEAD, fill=colr)
y += 40
for v in views:
    for i, which in enumerate(['clear', 'cloudy']):
        try:
            img = Image.open('%s/%s_%s.png' % (src, which, v['name'])).convert('RGB').resize((W, H), Image.LANCZOS)
        except OSError:
            img = Image.new('RGB', (W, H), (60, 60, 60))
        x = pad + i * (W + pad)
        sheet.paste(img, (x, y))
        d.text((x, y + H + 6), v['title'] if i == 0 else '', font=F_SMALL, fill=(220, 226, 236))
        lamps = len(lights['cloudy']) - len(lights['clear'])
        line = ('lamp lights on: 0 of 8, heads and lanterns in their own colour' if which == 'clear'
                else 'lamp lights on: %d of 8 (phones 4, FastMode 0), heads and lanterns warm, market lights stronger' % lamps)
        d.text((x, y + H + 26), line, font=F_SMALL, fill=(170, 180, 196))
    y += H + cap + pad
# the numbers
c, k = look['clear'], look['cloudy']
rows = [
    ('Lighting.Brightness', '%.2f' % c['brightness'], '%.2f' % k['brightness']),
    ('ExposureCompensation', '%.3f' % c['exposure'], '%.3f' % k['exposure']),
    ('Ambient / OutdoorAmbient', '%s / %s' % (rgb(c['ambient']), rgb(c['outdoor'])), '%s / %s' % (rgb(k['ambient']), rgb(k['outdoor']))),
    ('Atmosphere colour / density / haze', '%s / %.2f / %.2f' % (rgb(c['air']), c['density'], c['haze']), '%s / %.2f / %.2f' % (rgb(k['air']), k['density'], k['haze'])),
    ('Terrain clouds cover / colour', '%.2f / %s' % (c['cover'], rgb(c['cloud'])), '%.2f / %s' % (k['cover'], rgb(k['cloud']))),
]
x0 = pad
d.text((x0, y + 4), 'The base\'s Lighting values (BiomeMood.Palette, stage 0)', font=F_CAP, fill=(240, 244, 250))
for j, (a, b, e) in enumerate(rows):
    yy = y + 30 + j * 20
    d.text((x0, yy), a, font=F_SMALL, fill=(170, 180, 196))
    d.text((x0 + 320, yy), 'Clear  ' + b, font=F_SMALL, fill=(255, 224, 150))
    d.text((x0 + 780, yy), 'Cloudy  ' + e, font=F_SMALL, fill=(170, 210, 255))
sheet.save(out)
print('wrote', out, sheet.size)
