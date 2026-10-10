"""R151 hub snow: put the before / after renders on one sheet (docs/proposals/R151/snow_hub.png).
Usage: python3 make_snow_hub_sheet.py <render dir> <views.json> <out.png> [stats.txt]
<render dir> holds old_<view>.png / new_<view>.png from render_base_area.mjs (old = the R150 weather scripts on this checkout's hub, new = this
checkout); views.json gives the titles; stats.txt (optional) is one line per scene: "<old|new> <view> <parts> <coverage %> <zones>"."""
import json, sys
from PIL import Image, ImageDraw, ImageFont

src, views_file, out = sys.argv[1], sys.argv[2], sys.argv[3]
stats = {}
if len(sys.argv) > 4:
    for line in open(sys.argv[4]):
        p = line.split()
        if len(p) >= 5:
            stats[(p[0], p[1])] = (p[2], p[3], p[4])
views = json.load(open(views_file))['views']
W, H = 760, 428
pad, head, cap = 18, 70, 64
def font(size, bold=False):
    for name in (['DejaVuSans-Bold.ttf'] if bold else ['DejaVuSans.ttf']):
        try:
            return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/' + name, size)
        except OSError:
            pass
    return ImageFont.load_default()
F_TITLE, F_HEAD, F_CAP = font(24, True), font(22, True), font(16)
sheet_w = pad * 3 + W * 2
sheet_h = head + 44 + len(views) * (H + cap + pad) + pad + 40
sheet = Image.new('RGB', (sheet_w, sheet_h), (28, 32, 40))
d = ImageDraw.Draw(sheet)
d.text((pad, 16), 'R151 blizzard in the hub: before (R150: snow only near the player) / after (the whole hub, fewer bigger drifts)', font=F_TITLE, fill=(240, 244, 250))
y = head
for i, label in enumerate(['BEFORE (R150)', 'AFTER (R151)']):
    d.text((pad + i * (W + pad), y), label, font=F_HEAD, fill=(255, 214, 120) if i == 0 else (140, 230, 160))
y += 36
for v in views:
    for i, which in enumerate(['old', 'new']):
        try:
            img = Image.open('%s/%s_%s.png' % (src, which, v['name'])).convert('RGB').resize((W, H), Image.LANCZOS)
        except OSError:
            img = Image.new('RGB', (W, H), (60, 60, 60))
        x = pad + i * (W + pad)
        sheet.paste(img, (x, y))
        s = stats.get((which, v['name']))
        line = v['title']
        if s:
            line2 = '%s snow parts drawn, %s%% of the hub floor under snow, snow in %s of 9 zones of the hub' % s
        else:
            line2 = ''
        d.text((x, y + H + 6), line, font=F_CAP, fill=(220, 226, 236))
        d.text((x, y + H + 28), line2, font=F_CAP, fill=(170, 180, 196))
    y += H + cap + pad
d.text((pad, sheet_h - 34), 'Preview render (three.js, no Roblox lighting / materials): the real start-up builders + the R151 festival square on the owner\'s place, the REAL weather client after 40 s of blizzard, tier 3.',
       font=F_CAP, fill=(150, 158, 172))
sheet.save(out)
print('wrote', out, sheet.size)
