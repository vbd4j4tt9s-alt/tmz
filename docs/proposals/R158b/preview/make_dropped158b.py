"""R158b preview of the dropped pack (docs/proposals/R158/dropped_pack158.png): BEFORE (the pack as it lies today) and AFTER (its Highlight, marker and beam) on the seven biome floors,
from the runner's camera, near (15 studs) and far (165 studs).

  python3 make_dropped158b.py html <R156 pyramid.html> <out html>
      R156's three.js map renderer plus (1) scene.beams (a Roblox Beam: a camera-facing ribbon, additive, a width and a colour at each end, a transparency sequence) and
      (2) window.shootMask (only the pack, white on black, the same camera: what the Roblox Highlight is drawn from).
  python3 make_dropped158b.py scenes <dump.txt> <native dir> <out dir>
      dump.txt: dump_dropped158b.luau (the REAL pack of SeedPackVisuals.Bag with the owner's templates, the REAL keyboard floor colours of KeyboardTrack, the look numbers of
      DroppedPackLook158b). native dir: SeedPackArt<Biome>03.lua (the V120 native render data the pouch meshes were made from; they are uploaded assets, not available offline).
      Writes <biome>_before.json / <biome>_after.json (floor, walls, the pack; after: + the beam), jobs.json (the cameras) and look.json (what compose needs).
  python3 make_dropped158b.py compose <work dir> <out png>
      (<work dir>/out: the renders of render_dropped158b.mjs, <work dir>/scenes/look.json from `scenes`.) The Highlight (an outline of the pack's silhouette and a soft fill, drawn over everything, as Roblox draws an AlwaysOnTop Highlight), the marker and the server's own timer
      label, drawn on the renders (Pillow), then the sheet.
APPROXIMATE: three.js, not Roblox (no Roblox lighting, materials, atmosphere or bloom; the fonts are DejaVu Sans, not Fredoka; the outline and the UI sizes are drawn at 1920 x 1080
screen pixels and the pulse is shown at its two ends). The pack's own faint rarity sparkle (SeedPackRender) is not drawn, in either column."""
import importlib.util, json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
BIOMES = {1: 'Forest', 2: 'Desert', 3: 'Snow', 4: 'Lava', 5: 'Crystal', 6: 'Jungle', 7: 'Storm'}
SHOW = [1, 6, 2, 3, 4, 5, 7]  # the rows of the sheet (the track's order)
WALL = {1: [66, 92, 52], 2: [196, 164, 98], 3: [150, 186, 198], 4: [30, 24, 22], 5: [64, 46, 96], 6: [58, 78, 48], 7: [44, 50, 64]}
NEAR, FAR = 15.0, 165.0       # camera to pack, studs
CAM_Y, PACK_X, ZP = 9.5, 4.0, 1000.0
FOV = 70.0                    # Roblox's default vertical field of view
W, H = 1920, 1080


def pyramid_module():
    spec = importlib.util.spec_from_file_location('pyramid156', os.path.join(REPO, 'docs/proposals/R156/preview/make_pyramid_preview156.py'))
    m = importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m


# ------------------------------------------------------------------------------------------------------------------------------ html
def make_html(src, dst):
    s = open(src, encoding='utf-8').read()
    beam = r'''
// R158b: a Roblox Beam (FaceCamera, LightEmission 1): a ribbon from p0 to p1 that always faces the camera, width w0 -> w1, colour c0 -> c1, a transparency sequence tr = [[t, transparency]...]. Additive.
function beamMesh(b){
  const g=new THREE.PlaneGeometry(1,1,1,24);
  const tr=b.tr;const f=tr.map(k=>k[0]),v=tr.map(k=>k[1]);
  let fn='float transp(float t){';for(let i=0;i<tr.length-1;i++){fn+=`if(t<=${f[i+1].toFixed(4)}){return mix(${v[i].toFixed(4)},${v[i+1].toFixed(4)},(t-${f[i].toFixed(4)})/${(f[i+1]-f[i]).toFixed(4)});}`}fn+=`return ${v[v.length-1].toFixed(4)};}`;
  const m=new THREE.ShaderMaterial({transparent:true,depthWrite:false,blending:THREE.CustomBlending,blendEquation:THREE.AddEquation,blendSrc:THREE.OneFactor,blendDst:THREE.OneMinusSrcAlphaFactor,side:THREE.DoubleSide,toneMapped:false,
    uniforms:{P0:{value:new THREE.Vector3(...b.p0)},P1:{value:new THREE.Vector3(...b.p1)},W0:{value:b.w0},W1:{value:b.w1},E:{value:b.em},C0:{value:new THREE.Vector3(...b.c0.map(x=>x/255))},C1:{value:new THREE.Vector3(...b.c1.map(x=>x/255))}},
    vertexShader:'uniform vec3 P0;uniform vec3 P1;uniform float W0;uniform float W1;varying float vT;void main(){float t=uv.y;vec3 p=mix(P0,P1,t);vec3 d=normalize(P1-P0);vec3 c=normalize(cameraPosition-p);vec3 side=normalize(cross(d,c));p+=side*(uv.x-.5)*mix(W0,W1,t);vT=t;gl_Position=projectionMatrix*viewMatrix*vec4(p,1.0);}',
    fragmentShader:'uniform vec3 C0;uniform vec3 C1;uniform float E;varying float vT;'+fn+'void main(){float a=1.0-transp(vT);gl_FragColor=vec4(mix(C0,C1,vT)*a,a*(1.0-E));}'}); // (LightEmission E: 1 = added to what is behind, 0 = laid over it)
  const mesh=new THREE.Mesh(g,m);mesh.frustumCulled=false;mesh.renderOrder=5;return mesh;
}
'''
    s = s.replace('window.shoot=function(scene,W,H,view){', beam + 'window.shoot=function(scene,W,H,view){', 1)
    old = '  let cam;\n  if(view.ortho)'
    assert old in s
    s = s.replace(old, '  for(const b of scene.beams||[])s.add(beamMesh(b));\n' + old, 1)
    mask = r'''
// R158b: only the pack (parts flagged pack + the pouch meshes), flat white on black, the same camera: the silhouette a Roblox Highlight is drawn from.
window.shootMask=function(scene,W,H,view){
  renderer.setSize(W,H);const s=new THREE.Scene();s.background=new THREE.Color(0x000000);
  const white=new THREE.MeshBasicMaterial({color:0xffffff,toneMapped:false,side:THREE.DoubleSide});
  const list=scene.parts.filter(p=>p.pack);const im=new THREE.InstancedMesh(G.box,white,Math.max(1,list.length));const m4=new THREE.Matrix4(),sc=new THREE.Matrix4();
  list.forEach((p,i)=>{const r=p.r;m4.set(r[0][0],r[0][1],r[0][2],p.p[0],r[1][0],r[1][1],r[1][2],p.p[1],r[2][0],r[2][1],r[2][2],p.p[2],0,0,0,1);sc.makeScale(p.size[0],p.size[1],p.size[2]);m4.multiply(sc);im.setMatrixAt(i,m4)});
  im.count=list.length;s.add(im);
  for(const mesh of scene.meshes||[]){const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.Float32BufferAttribute(mesh.pos,3));s.add(new THREE.Mesh(geo,white))}
  const cam=new THREE.PerspectiveCamera(view.fov||60,W/H,.3,9000);cam.position.set(...view.pos);cam.lookAt(new THREE.Vector3(...view.look));
  const tm=renderer.toneMapping;renderer.toneMapping=THREE.NoToneMapping;renderer.render(s,cam);renderer.toneMapping=tm;
  return renderer.domElement.toDataURL('image/png');
};
'''
    s = s.replace('window.ready=true;', mask + 'window.ready=true;', 1)
    open(dst, 'w', encoding='utf-8').write(s)
    print('wrote', dst)


# ------------------------------------------------------------------------------------------------------------------------------ scenes
def parse_dump(path):
    out = {'PACK': {}, 'KEYS': {}, 'LOOK': None}
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'(PACK|KEYS) (\d+) (\{.*\})\s*$', line)
        if m: out[m.group(1)][int(m.group(2))] = json.loads(m.group(3))
        elif line.startswith('LOOK '): out['LOOK'] = json.loads(line[5:])
    return out


def look_at(pos, target):
    f = [target[i] - pos[i] for i in range(3)];n = math.sqrt(sum(x * x for x in f));f = [x / n for x in f]
    up = [0, 1, 0];r = [f[1] * up[2] - f[2] * up[1], f[2] * up[0] - f[0] * up[2], f[0] * up[1] - f[1] * up[0]];n = math.sqrt(sum(x * x for x in r)) or 1;r = [x / n for x in r]
    u = [r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0]]
    return [[r[0], u[0], -f[0]], [r[1], u[1], -f[1]], [r[2], u[2], -f[2]]]


def mat_apply(r, v): return [r[i][0] * v[0] + r[i][1] * v[1] + r[i][2] * v[2] for i in range(3)]
def mat_mul(a, b): return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def native_extent(comps, k):
    ys = [v[i] / 1e4 * k for _, v, _, _, _ in comps for i in range(1, len(v), 3)]
    return min(ys), max(ys)


def build_scene(stage, dump, native_dir, with_beam):
    pack, keys, look = dump['PACK'][stage], dump['KEYS'][stage], dump['LOOK']
    pm = pyramid_module()
    comps = pm.native(os.path.join(native_dir, 'SeedPackArt%s03.lua' % BIOMES[stage]), pack['key'])
    k = pack['scale']
    lo, hi = native_extent(comps, k)
    top = keys['floorTop'] + keys['rise']                 # the resting key tops
    root_y = top + .16 - lo                               # the pack rests on the keys (SeedPackRender's hover is .16)
    cam_x = 0.0
    R = look_at([PACK_X, root_y, ZP], [cam_x, root_y, ZP - 100])  # the pack's front (-Z of its frame) towards the camera (SeedPackRender faces world packs to it)
    parts = []
    # floor: the grout bed, then every key of the biome's own colours (KeyboardTrack's shades), 22 across the 180-wide track; rows of 8.18 studs
    pitch, gap, ky, width = keys['pitch'], keys['gap'], keys['keyY'], keys['width']
    zstart = ZP - 24 * pitch + 2.0
    bed_top = keys['floorTop'] - keys['bedDepth']
    parts.append({'path': 'Floor/Bed', 'name': 'Bed', 'class': 'Part', 'shape': 'Block', 'size': [width, 1, 80 * pitch], 'p': [0, bed_top - .5, zstart + 40 * pitch], 'r': [[1, 0, 0], [0, 1, 0], [0, 0, 1]], 'color': keys['bed'], 'material': 'Plastic', 't': 0})
    for row in range(80):
        zc = zstart + (row + .5) * pitch
        for col in range(1, 23):
            xc = width / 2 - (col - .5) * pitch
            parts.append({'path': 'Floor/Key', 'name': 'Key', 'class': 'MeshPart', 'shape': 'Mesh', 'size': [pitch - gap, ky, pitch - gap], 'p': [xc, top - ky / 2, zc],
                          'r': [[1, 0, 0], [0, 1, 0], [0, 0, 1]], 'color': keys['rows'][row][col - 1], 'material': 'Plastic', 't': 0})
    for sx in (-1, 1):  # the track walls (a plain block each side; the real ones are the R158 walls)
        parts.append({'path': 'Floor/Wall', 'name': 'Wall', 'class': 'Part', 'shape': 'Block', 'size': [3, 40, 80 * pitch], 'p': [sx * (width / 2 + 1.5), bed_top + 20, zstart + 40 * pitch],
                      'r': [[1, 0, 0], [0, 1, 0], [0, 0, 1]], 'color': WALL[stage], 'material': 'Plastic', 't': 0})
    # the pack: its blocks (seal, tear strips) as parts flagged pack, the pouch from the native render data
    for p in pack['parts']:
        if p['class'] == 'MeshPart': continue
        pp = mat_apply(R, p['p']);rr = mat_mul(R, p['r'])
        q = dict(p);q['path'] = 'Pack/' + p['name'];q['p'] = [PACK_X + pp[0], root_y + pp[1], ZP + pp[2]];q['r'] = rr;q['pack'] = True
        parts.append(q)
    meshes = pm.pack_meshes({'root': {'r': R, 'p': [PACK_X, root_y, ZP]}, 'scale': k}, comps)
    scene = {'parts': parts, 'meshes': meshes, 'guis': [], 'lights': [], 'emitters': [], 'beams': []}
    height = hi - lo
    body = [PACK_X, root_y + (lo + hi) / 2, ZP]            # the server's Body: the pack's middle
    if with_beam:
        scene['beams'].append({'p0': [body[0], body[1] + height * .5, body[2]], 'p1': [body[0], body[1] + look['beamHeight'], body[2]], 'w0': look['beamFoot'], 'w1': look['beamTop'],
                               'c0': look['gold'], 'c1': look['white'], 'em': look['beamEmission'], 'tr': look['beamFade']})
    return scene, {'body': body, 'height': height, 'tierColor': pack['tierColor'], 'rank': pack['rank'], 'scale': k, 'stage': stage, 'name': BIOMES[stage]}


def cameras():
    out = {}
    for name, dist in (('near', NEAR), ('far', FAR)):
        dy = 7.6 - CAM_Y  # (the pack's middle is about 7.6 studs up)
        dz = math.sqrt(dist ** 2 - PACK_X ** 2 - dy ** 2)
        pos = [0.0, CAM_Y, ZP - dz]
        out[name] = {'pos': pos, 'look': [0.0, 8.2, pos[2] + 60], 'fov': FOV, 'shadowAt': [PACK_X, 5, ZP], 'shadowExtent': 70 if name == 'near' else 230, 'fogNear': 260, 'fogFar': 1500, 'dist': dist}
    return out


def make_scenes(dumptxt, native_dir, out):
    os.makedirs(out, exist_ok=True)
    dump = parse_dump(dumptxt);cams = cameras();jobs = [];info = {}
    for stage in SHOW:
        name = BIOMES[stage].lower()
        for variant, beam in (('before', False), ('after', True)):
            scene, meta = build_scene(stage, dump, native_dir, beam)
            json.dump(scene, open(os.path.join(out, '%s_%s.json' % (name, variant)), 'w'))
            info[name] = meta
            for cam, view in cams.items():
                jobs.append({'id': '%s_%s_%s' % (name, cam, variant), 'scene': 'scenes/%s_%s.json' % (name, variant), 'view': view, 'mask': variant == 'after'})
    json.dump(jobs, open(os.path.join(out, 'jobs.json'), 'w'))
    json.dump({'info': info, 'cams': cams, 'look': dump['LOOK']}, open(os.path.join(out, 'look.json'), 'w'))
    print('scenes: %d biomes x before / after, %d renders' % (len(SHOW), len(jobs)))


# ------------------------------------------------------------------------------------------------------------------------------ compose
def project(view, pt, w=W, h=H):
    pos, look = view['pos'], view['look']
    f = [look[i] - pos[i] for i in range(3)];n = math.sqrt(sum(x * x for x in f));f = [x / n for x in f]
    r = [-f[2], 0, f[0]];n = math.sqrt(r[0] ** 2 + r[2] ** 2);r = [r[0] / n, 0, r[2] / n]  # (the camera's right: looking down +Z, screen right is world -X)
    u = [r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0]]
    v = [pt[i] - pos[i] for i in range(3)]
    xc, yc, zc = sum(v[i] * r[i] for i in range(3)), sum(v[i] * u[i] for i in range(3)), sum(v[i] * f[i] for i in range(3))
    t = math.tan(math.radians(view['fov']) / 2)
    return (xc / (zc * t * (w / h)) * .5 + .5) * w, (1 - (yc / (zc * t) * .5 + .5)) * h, zc


def fonts():
    from PIL import ImageFont
    base = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
    return lambda n, bold=True: ImageFont.truetype(base % ('-Bold' if bold else ''), n)


def draw_highlight(img, mask, outline, fill, fill_transparency, thickness=2):
    """A Roblox Highlight, AlwaysOnTop: the silhouette (the mask) filled with FillColor at 1 - FillTransparency, an opaque outline of OutlineColor around its edge."""
    from PIL import Image, ImageFilter, ImageChops
    m = mask.convert('L').point(lambda v: 255 if v > 100 else 0)
    grown = m.filter(ImageFilter.MaxFilter(2 * thickness + 1))
    ring = ImageChops.subtract(grown, m.filter(ImageFilter.MinFilter(3)))  # (the outline sits on the edge: outside by `thickness`, 1 px inside)
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    layer.paste(Image.new('RGBA', img.size, tuple(fill) + (int(255 * (1 - fill_transparency)),)), mask=m)
    layer.paste(Image.new('RGBA', img.size, tuple(outline) + (255,)), mask=ring)
    img.alpha_composite(layer)


def draw_marker(img, view, body, height, look, studs, F):
    from PIL import Image, ImageDraw
    up = height / 2 + look['markerAbove']
    cx, cy, _ = project(view, [body[0], body[1] + up, body[2]])
    ink, gold = tuple(look['ink']), tuple(look['gold'])
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0));d = ImageDraw.Draw(layer)
    top = cy - 66  # the picture is the top half of the 160 x 132 gui; the world point is its middle
    title, dist = 'DROPPED PACK', '%d studs' % round(studs)
    for text, size, y, color in ((title, 16, 10, (255, 255, 255)), (dist, 14, 26, gold)):
        d.text((cx, top + y), text, font=F(size), fill=color + (255,), anchor='mm', stroke_width=2, stroke_fill=ink + (255,))
    gem = Image.new('RGBA', (60, 60), (0, 0, 0, 0));g = ImageDraw.Draw(gem)
    g.rounded_rectangle((21, 21, 39, 39), radius=4, fill=gold + (255,), outline=ink + (255,), width=3)
    g.ellipse((27, 27, 33, 33), fill=(255, 255, 255, 255))
    gem = gem.rotate(45, resample=Image.BICUBIC)
    layer.alpha_composite(gem, (int(cx - 30), int(top + 50 - 30)))
    img.alpha_composite(layer)
    return cx, cy


def draw_timer(img, view, body, F, seconds=4):
    """The server's own DropTimer (a BillboardGui 3.2 studs over the pack's middle, 120 studs range): green text, black edge."""
    from PIL import ImageDraw, Image
    cx, cy, _ = project(view, [body[0], body[1] + 3.2, body[2]])
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((cx, cy), 'SEED!  %ds' % seconds, font=F(20), fill=(100, 210, 112, 255), anchor='mm', stroke_width=1, stroke_fill=(0, 0, 0, 255))
    img.alpha_composite(layer)


def compose(work, out_png):
    from PIL import Image, ImageDraw
    rendered = os.path.join(work, 'out');comp = os.path.join(work, 'comp');os.makedirs(comp, exist_ok=True)
    L = json.load(open(os.path.join(work, 'scenes', 'look.json')))
    look, cams, info = L['look'], L['cams'], L['info']
    F = fonts()
    white, gold = tuple(look['white']), tuple(look['gold'])
    cw, ch = 600, 338

    def view_image(name, cam, variant, outline, fast=False):
        """One picture at 1920 x 1080: the render, and for AFTER the Highlight, the marker; the server's own timer label when it is within its 120 studs (both)."""
        src = 'before' if (fast or variant == 'before') else 'after'  # (Fast Mode has no beam: the beam-less render)
        base = Image.open(os.path.join(rendered, '%s_%s_%s.png' % (name, cam, src))).convert('RGBA')
        meta = info[name];view = cams[cam];body = meta['body']
        dist = math.sqrt(sum((body[i] - view['pos'][i]) ** 2 for i in range(3)))
        if variant == 'after':
            mask = Image.open(os.path.join(rendered, '%s_%s_after_mask.png' % (name, cam))).convert('L')
            draw_highlight(base, mask, outline, look['fill'], look['fillTransparency'])
            draw_marker(base, view, body, meta['height'], look, dist, F)
        if dist <= 120: draw_timer(base, view, body, F)
        return base

    def cell(sheet, d, img, name, cam, x, y, title):
        meta = info[name];view = cams[cam]
        sheet.paste(img.convert('RGB').resize((cw, ch), Image.LANCZOS), (x, y))
        d.text((x + 6, y + 6), title, font=F(16), fill=(236, 238, 245), stroke_width=2, stroke_fill=(0, 0, 0))
        # an inset: the real pixels around the pack (near: 1 : 1, 300 x 170 of the 1920 x 1080 picture; far: 160 x 120, enlarged 2 x), so the thin outline and the small marker can be judged
        cx, cy, _ = project(view, meta['body'])
        if cam == 'near': box, scale = (int(cx - 150), int(cy - 110), int(cx + 150), int(cy + 60)), 1
        else: box, scale = (int(cx - 80), int(cy - 105), int(cx + 80), int(cy + 15)), 2
        patch = img.convert('RGB').crop(box);patch = patch.resize((patch.width * scale, patch.height * scale), Image.NEAREST if scale > 1 else Image.LANCZOS)
        px, py = x + cw - patch.width - 4, y + ch - patch.height - 4
        sheet.paste(patch, (px, py));d.rectangle((px - 1, py - 1, px + patch.width, py + patch.height), outline=(255, 255, 255))

    cols = [('BEFORE', 'near', 'before', None), ('AFTER, outline white', 'near', 'after', white), ('AFTER, outline gold', 'near', 'after', gold), ('BEFORE', 'far', 'before', None), ('AFTER, outline gold', 'far', 'after', gold)]
    rows = [BIOMES[s].lower() for s in SHOW]
    pad, head, label = 12, 118, 8
    fast = [('snow', 'near'), ('snow', 'far'), ('lava', 'near'), ('lava', 'far'), ('desert', 'near')]
    sheet = Image.new('RGB', (pad + len(cols) * (cw + pad), head + len(rows) * (ch + label + pad) + 44 + ch + pad + 60), (24, 26, 32))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 12), 'Dropped packs: before and after (R158b)', font=F(30), fill=(255, 222, 130))
    d.text((pad, 52), 'A runner\'s camera on all seven track floors (the game\'s own keyboard colours and pack art). Near = 15 studs, far = 165 studs. The pack is about 2 studs wide: from 165 studs it is about 12 pixels.', font=F(15, False), fill=(205, 208, 216))
    d.text((pad, 74), 'AFTER: a Highlight on the pack (outline pulses white <-> gold, pale gold fill, always on top), a gold diamond marker with its distance, a slim beam of light. The small boxes show the real pixels.', font=F(15, False), fill=(205, 208, 216))
    d.text((pad, 96), 'APPROXIMATE picture: three.js + Pillow, not Roblox (no Roblox lighting / bloom / haze; DejaVu font, not Fredoka). The pack\'s own faint rarity sparkle is not drawn, in either column.', font=F(15, False), fill=(240, 170, 140))
    y = head
    for name in rows:
        for i, (title, cam, variant, outline) in enumerate(cols):
            img = view_image(name, cam, variant, outline)
            img.convert('RGB').save(os.path.join(comp, '%s_%s_%s_%s.png' % (name, cam, variant, 'plain' if outline is None else 'white' if tuple(outline) == white else 'gold')))
            cell(sheet, d, img, name, cam, pad + i * (cw + pad), y + label, '%s, %s: %s' % (info[name]['name'], 'near 15 studs' if cam == 'near' else 'far 165 studs', title))
        y += ch + label + pad
    d.text((pad, y + 6), 'Fast Mode / low graphics: the Highlight STAYS (the nearest 3), so does the marker; the beam and the pulse / bob are off (the outline is one steady colour, white).', font=F(18), fill=(255, 222, 130))
    y += 44
    for i, (name, cam) in enumerate(fast):
        img = view_image(name, cam, 'after', tuple(look['staticOutline']), fast=True)
        img.convert('RGB').save(os.path.join(comp, '%s_%s_fast.png' % (name, cam)))
        cell(sheet, d, img, name, cam, pad + i * (cw + pad), y, '%s, %s, Fast Mode' % (info[name]['name'], 'near 15 studs' if cam == 'near' else 'far 165 studs'))
    y += ch + pad
    d.text((pad, y + 4), 'Numbers: Highlights for the nearest %d drops (%d in Fast Mode), never more than the room left of Roblox\'s 31; a marker for every drop (up to %d); beams for the nearest %d (none in Fast Mode).' % (look['maxHighlights'][2], look['maxHighlights'][0], look['maxMarkers'], look['maxBeams'][2]), font=F(15, False), fill=(205, 208, 216))
    sheet = sheet.crop((0, 0, sheet.width, y + 34))
    sheet.save(out_png, optimize=True)
    print('wrote', out_png, sheet.size)


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'html': make_html(sys.argv[2], sys.argv[3])
    elif cmd == 'scenes': make_scenes(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == 'compose': compose(sys.argv[2], sys.argv[3])
    else: raise SystemExit(__doc__)
