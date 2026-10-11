"""R154 hub z-fighting, the STRICT HUB MODE (owner: "remove the cases of z fighting in the hub area too").
Usage: python3 check_hub_zfight154.py [--saved place.json] [--json out.json] [--list N] [--tight N] NAME=scene.json [NAME=scene.json ...]
R149's detector (docs/proposals/R149/tools/zfight.py) on scenes of the whole hub (build_hub154.sh: the plaza, streets, market, the bases' fronts, the gate
run-up, the corners and nooks, the hub displays, the giveaway pedestal, the client's trees / lawns / lamps, and the blizzard's drifts). Unlike the R152
sweep, EVERY pair whose overlap lies in the hub counts, whoever made the parts - the saved place, a server builder or a client builder - and a pair of
faces that look alike counts too when the material carries a texture (Grass, Slate, Metal, Brick ...: Roblox lays a material's texture out from each
part's own position, so two overlapping parts in one plane show their textures flickering through each other even in one colour). Only look-alike
faces of an untextured material (SmoothPlastic, Neon, Glass, ForceField, no Studs) cannot show anything.
A pair is VISIBLE (and fails) when it is one of those and its two planes are closer than the depth rule allows: R149's coplanar / near / far tiers
(4 steps of a 24-bit depth buffer at the distance the overlap still covers ~8 pixels, 0.02 stud up to 0.043 at 300 studs), and, for an overlap wide
enough to be seen from that 300-stud cap, R152's 0.049 (the rule's 0.043 plus the quantisation). The short list ALLOWED below (each with its reason)
is printed apart. Two Decals / Textures with one ZIndex on a face of a hub part also fail (R152's stacked check).
Every pair is listed with where it is (the street / plaza / base / building its overlap lies in, and x, y, z), ranked by how visible it is:
  score = overlap area x facing (1 up: flat ground seen across the square, .6 sideways, .3 down) x height (1 up to 10 studs over the ground, falling
          off above heads) x contrast (the colour difference / 255, 1 for another material or decal; .5 for a textured look-alike).
"tight" (informational): the pairs the rule accepts that are still under 0.1 stud apart (the designed paving steps, the run-up lanes ...).
--saved: the place file's own parts (rbxl_geom.py <place> out.json Workspace/ChestChaseMap) to tell saved parts from built ones in the list.
Exits 1 when a visible pair is left that is not allowed."""
import argparse, collections, json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R152', 'tests'))
import zfight as Z  # noqa: E402
import check_zfight_sweep as SW  # noqa: E402  (R152: allowed(), stacked_faces())

HUB = (-340.0, -623.0, 340.0, -99.0)     # the lobby floor inside the hub walls (x0, z0, x1, z1)
MIN_GAP = SW.MIN_GAP                      # .049
CAP_LIMIT = Z.DEPTH_K * Z.FAR_CAP ** 2    # .0429: the depth rule at the 300-stud cap
UNTEXTURED = {'SmoothPlastic', 'Neon', 'Glass', 'ForceField'}   # (Plastic carries a faint surface texture: counted, to be safe)
TIGHT = 0.1


def inhub(f):
    x, _, z = f['at']
    return HUB[0] <= x <= HUB[2] and HUB[1] <= z <= HUB[3]


def short(p):
    return p.replace('Workspace/ChestChaseMap/', '').replace('Workspace/', '')


R15 = SW.R15


def allowed(f):
    """Why a visible pair is not one to fix (None = it is). R152's list without its weather line: the hub's blizzard drifts are checked here."""
    a, b = f['pathA'], f['pathB']
    for key in ('/Market fruit/', '/Market plant/', '/Hanging lantern/', '/Market seed pack/'):
        if key in a and key in b and a.split(key)[0] == b.split(key)[0]:
            return 'the market showcase\'s approved plant art (PlantArt*: same-size crystals, colours 8 - 9 / 255 apart, 0.11 stud2 each)'
    if 'HubDisplays151' in a and 'HubDisplays151' in b:
        na, nb = a.rsplit('/', 1)[-1], b.rsplit('/', 1)[-1]
        if na in R15 and nb in R15:
            return 'Roblox\'s own R15 avatar rig on the hub displays (a mock here; its limbs share a skin)'
        if na == 'Handle' or nb == 'Handle':
            return 'the hub avatar\'s accessories (Roblox\'s own; stand-ins on the mock)'
    return None


class Hub:
    def __init__(self, path, saved):
        d = json.load(open(path))
        self.raw = d['parts']
        self.parts, self.fs = Z.run(path)
        self.saved = saved
        self.areas = []
        for p in self.raw:  # named places a pair can lie in (smallest first)
            sp = short(p['path'])
            label = None
            if '/Paths/' in p['path'] and 'HubDecor151' in p['path']:
                label = p['name']
            elif p['name'] == 'Pad' and '/Bases/' in p['path']:
                label = sp.split('/')[1].replace('_', ' ') + ' (pad)'
            elif p['name'] in ('Market deck',) or '/MarketShowcase/' in p['path']:
                label = 'market'
            elif 'VerityNPC' in p['path'] and p['name'] == 'Dais':
                label = 'Verity\'s dais'
            elif 'HubTrampolines153' in p['path']:
                label = 'trampoline nook'
            elif 'VoidGiveaway152' in p['path']:
                label = 'giveaway pedestal'
            elif 'HubDisplays151' in p['path']:
                label = 'hub display ' + ('(best pull)' if 'BestPull' in p['path'] else '(biggest fruit)')
            elif 'GeneratedHubScenery' in p['path']:
                label = 'leaderboard'
            elif '/Gate/' in p['path'] and 'HubDecor151' in p['path']:
                label = 'track gate'
            elif '/Walls/' in p['path'] and 'HubDecor151' in p['path'] or 'ChestChaseWalls' in p['path']:
                label = 'hub wall'
            if label:
                x0, z0, x1, z1 = self.box(p)
                self.areas.append(((x1 - x0) * (z1 - z0), x0, z0, x1, z1, label, p))
        self.areas.sort(key=lambda a: a[0])

    @staticmethod
    def box(p):
        r, s, c = p['r'], p['size'], p['p']
        if len(r) == 9:
            r = [r[0:3], r[3:6], r[6:9]]
        hx = (abs(r[0][0]) * s[0] + abs(r[0][1]) * s[1] + abs(r[0][2]) * s[2]) / 2
        hz = (abs(r[2][0]) * s[0] + abs(r[2][1]) * s[1] + abs(r[2][2]) * s[2]) / 2
        return c[0] - hx, c[2] - hz, c[0] + hx, c[2] + hz

    def where(self, f):
        x, y, z = f['at']
        for a in self.areas:
            if a[1] - .5 <= x <= a[3] + .5 and a[2] - .5 <= z <= a[4] + .5:
                return a[5]
        best = None
        for a in self.areas:
            d = math.hypot(max(a[1] - x, 0, x - a[3]), max(a[2] - z, 0, z - a[4]))
            if best is None or d < best[0]:
                best = (d, a[5])
        return 'lawn / floor %.0f studs from %s' % best if best and best[0] < 60 else 'open floor'

    def origin(self, path):
        if self.saved is None:
            return '?'
        return 'saved' if path in self.saved else 'built'


def studs_on(raw, face):
    return raw.get('studs') == face


def classify(hub, f):
    """kind: 'look' (two different looks), 'texture' (look-alike on a textured material), 'plain' (look-alike, untextured: nothing to see)."""
    pa, pb = hub.raw[f['a']], hub.raw[f['b']]
    sa, sb = studs_on(pa, f['faceA']), studs_on(pb, f['faceB'])
    if not f['same_look'] or sa != sb:
        return 'look'
    if pa.get('material') not in UNTEXTURED or pb.get('material') not in UNTEXTURED or sa or sb:
        return 'texture'
    return 'plain'


def limit(f):
    lim = f.get('far_limit') or Z.NEAR
    return MIN_GAP if lim >= CAP_LIMIT - 1e-3 else lim


def score(hub, f, kind):
    n = f['normal']
    face = 1.0 if n[1] > .7 else (.3 if n[1] < -.7 else .6)
    h = f['at'][1]
    height = 1.0 / (1.0 + max(0.0, h - 14.0) / 10.0)
    contrast = .5 if kind == 'texture' else (0 if kind == 'plain' else max(.25, f.get('contrast', 255) / 255.0))
    return f['area'] * face * height * contrast


def analyse(name, path, saved):
    hub = Hub(path, saved)
    rows = []
    for f in hub.fs:
        if not inhub(f):
            continue
        kind = classify(hub, f)
        off = abs(f['offset'])
        vis = kind != 'plain' and off < limit(f)
        tight = kind != 'plain' and not vis and off < TIGHT
        oa, ob = hub.origin(f['pathA']), hub.origin(f['pathB'])
        rows.append({'scene': name, 'kind': kind, 'visible': vis, 'tight': tight, 'tier': f['tier'], 'offset': f['offset'], 'area': f['area'],
                     'limit': round(limit(f), 4), 'at': f['at'], 'where': hub.where(f), 'a': short(f['pathA']), 'faceA': f['faceA'], 'b': short(f['pathB']),
                     'faceB': f['faceB'], 'origin': '+'.join(sorted((oa, ob), reverse=True)), 'allowed': allowed(f), 'score': round(score(hub, f, kind), 2),
                     'normal': f['normal'], 'matA': hub.raw[f['a']].get('material'), 'matB': hub.raw[f['b']].get('material')})
    stacked = [s for s in SW.stacked_faces([p for p in hub.raw if HUB[0] <= p['p'][0] <= HUB[2] and HUB[1] <= p['p'][2] <= HUB[3]], name)]
    return rows, stacked, len(hub.parts)


def gen(p):
    parts = p.split('/')
    return '/'.join(parts[:2]) + '/../' + parts[-1] if len(parts) > 3 else p


def group(rows):
    g = collections.OrderedDict()
    for r in sorted(rows, key=lambda r: -r['score']):
        k = (r['kind'], r['tier'], gen(r['a']) + '.' + r['faceA'], gen(r['b']) + '.' + r['faceB'], round(r['offset'], 3))
        g.setdefault(k, []).append(r)
    return g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('scenes', nargs='+')
    ap.add_argument('--saved')
    ap.add_argument('--json')
    ap.add_argument('--list', type=int, default=60)
    ap.add_argument('--tight', type=int, default=40)
    a = ap.parse_args()
    saved = None
    if a.saved:
        saved = {p['path'] for p in json.load(open(a.saved))['parts']}
    allrows, bad = [], 0
    for spec in a.scenes:
        name, path = spec.split('=', 1)
        rows, stacked, nparts = analyse(name, path, saved)
        allrows += rows
        c = collections.Counter((r['kind'], 'visible' if r['visible'] else ('tight' if r['tight'] else 'safe')) for r in rows)
        print('== %s: %d parts, %d pairs in the hub: visible %d (different look %d, textured look-alike %d), tight %d, depth-safe %d, untextured look-alike %d'
              % (name, nparts, len(rows), c[('look', 'visible')] + c[('texture', 'visible')], c[('look', 'visible')], c[('texture', 'visible')],
                 c[('look', 'tight')] + c[('texture', 'tight')], c[('look', 'safe')] + c[('texture', 'safe')], sum(v for k, v in c.items() if k[0] == 'plain')))
        for s in stacked:
            print('  STACKED', s)
        bad += len(stacked)
    seen, uniq = set(), []
    for r in allrows:  # one row per pair of faces (the blizzard scenes repeat the hub's own pairs)
        k = (r['a'], r['faceA'], r['b'], r['faceB'], tuple(round(c, 1) for c in r['at']))
        if k not in seen:
            seen.add(k)
            uniq.append(r)
    allrows = uniq
    print('%d different pairs in the hub over the scenes' % len(allrows))
    vis = [r for r in allrows if r['visible'] and not r['allowed']]
    ok = [r for r in allrows if r['visible'] and r['allowed']]
    tight = [r for r in allrows if r['tight']]
    by = collections.Counter((r['kind'], r['origin']) for r in vis)
    print('visible hub pairs (fail): %d  [%s]' % (len(vis), ', '.join('%s %s: %d' % (k[0], k[1], v) for k, v in sorted(by.items()))))
    for k, lst in list(group(vis).items())[:a.list]:
        r = lst[0]
        print('  FLICKER %-7s %-8s x%-3d score=%8.2f off=%+.4f (needs %.3f) area=%7.2f %s.%s [%s] <-> %s.%s [%s] (%s) in %s at %s' % (
            r['kind'], r['tier'], len(lst), sum(x['score'] for x in lst), r['offset'], r['limit'], max(x['area'] for x in lst), k[2], '', r['matA'], k[3], '', r['matB'],
            r['origin'], r['where'], r['at']))
    reasons = collections.Counter(r['allowed'] for r in ok)
    for why, n in reasons.items():
        print('  allowed: %3d  %s' % (n, why))
    print('tight (the depth rule accepts them; under %.2f stud apart): %d' % (TIGHT, len(tight)))
    for k, lst in list(group(tight).items())[:a.tight]:
        r = lst[0]
        print('  tight   %-7s x%-3d score=%8.2f off=%+.4f area=%7.2f %s <-> %s (%s) in %s at %s' % (r['kind'], len(lst), sum(x['score'] for x in lst), r['offset'],
              max(x['area'] for x in lst), k[2], k[3], r['origin'], r['where'], r['at']))
    if a.json:
        json.dump(allrows, open(a.json, 'w'), indent=0)
    bad += len(vis)
    print('R154 hub z-fighting (strict hub mode): %s' % ('PASS' if bad == 0 else 'FAIL (%d)' % bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
