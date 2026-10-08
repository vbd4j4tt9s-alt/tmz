"""R153: is every part of a pack attached to its REAL pouch?

The R151 audit (docs/proposals/R151/tests/check_packs.py) read every pouch MeshPart as its Size box. The box of a design is not its pouch: the print
stands out of the front (the leaf relief of Forest_01 reaches z = -.574 where the pouch itself is -.42 at its middle and -.13 at a corner), so a part
that sits on the box's front face can hang far in front of the pouch. Here the pouch is the real one (pouch_mesh.Pouch).

attached(scene, pouch, tol)  ->  {index: gap} for every visible part that is NOT attached, and the gap of every part to the pouch
  * a part is attached when one of its surface samples is within `tol` of the pouch surface (or inside it), or when it touches (check_packs.inside,
    grown by `tol`) an attached part;
  * a part that MOVES (a VoidSpin / MechMotion part: the Void's galaxy arms, halo and debris, the Mech's servos) can attach a part only through
    the static ones: a star held only by a spinning arm would hang in the air the rest of the time. Moving parts themselves must touch a static
    attached part in their rest pose (the arms turn in their own plane about the singularity, over discs centred on it).
  * the pouch's own MeshParts and the hidden root are not parts here (scene parts with class MeshPart are the pouch).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R151', 'tests'))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import check_packs as C  # noqa: E402


def samples(p):
    """check_packs' surface samples, plus the two end discs of a Cylinder (a thin disc is all end face: its rim alone misses what it lies on)."""
    q = C.world_samples(p)
    if p['shape'] == 'Cylinder':
        sx, sy, sz = p['size']; r = min(sy, sz) / 2; extra = []
        for k in range(6):
            rr = r * k / 5
            n = 1 if k == 0 else 6 * k
            for a in range(n):
                th = 2 * math.pi * a / n
                for x in (-sx / 2, sx / 2):
                    extra.append((x, rr * math.cos(th), rr * math.sin(th)))
        R, c = C.frame(p)
        q = np.concatenate([q, np.array(extra) @ R.T + c])
    return q


def visible(scene):
    return [p for p in scene['parts'] if p.get('t', 0) < .95 and p['class'] != 'MeshPart']


def attached(scene, pouch, tol=.03, parts=None):
    parts = parts if parts is not None else visible(scene)
    n = len(parts)
    pts = [samples(p) for p in parts]
    gaps = [pouch.gap(q) for q in pts]
    moving = [bool(p.get('fx')) for p in parts]
    ok = [(not moving[i]) and gaps[i] <= tol for i in range(n)]
    centers = np.array([p['p'] for p in parts]) if n else np.zeros((0, 3))
    radii = np.array([np.linalg.norm(p['size']) / 2 for p in parts]) if n else np.zeros(0)
    touch = {}

    def touches(a, b):
        key = (min(a, b), max(a, b))
        if key not in touch:
            if np.linalg.norm(centers[a] - centers[b]) > radii[a] + radii[b] + tol:
                touch[key] = False
            else:
                touch[key] = bool(C.inside(parts[b], pts[a], tol).any() or C.inside(parts[a], pts[b], tol).any())
        return touch[key]
    changed = True
    while changed:  # static parts first: grow the attached set through static parts only
        changed = False
        for a in range(n):
            if ok[a] or moving[a]:
                continue
            for b in range(n):
                if ok[b] and not moving[b] and touches(a, b):
                    ok[a] = True; changed = True; break
    for a in range(n):  # then every moving part must rest on an attached static part (or on the pouch itself)
        if moving[a]:
            ok[a] = gaps[a] <= tol or any(ok[b] and not moving[b] and touches(a, b) for b in range(n))
    return {i: gaps[i] for i in range(n) if not ok[i]}, gaps, parts
