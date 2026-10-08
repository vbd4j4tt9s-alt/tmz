"""R153: is every part of every pack attached to its REAL pouch? (the geometric half of the pack-parts suite)

Usage: python3 check_pack_parts.py <scenes.txt> <src dir> [--templates pack_templates.luau] [--expect-floating | --seats]

1. THE POUCH IS REAL. For every design with native render data (all 42), the union of its components (tools/pouch_mesh.py) has exactly the box of its
   template's MeshParts (pack_templates.luau, the owner's place: every Size and PackLocalFrame) to 1e-4, and its BagBody closes on the seam plane: both
   crimp rows at z = 0 (+-.012), y = 1.02 / -1.04, x +-.95 - exactly where SeedPackVisuals.Bag puts the 8 tear strips and the seal.
2. EVERY SCENE'S POUCH IS WHERE THE DATA IS DRAWN: each MeshPart of a scene (dump_pack_parts.luau) sits on its template's PackLocalFrame (1e-4).
3. NOTHING HANGS OFF IT (tools/attach.py): every visible part is within .03 of the pouch's surface or touches, through static parts, one that is.
   Known and not counted: the Void's event-horizon halo and its debris (EventHorizon*, HaloDebris*: R122's ring that hangs round the pack on purpose and
   spins). The MECH pack (R153 look B, MechPackArt153) is COUNTED, on its own body: Body 'MechPouch' (the generated flat pouch: the scene's `pouch`
   triangles) or 'MechSachet' (the plain-parts sachet: its Sachet* parts are the body), never Forest_01's mesh.
   --expect-floating   the base side of the suite: exit 0 only if some part that is not on the known list floats in a scene that is not the Mech's
                       (the R152 Void corner details; the R152 Mech's own floating parts are printed too).
--seats      ONLY this: <src dir>'s EclipsePackArt.Seats equals what void_seats.py computes from the pouch for the Void details that float WITHOUT a seat (give
             it a scene of the base code, where nothing is seated): within .002.
Exit 1 on any failure."""
import json
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import attach  # noqa: E402
import pouch_mesh  # noqa: E402
C = attach.C  # (R151 check_packs: part frames)

KNOWN = [(r'^Void', r'^(EventHorizon|HaloDebris)\d', 'the R122 event-horizon halo and its debris hang round the pack on purpose (they spin)')]


class MeshPouch(pouch_mesh.Pouch):
    """a pouch given as triangles [(name, vertices, faces)] in the scene's frame (pouch_mesh.Pouch's surface and gap on them)."""
    def __init__(self, key, parts):
        self.key = key; self.parts = parts; self.body = None; self._hm = None
        allv = np.concatenate([v for _, v, _ in parts]); self.lo, self.hi = allv.min(0), allv.max(0)


def solid(p):
    """a sachet body part as triangles in the scene's frame: a Block's box, a Cylinder (16 sides, along its X), a WedgePart (Roblox's wedge)."""
    R, c = C.frame(p); sx, sy, sz = np.array(p['size'], float) / 2
    if p['shape'] == 'Cylinder':
        n = 16; r = min(sy, sz); a = 2 * np.pi * np.arange(n) / n
        v = [[x, r * math.cos(t), r * math.sin(t)] for x in (-sx, sx) for t in a] + [[-sx, 0, 0], [sx, 0, 0]]
        f = [[k, (k + 1) % n, n + k] for k in range(n)] + [[(k + 1) % n, n + (k + 1) % n, n + k] for k in range(n)]
        f += [[2 * n, (k + 1) % n, k] for k in range(n)] + [[2 * n + 1, n + k, n + (k + 1) % n] for k in range(n)]
    elif p['class'] == 'WedgePart':  # bottom (y-) and back (z+) full, the slope from the top-back edge to the bottom-front one
        v = [[x, -sy, -sz] for x in (-sx, sx)] + [[x, -sy, sz] for x in (-sx, sx)] + [[x, sy, sz] for x in (-sx, sx)]
        f = [[0, 1, 3], [0, 3, 2], [2, 3, 5], [2, 5, 4], [0, 4, 5], [0, 5, 1], [0, 2, 4], [1, 5, 3]]
    else:
        v = [[x, y, z] for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        f = [[0, 1, 3], [0, 3, 2], [4, 5, 7], [4, 7, 6], [0, 1, 5], [0, 5, 4], [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 3, 7], [1, 7, 5]]
    return (p['name'], np.array(v, float) @ R.T + c, np.array(f, int))


def mech_body(sc):
    """(the Mech's own pouch surface, its visible parts that are not the body): R153 look B"""
    if sc['attrs']['Body'] == 'MechPouch':
        return MeshPouch('MechPouch', [('pouch', np.array(sc['pouch']['v'], float), np.array(sc['pouch']['f'], int))]), attach.visible(sc)
    body = [p for p in attach.visible(sc) if p['name'].startswith('Sachet')]
    return MeshPouch('MechSachet', [solid(p) for p in body]), [p for p in attach.visible(sc) if not p['name'].startswith('Sachet')]


def templates(path):
    s = open(path, encoding='utf-8').read(); out = {}
    for m in re.finditer(r'\{"([A-Za-z]+_\d\d)",\{(.*?)\n \}\}', s, re.S):
        rows = {}
        for r in re.finditer(r'n="([^"]+)",s=\{([^}]*)\},p=\{([^}]*)\},r=\{([^}]*)\}', m.group(2)):
            rows[r.group(1)] = (np.array(list(map(float, r.group(2).split(',')))), np.array(list(map(float, r.group(3).split(',')))),
                                np.array(list(map(float, r.group(4).split(',')))).reshape(3, 3))
        out[m.group(1)] = rows
    return out


def known(label, name):
    return next((why for l, n, why in KNOWN if re.search(l, label) and re.search(n, name)), None)


def check_seats(scenes, src):
    import void_seats
    void = next(sc for sc in scenes if sc['label'] == 'Void')
    table = void_seats.seats(void, pouch_mesh.Pouch(src, 'Forest_01'))[0]
    lua = open(os.path.join(src, 'ReplicatedStorage', 'EclipsePackArt.lua'), encoding='utf-8').read()
    have = {}
    for side, body in re.findall(r'^ (F|B)=\{(.*?)\},?$', lua, re.M):
        for kind, items in re.findall(r'(Star|Speck|Rune)=\{([^}]*)\}', body):
            for i, v in re.findall(r'\[(\d+)\]=([.\d]+)', items):
                have[(side, kind, int(i))] = float(v)
    diff = [(g, table.get(g), have.get(g)) for g in sorted(set(table) | set(have)) if g not in table or g not in have or abs(table[g] - have[g]) > .002]
    for g, want, got in diff:
        print('FAIL: EclipsePackArt.Seats %s: the pouch says %s, the table %s' % (g, want, got))
    print('the Void seats: %d details float when nothing is seated (%s); EclipsePackArt.Seats holds exactly their pouch depths (within .002): %s' % (
        len(table), ' '.join('%s%s%d' % g for g in sorted(table)), 'yes' if not diff and table else 'NO'))
    return 0 if not diff and table else 1


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    scenes_path, src = args[0], args[1]
    tpath = sys.argv[sys.argv.index('--templates') + 1] if '--templates' in sys.argv else os.path.join(HERE, '..', '..', 'R151', 'tests', 'pack_templates.luau')
    if '--templates' in sys.argv:
        args.remove(tpath)
    T = templates(tpath)
    if '--seats' in sys.argv:
        sys.exit(check_seats([json.loads(l[6:]) for l in open(scenes_path, encoding='utf-8') if l.startswith('SCENE ')], src))
    bad = 0
    # 1. the native render data IS the pouch the place draws
    worst_box = 0.0; worst_seam = 0.0; pouches = {}
    for key, rows in sorted(T.items()):
        P = pouch_mesh.Pouch(src, key); pouches[key] = P
        lo = np.min([p - np.abs(r) @ s / 2 for s, p, r in rows.values()], 0); hi = np.max([p + np.abs(r) @ s / 2 for s, p, r in rows.values()], 0)
        d = float(max(np.abs(P.lo - lo).max(), np.abs(P.hi - hi).max())); worst_box = max(worst_box, d)
        top, bot = P.crimps()
        seam = max(abs(top[:, 2].max() + top[:, 2].min()) / 2, abs(bot[:, 2].max() + bot[:, 2].min()) / 2, abs(top[:, 1].max() - 1.02), abs(bot[:, 1].min() + 1.04),
                   abs(top[:, 0].max() - .95), abs(top[:, 0].min() + .95), abs(bot[:, 0].max() - .95), abs(bot[:, 0].min() + .95))
        worst_seam = max(worst_seam, seam)
        if d > 1e-4:
            bad += 1; print('FAIL: %s: the native render data is not the template\'s box (off by %.5f)' % (key, d))
        if seam > 1e-4 or top[:, 2].max() - top[:, 2].min() > .03:
            bad += 1; print('FAIL: %s: its pouch does not close on the seam plane where the seal and strips are (%.4f)' % (key, seam))
    print('the pouch: %d designs, the native render data has the template\'s box (worst %.1e) and every pouch closes at z = 0, y = 1.02 / -1.04, x +-.95 (worst %.1e)' % (len(T), worst_box, worst_seam))
    # 2. + 3. every scene
    scenes = [json.loads(l[6:]) for l in open(scenes_path, encoding='utf-8') if l.startswith('SCENE ')]
    floating_unknown = 0; floating_base = 0; listed = {}
    for sc in scenes:
        key = sc['attrs'].get('Body') or sc['attrs']['Key']
        if key in ('MechPouch', 'MechSachet'):  # (R153 Mech look B: its own body, see mech_body)
            P, own = mech_body(sc)
            loose, gaps, parts = attach.attached(sc, P, parts=own)
        else:
            rows = T[key]; P = pouches[key]
            for p in sc['parts']:
                if p['class'] != 'MeshPart':
                    continue
                s, pos, r = rows[p['name']]
                dp = float(np.abs(np.array(p['p']) - pos).max()); dr = float(np.abs(np.array(p['r']) - r).max())
                if dp > 1e-4 or dr > 1e-4:
                    bad += 1; print('FAIL: %s: %s is not on its template frame (%.5f, %.5f)' % (sc['label'], p['name'], dp, dr))
            loose, gaps, parts = attach.attached(sc, P)
        for i, g in sorted(loose.items(), key=lambda kv: -kv[1]):
            why = known(sc['label'], parts[i]['name'])
            if why:
                listed.setdefault((sc['label'], why), []).append((parts[i]['name'], g))
            else:
                floating_unknown += 1; floating_base += 0 if sc['label'].startswith('Mech') else 1
                if not '--expect-floating' in sys.argv:
                    print('FAIL: %s: %s hangs %.3f off the pouch and touches nothing that is on it' % (sc['label'], parts[i]['name'], g))
                else:
                    print('floats (base): %s: %s %.3f' % (sc['label'], parts[i]['name'], g))
        vis = len(parts); far = max([g for i, g in enumerate(gaps) if i not in loose] or [0])
        print('%-16s %3d parts: %d not attached (%d known), the farthest attached part is %.3f off the pouch (held by the parts it touches)' % (
            sc['label'], vis, len(loose), sum(1 for i in loose if known(sc['label'], parts[i]['name'])), far))
    for (label, why), items in sorted(listed.items()):
        names = sorted(set(re.sub(r'([FB-]?\d[\d._-]*)$', '', n) for n, _ in items))
        print('  listed, not counted: %s: %d parts (%s), %.2f - %.2f off: %s' % (label, len(items), ', '.join(names), min(g for _, g in items), max(g for _, g in items), why))
    if '--expect-floating' in sys.argv:
        print('base: %d parts float that are not on the known list, %d outside the Mech (expected some: the R152 Void corner details)' % (floating_unknown, floating_base))
        sys.exit(0 if floating_base > 0 and bad == 0 else 1)
    bad += floating_unknown
    print('pack parts (real pouch): %d scenes, %d failures' % (len(scenes), bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
