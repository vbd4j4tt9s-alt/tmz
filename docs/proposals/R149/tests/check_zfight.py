"""R149: z-fighting before / after on the whole map (scenes from zfight_scene.luau) and the pass / fail rule of run_zfight.sh.
Usage: python3 check_zfight.py <label> <before scene.json> <after scene.json> [<label> <before> <after> ...]

Prints, per scene, the counted findings (coplanar + near + far, see tools/zfight.py) per area before and after, and the
strict-rule column. FAILS when an AFTER scene still has a counted finding that is ours to fix. Not ours (listed, not failed):
  * mesh pairs (MeshParts: only their bounding boxes are known here; the keepers' bodies),
  * anything drawn by KeyboardTrack.client.lua (Workspace.KeyboardTrackVisuals; the file is being changed by another agent),
  * pairs inside ONE showcase fruit / plant model (their parts come from PlantArt* / ApprovedPlantArt*, other agents' files),
  * pairs between two of SnowPatches149's discs (Workspace._SnowBiomeR149 / weather snow; R149 weather work)."""
import collections, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import zfight as Z  # noqa: E402


def owner(f):
    a, b = f['pathA'], f['pathB']
    if f['mesh']:
        return 'mesh'
    if 'KeyboardTrackVisuals' in a or 'KeyboardTrackVisuals' in b:
        return 'KeyboardTrack.client.lua'
    for key in ('/Market fruit/', '/Market plant/', '/Hanging lantern/', '/Market seed pack/'):
        if key in a and key in b and a.split(key)[0] == b.split(key)[0]:
            ma = a.split('/MarketShowcase/')[-1].split('/')[0]
            if ma:
                return 'fruit / plant art (PlantArt*, ApprovedPlantArt*)'
    if 'Snow' in a.rsplit('/', 1)[-1] and 'Snow' in b.rsplit('/', 1)[-1] and ('_Snow' in a or 'Weather' in a):
        return 'SnowPatches149 (R149 weather)'
    return None


def counted(f):
    return f['tier'] in Z.COUNTED and not f['same_look']


def table(fs):
    rows = collections.defaultdict(collections.Counter)
    for f in fs:
        if f['same_look']:
            continue
        rows[f['area_label']]['counted' if counted(f) else f['tier']] += 1
    return rows


def main():
    args = sys.argv[1:]
    bad = 0
    for i in range(0, len(args), 3):
        label, before, after = args[i:i + 3]
        _, fb = Z.run(before)
        _, fa = Z.run(after)
        tb, ta = table(fb), table(fa)
        print('== %s: counted findings (coplanar + near + far, meshes included) per area, before -> after; strict-rule-only in brackets' % label)
        tot = [0, 0, 0, 0]
        for area in sorted(set(tb) | set(ta)):
            b, a = tb[area], ta[area]
            print('  %-24s %4d -> %-4d   [%4d -> %4d]' % (area, b['counted'], a['counted'], b['strict'], a['strict']))
            tot[0] += b['counted']; tot[1] += a['counted']; tot[2] += b['strict']; tot[3] += a['strict']
        print('  %-24s %4d -> %-4d   [%4d -> %4d]' % ('TOTAL', tot[0], tot[1], tot[2], tot[3]))
        left = collections.Counter(); ours = []
        for f in fa:
            if not counted(f):
                continue
            o = owner(f)
            if o:
                left[o] += 1
            else:
                ours.append(f)
        for o, n in sorted(left.items()):
            print('  left for others: %-50s %d' % (o, n))
        for f in ours:
            print('  STILL Z-FIGHTING: %s %s off=%+.4f area=%.2f  %s.%s <-> %s.%s at %s' % (f['tier'], f['area_label'], f['offset'], f['area'],
                  f['pathA'], f['faceA'], f['pathB'], f['faceB'], f['at']))
        bad += len(ours)
        print('  %s: %d counted findings left that are ours' % (label, len(ours)))
    print('z-fighting check: %s' % ('PASS' if bad == 0 else 'FAIL (%d)' % bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
