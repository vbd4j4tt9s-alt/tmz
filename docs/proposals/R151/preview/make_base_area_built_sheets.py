"""R151 as built: compose render_base_area.mjs output of the REAL src builders into docs/proposals/R151/base_area_built_*.png.
Usage: python3 make_base_area_built_sheets.py <render out dir> <views.json> <variety views.json> <docs/proposals/R151 dir> [budget.txt]
  base_area_built_<view>.png     TODAY (the branch before R151's code) and the LOW TIER (phones on low, FastMode: the core level only) small,
                                 AS BUILT (this checkout, desktop tier) large; the proposal's cameras
  base_area_built_darkened.png   the lamps in the dark (The Darkened's blackout)
  base_area_built_plan.png       the built hub from above with its zones
  base_area_built_variety.png    close-ups of the tree and prop variety
  base_area_built_studded.png    (env STUDDED_VIEWS=<base_area_studded_views.json>) the studded trees: with two STAND-IN tree models in
                                 ReplicatedStorage.HubTreeTemplates151 (not the owner's) next to the part-built studded trees"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT, VIEWS, VARIETY, DOCS = sys.argv[1:5]
BUDGET = sys.argv[5] if len(sys.argv) > 5 else None
V = json.load(open(VIEWS)); VV = json.load(open(VARIETY))
BG, INK, SUB, ACC = (27, 29, 35), (238, 240, 245), (170, 176, 190), (255, 206, 84)
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
def font(n, bold=False): return ImageFont.truetype(F % ('-Bold' if bold else ''), n)
T1, T2, T3, T4 = font(30, True), font(19), font(17, True), font(15)
TODAY, BUILT, LOW = (150, 60, 60), (40, 140, 90), (120, 90, 40)


def tag(d, xy, text, f=T3, fill=(20, 22, 28), ink=INK, pad=6):
    x, y = xy; w = d.textlength(text, font=f)
    d.rectangle([x, y, x + w + 2 * pad, y + f.size + 2 * pad - 2], fill=fill); d.text((x + pad, y + pad - 2), text, font=f, fill=ink)


def wrap(d, text, width, f):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= width: cur = t
        else: lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines


def paste(im, d, path, x, y, w, h, label, colour):
    if os.path.exists(path): im.paste(Image.open(path).convert('RGB').resize((w, h), Image.LANCZOS), (x, y))
    else: d.rectangle([x, y, x + w, y + h], outline=SUB); d.text((x + 20, y + 20), 'missing ' + os.path.basename(path), font=T2, fill=SUB)
    tag(d, (x + 10, y + 10), label, fill=colour)


def sheet(name, title, caption, small, big):
    gap = 14; pw, ph = 640, 360; W = 2 * pw + 3 * gap
    dd = ImageDraw.Draw(Image.new('RGB', (W, 10))); cap = wrap(dd, caption, W - 2 * gap, T2)
    bw = W - 2 * gap; bh = bw * 9 // 16
    H = 64 + 25 * len(cap) + 8 + ph + gap + bh + gap
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    d.text((gap, 14), title, font=T1, fill=INK)
    y = 58
    for line in cap: d.text((gap, y), line, font=T2, fill=SUB); y += 25
    y += 8
    for i, (label, path, colour) in enumerate(small): paste(im, d, path, gap + i * (pw + gap), y, pw, ph, label, colour)
    paste(im, d, big[1], gap, y + ph + gap, bw, bh, big[0], big[2])
    im.save(os.path.join(DOCS, 'base_area_built_%s.png' % name), optimize=True); print('wrote base_area_built_%s.png' % name, im.size)


CAPTIONS = {
 'spawn': "Ben spawns inside Base 1 and looks out at the hub. AS BUILT: his arch (BASE 1 inside, BEN'S BASE outside), a spur with curbs and a welcome mat in his colour, potted topiary, the avenue's poplars, blossoms, lamps and bunting, the market square and the gate towers on the right. The LOW TIER keeps every silhouette (trunks, main crowns, lamps, benches, beds, the fountain) and drops the small detail.",
 'street': "The west street at the mouth of the alley between Base 1 and Base 3. AS BUILT: the Lava garden walk with its red edging, ember trees with glowing embers, basalt rocks, bollard lamps, pebbles, the base banners 1 and 3 and the LAVA mural (5 of 7) closing the view.",
 'entrance': "Base 3 from the west street. AS BUILT: the arch in the base's colour with the owner's name, the number medallion, pennants, a flower verge, potted topiary at the spur's street end; the 32-stud opening, fence art, treadmill and pedestal are untouched.",
 'walls': "The east wall at the end of the Desert garden. AS BUILT: the saved wall part (same size, place, collision) in cream plaster with a stone plinth and cap, a gold string course, pilasters on stone bases with topiary balls and two-tier topiary, a clipped hedge, wall lanterns, the DESERT mural (3 of 7, a richer relief), palms, cacti and the garden nook.",
 'backwall': "From the south street down the back lane between Base 5 and Base 6. AS BUILT: pines with snow rims along the lane, the lane's curbs, the SNOW mural (4 of 7) with a snowman, base banners 5 and 6.",
 'gate': "From the front street. AS BUILT: the keyboard arch with one key per biome and that keeper's speed (Forest 0 ... Storm Peaks 2.6B); this player is faster than the Jungle keeper, so Forest and Jungle are ticked green on HIS screen only. Seven flags, THE TRACK crest, the seven biome lanes of the run-up, potted topiary and the signpost.",
 'aerial': "AS BUILT: the dressed walls with towers, murals and banners; the ring of streets with curbs and edging past every base; the market square, stage circle and Seed Fountain; 58 studded trees of 15+ kinds, bushes, topiary, beds, lamps, benches, bunting, grass patches. The two back corners stay empty for the R151 Best Pull / Biggest Fruit displays.",
 'avenue': "Down the avenue from the front street. AS BUILT: curbs, blossom trees and potted topiary at the avenue's mouth, lamps with crossed bunting, flower beds and benches on the lawns, poplars by the side streets, the brick market square with double lamps, planters and bunting to the market's eaves.",
 'darkened': "There is no day/night yet; The Darkened's arrival (and Rain / Thunderstorm) darkens the hub. AS BUILT: 8 lamps carry a real light that the client switches on in the dark (22 lamp posts and 4 bollards all have neon lanterns, plus 14 wall lanterns), so the streets stay readable. (Approximate: the real blackout is darker past a short distance.)",
}
for v in V['views']:
    n = v['name']
    cap = CAPTIONS.get(n, v['caption'])
    if n == 'darkened':
        small = [('TODAY, lights out', os.path.join(OUT, 'before_darkened.png'), TODAY), ('AS BUILT, by day', os.path.join(OUT, 'built_avenue.png'), BUILT)]
        sheet(n, v['title'] + ' (as built)', cap, small, ('AS BUILT, lights out: lamps on', os.path.join(OUT, 'night_darkened.png'), BUILT))
        continue
    small = [('TODAY (before R151)', os.path.join(OUT, 'before_%s.png' % n), TODAY),
             ('AS BUILT, LOW TIER (phones on low / FastMode)', os.path.join(OUT, 'tier1_%s.png' % n), LOW)]
    sheet(n, v['title'] + ' (as built)', cap, small, ('AS BUILT (this checkout, desktop tier)', os.path.join(OUT, 'built_%s.png' % n), BUILT))

# variety close-ups: 2 columns
gap = 14; pw, ph = 720, 405; cols = 2; rows = (len(VV['views']) + cols - 1) // cols
W = cols * pw + (cols + 1) * gap
lines = wrap(ImageDraw.Draw(Image.new('RGB', (W, 10))), 'Every tree and prop gets its own deterministic variation from its kind and position (scale, lean, turn, '
             'colour shade, crown layering), so every client builds the same square and no two trees are clones. Trees, bushes and topiary '
             'are studded Plastic blocks (Studs on top, like the place\'s own track trees; owner: "make sure they are studded"). Close-ups of the real '
             'HubLifeArt151 / HubDecor151 output on the owner\'s place (preview renderer, not Roblox).', W - 2 * gap, T2)
top = 64 + 24 * len(lines); H = top + rows * (ph + gap)
im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
d.text((gap, 14), 'As built: the variety (owner: "polish the trees, give them more variety")', font=T1, fill=INK)
for i, line in enumerate(lines): d.text((gap, 56 + 24 * i), line, font=T2, fill=SUB)
for k, v in enumerate(VV['views']):
    x = gap + (k % cols) * (pw + gap); y = top + (k // cols) * (ph + gap)
    paste(im, d, os.path.join(OUT, 'built_%s.png' % v['name']), x, y, pw, ph, v['title'], (30, 34, 44))
im.save(os.path.join(DOCS, 'base_area_built_variety.png'), optimize=True); print('wrote base_area_built_variety.png', im.size)

# studded trees: STAND-IN tree models (left) next to the part-built studded trees (right)
STUD = os.environ.get('STUDDED_VIEWS')
if STUD and os.path.exists(STUD):
    SV = {v['name']: v for v in json.load(open(STUD))['views']}
    STAND, PART = (170, 70, 30), (40, 110, 140)
    rows = [[('trees', 's_oaks'), ('built', 's_oaks')], [('trees', 's_blossoms'), ('built', 's_blossoms')], [('trees', 's_fruit'), ('built', 's_fruit')],
            [('trees', 's_close'), ('built', 's_close')], [('trees', 's_avenue'), ('built', 's_avenue')], [('built', 'p_desert'), ('built', 'p_lava')],
            [('built', 'p_snow'), ('tier1', 's_avenue')]]
    gap = 14; pw, ph = 720, 405; cols = 2
    W = cols * pw + (cols + 1) * gap
    intro = ('Owner: "there are different variations of trees that we can use make sure they are studded". LEFT: the leafy trees (oaks, blossoms, '
             'fruit trees) with two STAND-IN studded tree models in ReplicatedStorage.HubTreeTemplates151 - made here, NOT the owner\'s Creator Store '
             'trees (16637971059, 17280628013), which cannot be downloaded offline: each slot gets a clone fitted to its size, turned, leaned, its '
             'leaves in the slot\'s colour, fruit set in. RIGHT: no models (until they load, or on phones on low): the part-built studded trees. '
             'Pines, palms, cacti and ember trees are always part-built and studded. Preview renderer with a drawn stud pattern, not Roblox.')
    lines = wrap(ImageDraw.Draw(Image.new('RGB', (W, 10))), intro, W - 2 * gap, T2)
    top = 64 + 24 * len(lines); H = top + len(rows) * (ph + gap)
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    d.text((gap, 14), 'Studded trees: STAND-IN models vs the part-built studded trees', font=T1, fill=INK)
    for i, line in enumerate(lines): d.text((gap, 56 + 24 * i), line, font=T2, fill=SUB)
    for r, row in enumerate(rows):
        for c, (scene, view) in enumerate(row):
            x = gap + c * (pw + gap); y = top + r * (ph + gap)
            label = ('STAND-IN MODELS: ' if scene == 'trees' else 'PHONES ON LOW (tier 1, part-built): ' if scene == 'tier1' else 'PART-BUILT: ') + SV[view]['title']
            paste(im, d, os.path.join(OUT, '%s_%s.png' % (scene, view)), x, y, pw, ph, label, STAND if scene == 'trees' else PART)
    im.save(os.path.join(DOCS, 'base_area_built_studded.png'), optimize=True); print('wrote base_area_built_studded.png', im.size)

# plan
cx, cz, hw, hh = V['plan']['ortho']; PW, PH = V['plan']['w'], V['plan']['h']
def px(x, z): return (PW / 2 + (cx - x) * PW / (2 * hw), PH / 2 - (z - cz) * PH / (2 * hh))
base = Image.open(os.path.join(OUT, 'built_plan.png')).convert('RGBA'); ov = Image.new('RGBA', base.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
def label(x, z, t, fill=(20, 22, 28, 215), f=T3):
    X, Y = px(x, z); w = d.textlength(t, font=f)
    d.rounded_rectangle([X - w / 2 - 6, Y - f.size / 2 - 5, X + w / 2 + 6, Y + f.size / 2 + 5], radius=6, fill=fill); d.text((X - w / 2, Y - f.size / 2 - 2), t, font=f, fill=INK)
for x, z, t, c in [(0, -122, 'TRACK GATE + 7 biome lanes', (30, 110, 60, 230)), (0, -300, 'MARKET SQUARE', None), (0, -352, 'stage circle', None),
                   (0, -415, 'SEED FOUNTAIN', None), (230, -258, 'DESERT GARDEN', (150, 110, 40, 230)), (-230, -258, 'LAVA GARDEN', (150, 60, 40, 230)),
                   (0, -560, 'SNOW LANE', None), (-240, -520, 'RESERVED: R151 display', (120, 40, 40, 230)), (240, -520, 'RESERVED: R151 display', (120, 40, 40, 230))]:
    label(x, z, t, fill=c or (20, 22, 28, 215))
plan = Image.alpha_composite(base, ov).convert('RGB')
LW = 470; W = PW + LW + 3 * 14; H = PH + 110
im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
d.text((14, 14), 'As built from above: Seed Festival Square (real src builders)', font=T1, fill=INK)
d.text((14, 56), 'Track up, -X right. Server: walls, murals, banners, gate, paths, base arches. Client: trees, props, fountain (desktop tier shown).', font=T2, fill=SUB)
im.paste(plan, (14, 96)); x0 = PW + 28; y = 96
if BUDGET and os.path.exists(BUDGET):
    d.text((x0, y), 'PART BUDGET (counted by the tests)', font=T3, fill=ACC); y += 28
    for line in open(BUDGET).read().strip().splitlines():
        for w in wrap(d, line.replace('BUDGET ', ''), LW - 10, T4): d.text((x0, y), w, font=T4, fill=SUB); y += 20
        y += 4
im.save(os.path.join(DOCS, 'base_area_built_plan.png'), optimize=True); print('wrote base_area_built_plan.png', im.size)
