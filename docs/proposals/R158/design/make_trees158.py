"""R158: lays out the Forest and Jungle trees outside the walls (OuterTrackAssets158.Slots, between the TREES158 BEGIN / END lines).
  python3 make_trees158.py [--write]     prints the spots and the part counts; --write puts them into OuterTrackAssets158.lua

Owner: "forest and jungle can just have large trees on the outside with our current game assets". Only large trees, made from the game's own tree models (the map's oak and jungle
tree; the hub's oak, poplar and palm: OuterTrackAssets158.Game), several different looks per biome, uneven heights, every turn, a few close tints, along the whole length of the
biome on both sides, a denser back row; never inside |x| 100, never over the hub (z >= -99), never past the biome's own ends. Owner rule: no repetitive design: nothing here is a
grid: every row has its own spacing, gaps, heights, turns and tints, all from a fixed seed (the same file every time).

PROTOS = what the loader builds for each Look of a key (1 = the first model of the key), as test_walls158 prints them (the 'INFO tree look' lines; it also checks every placed tree
against its spot's box, so a wrong number here fails there): the label, the part count and the model's size at scale 1 (x, y, z).
A spot's H is the tree's height; W and D are its width and depth at that height (rounded up), so the height is what limits the scale and the box holds the tree whatever its turn."""
import math, os, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, '..', '..', '..', '..', 'src', 'ServerScriptService', 'ChestChaseServer', 'OuterTrackAssets158.lua')
BEGIN, END = ' -- TREES158 BEGIN', ' -- TREES158 END'
HUB_Z, MIN_X = -99, 100

PROTOS = {
    'ForestTree': [
        ('Oak', 17, (33.68, 41.35, 29.09)),
        ('hub oak L', 8, (18.92, 20.85, 17.14)),
        ('hub oak M', 8, (15.96, 17.64, 16.00)),
        ('hub oak L 2', 6, (18.08, 23.64, 18.07)),
        ('hub oak M 2', 6, (14.26, 18.66, 12.43)),
        ('hub oak S', 7, (11.01, 13.21, 11.21)),
        ('hub poplar', 6, (7.41, 18.99, 7.41)),
        ('hub poplar 2', 6, (7.77, 21.56, 7.74)),
    ],
    'JungleTree': [
        ('Tall jungle tree', 33, (36.67, 46.52, 32.02)),
        ('Oak', 17, (33.14, 40.06, 28.97)),
        ('hub palm', 11, (11.57, 12.44, 11.45)),
        ('hub palm 2', 11, (15.33, 15.70, 15.65)),
        ('hub palm 3', 11, (15.05, 15.14, 14.14)),
        ('hub oak M', 8, (14.56, 16.11, 13.18)),
        ('hub poplar', 6, (6.28, 16.10, 6.28)),
        ('hub oak M 2', 6, (14.26, 18.66, 12.43)),
    ],
}
# The biomes' stretches (TrackWallSpecs158.Biomes: Z0 / Z1); the hub rule cuts the Forest's start at -99.
BIOMES = {'ForestTree': ('Forest', -99, 80), 'JungleTree': ('Jungle', 80, 530)}

# Rows: x = where the row's inner edge may stand (studs from the track's middle; the tree's centre is half its width further out), h = heights (tall: from the track the walls hide
# the lower 50 - 75 studs of a tree, so only the top of a tree shows over them), wmax = the widest a crown may get (a wide oak stops growing, a slim poplar goes on), cover = how much of
# the row's length the crowns fill (1 = side by side, more = overlapping: the back rows are denser), gap = the chance a place is left empty, w = the weights of the looks (Look number, 1-based).
ROWS = {
    'ForestTree': [
        dict(name='front', x=(104, 116), h=(104, 138), wmax=92, cover=1.25, gap=.05, w={1: 4, 2: 2, 3: 2, 5: 2, 6: 2, 7: 1}),
        dict(name='middle', x=(146, 186), h=(122, 160), wmax=100, cover=1.35, gap=.04, w={1: 3, 2: 1.5, 4: 2, 5: 2, 6: 1, 7: 2, 8: 2}),
        dict(name='back', x=(222, 276), h=(130, 172), wmax=110, cover=1.8, gap=.02, w={1: 2, 3: 1, 4: 1, 5: 1, 7: 3, 8: 3}),
    ],
    'JungleTree': [
        dict(name='front', x=(104, 118), h=(100, 134), wmax=100, cover=1.2, gap=.06, w={2: 3, 3: 2.5, 4: 2, 6: 2, 8: 2, 1: 1.5}),
        dict(name='middle', x=(148, 190), h=(122, 158), wmax=108, cover=1.3, gap=.05, w={1: 1.8, 2: 2, 5: 2, 6: 1, 7: 3, 8: 2}),
        dict(name='back', x=(226, 286), h=(130, 172), wmax=110, cover=1.8, gap=.02, w={2: 2, 7: 3, 8: 2, 3: 2, 5: 2, 6: 1}),
    ],
}
# Tint: the colour multiplier of a look (r, g, b in 0 - 255), then a few close shades each. The map's trees keep their own greens; the hub's greens are lighter, so they are taken down
# a little to sit with them (the jungle's go deeper: its own trees are darker).
TINTS = {
    'ForestTree': {1: (255, 252, 248), 2: (226, 234, 224), 3: (226, 234, 224), 4: (220, 230, 220), 5: (222, 232, 222), 6: (214, 226, 214), 7: (246, 252, 246), 8: (240, 250, 244)},
    'JungleTree': {1: (255, 252, 250), 2: (255, 252, 250), 3: (170, 205, 176), 4: (166, 200, 172), 5: (170, 205, 176), 6: (150, 190, 160), 7: (160, 200, 176), 8: (156, 196, 166)},
}
SEED = {'ForestTree': 158459, 'JungleTree': 158421}


def make(rng, key, row, look, side, hscale=1.0):
    label, parts, (sx, sy, sz) = PROTOS[key][look - 1]
    h = rng.uniform(*row['h']) * hscale
    h = round(min(h, row['wmax'] * sy / max(sx, sz) * rng.uniform(.88, 1.0)), 1)  # (a wide crown stops at the row's widest)
    k = h / sy
    w, d = math.ceil(sx * k * 10) / 10, math.ceil(sz * k * 10) / 10
    yaw = rng.randrange(0, 360)
    c, s = abs(math.cos(math.radians(yaw))), abs(math.sin(math.radians(yaw)))
    hx, hz = (w * c + d * s) / 2, (w * s + d * c) / 2
    tr, tg, tb = TINTS[key][look]
    tint = [min(255, max(0, round(v * rng.uniform(.95, 1.0)))) for v in (tr, tg, tb)]
    inner = rng.uniform(*row['x'])
    return dict(Key=key, Yaw=yaw, W=w, H=h, D=d, Tint=tint, Look=look, Row=row['name'], Parts=parts, hx=hx, hz=hz, side=side, X=side * round(max(inner + hx, MIN_X + hx + 5)))


def spots(key):
    rng = random.Random(SEED[key])
    name, z0, z1 = BIOMES[key]
    out = []
    for side in (-1, 1):
        for row in ROWS[key]:
            prev = None
            looks = list(row['w'].keys())
            bag = []
            zc = None
            while True:
                placed = None
                for attempt in range(14):
                    if not bag:  # a shuffled bag with each look as often as its weight says: every look turns up before one repeats
                        bag = [lk for lk in looks for _ in range(max(1, round(row['w'][lk])))]
                        rng.shuffle(bag)
                    look = bag.pop()
                    if look == prev and len(looks) > 1:
                        bag.insert(0, look)
                        continue
                    slim = [lk for lk in looks if PROTOS[key][lk - 1][2][0] / PROTOS[key][lk - 1][2][1] < .5]
                    if attempt >= 7 and slim:  # (the end of the row is near and the tree does not fit: a slim one will)
                        look = rng.choice(slim)
                    t = make(rng, key, row, look, side, 1.0 if attempt < 6 else .8)
                    if prev is None:
                        z = z0 + t['hz'] + rng.uniform(1, 9)
                    else:
                        z = zc + (prev_hz + t['hz']) / row['cover'] * rng.uniform(.82, 1.18)
                    t['Z'] = round(z)
                    # no two trees the same height (within 1 stud), no two trunks closer than 28 studs
                    if any(abs(o['H'] - t['H']) < 1.0 or math.hypot(o['X'] - t['X'], o['Z'] - t['Z']) < 28 for o in out):
                        continue
                    if z + t['hz'] <= z1 - 1:
                        placed = t
                        break
                if placed is None:
                    break
                prev, zc, prev_hz = placed['Look'], placed['Z'], placed['hz']
                if rng.random() > row['gap']:
                    out.append(placed)
    return out


def lua(s):
    return " {Key='%s',X=%d,Z=%d,Yaw=%d,W=%.1f,H=%.1f,D=%.1f,Tint={%d,%d,%d},Look=%d}," % (s['Key'], s['X'], s['Z'], s['Yaw'], s['W'], s['H'], s['D'], s['Tint'][0], s['Tint'][1], s['Tint'][2], s['Look'])


def main():
    allspots = {k: spots(k) for k in BIOMES}
    text = []
    for key, (name, z0, z1) in BIOMES.items():
        text.append(' -- %s: large trees on both sides in three bands (front, middle, back: taller and denser the further out); Look = the key\'s model (A.Game order)' % name)
        for side in (-1, 1):
            for row in ROWS[key]:
                for s in allspots[key]:
                    if s['side'] == side and s['Row'] == row['name']:
                        text.append(lua(s))
    for key, lst in allspots.items():
        by = {}
        for s in lst:
            by[s['Look']] = by.get(s['Look'], 0) + 1
        rows = {r['name']: sum(1 for s in lst if s['Row'] == r['name']) for r in ROWS[key]}
        print('%s: %d spots, %d parts, per side %s, rows %s, looks %s, heights %.0f - %.0f' % (key, len(lst), sum(s['Parts'] for s in lst), [sum(1 for s in lst if s['side'] == sd) for sd in (-1, 1)], rows, sorted(by.items()), min(s['H'] for s in lst), max(s['H'] for s in lst)))
    print('Forest + Jungle parts: %d' % sum(s['Parts'] for l in allspots.values() for s in l))
    if '--write' in sys.argv:
        src = open(ASSETS, encoding='utf-8').read().split('\n')
        a = src.index(BEGIN)
        b = src.index(END)
        src[a + 1:b] = text
        open(ASSETS, 'w', encoding='utf-8').write('\n'.join(src))
        print('wrote', ASSETS)
    else:
        print('\n'.join(text))


if __name__ == '__main__':
    main()
