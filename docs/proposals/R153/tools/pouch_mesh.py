"""R153: the REAL pouch geometry of a pack design, for the geometric checks.

The pouch MeshParts of the 42 designs are uploaded assets (MeshId only in the place file), but each was made from the design's V120 native
render data, which the checkout still ships: src/ReplicatedStorage/SeedPackArt<Biome><NN>.lua (Snow_06 in two chunks, 06A / 06B), every
component as V = "x,y,z,..." (1/10000 stud, the PACK's frame at scale 1) and F = "a,b,c,..." (1-based, per component). The union of a design's
components has EXACTLY the bounding box of its template's MeshParts (every Size / PackLocalFrame of pack_templates.luau, to 1e-4, for all 41
designs that have native data; checked by check_pack_parts.py), so this is the pouch as the game draws it, not a box.

  Pouch(src, key)         every component of the design (pack frame, scale 1)
  .body                   the BagBody component (the pouch itself: y -1.04 .. 1.02, its crimp rows at z = 0)
  .height()               front (min z) / back (max z) surface of the union on a 0.01 grid
  .gap(points)            distance (pack units) from the nearest point of `points` to the pouch's surface; 0 when a point is inside
"""
import glob
import os
import re

import numpy as np

STEP, X0, X1, Y0, Y1 = .01, -1.7, 1.7, -1.4, 2.0
_NAME = re.compile(r'SeedPackArt([A-Za-z]+?)(\d\d)([AB]?)\.lua$')
_COMP = re.compile(r'\{Name="([^"]+)",V="([^"]*)"(.*?)F="([^"]*)"', re.S)


def design_files(src, key):
    out = []
    for f in sorted(glob.glob(os.path.join(src, 'ReplicatedStorage', 'SeedPackArt*.lua'))):
        m = _NAME.search(os.path.basename(f))
        if m and '%s_%s' % (m.group(1), m.group(2)) == key:
            out.append(f)
    return out


def components(src, key):
    out = []
    for f in design_files(src, key):
        for m in _COMP.finditer(open(f, encoding='utf-8').read()):
            if not m.group(2):
                continue
            v = np.array(list(map(int, m.group(2).split(','))), float).reshape(-1, 3) / 1e4
            fc = np.array(list(map(int, m.group(4).split(','))), int).reshape(-1, 3) - 1 if m.group(4) else np.zeros((0, 3), int)
            out.append((m.group(1), v, fc))
    return out


class Pouch:
    def __init__(self, src, key):
        self.key = key
        self.parts = components(src, key)
        if not self.parts:
            raise ValueError('no native render data for ' + key)
        self.body = next((v for n, v, f in self.parts if n == 'BagBody'), None)
        allv = np.concatenate([v for _, v, _ in self.parts])
        self.lo, self.hi = allv.min(0), allv.max(0)
        self._hm = None

    def crimps(self):
        """(top row, bottom row) of the BagBody: the vertices at its highest / lowest y (where the strips / seal close it)."""
        b = self.body
        top, bot = b[:, 1].max(), b[:, 1].min()
        return b[np.abs(b[:, 1] - top) < 1e-9], b[np.abs(b[:, 1] - bot) < 1e-9]

    def height(self):
        if self._hm is not None:
            return self._hm
        xs = np.arange(X0, X1 + 1e-9, STEP); ys = np.arange(Y0, Y1 + 1e-9, STEP)
        F = np.full((len(ys), len(xs)), np.inf); B = np.full((len(ys), len(xs)), -np.inf)
        for _, v, fc in self.parts:
            for t in fc:
                if t.max() >= len(v):
                    continue
                a, b, c = v[t[0]], v[t[1]], v[t[2]]
                i0 = int(np.ceil((min(a[0], b[0], c[0]) - X0) / STEP - 1e-9)); i1 = int(np.floor((max(a[0], b[0], c[0]) - X0) / STEP + 1e-9))
                j0 = int(np.ceil((min(a[1], b[1], c[1]) - Y0) / STEP - 1e-9)); j1 = int(np.floor((max(a[1], b[1], c[1]) - Y0) / STEP + 1e-9))
                if i1 < i0 or j1 < j0:
                    continue
                d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
                if abs(d) < 1e-14:
                    continue
                gx, gy = np.meshgrid(xs[i0:i1 + 1], ys[j0:j1 + 1])
                l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / d
                l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / d
                ok = (l1 >= -1e-9) & (l2 >= -1e-9) & (1 - l1 - l2 >= -1e-9)
                z = l1 * a[2] + l2 * b[2] + (1 - l1 - l2) * c[2]
                sub = F[j0:j1 + 1, i0:i1 + 1]; sub[ok] = np.minimum(sub[ok], z[ok])
                sub = B[j0:j1 + 1, i0:i1 + 1]; sub[ok] = np.maximum(sub[ok], z[ok])
        gx, gy = np.meshgrid(xs, ys); m = np.isfinite(F)
        cloud = np.concatenate([np.stack([gx[m], gy[m], F[m]], 1), np.stack([gx[m], gy[m], B[m]], 1)] + [v for _, v, _ in self.parts])
        self._hm = (xs, ys, F, B, cloud)
        return self._hm

    def _coarse(self):
        if getattr(self, '_c', None) is None:
            xs, ys, F, B, _ = self.height()
            gx, gy = np.meshgrid(xs[::3], ys[::3]); f, b = F[::3, ::3], B[::3, ::3]; m = np.isfinite(f)
            self._c = np.concatenate([np.stack([gx[m], gy[m], f[m]], 1), np.stack([gx[m], gy[m], b[m]], 1)])
        return self._c

    def surface(self, x, y, back=False):
        """the front (min z) or back (max z) surface at (x, y) arrays; nan where the pouch is not."""
        xs, ys, F, B, _ = self.height()
        i = np.clip(np.round((np.asarray(x) - X0) / STEP).astype(int), 0, len(xs) - 1)
        j = np.clip(np.round((np.asarray(y) - Y0) / STEP).astype(int), 0, len(ys) - 1)
        s = (B if back else F)[j, i]
        return np.where(np.isfinite(s), s, np.nan)

    def gap(self, pts):
        xs, ys, F, B, cloud = self.height()
        pts = np.asarray(pts, float)
        i = np.clip(np.round((pts[:, 0] - X0) / STEP).astype(int), 0, len(xs) - 1)
        j = np.clip(np.round((pts[:, 1] - Y0) / STEP).astype(int), 0, len(ys) - 1)
        f, b = F[j, i], B[j, i]
        if ((pts[:, 2] >= f - 1e-9) & (pts[:, 2] <= b + 1e-9)).any():
            return 0.0
        vg = np.where(np.isfinite(f), np.minimum(np.abs(pts[:, 2] - f), np.abs(pts[:, 2] - b)), 9.0)
        g = float(vg.min())
        lo, hi = pts.min(0) - g, pts.max(0) + g
        if g > .1:  # (far off: a coarser surface is plenty to say how far)
            cloud = self._coarse()
        sel = cloud[(cloud[:, 0] >= lo[0]) & (cloud[:, 0] <= hi[0]) & (cloud[:, 1] >= lo[1]) & (cloud[:, 1] <= hi[1]) & (cloud[:, 2] >= lo[2]) & (cloud[:, 2] <= hi[2])]
        for k in range(0, len(pts), 32):
            if len(sel) == 0:
                break
            g = min(g, float(np.sqrt(((pts[k:k + 32, None, :] - sel[None, :, :]) ** 2).sum(-1)).min()))
        return g
