"""R153 refresh barrier z-fighting check: the finished hub with the track closed (run_barrier_zfight.sh: the real start-up builders, the R152 rook gate, the blackout
cover and the barrier MapService:SetBiomeRefreshing builds) through the R149 detector (docs/proposals/R149/tools/zfight.py, all tiers).
Usage: python3 check_barrier_zfight.py <scene.json> [--tight 0.1] [--list N]
Prints every finding that involves the barrier (Workspace/ChestChaseMap/_GameplayRuntime/BiomeRefreshWall) and, apart, the ones that involve the blackout cover behind it:
  counted   coplanar / near / far (|offset| under 4 steps of a 24-bit depth buffer at the distance the overlap is seen from, 0.02 - 0.043): must be ZERO
  tight     the 'strict' tier under --tight (default 0.1 stud, the hub decor's own rule): must be ZERO
Exits 1 when there is one, or when the barrier is not in the scene (nothing was checked)."""
import argparse, collections, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

WALL = '/BiomeRefreshWall'
COVER = '/TrackRefreshBlackout/'


def short(p):
    p = p.replace('Workspace/ChestChaseMap/', '').replace('Workspace/', '')
    parts = p.split('/')
    return parts[0] + '/' + parts[-1] if len(parts) > 2 else p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('scene')
    ap.add_argument('--tight', type=float, default=0.1)
    ap.add_argument('--list', type=int, default=20)
    a = ap.parse_args()
    parts, fs = Z.run(a.scene)
    walls = [p for p in parts if p.path.endswith(WALL)]
    gate = [p for p in parts if '/HubDecor151/Gate/' in p.path]
    covers = [p for p in parts if COVER in p.path]
    print('scene: %d parts, the barrier %d (%s), the gate %d parts, the blackout cover %d parts' % (len(parts), len(walls), ', '.join('%.1f x %.1f x %.1f' % tuple(p.size) for p in walls), len(gate), len(covers)))
    if len(walls) != 1 or len(gate) < 60:
        print('FAIL: the closed track is not in the scene (nothing was checked)')
        return 1
    vis = [f for f in fs if not f['same_look']]
    mine = [f for f in vis if WALL in f['pathA'] or WALL in f['pathB']]
    counted = [f for f in mine if f['tier'] in Z.COUNTED]
    tight = [f for f in mine if f['tier'] == 'strict' and abs(f['offset']) < a.tight]
    near_cover = [f for f in vis if (COVER in f['pathA'] or COVER in f['pathB']) and f['tier'] in Z.COUNTED]
    for title, lst in (('counted', counted), ('tight', tight), ('cover (counted)', near_cover)):
        g = collections.OrderedDict()
        for f in lst:
            g.setdefault((short(f['pathA']) + '.' + f['faceA'], short(f['pathB']) + '.' + f['faceB']), []).append(f)
        for k, v in list(g.items())[:a.list]:
            f = v[0]
            print('   %-15s x%-3d off=%+.4f area=%6.2f %s <-> %s at %s' % (title, len(v), f['offset'], f['area'], k[0], k[1], f['at']))
    print('barrier: %d visible findings with it, counted %d, tight (< %.2f) %d; blackout cover: %d counted' % (len(mine), len(counted), a.tight, len(tight), len(near_cover)))
    bad = len(counted) + len(tight)
    print('R153 barrier z-fighting: %s' % ('NONE' if bad == 0 else '%d findings' % bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
