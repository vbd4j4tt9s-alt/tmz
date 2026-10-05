"""R151 base area: compose the renders of render_base_area.mjs into docs/proposals/R151/base_area_*.png.
Usage: python3 make_base_area_sheets.py <render out dir> <views.json> <docs/proposals/R151 dir> [counts.txt]
  base_area_today.png     today: the hub plan with the measured layout + three views from player height
  base_area_plan.png      the redesign from above with its zones, today's plan small for comparison
  base_area_<view>.png    TODAY | AFTER (spawn, gate, aerial: TODAY | PHASE 1 | PHASE 1+2) with title and caption
  base_area_lowwall.png   owner option: the dressed 48-stud wall vs a 30-stud wall with a biome skyline beyond"""
import json, os, sys, textwrap
from PIL import Image, ImageDraw, ImageFont

OUT, VIEWS, DOCS = sys.argv[1], sys.argv[2], sys.argv[3]
V = json.load(open(VIEWS))
BG, INK, SUB, ACC = (27, 29, 35), (238, 240, 245), (170, 176, 190), (255, 206, 84)
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
def font(n, bold=False): return ImageFont.truetype(F % ('-Bold' if bold else ''), n)
T1, T2, T3, T4 = font(30, True), font(19), font(17, True), font(15)


def tag(d, xy, text, f=T3, fill=(20, 22, 28), ink=INK, pad=6):
    x, y = xy; w = d.textlength(text, font=f)
    d.rectangle([x, y, x + w + 2 * pad, y + f.size + 2 * pad - 2], fill=fill)
    d.text((x + pad, y + pad - 2), text, font=f, fill=ink)


def wrap(d, text, width_px, f):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= width_px: cur = t
        else: lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines


def sheet(name, title, caption, panels, pw, ph):
    # two panels side by side; three panels: TODAY | PHASE 1 small on top, PHASE 1 + 2 full width below
    gap = 14; W = 2 * pw + 3 * gap
    tmp = Image.new('RGB', (W, 10)); dd = ImageDraw.Draw(tmp)
    cap = wrap(dd, caption, W - 2 * gap, T2)
    big = (W - 2 * gap, (W - 2 * gap) * 9 // 16) if len(panels) == 3 else None
    H = 64 + len(cap) * 25 + 12 + ph + gap + (big[1] + gap if big else 0)
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    d.text((gap, 14), title, font=T1, fill=INK)
    y0 = 58
    for line in cap: d.text((gap, y0), line, font=T2, fill=SUB); y0 += 25
    y0 += 8
    for i, (label, path, colour) in enumerate(panels):
        if i < 2: x, y, w, h = gap + i * (pw + gap), y0, pw, ph
        else: x, y, w, h = gap, y0 + ph + gap, big[0], big[1]
        if os.path.exists(path):
            p = Image.open(path).convert('RGB').resize((w, h), Image.LANCZOS); im.paste(p, (x, y))
        else:
            d.rectangle([x, y, x + w, y + h], outline=SUB); d.text((x + 20, y + 20), 'missing ' + os.path.basename(path), font=T2, fill=SUB)
        tag(d, (x + 10, y + 10), label, fill=colour)
    im.save(os.path.join(DOCS, 'base_area_%s.png' % name), optimize=True)
    print('wrote base_area_%s.png' % name, im.size)


TODAY, P1, FULL, LOW = (150, 60, 60), (40, 110, 170), (40, 140, 90), (120, 80, 170)
for v in V['views']:
    n = v['name']
    three = n in ('spawn', 'gate', 'aerial')
    panels = [('TODAY (R150 live)', os.path.join(OUT, 'before_%s.png' % n), TODAY)]
    if three:
        panels.append(('PHASE 1', os.path.join(OUT, 'p1_%s.png' % n), P1))
    panels.append(('PHASE 1 + 2' if three or n == 'darkened' else 'AFTER (PHASE 1 + 2)', os.path.join(OUT, 'after_%s.png' % n), FULL))
    pw, ph = (640, 360) if three else (900, 506)
    sheet(n, v['title'], v['caption'], panels, pw, ph)

# owner option: low wall + skyline
lw = [v for v in V['views'] if v['name'] in ('walls', 'street', 'aerial')]
pw, ph = 720, 405; gap = 14; W = 2 * pw + 3 * gap
lines = wrap(ImageDraw.Draw(Image.new('RGB', (W, 10))), 'Left: the Phase 1 wall (the saved 48-stud wall, dressed). Right: the saved wall turned invisible (it still '
             'blocks exactly where it blocks today) behind a 30-stud dressed wall, with far biome silhouettes (Forest hills, Jungle domes, Desert pyramid, '
             'Snow peaks, Lava volcano, Crystal spires, Storm peak) built on each screen beyond it. 41 client parts, no collision.', W - 2 * gap, T2)
top = 64 + 25 * len(lines)
im = Image.new('RGB', (W, top + len(lw) * (ph + gap)), BG); d = ImageDraw.Draw(im)
d.text((gap, 14), 'Owner option: a 30-stud visible wall with a biome skyline beyond', font=T1, fill=INK)
for i, line in enumerate(lines): d.text((gap, 56 + 25 * i), line, font=T2, fill=SUB)
y = top
for v in lw:
    for j, (label, pre, colour) in enumerate((('48-STUD WALL (PHASE 1)', 'after', FULL), ('30-STUD WALL + SKYLINE (OPTION)', 'low', LOW))):
        x = gap + j * (pw + gap); p = os.path.join(OUT, '%s_%s.png' % (pre, v['name']))
        if os.path.exists(p): im.paste(Image.open(p).convert('RGB').resize((pw, ph), Image.LANCZOS), (x, y))
        tag(d, (x + 10, y + 10), label + ' - ' + v['title'].split(' (')[0].lower(), fill=colour)
    y += ph + gap
im.save(os.path.join(DOCS, 'base_area_lowwall.png'), optimize=True); print('wrote base_area_lowwall.png', im.size)

# plans: world (x, z) -> pixel on the 1400 x 1100 ortho render
cx, cz, hw, hh = V['plan']['ortho']; PW, PH = V['plan']['w'], V['plan']['h']
def px(x, z, s=1.0): return ((PW / 2 + (cx - x) * PW / (2 * hw)) * s, (PH / 2 - (z - cz) * PH / (2 * hh)) * s)


def label(d, x, z, text, s=1.0, fill=(20, 22, 28, 215), ink=INK, f=T4):
    X, Y = px(x, z, s); w = d.textlength(text, font=f)
    d.rounded_rectangle([X - w / 2 - 6, Y - f.size / 2 - 5, X + w / 2 + 6, Y + f.size / 2 + 5], radius=6, fill=fill)
    d.text((X - w / 2, Y - f.size / 2 - 2), text, font=f, fill=ink)


def plan_today():
    base = Image.open(os.path.join(OUT, 'before_plan.png')).convert('RGBA')
    ov = Image.new('RGBA', base.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    for i, (x, z) in enumerate([(-235, -180.5), (235, -180.5), (-235, -358), (235, -358), (-74, -512), (74, -512)]):
        label(d, x, z, 'Base %d  (180 x 118 plot)' % (i + 1), f=T3)
    label(d, 0, -268, 'MARKET (x1.7, 51 x 43)', f=T3)
    label(d, 0, -312, 'Verity (event, ends 1 Nov)')
    label(d, 0, -141, 'fallback spawn (0, 4.1, -141)')
    label(d, 0, -112, 'safe line z -99.3 -> the track (188-stud gap)', fill=(30, 110, 60, 225))
    label(d, -116, -130, 'Most Cash board'); label(d, 116, -130, 'Top Speed board')
    label(d, 0, -200, 'open grass 290 x 320 (no paths, trees, benches, lamps)', fill=(120, 40, 40, 220))
    label(d, -240, -269, 'empty alley 52 wide'); label(d, 240, -269, 'empty alley 52 wide')
    label(d, 0, -470, '30-stud lane'); label(d, -240, -525, 'empty corner ~190 x 198', fill=(120, 40, 40, 220)); label(d, 240, -525, 'empty corner ~190 x 198', fill=(120, 40, 40, 220))
    label(d, -240, -555, '(R151 display, in progress)'); label(d, 240, -555, '(R151 display, in progress)')
    label(d, 0, -605, 'walls: 5 plain parts, 48 studs high, sage plastic + wood cap', fill=(120, 40, 40, 220))
    return Image.alpha_composite(base, ov).convert('RGB')


today_plan = plan_today()
pw, ph = 720, 405
row = [('before_spawn', 'spawn: leaving Base 1'), ('before_street', 'between Base 1 and Base 3'), ('before_gate', 'the track gap')]
W = 1400 + 2 * 14; H = 96 + 1100 + 14 + ph * 2 // 3 + 60
im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
d.text((14, 14), 'Today: the hub (R150 live, from the owner\'s place file + the real start-up builders)', font=T1, fill=INK)
d.text((14, 56), 'Top view (track up, -X right, 2 px per stud) and three views from player height. Plain grass, plain walls, nothing between the buildings.', font=T2, fill=SUB)
im.paste(today_plan, (14, 90))
sw = (1400 - 2 * 14) // 3; sh = sw * 9 // 16
for i, (f, cap) in enumerate(row):
    x = 14 + i * (sw + 14); y = 90 + 1100 + 14
    im.paste(Image.open(os.path.join(OUT, f + '.png')).convert('RGB').resize((sw, sh), Image.LANCZOS), (x, y)); tag(d, (x + 8, y + 8), cap, fill=TODAY)
im = im.crop((0, 0, W, 90 + 1100 + 14 + sh + 14)); im.save(os.path.join(DOCS, 'base_area_today.png'), optimize=True); print('wrote base_area_today.png', im.size)

# the redesign plan with zones
base = Image.open(os.path.join(OUT, 'after_plan.png')).convert('RGBA')
ov = Image.new('RGBA', base.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
Z = [  # (x, z, text, colour)
    (0, -122, '1  TRACK GATE + 7 biome lanes', (30, 110, 60, 230)), (0, -159, '2  front street', None), (60, -205, '3  welcome lawn', None), (-60, -205, '3  welcome lawn', None),
    (0, -300, '4  MARKET SQUARE', None), (0, -352, '5  stage circle (Verity)', None), (0, -415, '6  SEED FOUNTAIN', None),
    (118, -285, '7  ring street', None), (-118, -285, '7  ring street', None), (230, -258, '8  DESERT GARDEN', (150, 110, 40, 230)), (-230, -258, '8  LAVA GARDEN', (150, 60, 40, 230)),
    (0, -560, '9  back lane', None), (-240, -520, 'RESERVED: R151 display', (120, 40, 40, 230)), (240, -520, 'RESERVED: R151 display', (120, 40, 40, 230)),
]
for x, z, t, c in Z: label(d, x, z, t, fill=c or (20, 22, 28, 215), f=T3)
for i, (x, z) in enumerate([(-235, -205), (235, -205), (-235, -383), (235, -383), (-74, -470), (74, -470)]):
    label(d, x, z, 'Base %d: arch + verge' % (i + 1), fill=(60, 60, 70, 200))
for n, (x, z) in enumerate([(160, -112), (262, -112), (325, -269), (0, -608), (-325, -269), (-262, -112), (-160, -112)]):
    X, Y = px(x, z); d.ellipse([X - 15, Y - 15, X + 15, Y + 15], fill=(244, 196, 86, 240), outline=(60, 40, 20, 255), width=2)
    t = str(n + 1); w = d.textlength(t, font=T3); d.text((X - w / 2, Y - 11), t, font=T3, fill=(40, 30, 20))
plan = Image.alpha_composite(base, ov).convert('RGB')
LW = 520; W = 1400 + LW + 3 * 14; H = 1100 + 110
im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
d.text((14, 14), 'The redesign from above: Seed Festival Square (Phase 1 + 2)', font=T1, fill=INK)
d.text((14, 56), 'Track up, -X right. Gold discs 1-7: the biome murals in track order, starting and ending at the gate.', font=T2, fill=SUB)
im.paste(plan, (14, 96))
x0 = 1400 + 28; y = 96
small = today_plan.resize((LW, LW * 1100 // 1400), Image.LANCZOS); im.paste(small, (x0, y)); tag(d, (x0 + 6, y + 6), 'today (same scale, labelled)', fill=TODAY, f=T4); y += small.size[1] + 16
legend = ['ZONES', '1 Track gate: keyboard arch, 7 biome keys with', '   keeper speeds, flags, biome run-up lanes',
          '2 Front street joins gate, avenue and the ring', '3 Welcome lawns: trees, beds, benches, signpost', '4 Market square (brick) around the market',
          '5 Stage circle: Verity now, event stage later', '6 Seed Fountain: the centrepiece', '7 Ring street past all six base entrances',
          '8 Side gardens: Desert (palms, cacti) and', '   Lava (ember trees, glowing rocks)', '9 Back lane to the SNOW mural', '',
          'WALLS: same 5 saved parts (size, place, collision)', '   cream plaster, plinth, gold course, 36 pilasters', '   with topiary, hedge top, 4 corner towers,', '   7 framed biome murals, 6 base banners', '',
          'BASES: arch in the base colour + owner name,', '   number medallion, pennants, flower verge, a spur', '   paved to the street, base-coloured curbs + mat']
for line in legend:
    d.text((x0, y), line, font=T3 if line in ('ZONES',) or line.startswith('WALLS') or line.startswith('BASES') else T4, fill=INK if not line.startswith('   ') else SUB); y += 22
if len(sys.argv) > 4 and os.path.exists(sys.argv[4]):
    y += 10; d.text((x0, y), 'PARTS (counted in the scenes)', font=T3, fill=ACC); y += 24
    txt = open(sys.argv[4]).read().split('== after.json')[1].split('==')[0]
    import re
    grab = lambda k: (re.search(r'R151 total %s\s+(\d+)' % re.escape(k), txt) or [0, '?'])[1]
    today = re.search(r"today's hub \(visible parts, z < -95\): (\d+)", txt).group(1)
    for line in ['today\'s hub: %s visible parts (market 2,229)' % today, 'Phase 1, server-built: %s parts' % grab('P1 server'),
                 'Phase 2, client-built (LOD): %s parts' % grab('P2 client'), 'z-fighting with R151 parts: none (R149 detector)']:
        d.text((x0, y), line, font=T4, fill=SUB); y += 21
im.save(os.path.join(DOCS, 'base_area_plan.png'), optimize=True); print('wrote base_area_plan.png', im.size)
