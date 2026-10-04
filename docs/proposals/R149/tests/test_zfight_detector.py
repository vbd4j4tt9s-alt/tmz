"""R149: the z-fighting detector (tools/zfight.py) on small hand-made scenes whose answer is known.
Usage: python3 test_zfight_detector.py        (prints one line per failed check and a summary; exit 1 on failure)"""
import json, math, os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import zfight as Z  # noqa: E402

fails = checks = 0


def check(c, msg):
    global fails, checks
    checks += 1
    if not c:
        fails += 1
        print('FAIL: ' + msg)


I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def part(name, size, p, color=(200, 0, 0), r=I3, shape='Block', cls='Part', t=0, material='SmoothPlastic', faces=None, area='test'):
    d = {'path': 'Workspace/' + name, 'name': name, 'class': cls, 'shape': shape, 'size': list(size), 'p': list(p), 'r': r,
         'color': list(color), 'material': material, 't': t, 'area': area}
    if faces:
        d['faces'] = faces
    return d


FLOOR = part('Floor', (200, 1, 200), (0, -0.5, 0), (80, 160, 80))


def run(parts, playable=None):
    scene = {'parts': [FLOOR] + parts}
    if playable:
        scene['playable'] = playable
    f = tempfile.NamedTemporaryFile('w', suffix='.json', delete=False)
    json.dump(scene, f); f.close()
    try:
        _, fs = Z.run(f.name)
    finally:
        os.unlink(f.name)
    return [x for x in fs if not x['same_look']], [x for x in fs if x['same_look']]


def tiers(fs):
    return sorted(x['tier'] for x in fs)


def counted(fs):
    return [x for x in fs if x['tier'] in ('coplanar', 'near', 'far')]


# 1. two boxes on the floor, tops in the same plane, overlapping, different colours: coplanar
fs, _ = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200))])
check(any(x['tier'] == 'coplanar' and {x['faceA'], x['faceB']} == {'Top'} for x in fs), 'coplanar tops are found')
check(any(x['tier'] == 'coplanar' and x['faceA'] == 'Bottom' for x in fs), 'their undersides (1 stud of room above the floor) too')
check(any(x['tier'] == 'coplanar' and x['faceA'] in ('Front', 'Back') for x in fs), 'and their front / back faces')
check(all(abs(x['area'] - 8) < .6 or x['faceA'] not in ('Top',) for x in fs), 'the overlap area is 2 x 4 = 8 for the tops')
# 2. the same colour and material: the flicker is invisible (listed apart), unless a decal makes one face different
fs, same = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0))])
check(not fs and same, 'same colour + material: look-alike, not counted')
fs, same = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), faces=[{'kind': 'Decal', 'face': 'Top', 'sig': 'x', 't': 0}])])
check(any(x['faceA'] == 'Top' and x['faceB'] == 'Top' for x in fs), 'a decal on one of the two top faces makes them differ: counted')
fs, _ = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), (201, 1, 0))])
check(not fs, 'colours within 1/255 (rounding): look-alike')
fs, _ = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), (204, 3, 2))])
check(fs, 'colours 4/255 apart: counted (a faint flicker is still a flicker)')
# 3. a part resting on another (opposite faces) never fights
fs, _ = run([part('Plate', (4, .2, 4), (0, .1, 0), (0, 0, 200))])
check(not counted(fs), 'a plate resting on the floor: its bottom and the floor top face opposite ways, its top is .2 up')
check(not any(x['faceA'] == 'Bottom' or x['faceB'] == 'Bottom' for x in fs), 'and its underside lies on the floor: no camera can look at it')
# 4. thin decal plates above the floor: .01 = near, .03 over a big plate = far, .03 small = fine, .2 = fine (strict only)
fs, _ = run([part('Decal01', (40, .2, 40), (0, -.09, 0), (0, 0, 200))])
check(tiers(fs) == ['near'], 'a big plate .01 above the floor top: near (' + str(tiers(fs)) + ')')
fs, _ = run([part('Decal03', (40, .2, 40), (0, -.07, 0), (0, 0, 200))])
check(tiers(fs) == ['far'], 'a 40-stud plate .03 above the floor: far, seen from 300 studs (' + str(tiers(fs)) + ')')
fs, _ = run([part('Small03', (2, .2, 2), (0, -.07, 0), (0, 0, 200))])
check(counted(fs) == [], 'a 2-stud plate .03 above the floor: fine (' + str(tiers(fs)) + ')')
fs, _ = run([part('Decal20', (40, .4, 40), (0, 0, 0), (0, 0, 200))])
check(tiers(fs) == ['strict'], 'a 40-stud plate .2 above the floor: only the strict 0.002 x D rule reports it (' + str(tiers(fs)) + ')')
# 5. hidden overlaps: a third solid covering the shared face hides it
fs, _ = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200)), part('Lid', (10, 1, 10), (1, 4.5, 0), (90, 90, 90))])
check(not any(x['faceA'] == 'Top' for x in fs), 'a lid lying on both tops hides their coplanar overlap')
# 6. rotation: a 30-degree turned pair still found; a 1-degree tilt between faces is not "the same plane"
fs, _ = run([part('A', (4, 2, 4), (0, 3, 0), r=rot_y(.5)), part('B', (4, 2, 4), (1, 3, 1), (0, 0, 200), r=rot_y(.5))])
check(any(x['tier'] == 'coplanar' and x['faceA'] == 'Top' for x in fs), 'turned parts: coplanar tops found')
fs, _ = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200), r=rot_z(math.radians(1)))])
check(not any(x['faceA'] == 'Top' for x in fs), 'a 1-degree tilt: not coplanar')
# 7. wedges: the slope, the back and the triangle sides are faces; two overlapping wedges share their side triangles
fs, _ = run([part('W1', (2, 4, 8), (0, 2, 0), shape='Wedge', cls='WedgePart'), part('W2', (2, 4, 8), (0, 2, 2), (0, 0, 200), shape='Wedge', cls='WedgePart')])
check(any(x['faceA'] in ('Right', 'Left') and x['tier'] == 'coplanar' for x in fs), 'overlapping wedges: coplanar side triangles')
check(any(x['faceA'] == 'Top' and x['tier'] == 'coplanar' for x in fs) is False, 'their slopes are parallel but 2 studs apart along the run, not coplanar here')
# 8. cylinders: two coaxial equal cylinders overlapping; end discs in one plane
cyl = rot_z(math.pi / 2)  # axis X -> up
fs, _ = run([part('C1', (2, 3, 3), (0, 1, 0), r=cyl, shape='Cylinder'), part('C2', (2, 3, 3), (0, 1.5, 0), (0, 0, 200), r=cyl, shape='Cylinder')])
check(any(x['faceA'] == 'Side' for x in fs), 'coaxial equal cylinders: their round sides fight')
fs, _ = run([part('D1', (.2, 3, 3), (0, 1.1, 0), r=cyl, shape='Cylinder'), part('D2', (.4, 2, 2), (0, 1.0, 0), (0, 0, 200), r=cyl, shape='Cylinder')])
check(any(x['tier'] == 'coplanar' and x['faceA'] in ('Right', 'Left') for x in fs), 'two discs with their tops at 1.2: coplanar end caps')
fs, _ = run([part('D1', (.2, 3, 3), (4, 1.1, 4), r=cyl, shape='Cylinder'), part('Sq', (.2, 3, 3), (6.9, 1.1, 4), (0, 0, 200))])
check(not any(x['faceA'] == 'Top' or x['faceB'] == 'Top' for x in fs), 'a disc and a square whose boxes overlap only outside the disc: nothing')
# 9. balls: concentric equal balls fight, a ball touching a plane does not
fs, _ = run([part('B1', (2, 2, 2), (0, 3, 0), shape='Ball'), part('B2', (2, 2, 2), (0, 3, 0), (0, 0, 200), shape='Ball')])
check(any(x['faceA'] == 'Sphere' for x in fs), 'two equal concentric balls fight')
fs, _ = run([part('B1', (2, 2, 2), (0, 1, 0), shape='Ball')])
check(not fs, 'a ball resting on the floor: nothing')
# 10. meshes: bounding faces are reported apart
fs, _ = run([part('M', (4, 2, 4), (0, 3, 0), shape='Mesh', cls='MeshPart'), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200))])
check(fs and all(x['mesh'] for x in fs), 'a MeshPart pair is flagged as mesh (its real surface may not reach its box)')
# 11. a see-through part carrying a SurfaceGui still draws it
gui = [{'kind': 'SurfaceGui', 'face': 'Top', 'sig': 'gui:x', 't': 0}]
fs, _ = run([part('Sign', (4, .2, 4), (0, -.1, 0), (255, 255, 255), t=1, faces=gui)])
check(any(x['tier'] == 'coplanar' for x in fs), 'an invisible part with a SurfaceGui on its top, level with the floor: the GUI fights the floor')
# 12. the map's outer edge: a face whose front lies outside every playable box is never seen
fs, _ = run([part('Wall', (2, 6, 20), (11, 3, 0)), part('Trim', (2, 1, 20), (11, 6, 0), (0, 0, 200))], playable=[[-10, -100, 10, 100]])
check(not any(x['faceA'] == 'Right' for x in fs), 'outer faces of a wall at the edge of the playable area are not counted')
check(any(x['faceA'] == 'Left' for x in fs), 'its inner faces are')
# 13. downward faces need camera room: an awning 3 studs up counts, a plate .3 above a step does not
fs, _ = run([part('Aw1', (4, .2, 4), (0, 3, 0)), part('Aw2', (4, .2, 4), (2, 3, 0), (0, 0, 200))])
check(any(x['faceA'] == 'Bottom' for x in fs), 'undersides 2.9 studs above the floor: counted')
fs, _ = run([part('Lo1', (4, .2, 4), (0, .4, 0)), part('Lo2', (4, .2, 4), (2, .4, 0), (0, 0, 200))])
check(not any(x['faceA'] == 'Bottom' for x in fs), 'undersides .3 above the floor: no camera fits under them')
print('%d checks, %d failed' % (checks, fails))
sys.exit(1 if fails else 0)
