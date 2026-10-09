"""R154 hub z-fighting: before / after close-ups of where the hub flickered (a diagnostic, not a Roblox render).
Usage: python3 render_zfight_crops.py <before scene.json> <after scene.json> <views.json> <out.png>
A small ray caster over the scene's parts (the scene format of docs/proposals/R149/tools/zfight.py: boxes, wedges, cylinders, balls; meshes as their
boxes) draws each view twice, BEFORE and AFTER, side by side. Each part is flat-shaded in its colour; a textured material (Grass, Slate, Metal, Brick ...)
carries a procedural pattern laid out from the PART's own position, as Roblox lays its material textures out per part. Where the two nearest surfaces
under a pixel face the same way and lie closer than a 24-bit depth buffer can tell apart at that distance (4 steps, Roblox's .5 stud near plane - R149's
rule), the pixel shows either surface at random: that speckle is the flicker. Pixels where it happens are also outlined in magenta.
views.json: [{"name", "pos": [x, y, z], "look": [x, y, z], "fov": 70, "clip": 45}, ...] (clip = keep parts whose centre lies within this many studs of look)."""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

W, H = 440, 300
NEAR = 0.5
STEP_K = 4.0 / (NEAR * 2 ** 24)
UNTEXTURED = {'SmoothPlastic', 'Neon', 'Glass', 'ForceField'}
SUN = np.array([.45, .8, .38]); SUN /= np.linalg.norm(SUN)


def planes_of(p):
    """Local half-spaces n . x <= d of a convex part (Block / Mesh / Wedge / CornerWedge approximated by its box)."""
    hx, hy, hz = (s / 2 for s in p.size)
    pl = [((1, 0, 0), hx), ((-1, 0, 0), hx), ((0, 1, 0), hy), ((0, -1, 0), hy), ((0, 0, 1), hz), ((0, 0, -1), hz)]
    if p.shape == 'Wedge' and hy > 0 and hz > 0:
        # Roblox wedge: slope from the front-bottom edge to the back-top edge; keeps y <= -hy + (z + hz) * hy / hz
        n = np.array([0.0, 2 * hz, -2 * hy]); n /= np.linalg.norm(n)
        pl = [((1, 0, 0), hx), ((-1, 0, 0), hx), ((0, -1, 0), hy), ((0, 0, 1), hz), (tuple(n), float(np.dot(n, [0, -hy, -hz])))]
    return [(np.array(n, float), d) for n, d in pl]


def hit_convex(o, dirs, planes):
    """Entry distance and local normal of rays (o local, dirs local N x 3) into the intersection of half-spaces."""
    n_rays = dirs.shape[0]
    t0 = np.full(n_rays, -np.inf); t1 = np.full(n_rays, np.inf); nrm = np.zeros((n_rays, 3))
    for n, d in planes:
        dn = dirs @ n
        on = np.dot(o, n) - d
        with np.errstate(divide='ignore', invalid='ignore'):
            t = -on / dn
        entering = dn < 0
        upd = entering & (t > t0)
        t0 = np.where(upd, t, t0); nrm[upd] = n
        t1 = np.where(~entering & (dn > 0), np.minimum(t1, t), t1)
        t1 = np.where((dn == 0) & (on > 0), -np.inf, t1)
    ok = (t0 <= t1) & (t0 > NEAR)
    return np.where(ok, t0, np.inf), nrm


def hit_cylinder(o, dirs, hx, r):
    """Local X-axis cylinder |x| <= hx, y^2 + z^2 <= r^2: entry distance and local normal."""
    n_rays = dirs.shape[0]
    best = np.full(n_rays, np.inf); nrm = np.zeros((n_rays, 3))
    a = dirs[:, 1] ** 2 + dirs[:, 2] ** 2
    b = 2 * (o[1] * dirs[:, 1] + o[2] * dirs[:, 2])
    c = o[1] ** 2 + o[2] ** 2 - r * r
    disc = b * b - 4 * a * c
    with np.errstate(invalid='ignore', divide='ignore'):
        t = (-b - np.sqrt(np.maximum(disc, 0))) / (2 * a)
    x = o[0] + t * dirs[:, 0]
    ok = (disc >= 0) & (a > 1e-12) & (t > NEAR) & (np.abs(x) <= hx)
    best = np.where(ok, t, best)
    side = np.stack([np.zeros(n_rays), o[1] + t * dirs[:, 1], o[2] + t * dirs[:, 2]], 1) / r
    nrm[ok] = side[ok]
    for sgn in (1, -1):
        with np.errstate(divide='ignore', invalid='ignore'):
            tc = (sgn * hx - o[0]) / dirs[:, 0]
        yy = o[1] + tc * dirs[:, 1]; zz = o[2] + tc * dirs[:, 2]
        okc = (tc > NEAR) & (yy ** 2 + zz ** 2 <= r * r) & (sgn * dirs[:, 0] < 0) & (tc < best)
        best = np.where(okc, tc, best); nrm[okc] = (sgn, 0, 0)
    return best, nrm


def hit_ball(o, dirs, r):
    b = 2 * (dirs @ o); c = np.dot(o, o) - r * r
    disc = b * b - 4 * c
    t = (-b - np.sqrt(np.maximum(disc, 0))) / 2
    ok = (disc >= 0) & (t > NEAR)
    p = o + t[:, None] * dirs
    return np.where(ok, t, np.inf), p / r


def pattern(material, local, normal):
    """A material texture laid out from the part's own position (two scales of hashed cells), 1 = no pattern."""
    if material in UNTEXTURED:
        return np.ones(local.shape[0])
    an = np.abs(normal)
    ax = np.argmax(an, 1)
    u = np.where(ax == 0, local[:, 1], local[:, 0]); v = np.where(ax == 2, local[:, 1], local[:, 2])
    k = 1.6 if material in ('Grass', 'Ground', 'Sand', 'Snow') else 1.0
    def cells(s):
        iu = np.floor(u * s).astype(np.int64); iv = np.floor(v * s).astype(np.int64)
        h = (iu * 73856093) ^ (iv * 19349663)
        return ((h % 1000) / 1000.0)
    return .78 + .16 * cells(k) + .12 * cells(k * 3.1)


def render(scene, view):
    parts = [p for p in Z.load(scene) if p.t < Z.VISIBLE_T]
    look = np.array(view['look'], float); pos = np.array(view['pos'], float)
    clip = view.get('clip', 45)
    parts = [p for p in parts if np.linalg.norm(np.array(p.p) - look) < clip + max(p.size) / 2]
    fwd = look - pos; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right); up = np.cross(right, fwd)
    f = math.tan(math.radians(view.get('fov', 70)) / 2)
    ys, xs = np.mgrid[0:H, 0:W]
    px = ((xs + .5) / W * 2 - 1) * f * W / H; py = (1 - (ys + .5) / H * 2) * f
    dirs = (fwd[None, None] + px[..., None] * right + py[..., None] * up).reshape(-1, 3)
    dirs /= np.linalg.norm(dirs, axis=1)[:, None]
    n = dirs.shape[0]
    t1 = np.full(n, np.inf); t2 = np.full(n, np.inf); i1 = np.full(n, -1); i2 = np.full(n, -1)
    n1 = np.zeros((n, 3)); n2 = np.zeros((n, 3)); c1 = np.zeros((n, 3)); c2 = np.zeros((n, 3))
    for idx, p in enumerate(parts):
        R = np.array(p.cols).T  # columns: right, up, back
        o = R.T @ (pos - np.array(p.p)); dl = dirs @ R
        if p.shape == 'Cylinder':
            t, nl = hit_cylinder(o, dl, p.size[0] / 2, p.size[1] / 2)
        elif p.shape == 'Ball':
            t, nl = hit_ball(o, dl, p.size[0] / 2)
        elif p.shape == 'YCylinder':
            t, nl = hit_convex(o, dl, planes_of(p))
        else:
            t, nl = hit_convex(o, dl, planes_of(p))
        m = np.isfinite(t)
        if not m.any():
            continue
        local = o + t[m, None] * dl[m]
        nw = nl[m] @ R.T
        shade = .5 + .5 * np.clip(nw @ SUN, 0, 1)
        col = np.array(p.color, float)[None] * (shade * pattern(p.material, local, nl[m]))[:, None]
        if p.material == 'Neon':
            col = np.array(p.color, float)[None].repeat(m.sum(), 0)
        tm = t[m]
        cur1, cur2 = t1[m], t2[m]
        first = tm < cur1
        second = ~first & (tm < cur2)
        sel = np.where(m)[0]
        a = sel[first]
        t2[a], i2[a], n2[a], c2[a] = t1[a], i1[a], n1[a], c1[a]
        t1[a], i1[a], n1[a], c1[a] = tm[first], idx, nw[first], col[first]
        b = sel[second]
        t2[b], i2[b], n2[b], c2[b] = tm[second], idx, nw[second], col[second]
    sky = np.array([200, 222, 240], float)
    img = np.where(np.isfinite(t1)[:, None], c1, sky[None])
    z1 = t1 * (dirs @ fwd); z2 = t2 * (dirs @ fwd)
    tol = STEP_K * z1 ** 2
    fight = np.isfinite(t2) & (i1 != i2) & (np.abs(z2 - z1) < np.maximum(tol, 1e-6)) & (np.sum(n1 * n2, 1) > .999)
    fight &= np.abs(c1 - c2).max(1) > 1.0  # a visible difference (colour or pattern)
    rng = np.random.default_rng(7)
    flip = fight & (rng.random(n) < .5)
    img[flip] = c2[flip]
    img = np.clip(img, 0, 255).reshape(H, W, 3).astype(np.uint8)
    mask = fight.reshape(H, W)
    edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
    img[edge] = (255, 0, 200)
    return Image.fromarray(img), int(mask.sum())


def main():
    before, after, views, out = sys.argv[1:5]
    vs = json.load(open(views))
    rows = []
    for v in vs:
        a, na = render(before, v)
        b, nb = render(after, v)
        rows.append((v, a, na, b, nb))
        print('%-34s before: %6d flicker pixels   after: %6d' % (v['name'], na, nb))
    pad, top = 8, 22
    sheet = Image.new('RGB', (2 * W + 3 * pad, len(rows) * (H + top + pad) + pad), (30, 32, 38))
    d = ImageDraw.Draw(sheet)
    for k, (v, a, na, b, nb) in enumerate(rows):
        y = pad + k * (H + top + pad)
        d.text((pad, y + 4), '%s - BEFORE (R153): %d flicker pixels' % (v['name'], na), fill=(255, 210, 120))
        d.text((2 * pad + W, y + 4), 'AFTER (R154): %d' % nb, fill=(150, 230, 150))
        sheet.paste(a, (pad, y + top)); sheet.paste(b, (2 * pad + W, y + top))
    sheet.save(out)
    print('wrote', out)


if __name__ == '__main__':
    main()
