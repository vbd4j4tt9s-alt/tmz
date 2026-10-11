"""R158: the pictures of what was BUILT (not the design preview): track_walls.png and base_walls.png, drawn from the real map the game builds.
  python3 make_built158.py scenes <plain world dir> <built world dir> <out dir>
      plain world: the owner's place after every REAL start-up pass WITHOUT the R158 passes; built world: the same WITH them (docs/proposals/R158/tests/run_walls158.sh builds both:
      one scene per biome + the hub, the REAL keyboard client around a runner). Writes the scenes the renderer draws (cut to what each view can see), views.json and jobs.txt.
  python3 make_built158.py sheet <render out dir> <specs.txt> <design dir>
      specs.txt: dump_specs158.luau's output (the built data: counts). Composes track_walls.png and base_walls.png in the design dir.
The renderer is R156's three.js map renderer (software WebGL in headless Chromium) with Ice drawn opaque (make158.py html): APPROXIMATE, not Roblox lighting / materials / bloom.
render_built158.sh runs the whole chain."""
import collections, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make158 as M  # noqa: E402  (the design's scene helpers: SPOTS, overlaps, write, load_specs)

ROOT = M.ROOT


OUTER_BIOMES = ['forest', 'jungle', 'desert', 'crystal', 'storm']  # the backdrops that exist without the owner's meshes (the mock cannot load meshes)
TREE_BIOMES = ('forest', 'jungle')  # Forest and Jungle: large trees only; three views each (over the left wall, over the right wall, from the runner's camera on the track)


def views():
    V = []
    for bid, sp in M.SPOTS.items():
        z = sp['z']
        V.append({'name': 'wall_' + bid, 'pos': [16, 21, z - 40], 'look': [-89, 32, z + 34], 'fov': 62, 'shadowAt': [-60, 20, z + 30], 'shadowExtent': 140, 'fogNear': 700, 'fogFar': 2600})
        V.append({'name': 'along_' + bid, 'pos': [55, 26, z - 150], 'look': [-89, 34, z + 70], 'fov': 66, 'shadowAt': [-60, 20, z - 20], 'shadowExtent': 200, 'fogNear': 900, 'fogFar': 3000})
    for bid in OUTER_BIOMES:
        (cx, cy, cz), (lx, ly, lz) = {'storm': ((0, 170, -520), (0, 70, 260)), 'forest': ((30, 75, -70), (-160, 55, 60)), 'jungle': ((30, 75, -110), (-165, 55, 70)), 'crystal': ((30, 90, -330), (0, 70, 200))}.get(bid, M.OUTER[bid])  # (a camera held up over the walls so the backdrop shows)
        z = M.SPOTS[bid]['z']
        V.append({'name': 'out_' + bid, 'pos': [cx, cy, z + cz], 'look': [lx, ly, z + lz], 'fov': 64, 'shadowAt': [0, 20, z], 'shadowExtent': 260, 'fogNear': 1200, 'fogFar': 4200})
        if bid in TREE_BIOMES:
            # the other side, over the right wall, further along the track
            V.append({'name': 'outr_' + bid, 'pos': [-cx, cy, z + cz + 150], 'look': [-lx, ly, z + lz + 150], 'fov': 64, 'shadowAt': [0, 20, z], 'shadowExtent': 260, 'fogNear': 1200, 'fogFar': 4200})
            # the runner's camera on the track (a little behind and above the runner, looking along the track): what the player sees of the trees over the walls
            V.append({'name': 'run_' + bid, 'pos': [0, 20, z + cz - 20 + (30 if bid == 'forest' else 60)], 'look': [-20, 58, z + cz + 150 + (60 if bid == 'forest' else 100)], 'fov': 70, 'shadowAt': [0, 20, z], 'shadowExtent': 260, 'fogNear': 1200, 'fogFar': 4200})
    V.append({'name': 'hub_gate', 'pos': [-26, 40, -158], 'look': [-6, 63, -100], 'fov': 46, 'shadowAt': [0, 30, -110], 'shadowExtent': 130, 'fogNear': 900, 'fogFar': 2600})
    V.append({'name': 'hub_top', 'pos': [-168, 40, -146], 'look': [-236, 54, -104], 'fov': 44, 'shadowAt': [-220, 40, -110], 'shadowExtent': 90, 'fogNear': 900, 'fogFar': 2600})
    V.append({'name': 'hub_corner', 'pos': [-262, 34, -178], 'look': [-334, 53, -106], 'fov': 50, 'shadowAt': [-300, 40, -130], 'shadowExtent': 110, 'fogNear': 900, 'fogFar': 2600})
    V.append({'name': 'hub_close', 'pos': [-200, 62, -120], 'look': [-236, 56, -104], 'fov': 40, 'shadowAt': [-220, 40, -110], 'shadowExtent': 60, 'fogNear': 900, 'fogFar': 2600})
    return V


def cmd_scenes(plain, built, out):
    os.makedirs(out, exist_ok=True)
    jobs = []
    for bid, sp in M.SPOTS.items():
        z = sp['z']
        a = json.load(open(os.path.join(plain, bid + '.json')))
        b = json.load(open(os.path.join(built, bid + '.json')))
        for tag, d in (('cur', a), ('new', b)):
            near = [p for p in d['parts'] if M.overlaps(p, -400, 400, z - 260, z + 900) and '/Models/' not in p['path']]
            guis = [g for g in d.get('guis', []) if z - 260 <= g['p'][2] <= z + 900]
            M.write(os.path.join(out, '%s_%s.json' % (tag, bid)), near, guis)
        jobs += ['cur_%s=%s@wall_%s,along_%s' % (bid, os.path.join(out, 'cur_%s.json' % bid), bid, bid), 'new_%s=%s@wall_%s,along_%s' % (bid, os.path.join(out, 'new_%s.json' % bid), bid, bid)]
        if bid in OUTER_BIOMES:
            far = [p for p in b['parts'] if M.overlaps(p, -2000, 2000, z - 700, z + 2400)]
            M.write(os.path.join(out, 'far_%s.json' % bid), far, [])
            jobs.append('far_%s=%s@out_%s%s' % (bid, os.path.join(out, 'far_%s.json' % bid), bid, (',outr_%s,run_%s' % (bid, bid)) if bid in TREE_BIOMES else ''))
    for tag, world in (('cur', plain), ('new', built)):
        d = json.load(open(os.path.join(world, 'hub.json')))
        hub = [p for p in d['parts'] if M.overlaps(p, -700, 700, -700, 400) and '/TrackBackdrops158/' not in p['path'] and '/TrackWalls158/' not in p['path']]
        M.write(os.path.join(out, 'hub_%s.json' % tag), hub, d.get('guis', []), d.get('lights', []))
        jobs.append('hub_%s=%s@hub_gate,hub_top,hub_corner,hub_close' % (tag, os.path.join(out, 'hub_%s.json' % tag)))
    json.dump({'note': 'R158 built views (make_built158.py views)', 'views': views()}, open(os.path.join(out, 'views.json'), 'w'), indent=1)
    open(os.path.join(out, 'jobs.txt'), 'w').write('\n'.join(jobs) + '\n')
    print('scenes: %d jobs in %s' % (len(jobs), out))


def cmd_sheet(rendered, specs_path, design):
    from PIL import Image, ImageDraw, ImageFont
    S = M.load_specs(specs_path)
    F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
    font = lambda n, b=False: ImageFont.truetype(F % ('-Bold' if b else ''), n)
    BG, INK, SUB, GOLD = (24, 26, 31), (238, 240, 245), (176, 182, 194), (250, 226, 150)
    NOW, NEW = (190, 84, 84), (66, 170, 110)
    W, H = 560, 315
    gap, head, cap = 14, 112, 56

    def img(name):
        p = os.path.join(rendered, name + '.png')
        if os.path.exists(p):
            return Image.open(p).convert('RGB').resize((W, H), Image.LANCZOS)
        im = Image.new('RGB', (W, H), (60, 30, 30))
        ImageDraw.Draw(im).text((20, 20), 'missing: ' + name, font=font(18), fill=INK)
        return im

    def tag(d, x, y, text, color):
        f = font(15, True)
        w = d.textlength(text, font=f)
        d.rounded_rectangle((x, y, x + w + 16, y + 24), 6, fill=color)
        d.text((x + 8, y + 3), text, font=f, fill=(255, 255, 255))

    def wrap(d, text, width, f):
        words, lines, cur = text.split(), [], ''
        for w in words:
            t = (cur + ' ' + w).strip()
            if d.textlength(t, font=f) <= width:
                cur = t
            else:
                lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        return lines

    counts = collections.Counter(s['Group'].split('/')[1] for s in S['specs']['walls'])
    borders = sum(v for k, v in counts.items() if k.startswith('Border'))
    rows = S['biomes']
    sheet = Image.new('RGB', (3 * W + 4 * gap, head + len(rows) * (H + cap + gap) + 70), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 14), 'Track walls as built: a different wall in every biome, nothing stamped', font=font(30, True), fill=GOLD)
    d.text((gap, 56), 'Left: the wall before.  Middle: as built, close.  Right: as built, along the wall (look for repeats: there are none you can count on).', font=font(17), fill=SUB)
    d.text((gap, 80), 'Drawn from the real map the game builds (not the old preview) in an approximate picture: not Roblox lighting. Details are placed from a fixed seed per wall: irregular spacing, sizes, heights, gaps and breaks.', font=font(15), fill=SUB)
    for i, b in enumerate(rows):
        y = head + i * (H + cap + gap)
        n = counts.get(b['Name'], 0)
        d.text((gap, y + 4), '%d. %s' % (i + 1, b['Name']), font=font(22, True), fill=INK)
        d.text((gap + 210, y + 8), '%d parts for both walls' % n, font=font(16), fill=SUB)
        lines = wrap(d, b['Look'], 3 * W + 2 * gap - 10, font(15))
        for k, l in enumerate(lines[:2]):
            d.text((gap, y + 30 + k * 18), l, font=font(15), fill=SUB)
        for k, (name, label, color) in enumerate((('cur_%s_wall_%s' % (b['Id'], b['Id']), 'BEFORE', NOW), ('new_%s_wall_%s' % (b['Id'], b['Id']), 'BUILT', NEW), ('new_%s_along_%s' % (b['Id'], b['Id']), 'BUILT, ALONG THE WALL', NEW))):
            x = gap + k * (W + gap)
            sheet.paste(img(name), (x, y + cap))
            tag(d, x + 8, y + cap + 8, label, color)
    fy = head + len(rows) * (H + cap + gap) + 4
    d.text((gap, fy), 'Walls: %d parts in all, %d of them the 6 border towers where two biomes meet. The design said 1,747 at most. Nothing new collides; the walls keep their size and height.' % (len(S['specs']['walls']), borders), font=font(16), fill=SUB)
    d.text((gap, fy + 24), 'Every new part: anchored, no collision, no touch, no query (players, keepers, packs and the camera go through it). Only parts 20+ studs long cast a shadow.', font=font(16), fill=SUB)
    sheet.save(os.path.join(design, 'track_walls.png'), optimize=True)

    # base_walls.png: now / A, columns gate / wall top / corner / close-up
    cols = ['hub_gate', 'hub_top', 'hub_corner', 'hub_close']
    w4, h4 = 420, 236
    opts = [('hub_cur', 'NOW', 'Plain merlons (what you had)', NOW, ''), ('hub_new', 'A', 'Stone caps (built)', NEW, '%d parts' % len(S['specs']['baseA']))]
    sheet = Image.new('RGB', (4 * w4 + 5 * gap, head + len(opts) * (h4 + 70 + gap) + 20), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 14), 'Base walls A as built: stone caps on the castle wall tops', font=font(30, True), fill=GOLD)
    d.text((gap, 56), 'The gate (no sign, as in the hotfix), a stretch of wall top, a corner and a close-up. Same walls, same height, same collision. The caps come in a few close stone shades.', font=font(17), fill=SUB)
    looks = {'NOW': 'Square plaster merlons on the plain wall top: no caps, no trim.', 'A': 'A dark stone cap on every merlon (five close shades, a hair of thickness difference) and a stone coping along the whole wall top, with a thin dark line under it.'}
    for i, (pre, label, title, color, n) in enumerate(opts):
        y = head + i * (h4 + 70 + gap)
        tag(d, gap, y + 8, label, color)
        tx = gap + 16 + d.textlength(label, font=font(15, True)) + 12
        d.text((tx, y + 6), title, font=font(21, True), fill=INK)
        if n:
            d.text((tx + d.textlength(title, font=font(21, True)) + 16, y + 11), n, font=font(16), fill=SUB)
        for k, l in enumerate(wrap(d, looks[label], 4 * w4 + 3 * gap, font(15))[:2]):
            d.text((gap, y + 38 + k * 18), l, font=font(15), fill=SUB)
        for k, c in enumerate(cols):
            p = os.path.join(rendered, '%s_%s.png' % (pre, c))
            im = Image.open(p).convert('RGB').resize((w4, h4), Image.LANCZOS) if os.path.exists(p) else Image.new('RGB', (w4, h4), (60, 30, 30))
            sheet.paste(im, (gap + k * (w4 + gap), y + 70))
    sheet.save(os.path.join(design, 'base_walls.png'), optimize=True)
    # outer_track_built.png: what stands outside the walls now (the game's own models + the owner's pyramid and dark mountain; the volcano and the snow hills load by mesh id in Studio)
    # three columns: Forest (3 views), Jungle (3 views), then Desert / Crystal / Storm Peaks
    cells = [('far_forest_out_forest', 'Forest: from over the left wall', 'the Forest\'s oak, the hub\'s oaks and poplars: 14 trees, 131 parts'),
             ('far_forest_outr_forest', 'Forest: from over the right wall', 'three bands a side, denser and taller at the back'),
             ('far_forest_run_forest', 'Forest: from the track', 'what the runner sees: the tops of the trees over the log fort'),
             ('far_jungle_out_jungle', 'Jungle: from over the left wall', 'jungle trees, the hub\'s palms, oaks, poplar: 29 trees, 348 parts'),
             ('far_jungle_outr_jungle', 'Jungle: from over the right wall', 'a loose jungle on both sides, a denser and taller back row'),
             ('far_jungle_run_jungle', 'Jungle: from the track', 'what the runner sees over the temple wall'),
             ('far_desert_out_desert', 'Desert', 'the owner\'s great pyramid (82 blocks) far right; dunes wait'),
             ('far_crystal_out_crystal', 'Crystal', 'the game\'s own crystal clusters as giant spires (6 spots)'),
             ('far_storm_out_storm', 'Storm Peaks', 'the owner\'s dark mountain, 280 blocks a copy, two each side')]
    w2, h2 = 560, 315
    sheet = Image.new('RGB', (3 * w2 + 4 * gap, 100 + 3 * (h2 + 60 + gap)), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 14), 'Outside the walls, as built now (approximate picture)', font=font(28, True), fill=GOLD)
    d.text((gap, 54), 'No part-built objects: the ground and the owner\'s / the game\'s own models. Forest and Jungle: only large trees (479 parts together). The owner\'s volcano and snow hills are meshes: they appear in Studio, not here.', font=font(15), fill=SUB)
    for i, (name, title, sub) in enumerate(cells):
        x = gap + (i % 3) * (w2 + gap)
        y = 90 + (i // 3) * (h2 + 60 + gap)
        d.text((x, y), title, font=font(21, True), fill=INK)
        d.text((x, y + 28), (sub if d.textlength(sub, font=font(15)) <= w2 else sub[:int(len(sub) * w2 / d.textlength(sub, font=font(15))) - 3] + '...'), font=font(15), fill=SUB)
        p = os.path.join(rendered, name + '.png')
        im = Image.open(p).convert('RGB').resize((w2, h2), Image.LANCZOS) if os.path.exists(p) else Image.new('RGB', (w2, h2), (60, 30, 30))
        sheet.paste(im, (x, y + 56))
    sheet.save(os.path.join(design, 'outer_track_built.png'), optimize=True)
    print('wrote track_walls.png, base_walls.png and outer_track_built.png in', design)


if __name__ == '__main__':
    if sys.argv[1] == 'scenes':
        cmd_scenes(*sys.argv[2:5])
    elif sys.argv[1] == 'sheet':
        cmd_sheet(*sys.argv[2:5])
    else:
        sys.exit(__doc__)
