"""R158: packs the owner's part-built models (the Desert pyramid, asset 9981304, 82 parts; the Storm Peaks dark mountain, 1,532 parts) into the game's data module
src/ServerScriptService/ChestChaseServer/OuterTrackModels158.lua  (python3 make_models158.py [out.lua]).

Input: assets/desert_pyramid_9981304_parts.json and assets/dark_mount_parts.json (tools/rbxm_parts.py output of the owner's .rbxm files).
 * Welds, Snap / ManualWeld joints, SpotLights, CylinderMeshes and Models are dropped (everything is anchored; only parts are rebuilt).
 * The dark mountain is cut down for performance: every "Steps" part goes (it lies inside the silhouette of the bigger parts: the cut leaves the
   front / side / top silhouettes identical), then the parts are kept biggest volume first until KEEP are left (default 280 per copy). The silhouette
   overlap (IoU) of the cut model with the full one is printed (and written into the module's header).
 * Each part is packed as: size x, y, z; centre x, y, z (relative to the model's base centre: x / z = centre of its box, y = its lowest point); the
   turn as Euler degrees (Ry * Rx * Rz = CFrame.fromOrientation's order).  Numbers are rounded to 0.1 (sizes to 0.01).
"""
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
KEEP = 280
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', '..', '..', 'src', 'ServerScriptService', 'ChestChaseServer', 'OuterTrackModels158.lua')


def euler_yxz(r):
    """R = Ry(y) Rx(x) Rz(z): row-major 3x3 (CFrame:GetComponents order)."""
    m = [[r[0], r[1], r[2]], [r[3], r[4], r[5]], [r[6], r[7], r[8]]]
    x = math.asin(max(-1, min(1, -m[1][2])))
    if abs(m[1][2]) < 0.99999:
        y = math.atan2(m[0][2], m[2][2])
        z = math.atan2(m[1][0], m[1][1])
    else:  # looking straight up / down
        y = math.atan2(-m[2][0], m[0][0])
        z = 0.0
    return math.degrees(y), math.degrees(x), math.degrees(z)


def rebuild(e):
    y, x, z = (math.radians(v) for v in e)
    def Rx(t): c, s = math.cos(t), math.sin(t); return [[1, 0, 0], [0, c, -s], [0, s, c]]
    def Ry(t): c, s = math.cos(t), math.sin(t); return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    def Rz(t): c, s = math.cos(t), math.sin(t); return [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    def mul(a, b): return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Ry(y), Rx(x)), Rz(z))


def corners(p):
    r, s, pos = p['CFrame']['rot'], p['size'], p['CFrame']['pos']
    out = []
    for a in (-.5, .5):
        for b in (-.5, .5):
            for c in (-.5, .5):
                v = (a * s[0], b * s[1], c * s[2])
                out.append([pos[i] + r[3 * i] * v[0] + r[3 * i + 1] * v[1] + r[3 * i + 2] * v[2] for i in range(3)])
    return out


def load(name):
    d = json.load(open(os.path.join(HERE, 'assets', name)))
    return [p for p in d if p['ClassName'] == 'Part']


def pack(parts):
    allc = [c for p in parts for c in corners(p)]
    lo = [min(c[i] for c in allc) for i in range(3)]
    hi = [max(c[i] for c in allc) for i in range(3)]
    cx, cz, y0 = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2, lo[1]
    rows = []
    worst = 0.0
    for p in parts:
        pos, s, r = p['CFrame']['pos'], p['size'], p['CFrame']['rot']
        e = tuple(round(v, 1) for v in euler_yxz(r))
        rr = rebuild(e)
        worst = max(worst, max(abs(rr[i][j] - r[3 * i + j]) for i in range(3) for j in range(3)))
        rows.append(','.join('%g' % round(v, 2) for v in (s[0], s[1], s[2])) + ',' + ','.join('%g' % round(v, 1) for v in (pos[0] - cx, pos[1] - y0, pos[2] - cz)) + ',' + ','.join('%g' % v for v in e))
    return rows, (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), worst


def silhouette_iou(full, cut):
    import numpy as np
    allc = [corners(p) for p in full]
    lo = [min(c[i] for cs in allc for c in cs) for i in range(3)]
    hi = [max(c[i] for cs in allc for c in cs) for i in range(3)]
    W = [int(hi[i] - lo[i]) + 2 for i in range(3)]

    def raster(parts, u, v):
        img = np.zeros((W[v], W[u]), bool)
        for p in parts:
            pts = np.array([[c[u] - lo[u], c[v] - lo[v]] for c in corners(p)])
            pts = pts[np.lexsort((pts[:, 1], pts[:, 0]))]
            def cr(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
            lower, upper = [], []
            for q in pts:
                while len(lower) >= 2 and cr(lower[-2], lower[-1], q) <= 0: lower.pop()
                lower.append(q)
            for q in pts[::-1]:
                while len(upper) >= 2 and cr(upper[-2], upper[-1], q) <= 0: upper.pop()
                upper.append(q)
            h = np.array(lower[:-1] + upper[:-1])
            x0, x1, y0, y1 = int(h[:, 0].min()), int(h[:, 0].max()) + 1, int(h[:, 1].min()), int(h[:, 1].max()) + 1
            xs, ys = np.meshgrid(np.arange(x0, x1) + .5, np.arange(y0, y1) + .5)
            ins = np.ones(xs.shape, bool)
            for k in range(len(h)):
                a, b = h[k], h[(k + 1) % len(h)]
                ins &= ((b[0] - a[0]) * (ys - a[1]) - (b[1] - a[1]) * (xs - a[0])) >= -1e-9
            sub = img[y0:y1, x0:x1]
            img[y0:y1, x0:x1] = sub | ins[:sub.shape[0], :sub.shape[1]]
        return img
    out = []
    for u, v in ((0, 1), (2, 1), (0, 2)):
        a, b = raster(full, u, v), raster(cut, u, v)
        out.append(float((a & b).sum() / (a | b).sum()))
    return out


def vol(p): return p['size'][0] * p['size'][1] * p['size'][2]


def main():
    pyr = load('desert_pyramid_9981304_parts.json')
    pyr_rows, pyr_box, pyr_err = pack(pyr)
    mount = load('dark_mount_parts.json')
    base = [p for p in mount if p['Name'] != 'Steps']
    kept = sorted(base, key=lambda p: -vol(p))[:KEEP]
    iou = silhouette_iou(mount, kept)
    # the model's own coordinates in the file: the kept order is by volume; sort by height so a reader sees a stack
    kept.sort(key=lambda p: (p['CFrame']['pos'][1], p['CFrame']['pos'][0], p['CFrame']['pos'][2]))
    m_rows, m_box, m_err = pack(kept)
    print('pyramid: %d parts, box %.1f x %.1f x %.1f, worst turn error %.5f' % (len(pyr_rows), pyr_box[0], pyr_box[1], pyr_box[2], pyr_err))
    print('dark mountain: %d of %d parts (%d Steps dropped), box %.1f x %.1f x %.1f, silhouette IoU front %.3f side %.3f top %.3f, worst turn error %.5f' % (
        len(m_rows), len(mount), len(mount) - len(base), m_box[0], m_box[1], m_box[2], iou[0], iou[1], iou[2], m_err))
    lines = []
    w = lines.append
    w("-- R158 outer track: the owner's part-built models as DATA (generated by docs/proposals/R158/design/make_models158.py from his .rbxm files; do not edit by hand).")
    w("--  Pyramid    the Desert pyramid, Creator Store asset 9981304 \"Pyramid\": %d anchored blocks (Concrete, colour 215,197,154), box %.1f x %.1f x %.1f (x, y, z)." % (len(pyr_rows), pyr_box[0], pyr_box[1], pyr_box[2]))
    w("--  DarkMount  the Storm Peaks dark mountain (his dark_mount.rbxm: 1,532 blocks, colour 27,42,53, Grass material, 172 \"Steps\", 19 SpotLights, 32 CylinderMeshes, 3,266 welds). CUT DOWN for speed:")
    w("--             all welds, lights and meshes gone (everything is anchored, nothing glows), the \"Steps\" gone (inside the bigger parts' silhouette), then the %d biggest blocks kept." % len(m_rows))
    w("--             Silhouette overlap with the full model: front %.1f %%, side %.1f %%, top %.1f %%. Box %.1f x %.1f x %.1f." % (100 * iou[0], 100 * iou[1], 100 * iou[2], m_box[0], m_box[1], m_box[2]))
    w("-- A part is 9 numbers: size x,y,z, centre x,y,z (x / z from the centre of the model's box, y up from its lowest point), turn y,x,z in degrees (Ry * Rx * Rz). Parts are pure blocks.")
    w("-- M.Specs(model, opt) returns part SPECS (the format of TrackWallSpecs158) placed on the ground at opt.X / opt.Z, scaled, turned and mirrored; TrackWalls158.Make builds them.")
    w("local M={Version=158}")
    w("M.Pyramid={Source='desert_pyramid_9981304',Color={215,197,154},Material='Concrete',Box={%.2f,%.2f,%.2f},Count=%d,Packed=[[" % (pyr_box[0], pyr_box[1], pyr_box[2], len(pyr_rows)))
    w(';'.join(pyr_rows) + "]]}")
    w("M.DarkMount={Source='dark_mount',Color={27,42,53},Material='Grass',Box={%.2f,%.2f,%.2f},Count=%d,Cut={Of=%d,Steps=%d,Iou={%.4f,%.4f,%.4f}},Packed=[[" % (m_box[0], m_box[1], m_box[2], len(m_rows), len(mount), len(mount) - len(base), iou[0], iou[1], iou[2]))
    w(';'.join(m_rows) + "]]}")
    # the owner's snow hills (snow_mountains.rbxm: MeshParts; the meshes load at run time, the layout is data)
    sd = json.load(open(os.path.join(HERE, 'assets', 'snow_mountains_parts.json')))
    hills = []
    for r in sd:
        if r['ClassName'] == 'Model' and r['Name'] == 'Model':
            kids = [q for q in sd if q['parent'] == r['ref'] and q['ClassName'] == 'MeshPart']
            if len(kids) == 2:
                hills.append(([k for k in kids if k['Name'] == 'Grass'][0], [k for k in kids if k['Name'] == 'Stone'][0]))
    ids = {}
    for q in sd:
        if q['ClassName'] == 'MeshPart':
            ids[q['Name']] = q['MeshId']
    lo = [min(q['CFrame']['pos'][i] - q['size'][i] / 2 for h in hills for q in h) for i in range(3)]
    hi = [max(q['CFrame']['pos'][i] + q['size'][i] / 2 for h in hills for q in h) for i in range(3)]
    cx, cz, y0 = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2, lo[1]
    hrows = []
    for g, st in hills:
        v = []
        for q in (g, st):
            v += list(q['size']) + [q['CFrame']['pos'][0] - cx, q['CFrame']['pos'][1] - y0, q['CFrame']['pos'][2] - cz]
        hrows.append(','.join('%g' % round(x, 2) for x in v))
    trunk = [q for q in sd if q.get('Name') == 'TreeTrunk'][0]
    leaves = [q for q in sd if q.get('Name') == 'TreeLeaves'][0]
    w("-- SnowHills: the owner's \"Low Poly Island Hills\" (snow_mountains.rbxm): %d hills, each a Grass cap and a Stone body (MeshParts; the meshes load at run time by id), %d little trees (re-placed unevenly)." % (len(hills), len([q for q in sd if q.get('Name') == 'TreeTrunk'])))
    w("-- A hill row: grass size x,y,z, grass centre x,y,z, stone size x,y,z, stone centre x,y,z (centres from the island's box centre, y up from its lowest point).")
    w("M.SnowHills={Box={%.2f,%.2f,%.2f},Mesh={Grass='%s',Stone='%s',Trunk='%s',Leaves='%s'},Color={Grass={233,233,244},Stone={107,107,107},Trunk={124,92,70},Leaves={233,233,244}},"
      "Tree={Trunk={%.2f,%.2f,%.2f},Leaves={%.2f,%.2f,%.2f},LeafOffset={%.2f,%.2f,%.2f}},Packed=[[" % (
          hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], ids['Grass'], ids['Stone'], ids['TreeTrunk'], ids['TreeLeaves'],
          trunk['size'][0], trunk['size'][1], trunk['size'][2], leaves['size'][0], leaves['size'][1], leaves['size'][2],
          leaves['CFrame']['pos'][0] - trunk['CFrame']['pos'][0], leaves['CFrame']['pos'][1] - trunk['CFrame']['pos'][1], leaves['CFrame']['pos'][2] - trunk['CFrame']['pos'][2]))
    w(';'.join(hrows) + "]]}")
    print('snow hills: %d hills, box %.1f x %.1f x %.1f, meshes %s' % (len(hills), hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], sorted(set(ids.values()))))
    w(r'''
local function mul(a,b)local r={}for i=1,3 do r[i]={}for j=1,3 do r[i][j]=a[i][1]*b[1][j]+a[i][2]*b[2][j]+a[i][3]*b[3][j]end end;return r end
local function Rx(t)local c,s=math.cos(t),math.sin(t);return{{1,0,0},{0,c,-s},{0,s,c}}end
local function Ry(t)local c,s=math.cos(t),math.sin(t);return{{c,0,s},{0,1,0},{-s,0,c}}end
local function Rz(t)local c,s=math.cos(t),math.sin(t);return{{c,-s,0},{s,c,0},{0,0,1}}end
-- The parsed parts of a model: {{sx,sy,sz, x,y,z, ey,ex,ez}, ...} (cached).
local parsed={}
function M.Parts(model)
 if parsed[model]then return parsed[model]end
 local list={}
 for row in string.gmatch(model.Packed,'[^;]+')do
  local t={};for v in string.gmatch(row,'[^,]+')do t[#t+1]=tonumber(v)end
  list[#list+1]=t
 end
 parsed[model]=list
 return list
end
-- Part specs for one placed copy. opt: X, Z (where the box's centre stands), Y (the ground, default 3.6), Scale (a number) or Fit={W,H,D} (the biggest scale that keeps the box
-- inside W x H x D, before the turn), Yaw (degrees about Y, + turns x toward -z), Mirror (swap left and right: x -> -x), Group (the spec group), Name, Shadow (a part 20+ studs may cast one).
function M.Specs(model,opt)
 local box=model.Box
 local k=opt.Scale
 if not k and opt.Fit then k=math.min(opt.Fit[1]/box[1],opt.Fit[2]/box[2],opt.Fit[3]/box[3])end
 k=k or 1
 local yaw=math.rad(opt.Yaw or 0)
 local sx=opt.Mirror and-1 or 1
 local out={}
 for _,t in ipairs(M.Parts(model))do
  local ey,ex,ez=t[7],t[8],t[9]
  local px,py,pz=sx*t[4]*k,t[5]*k,t[6]*k
  if opt.Mirror then ey,ez=-ey,-ez end
  -- turn about the base centre
  local c,s=math.cos(yaw),math.sin(yaw)
  local qx,qz=c*px+s*pz,-s*px+c*pz
  local R=mul(Ry(yaw),mul(mul(Ry(math.rad(ey)),Rx(math.rad(ex))),Rz(math.rad(ez))))
  local size={t[1]*k,t[2]*k,t[3]*k}
  local spec={Group=opt.Group or'TrackBackdrops158',Name=opt.Name or'Model',Shape='Block',Size=size,
   CF={(opt.X or 0)+qx,(opt.Y or 3.6)+py,(opt.Z or 0)+qz,R[1][1],R[1][2],R[1][3],R[2][1],R[2][2],R[2][3],R[3][1],R[3][2],R[3][3]},
   Color=model.Color,Material=model.Material,Transparency=0}
  if not(opt.Shadow and math.max(size[1],size[2],size[3])>=20)then spec.Shadow=false end -- (only parts 20+ studs may cast one, and only when asked)
  out[#out+1]=spec
 end
 return out,k
end
return M''')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print('wrote', os.path.normpath(OUT), '%.1f KB' % (os.path.getsize(OUT) / 1024))


main()
