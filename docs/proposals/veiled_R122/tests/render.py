"""Rough render of the R122 Void Pack from dump_art.luau output (geom.txt). Usage: python3 render.py geom.txt out.png
Small numpy z-buffer rasterizer: Lambert shading, Neon parts emissive + bloom, translucent parts blended.
APPROXIMATIONS: the approved Forest_01 pouch mesh is not available offline, so the body is a rounded pouch of the
same bounds; particles (haze / nebula swirl / star sparks), the Highlight outline and trails are not drawn."""
import sys, math, numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

def load(path):
    rows = {}
    for line in open(path):
        p = line.rstrip('\n').split(';')
        if len(p) < 10: continue
        tag, kind, name = p[0], p[1], p[2]
        pos = np.array([float(v) for v in p[3].split(',')])
        r = np.array([float(v) for v in p[4].split(',')]).reshape(3, 3)
        size = np.array([float(v) for v in p[5].split(',')])
        col = np.array([int(v) for v in p[6].split(',')]) / 255.0
        rows.setdefault(tag, []).append(dict(kind=kind, name=name, pos=pos, R=r, size=size, col=col, mat=p[7], alpha=float(p[8]), shape=p[9]))
    return rows

def box():
    v = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)])
    f = [(0,1,3),(0,3,2),(4,6,7),(4,7,5),(0,4,5),(0,5,1),(2,3,7),(2,7,6),(0,2,6),(0,6,4),(1,5,7),(1,7,3)]
    return v, np.array(f)

def cylinder(n=20):
    v = [[-.5, 0, 0], [.5, 0, 0]]
    for i in range(n):
        a = 2*math.pi*i/n
        v.append([-.5, .5*math.cos(a), .5*math.sin(a)]); v.append([.5, .5*math.cos(a), .5*math.sin(a)])
    f = []
    for i in range(n):
        a0, a1 = 2+2*i, 2+2*((i+1) % n)
        f += [(0, a1, a0), (1, a0+1, a1+1), (a0, a1, a1+1), (a0, a1+1, a0+1)]
    return np.array(v), np.array(f)

def sphere(n=10, m=14):
    v, f = [], []
    for i in range(n+1):
        t = math.pi*i/n
        for j in range(m):
            p = 2*math.pi*j/m
            v.append([.5*math.sin(t)*math.cos(p), .5*math.cos(t), .5*math.sin(t)*math.sin(p)])
    for i in range(n):
        for j in range(m):
            a, b = i*m+j, i*m+(j+1) % m
            c, d = a+m, b+m
            f += [(a, c, b), (b, c, d)]
    return np.array(v), np.array(f)

def pouch(size, n=28, m=36):
    # Rounded superellipsoid pouch: flat-ish faces, soft rim (stands in for the approved mesh).
    a, b, c = size[0]/2, size[1]/2, size[2]/2
    v, f = [], []
    for i in range(n+1):
        t = -math.pi/2 + math.pi*i/n
        for j in range(m):
            p = 2*math.pi*j/m
            ct, st, cp, sp = math.cos(t), math.sin(t), math.cos(p), math.sin(p)
            sg = lambda x, e: math.copysign(abs(x)**e, x)
            v.append([a*sg(ct, .35)*sg(cp, .35), b*sg(st, .35), c*sg(ct, .8)*sg(sp, .8)])
    for i in range(n):
        for j in range(m):
            q, r = i*m+j, i*m+(j+1) % m
            f += [(q, q+m, r), (r, q+m, r+m)]
    return np.array(v), np.array(f)

SHAPES = {'Block': box(), 'Cylinder': cylinder(), 'Ball': sphere()}

class Cam:
    def __init__(self, eye, target, fov, W, H):
        self.eye = np.array(eye, float); fwd = np.array(target, float) - self.eye; fwd /= np.linalg.norm(fwd)
        right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right); up = np.cross(right, fwd)
        self.f, self.r, self.u = fwd, right, up; self.W, self.H = W, H
        self.k = (H/2)/math.tan(math.radians(fov)/2)
    def project(self, P):
        d = P - self.eye
        z = d @ self.f; x = d @ self.r; y = d @ self.u
        return np.stack([self.W/2 + self.k*x/z, self.H/2 - self.k*y/z, z], 1)

def raster(cam, tris, cols, alpha, emis, W, H):
    zbuf = np.full((H, W), np.inf); img = np.zeros((H, W, 3)); glow = np.zeros((H, W, 3))
    order = np.arange(len(tris))
    translucent = []
    for i in order:
        if alpha[i] > 0.01: translucent.append(i); continue
        draw(cam, tris[i], cols[i], 0, emis[i], zbuf, img, glow, W, H)
    # Back-to-front for translucent pieces.
    translucent.sort(key=lambda i: -np.mean(cam.project(tris[i])[:, 2]))
    for i in translucent:
        draw(cam, tris[i], cols[i], alpha[i], emis[i], zbuf, img, glow, W, H, blend=True)
    return zbuf, img, glow

def draw(cam, tri, col, alpha, emis, zbuf, img, glow, W, H, blend=False):
    p = cam.project(tri)
    if np.any(p[:, 2] <= .05): return
    x0, x1 = int(max(0, math.floor(p[:, 0].min()))), int(min(W-1, math.ceil(p[:, 0].max())))
    y0, y1 = int(max(0, math.floor(p[:, 1].min()))), int(min(H-1, math.ceil(p[:, 1].max())))
    if x0 > x1 or y0 > y1: return
    xs, ys = np.meshgrid(np.arange(x0, x1+1)+.5, np.arange(y0, y1+1)+.5)
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = p
    den = (by-cy)*(ax-cx) + (cx-bx)*(ay-cy)
    if abs(den) < 1e-9: return
    w0 = ((by-cy)*(xs-cx) + (cx-bx)*(ys-cy))/den; w1 = ((cy-ay)*(xs-cx) + (ax-cx)*(ys-cy))/den; w2 = 1-w0-w1
    inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
    if not inside.any(): return
    z = 1/(w0/az + w1/bz + w2/cz)
    sub = zbuf[y0:y1+1, x0:x1+1]
    m = inside & (z < sub - 1e-5)
    if not m.any(): return
    if blend:
        a = 1-alpha
        img[y0:y1+1, x0:x1+1][m] = img[y0:y1+1, x0:x1+1][m]*(1-a) + col*a
        if emis: glow[y0:y1+1, x0:x1+1][m] = glow[y0:y1+1, x0:x1+1][m]*(1-a) + col*a
    else:
        sub[m] = z[m]; img[y0:y1+1, x0:x1+1][m] = col
        if emis: glow[y0:y1+1, x0:x1+1][m] = col
        else: glow[y0:y1+1, x0:x1+1][m] = 0

def scene(parts, cam, light=np.array([-.4, .7, -.6])):
    light = light/np.linalg.norm(light)
    tris, cols, alpha, emis = [], [], [], []
    for p in parts:
        if p['kind'] == 'body':
            if p['name'] != 'Body': continue
            v, f = pouch(np.array([p['size'][0], p['size'][1], .56]))
            P = v @ p['R'].T + p['pos']
        else:
            v, f = SHAPES.get(p['shape'], SHAPES['Block'])
            P = (v*p['size']) @ p['R'].T + p['pos']
        neon = p['mat'] == 'Neon'
        for a, b, c in f:
            t = np.array([P[a], P[b], P[c]])
            n = np.cross(t[1]-t[0], t[2]-t[0]); ln = np.linalg.norm(n)
            if ln < 1e-12: continue
            n /= ln
            if neon: shade = p['col']*1.0
            else:
                lam = abs(n @ light); spec = .35*abs(n @ light)**18 if p['mat'] in ('Metal', 'Glass') else 0
                shade = np.clip(p['col']*(.28+.85*lam) + spec + .02, 0, 1)
            tris.append(t); cols.append(shade); alpha.append(p['alpha']); emis.append(neon)
    return tris, cols, alpha, emis

def background(W, H, seed=3):
    rng = np.random.default_rng(seed)
    y = np.linspace(0, 1, H)[:, None]; x = np.linspace(0, 1, W)[None, :]
    bg = np.zeros((H, W, 3))
    bg[..., 0] = .03 + .05*np.exp(-((x-.7)**2+(y-.3)**2)/.08); bg[..., 1] = .02; bg[..., 2] = .06 + .07*np.exp(-((x-.25)**2+(y-.75)**2)/.1)
    for _ in range(int(W*H/900)):
        sx, sy = rng.integers(0, W), rng.integers(0, H); b = rng.uniform(.3, 1)
        bg[sy, sx] = np.maximum(bg[sy, sx], [b, b, b*1.05 if b < .95 else 1])
    return np.clip(bg, 0, 1)

def render(parts, eye, target, W, H, fov=34, label=None):
    cam = Cam(eye, target, fov, W, H)
    tris, cols, alpha, emis = scene(parts, cam)
    zbuf, img, glow = raster(cam, tris, cols, alpha, emis, W, H)
    bg = background(W, H)
    covered = np.isfinite(zbuf)[..., None]
    base = np.where(covered, img, bg)
    # Translucent pieces drawn over empty background were blended onto black: add them on top.
    base = np.where(covered, base, np.clip(bg + img, 0, 1))
    g = Image.fromarray((np.clip(glow, 0, 1)*255).astype(np.uint8))
    bloom = np.asarray(g.filter(ImageFilter.GaussianBlur(W/90))).astype(float)/255*1.15 + np.asarray(g.filter(ImageFilter.GaussianBlur(W/30))).astype(float)/255*.8
    out = np.clip(base + bloom*.85, 0, 1)
    im = Image.fromarray((out*255).astype(np.uint8))
    if label:
        d = ImageDraw.Draw(im)
        try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', max(12, W//34))
        except Exception: font = ImageFont.load_default()
        d.text((10, 8), label, fill=(225, 205, 255), font=font)
    return im

if __name__ == '__main__':
    rows = load(sys.argv[1]); out = sys.argv[2]
    hero = rows['spin'] + rows.get('fx', [])
    a = render(hero, (-2.3, 1.3, -5.6), (0, 0, 0), 900, 900, 38, 'Void Pack R122 - world (spin + orbiting debris/comets)')
    b = render(rows['void'], (0, .25, -6.2), (0, 0, 0), 440, 440, 34, 'front (inventory picture view)')
    c = render(rows['void'], (3.6, 1.6, 4.2), (0, 0, 0), 440, 440, 36, 'back 3/4')
    d = render(rows['gold'], (-2.0, .8, -5.6), (0, 0, 0), 440, 440, 34, 'Gold coat variation')
    e = render(rows['void'], (-5.6, .6, -.6), (0, 0, 0), 440, 440, 34, 'side (halo depth)')
    sheet = Image.new('RGB', (900+20+440*2+10, 900+20+440), (12, 8, 22))
    sheet.paste(a, (0, 0)); sheet.paste(b, (920, 0)); sheet.paste(c, (920+450, 0))
    sheet.paste(d, (920, 450)); sheet.paste(e, (920+450, 450))
    note = render([], (0, 0, -5), (0, 0, 0), 10, 10)
    dd = ImageDraw.Draw(sheet)
    try: f2 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
    except Exception: f2 = ImageFont.load_default()
    dd.multiline_text((12, 912), 'Rough offline render of the real EclipsePackArt build (SeedPackVisuals.Bag) - NOT a Studio screenshot.\n'
        'Approximations: pouch body stands in for the approved Forest_01 mesh; particles (dark haze, nebula swirl,\n'
        'star sparks), Highlight outline, comet trails and the pulse/heartbeat animation are not drawn.\n'
        'Neon parts are emissive with a bloom pass. Parts: 180 design parts on the body (budget 190).',
        fill=(205, 190, 235), font=f2, spacing=6)
    sheet.save(out); print('wrote', out, sheet.size)
