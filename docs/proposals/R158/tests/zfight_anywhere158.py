"""R158 z-fighting with the camera ANYWHERE (the design's own stricter rule: docs/proposals/R158/design/make158.py zfight).
Usage: python3 zfight_anywhere158.py <scene.json> [report.txt]      (a scene built by run_variant.sh: the owner's place after every REAL start-up pass, MapService.new included)

R149's detector (docs/proposals/R149/tools/zfight.py, the R152 sweep's rules) normally only counts faces a camera on the lobby floor or inside the track's walls can be in front of. The new parts
are also seen from the track over the walls, and a zoomed-out camera can be outside them, so here the playable boxes are the whole world: every pair of visible faces that point the same way,
overlap, look different and lie within the depth buffer's reach counts, when one of the two is a new part (TrackWalls158, TrackBackdrops158, BaseWalls158) or one of the walls the pass
re-coloured (Obby/BiomeWalls). Look-alike pairs (same colour and material: no visible flicker) are listed apart. Exits 1 when one is left."""
import collections, json, os, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

NEW = ('/TrackWalls158/', '/TrackBackdrops158/', '/BaseWalls158/', '/Biome4_Landmark/')
WALLS = '/Obby/BiomeWalls/'


def main():
    scene = json.load(open(sys.argv[1]))
    scene['playable'] = [[-3000, -700, 3000, 7000]]
    tmp = os.path.join(tempfile.mkdtemp(), 'anywhere.json')
    json.dump(scene, open(tmp, 'w'))
    parts, fs = Z.run(tmp)
    os.remove(tmp)
    n158 = sum(1 for p in scene['parts'] if any(k in p['path'] for k in NEW))
    ours = [f for f in fs if any(k in f['pathA'] or k in f['pathB'] for k in NEW) or WALLS in f['pathA'] or WALLS in f['pathB']]
    counted = [f for f in ours if f['tier'] in Z.COUNTED and not f['same_look']]
    alike = [f for f in ours if f['tier'] in Z.COUNTED and f['same_look']]
    lines = ['%d parts in the scene, %d of them new (walls, backdrops, base caps, the new volcano): counted %d, look-alike (no visible flicker) %d' % (len(parts), n158, len(counted), len(alike))]
    groups = collections.OrderedDict()
    for f in counted:
        k = (f['tier'], f['pathA'].split('ChestChaseMap/')[-1].rsplit('/', 1)[-1] + '.' + f['faceA'], f['pathB'].split('ChestChaseMap/')[-1].rsplit('/', 1)[-1] + '.' + f['faceB'])
        groups.setdefault(k, []).append(f)
    for (tier, a, b), lst in list(groups.items())[:40]:
        f = lst[0]
        lines.append('  FLICKER %-8s x%-3d off=%+.4f area=%.2f %s <-> %s at %s' % (tier, len(lst), f['offset'], f['area'], a, b, f['at']))
    lines.append('R158 z-fighting (camera anywhere): %s' % ('PASS' if not counted else 'FAIL (%d)' % len(counted)))
    txt = '\n'.join(lines)
    print(txt)
    if len(sys.argv) > 2:
        open(sys.argv[2], 'w').write(txt + '\n')
    return 1 if counted else 0


if __name__ == '__main__':
    sys.exit(main())
