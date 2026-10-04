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


def part(name, size, p, color=(200, 0, 0), r=I3, shape='Block', cls='Part', t=0, material='SmoothPlastic', faces=None, area='test', ltm=None, path=None):
    d = {'path': path or 'Workspace/' + name, 'name': name, 'class': cls, 'shape': shape, 'size': list(size), 'p': list(p), 'r': r,
         'color': list(color), 'material': material, 't': t, 'area': area}
    if ltm is not None:
        d['ltm'] = ltm
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
# 14. LocalTransparencyModifier (the R149 keyboard hides the real track floor and its decals on every client with 1): what is drawn is
# 1 - (1 - t) x (1 - ltm) for parts and for decals
check(abs(Z.effective_t(0, 1) - 1) < 1e-9 and abs(Z.effective_t(.5, .5) - .75) < 1e-9 and Z.effective_t(0, 0) == 0 and abs(Z.effective_t(.3, 0) - .3) < 1e-9 and Z.effective_t(1, 0) == 1,
      'effective transparency = 1 - (1 - t) x (1 - ltm)')
check(abs(Z.Part(0, part('H', (4, 2, 4), (0, 3, 0), t=.5, ltm=.5)).t - .75) < 1e-9, 'a part with t .5 and ltm .5 is drawn at .75')
fs, same = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200))])
check(any(x['faceA'] == 'Top' for x in fs), '(control: two coplanar boxes of different colours are found)')
fs, same = run([part('A', (4, 2, 4), (0, 3, 0), ltm=1), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200))])
check(not fs and not same, 'a part hidden with LocalTransparencyModifier 1 (t 0) is not drawn: nothing fights with it (' + str(tiers(fs)) + ')')
fs, same = run([part('A', (4, 2, 4), (0, 3, 0), ltm=.5), part('B', (4, 2, 4), (2, 3, 0), (0, 0, 200))])
check(any(x['faceA'] == 'Top' for x in fs), 'a half-hidden part (ltm .5) still draws, so it still fights')
fs, same = run([part('Hid', (200, 1, 200), (0, -0.5, 0), (80, 160, 80), ltm=1)])
check(not fs and not same, 'the keyboard\'s hidden floor on top of the map\'s own floor (same plane, both 200 x 200): not drawn, no finding')
fs, same = run([part('Floor2', (200, 1, 200), (0, -0.5, 0), (80, 160, 80))])
check(any(x['tier'] == 'coplanar' for x in fs + same), '(control: the same two floors without the modifier are coplanar)')
deco = [{'kind': 'Decal', 'face': 'Top', 'sig': 'grass', 't': 0, 'ltm': 1}]
fs, same = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), faces=deco)])
check(not fs and same, 'a decal hidden with its own LocalTransparencyModifier 1 does not make its face look different (look-alike)')
deco = [{'kind': 'Decal', 'face': 'Top', 'sig': 'grass', 't': 0, 'ltm': 0}]
fs, same = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), faces=deco)])
check(any(x['faceA'] == 'Top' for x in fs), '(control: the same decal without the modifier makes it differ)')
deco = [{'kind': 'Decal', 'face': 'Top', 'sig': 'grass', 't': .5, 'ltm': .5}]
fs, same = run([part('A', (4, 2, 4), (0, 3, 0)), part('B', (4, 2, 4), (2, 3, 0), faces=deco)])
check(any(x['faceA'] == 'Top' for x in fs), 'a decal drawn at .75 still counts as a decoration')

# 15. the keyboard fills the space under its floor: a bed (a Block called Bed, top at 2.4) with keycap meshes standing on it (tops 4.55, 0.5
# gaps) lies under the (hidden) floor; the rim and pit of a shovel hole lie 0.02 above the key tops, their undersides level
KB = 'Workspace/KeyboardTrackVisuals/'
bed = part('Bed', (180, 1, 180), (0, 1.9, 0), (60, 80, 60), path=KB + 'Bed/Bed')
keys = [part('Key', (7.68, 4.65, 7.68), (-86 + 8.18 * i, 2.225, -86 + 8.18 * j), (150, 200, 120), shape='Mesh', cls='MeshPart', path=KB + 'Keys/Key') for i in range(22) for j in range(22)]
cyl = rot_z(math.pi / 2)
hole = [part('Rim', (.04, 4, 4), (0, 4.59, 0), (100, 70, 40), r=cyl, shape='Cylinder', path='Workspace/TrackHoles/H/Rim'),
        part('Pit', (.08, 3.4, 3.4), (0, 4.61, 0), (40, 30, 20), r=cyl, shape='Cylinder', path='Workspace/TrackHoles/H/Pit')]
check(abs(keys[0]['p'][1] + 4.65 / 2 - 4.55) < 1e-9 and abs(hole[0]['p'][1] - .02 - 4.57) < 1e-9, '(the scene: key tops 4.55, hole undersides 4.57)')
fs, same = run(keys + [bed] + hole)
check(not [x for x in counted(fs) if x['faceA'] in ('Left', 'Right') and 'TrackHoles' in x['pathA']], 'a shovel hole\'s rim and pit undersides 0.02 above the key tops: no camera fits, not counted (' + str([x['faceA'] for x in counted(fs)]) + ')')
fs, same = run(hole)
check([x for x in counted(fs) if x['faceA'] in ('Left', 'Right') and 'TrackHoles' in x['pathA']], '(control: the same hole 0.57 above a plain floor: its undersides are found)')
# the real floor's undersides inside the keyboard (the floor slab y 3 .. 4 over the bed, 0.6 above its top) and a wall's: filled by keys
slab = part('GroundSlab', (180, 1, 180), (0, 3.5, 0), (80, 160, 80), ltm=0, path='Workspace/Map/Slab')
wall = part('Wall', (3, 1, 40), (0, 3.5, 0), (200, 200, 200), path='Workspace/Map/Wall')
fs, same = run(keys + [bed, slab, wall])
check(not [x for x in counted(fs) if x['faceA'] == 'Bottom'], 'two parts whose undersides (y 3.0) lie over the bed inside the keyboard: the keycaps fill that space, not counted (' + str([(x['pathA'], x['faceA']) for x in counted(fs)]) + ')')
bed2 = part('Bed', (180, 1, 180), (0, 1.9, 0), (60, 80, 60), path='Workspace/Elsewhere/Bed')
fs, same = run([bed2, slab, wall])
check([x for x in counted(fs) if x['faceA'] == 'Bottom'], '(control: the same slab and wall over a plain block 0.6 below: their undersides count)')
# above the key layer there is room: an awning 3 studs above the key tops is still checked
aw1 = part('Aw1', (4, .2, 4), (0, 7.6, 0), path='Workspace/Awning/A1')
aw2 = part('Aw2', (4, .2, 4), (2, 7.6, 0), (0, 0, 200), path='Workspace/Awning/A2')
fs, same = run(keys + [bed, aw1, aw2])
check([x for x in counted(fs) if x['faceA'] == 'Bottom'], 'an awning 3 studs above the key tops: a camera fits under it, still counted')
# beside the keyboard (outside the bed's rectangle) nothing is filled
aw3 = part('Aw3', (4, .2, 4), (94, 3, 0), path='Workspace/Awning/A3')
aw4 = part('Aw4', (4, .2, 4), (96, 3, 0), (0, 0, 200), path='Workspace/Awning/A4')
fs, same = run(keys + [bed, aw3, aw4])
check([x for x in counted(fs) if x['faceA'] == 'Bottom'], 'beside the keyboard the space under a face is free (3 studs up over the floor): counted')
print('%d checks, %d failed' % (checks, fails))
sys.exit(1 if fails else 0)
