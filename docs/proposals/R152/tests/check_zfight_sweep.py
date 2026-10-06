"""R152 whole-game z-fighting sweep: the checks run_zfight_sweep.sh makes on the scenes it builds (R149's detector, docs/proposals/R149/tools/zfight.py, all tiers; R152 owner:
"after finishing implementation and fixes look for z fighting cases fix them").
Usage: python3 check_zfight_sweep.py maps    <world dir> NAME [NAME ...]   the whole map as players see it, with the hub decor, the hub displays, the Void giveaway pedestal and the
                                                                          keyboard around a runner (scenes <world>/NAME.json, built by run_variant.sh)
       python3 check_zfight_sweep.py verity  <dump.txt>                    the Verity pack (dump_verity_zscene.luau)
       python3 check_zfight_sweep.py opening <dump.txt>                    the pack-opening scenes (dump_opening_zscene.luau)
Every subcommand exits 1 when a counted finding is left (coplanar / near / far: two visible faces that look different, point the same way, overlap and lie within the depth buffer's
reach of each other: 0.02 stud for a small overlap up to 0.043 at 300 studs) that is not on the short list of things that are not ours (ALLOWED below, each with its reason), when two
Decals / Textures with the same ZIndex stack on one face of a part, or when the explicit R152 layer gaps are not kept (see each subcommand).
MESHES: R149's check left every MeshPart pair "for others". Here a MeshPart is its bounding box (the keycap, the pouch, a keeper's body) and a pair with one is counted like any other:
the keyboard's letter strips on its keys were exactly that."""
import collections, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

R15 = {'Head', 'UpperTorso', 'LowerTorso', 'LeftUpperArm', 'LeftLowerArm', 'LeftHand', 'RightUpperArm', 'RightLowerArm', 'RightHand', 'LeftUpperLeg', 'LeftLowerLeg', 'LeftFoot',
       'RightUpperLeg', 'RightLowerLeg', 'RightFoot', 'HumanoidRootPart'}
MIN_GAP = 0.049      # the layers R152 stacks (strip over key, rings over cracks ...) stand this far apart: the depth rule's .043 plus the quantisation


def allowed(f):
    """Why a counted finding is not ours (None = it is)."""
    a, b = f['pathA'], f['pathB']
    if 'GuardianNPCPlaceholder' in a and 'GuardianNPCPlaceholder' in b:
        return 'the place file\'s saved keeper placeholders (old uploaded bodies: the server dresses a real keeper over each, ChaseService / BeastModels)'
    for key in ('/Market fruit/', '/Market plant/', '/Hanging lantern/', '/Market seed pack/'):
        if key in a and key in b and a.split(key)[0] == b.split(key)[0]:
            return 'the market showcase\'s approved plant art (PlantArt*: same-size crystals, colours 8 - 9 / 255 apart)'
    if 'HubDisplays151' in a and 'HubDisplays151' in b and a.rsplit('/', 1)[-1] in R15 and b.rsplit('/', 1)[-1] in R15:
        return 'Roblox\'s own R15 avatar rig (a mock here; its limbs share a skin)'
    if 'Snow' in a.rsplit('/', 1)[-1] and 'Snow' in b.rsplit('/', 1)[-1] and ('_Snow' in a or 'Weather' in a):
        return 'SnowPatches149 discs (R149 weather)'
    return None


def counted(f):
    return f['tier'] in Z.COUNTED and not f['same_look']


def short(p):
    return p.replace('Workspace/ChestChaseMap/', '').replace('Workspace/', '')


def report(fs, label):
    """Prints the counted findings grouped; returns the ones that are ours."""
    ours, left = [], collections.Counter()
    for f in fs:
        if not counted(f):
            continue
        why = allowed(f)
        if why:
            left[why] += 1
        else:
            ours.append(f)
    g = collections.OrderedDict()
    for f in ours:
        g.setdefault((f['tier'], short(f['pathA']).rsplit('/', 1)[-1] + '.' + f['faceA'], short(f['pathB']).rsplit('/', 1)[-1] + '.' + f['faceB'], round(f['offset'], 3)), []).append(f)
    for k, lst in list(g.items())[:25]:
        f = lst[0]
        print('  FLICKER %-8s x%-4d off=%+.4f area=%7.2f %s <-> %s (%s) at %s' % (k[0], len(lst), f['offset'], max(x['area'] for x in lst), k[1], k[2], label, f['at']))
    for why, n in left.items():
        print('  not ours: %3d  %s' % (n, why))
    return ours


def stacked_faces(parts_json, label):
    """Two Decals / Textures with the same ZIndex on one face of one part draw in no fixed order: they flicker (a ZIndex per layer is what the treadmill's belt textures use)."""
    bad = []
    for p in parts_json:
        fc = collections.defaultdict(list)
        for x in p.get('faces', []):
            if x.get('kind') in ('Decal', 'Texture') and Z.effective_t(x.get('t', 0), x.get('ltm', 0)) < Z.VISIBLE_T:
                fc[(x['face'], x.get('z', 1))].append(x)
        for (face, z), lst in fc.items():
            if len(lst) > 1:
                bad.append('%s: %s carries %d images on its %s face at ZIndex %s (%s)' % (label, short(p['path']), len(lst), face, z, ', '.join(x.get('name', '?') for x in lst)))
    return bad


# ---- maps -----------------------------------------------------------------------------------------------------------------------------------
def top_of(p):
    """The highest point of a part (its half extent along world Y from its rotation)."""
    r, sz = p['r'][1], p['size']
    return p['p'][1] + (abs(r[0]) * sz[0] + abs(r[1]) * sz[1] + abs(r[2]) * sz[2]) / 2


def cmd_maps(world, names):
    sys.path.insert(0, HERE)
    import check_hub_zfight as H  # noqa: E402
    bad = 0
    nkeys = nstrips = nfar = nbars = npatch = 0
    stripgap = []
    for n in names:
        path = os.path.join(world, n + '.json')
        parts, fs = Z.run(path)
        raw = json.load(open(path))['parts']
        vis = [f for f in fs if not f['same_look']]
        print('== %s: %d parts, %d visible findings, counted %d' % (n, len(parts), len(vis), sum(1 for f in vis if counted(f))))
        ours = report(vis, n)
        bad += len(ours)
        st = stacked_faces(raw, n)
        for s in st:
            print('  STACKED', s)
        bad += len(st)
        keys = [p for p in raw if '/KeyboardTrackVisuals/Keys/' in p['path'] and p['name'] == 'Key' and p['t'] < 0.98]
        strips = [p for p in raw if '/Legends/' in p['path'] and p['name'] == 'LegendStrip' and abs(p['p'][1]) < 100]
        fars = [p for p in raw if '/Legends/' in p['path'] and p['name'] == 'LegendFar' and abs(p['p'][1]) < 100]
        bars = [p for p in raw if p['name'] == 'Spacebar' and '/KeyboardTrackVisuals/' in p['path'] and abs(p['p'][1]) < 100]
        patches = [p for p in raw if p['name'] == 'GroundPatch']
        nkeys += len(keys); nstrips += len(strips); nfar += len(fars); nbars += len(bars); npatch += len(patches)
        if keys:
            rest = collections.Counter(round(top_of(k), 3) for k in keys).most_common(1)[0][0]
            for p in strips + fars:
                stripgap.append(top_of(p) - rest)
        if n == names[0]:
            a = H.analyse(path, 0.1)
            counted_decor, tight_bad = a[3], a[6]
            print('  hub decor (R152, check_hub_zfight): counted with a decor part %d, tight (< 0.1 stud) decor <-> decor / saved wall %d' % (len(counted_decor), len(tight_bad)))
            bad += len(counted_decor) + len(tight_bad)
    print('keyboard: %d keys, %d near strips, %d far strips, %d spacebars, %d local floor copies across %d scenes' % (nkeys, nstrips, nfar, nbars, npatch, len(names)))
    if nkeys < 500 or nstrips < 50 or nfar < 100 or nbars < 3 or npatch < 1:
        print('  FAIL: the sweep saw too little of the keyboard (keys %d strips %d far %d bars %d patches %d)' % (nkeys, nstrips, nfar, nbars, npatch))
        bad += 1
    if stripgap:
        lo = min(stripgap)
        print('keyboard: every letter strip stands at least %.4f stud above the resting key top (%d strips; the depth rule wants %.3f)' % (lo, len(stripgap), MIN_GAP))
        if lo < MIN_GAP:
            print('  FAIL: a letter strip is only %.4f above its keys' % lo)
            bad += 1
    print('R152 whole-map z-fighting: %s' % ('PASS' if bad == 0 else 'FAIL (%d)' % bad))
    return 1 if bad else 0


# ---- verity ---------------------------------------------------------------------------------------------------------------------------------
def scenes_of(dump):
    for l in open(dump, encoding='utf-8').read().split('\n'):
        if l.startswith('SCENE '):
            name, js = l[6:].split(' ', 1)
            yield name, js


def cmd_verity(dump):
    bad = 0
    n = 0
    tmp = dump + '.scene.json'
    for name, js in scenes_of(dump):
        n += 1
        open(tmp, 'w', encoding='utf-8').write(js)
        parts, fs = Z.run(tmp)
        raw = json.loads(js)['parts']
        vis = [f for f in fs if not f['same_look']]
        ours = report(vis, name)
        if ours:
            print('  in scene', name)
        bad += len(ours)
        for s in stacked_faces(raw, name):
            print('  STACKED', s)
            bad += 1
        pouch = [p for p in raw if p['class'] == 'MeshPart']
        deco = [(x['face'], x['kind']) for p in (pouch if not name.startswith('sachet') else [q for q in raw if q['name'] == 'VerityFace']) for x in p.get('faces', [])]
        if name.startswith('sachet'):
            continue
        if len(pouch) != 1 or sorted(deco) != [('Back', 'Decal'), ('Front', 'Decal')]:
            print('  FAIL: %s: the pouch should be one MeshPart with exactly a Front and a Back Decal (%d MeshParts, %s)' % (name, len(pouch), deco))
            bad += 1
    os.remove(tmp)
    print('Verity pack: %d scenes (ground, held R15 / R6, picture; sizes .5 / 1 / 25; plain, Gold, Diamond; and the sachet fallback): %s' % (n, 'PASS' if bad == 0 and n >= 24 else 'FAIL (%d)' % bad))
    return 1 if bad or n < 24 else 0


# ---- opening --------------------------------------------------------------------------------------------------------------------------------
def cmd_opening(dump):
    bad = 0
    n = 0
    tmp = dump + '.scene.json'
    heights = collections.defaultdict(list)    # layer gaps seen: name of the check -> smallest gap
    for name, js in scenes_of(dump):
        n += 1
        open(tmp, 'w', encoding='utf-8').write(js)
        parts, fs = Z.run(tmp)
        raw = json.loads(js)['parts']
        vis = [f for f in fs if not f['same_look']]
        ours = [f for f in vis if counted(f) and allowed(f) is None and ('_RarePullStage' in f['pathA'] + f['pathB'] or 'Sky beam' in f['pathA'] + f['pathB'] or 'RevealFlourish' in f['pathA'] + f['pathB'])]
        if ours:
            for f in ours[:3]:
                print('  FLICKER %s: %s off=%+.4f %s.%s <-> %s.%s at %s' % (name, f['tier'], f['offset'], short(f['pathA']).rsplit('/', 1)[-1], f['faceA'], short(f['pathB']).rsplit('/', 1)[-1], f['faceB'], f['at']))
        bad += len(ours)
        for s in stacked_faces(raw, name):
            print('  STACKED', s)
            bad += 1
        # the explicit layer gaps (a frame in which the two layers do not overlap cannot show the flicker, so the heights are checked in every frame)
        by = collections.defaultdict(list)
        for p in raw:
            by[p['name']].append(p)
        # (the dump's beam foot is at 10, 4, 20 on a floor whose top is 4: a ring not yet placed sits at the origin, below the floor, and is not in the world)
        placed = lambda p: p['p'][1] > 3.9
        crack = [top_of(p) for p in by.get('Ground crack', []) if p['t'] < 0.98 and placed(p)]
        ring1 = [top_of(p) for p in by.get('Shockwave', []) if p['t'] < 0.98 and 'Sky beam' in p['path'] and placed(p)]
        ring2 = [top_of(p) for p in by.get('Shockwave glow', []) if p['t'] < 0.98 and 'Sky beam' in p['path'] and placed(p)]
        gui1 = [top_of(p) for p in by.get('Shockwave', []) if 'Sky beam' in p['path'] and p.get('faces') and placed(p)]
        gui2 = [top_of(p) for p in by.get('Shockwave glow', []) if 'Sky beam' in p['path'] and p.get('faces') and placed(p)]
        r1, r2 = ring1 + gui1, ring2 + gui2
        if crack and (r1 or r2):
            for other, lab in ((r1, 'ring over the cracks'), (r2, 'glow ring over the cracks')):
                if other:
                    heights[lab].append(min(other) - max(crack))
        if r1 and r2:
            heights['glow ring over the white ring'].append(min(r2) - max(r1))
        fl = [p for p in raw if 'RevealFlourish' in p['path'] and p['name'] == 'Shockwave' and p['t'] < 0.98]
        if fl:
            levels = sorted({round(top_of(p), 4) for p in fl})
            if len(levels) > 1:
                heights['Mythic flourish: second ring over the first'].append(min(b - a for a, b in zip(levels, levels[1:])))
        rim = [p for p in raw if p['name'] == 'Rim glow' and '_RarePullStage' in p['path']]
        rune = [p for p in raw if p['name'] == 'Rune circle' and '_RarePullStage' in p['path']]
        if rim and rune:
            heights['void vault: rim glow over the rune circle'].append(top_of(rim[0]) - top_of(rune[0]))
    for lab, gaps in sorted(heights.items()):
        lo = min(gaps)
        ok = lo >= MIN_GAP
        print('opening: %-45s least gap %.4f stud over %d frames: %s' % (lab, lo, len(gaps), 'ok' if ok else 'TOO CLOSE (the depth rule wants %.3f)' % MIN_GAP))
        bad += 0 if ok else 1
    need = {'ring over the cracks', 'glow ring over the cracks', 'glow ring over the white ring', 'Mythic flourish: second ring over the first', 'void vault: rim glow over the rune circle'}
    for lab in sorted(need - set(heights)):
        print('  FAIL: the sweep never saw: %s' % lab)
        bad += 1
    os.remove(tmp)
    print('pack-opening scenes: %d scenes (story stages with / without images and lite, the sky beam at 3 tiers, the flourish at 3 scales): %s' % (n, 'PASS' if bad == 0 else 'FAIL (%d)' % bad))
    return 1 if bad else 0


if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'maps':
        sys.exit(cmd_maps(sys.argv[2], sys.argv[3:]))
    if len(sys.argv) == 3 and sys.argv[1] == 'verity':
        sys.exit(cmd_verity(sys.argv[2]))
    if len(sys.argv) == 3 and sys.argv[1] == 'opening':
        sys.exit(cmd_opening(sys.argv[2]))
    print(__doc__)
    sys.exit(2)
