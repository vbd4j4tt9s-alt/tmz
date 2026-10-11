"""R153: where the Void pack's corner details have to sit to be ON its pouch (EclipsePackArt.Seats).

Usage: python3 void_seats.py <scenes.txt> <src dir>     (scenes.txt: "SCENE {...}" lines of dump_packs.luau / dump_pack_parts.luau with a "Void" scene)

The Void's print is drawn on two flat sheets, one in front of each face of the Forest_01 pouch at the BOX's face (EclipsePackArt: body.MinZ - .02 /
body.MaxZ + .02). The box's front is the tip of the pouch's raised leaf print (z = -.574); the pouch itself curves away to -.42 at its middle and
-.08 .. -.31 under the corners. The middle of each sheet (nebula, singularity, photon ring, accretion disc, eye) rests on that leaf print, but the
corner details (rune sigils, and the stars / specks that do not overlap the nebula) touch nothing: they hung .16 - .46 in front of / behind the pouch.

For every such detail GROUP (a rune's three strokes, a star's two bars, a speck) this prints the pouch's surface under it: the outward distance of
the surface's highest point (front: -min z, back: max z) over the group's footprint, at scale 1. EclipsePackArt seats the group's back face on that
point (a hair inside: .004), keeping its x / y, size, turn and colour, so it reads exactly the same from the front. The highest point is used so no
part of the group sinks into the pouch; where the corner curves away under a group the far edge stands off by the curve (at most ~.1 under a rune).
Only groups that are NOT attached through the sheet are listed (attach.py): the others already rest on the sheet and stay there.
"""
import collections
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import attach  # noqa: E402
import pouch_mesh  # noqa: E402

GROUP = re.compile(r'^(?:(StarV|StarH)([FB])(\d+)|StarSpeck([FB])(\d+)|RuneSigil([FB])(\d+)_\d+)$')


def group_of(name):
    m = GROUP.match(name)
    if not m:
        return None
    if m.group(1):
        return (m.group(2), 'Star', int(m.group(3)))
    if m.group(4):
        return (m.group(4), 'Speck', int(m.group(5)))
    return (m.group(6), 'Rune', int(m.group(7)))


def seats(scene, pouch, tol=.03):
    loose, gaps, parts = attached(scene, pouch, tol)
    groups = collections.defaultdict(list)
    for i, p in enumerate(parts):
        g = group_of(p['name'])
        if g:
            groups[g].append(i)
    out = {}
    for g, idx in sorted(groups.items()):
        if not any(i in loose for i in idx):
            continue
        pts = np.concatenate([attach.samples(parts[i]) for i in idx])
        back = g[0] == 'B'
        s = pouch.surface(pts[:, 0], pts[:, 1], back)
        out[g] = float(np.nanmax(s)) if back else float(-np.nanmin(s))
    return out, loose, gaps, parts


def attached(scene, pouch, tol):
    return attach.attached(scene, pouch, tol)


def main():
    scenes, src = sys.argv[1], sys.argv[2]
    void = None
    for line in open(scenes, encoding='utf-8'):
        if line.startswith('SCENE '):
            sc = json.loads(line[6:])
            if sc['label'] == 'Void':
                void = sc
    assert void, 'no Void scene'
    pouch = pouch_mesh.Pouch(src, 'Forest_01')
    table, loose, gaps, parts = seats(void, pouch)
    by = collections.defaultdict(dict)
    for (side, kind, i), s in table.items():
        by[(side, kind)][i] = s
    for side in ('F', 'B'):
        print(side, '{' + ','.join('%s={%s}' % (kind, ','.join('[%d]=%.3f' % (i, by[(side, kind)][i]) for i in sorted(by[(side, kind)]))) for kind in ('Star', 'Speck', 'Rune') if by[(side, kind)]) + '}')


if __name__ == '__main__':
    main()
