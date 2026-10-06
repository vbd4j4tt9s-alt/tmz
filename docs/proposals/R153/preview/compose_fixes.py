"""R153 preview sheet: docs/proposals/R153/fixes.png = the refresh barrier in the rook gate's opening (R152 vs R153), the notification badges 1.5x (R152 vs R153, zoomed) and the 2x speed popups
on a phone (R152 vs R153).
Usage: python3 compose_fixes.py <scratch dir with the JSONs> <out png>
Inputs (written by run_fixes_preview.sh): refresh_after.json / refresh_before.json (the SCENE dump of the owner's place with the track closed, R153 / R152), badge_<before|after>_nav.json and
badge_<x>_gui.json (the real ChestIndex tree, 390 x 844), popups.json (popups_scene.luau).
APPROXIMATE: flat elevations of the gate's parts (boxes, wedges, cylinders as their outline) from the Roblox mock's scene, a stand-in font (DejaVu for Fredoka), no lighting. Not a Studio screenshot."""
import json
import math
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
RENDER = os.path.join(REPO, 'docs', 'proposals', 'R137', 'preview', 'render_index.py')
BG = (18, 26, 40)
GREEN, RED, YELLOW, GREY = (150, 255, 110), (255, 130, 130), (255, 226, 96), (205, 215, 240)


def font(px):
    return ImageFont.truetype(BOLD, max(6, int(round(px))))


def pad_box(b):
    return b


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# 1. the gate seen from the hub
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
KEYS = ['FOREST', 'JUNGLE', 'DESERT', 'SNOW', 'LAVA', 'CRYSTAL', 'STORM']


def aabb(p):
    r, s, c = p['r'], p['size'], p['p']
    e = [(abs(r[i][0]) * s[0] + abs(r[i][1]) * s[1] + abs(r[i][2]) * s[2]) / 2 for i in range(3)]
    return [c[0] - e[0], c[0] + e[0], c[1] - e[1], c[1] + e[1], c[2] - e[2], c[2] + e[2]]


def moon(d, cx, cy, r, ink):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(250, 250, 250), outline=ink, width=max(2, int(r * .09)))
    d.ellipse((cx - r * .55, cy - r * 1.02, cx + r * 1.05, cy + r * .58), fill=(242, 242, 242))
    d.arc((cx - r, cy - r, cx + r, cy + r), 40, 320, fill=ink, width=max(2, int(r * .09)))


def draw_face(img, rect, gui):
    """The barrier's front SurfaceGui layout (the scene's 'guis' entry) on the barrier's rectangle."""
    x0, y0, x1, y1 = rect
    d = ImageDraw.Draw(img)
    k = (x1 - x0) / gui['cw']
    d.rectangle(rect, fill=(242, 242, 242))
    sign = None
    for it in gui['items']:
        X, Y, Wd, H = x0 + it['x'] * k, y0 + it['y'] * k, it['w'] * k, it['h'] * k
        if it['cls'] == 'Frame' and it['stroke'] and it['bgT'] >= 1:
            d.rounded_rectangle((X, Y, X + Wd, Y + H), radius=max(2, it['corner'] * k), outline=tuple(it['stroke']['c']), width=max(1, int(it['stroke']['w'] * k)))
        elif it['cls'] == 'Frame' and it['rot'] == 45:
            cx, cy, a = X + Wd / 2, Y + H / 2, Wd / 2 * 1.2
            d.polygon([(cx, cy - a), (cx + a, cy), (cx, cy + a), (cx - a, cy)], fill=tuple(it['bg']))
        elif it['cls'] == 'Frame' and it['bgT'] >= 1 and it['w'] > 600 * 1 and it['h'] > 200 and it['x'] > 100:
            sign = it
    # the sign block's scale (Fit): its height over the R124 sign's 320 px
    fit = (sign['h'] / 320.0) if sign else 1.0
    for it in gui['items']:
        X, Y, Wd, H = x0 + it['x'] * k, y0 + it['y'] * k, it['w'] * k, it['h'] * k
        if it['cls'] == 'Frame' and it['bgT'] >= 1 and not it['stroke'] and sign and it is not sign and abs(it['w'] - it['h']) < 1 and it['w'] > 150:
            moon(d, X + Wd / 2, Y + H / 2, Wd / 2, (70, 72, 79))
        if it['cls'] == 'TextLabel' and it['text']:
            size = it['ts'] * (2.4 * fit if it['text'][-1] == 's' and it['ts'] == 100 else 1) * k
            d.text((X, Y + H / 2 * (1 if it['ts'] == 100 else 1) - (0 if it['ts'] != 100 else 0)), it['text'], font=font(size), fill=tuple(it['tc']), anchor='lm' if it['ts'] != 100 else 'lm',
                   stroke_width=(max(1, int(5 * k * (2.4 * fit if it['ts'] == 100 else 1) / 2.4)) if it['ts'] == 100 else 0), stroke_fill=(0, 0, 0))
        # (the three caption dots are left out: DejaVu's caption is wider than Fredoka's, so they would land on the text)


def elevation(scene, label, col, W_=1000, H_=300):
    parts = json.load(open(scene))
    gui = [g for g in parts['guis'] if g['path'].endswith('BiomeRefreshWall') and g['face'] == 'Front'][0]
    ps = parts['parts']
    keep = []
    for p in ps:
        path = p['path']
        if '/HubDecor151/Gate/' in path or path.endswith('/BiomeRefreshWall') or '/TrackRefreshBlackout/' in path or '/ChestChaseWalls/LobbyFrontWall' in path or path.endswith('/Lobby/LobbyFloor'):
            keep.append(p)
    x_lo, x_hi, y_lo, y_hi = -118.0, 118.0, 0.0, 74.0
    k = min(W_ / (x_hi - x_lo), H_ / (y_hi - y_lo))
    img = Image.new('RGB', (W_, H_), (20, 26, 48))
    d = ImageDraw.Draw(img)

    def sx(x):  # the viewer stands in the hub looking +Z: +X is on his left
        return (x_hi - x) * k

    def sy(y):
        return H_ - (y - y_lo) * k

    keep.sort(key=lambda p: -aabb(p)[4])  # farthest front face first
    for p in keep:
        a = aabb(p)
        path = p['path']
        col_p = tuple(p['color'])
        if path.endswith('/Lobby/LobbyFloor'):
            d.rectangle((0, sy(4), W_, H_), fill=(120, 150, 110))
            continue
        if '/TrackRefreshBlackout/' in path:
            d.rectangle((sx(a[1]), sy(min(a[3], y_hi)), sx(a[0]), sy(max(a[2], 0))), fill=(0, 0, 0))
            continue
        if path.endswith('/BiomeRefreshWall'):
            rect = (sx(a[1]), sy(a[3]), sx(a[0]), sy(a[2]))
            draw_face(img, tuple(int(v) for v in rect), gui)
            d = ImageDraw.Draw(img)
            d.rectangle(rect, outline=(255, 110, 110), width=2)
            continue
        if p['class'] == 'WedgePart':  # the haunches: tall side against the tower
            inner = a[0] if abs(a[0]) < abs(a[1]) else a[1]
            outer = a[1] if inner == a[0] else a[0]
            d.polygon([(sx(inner), sy(a[3])), (sx(outer), sy(a[3])), (sx(outer), sy(a[2]))], fill=col_p, outline=(120, 105, 80))
            continue
        d.rectangle((sx(a[1]), sy(a[3]), sx(a[0]), sy(a[2])), fill=col_p, outline=(120, 105, 80))
        if 'Biome key' in path:
            i = int(path.rsplit(' ', 1)[1]) - 1
            d.text(((sx(a[1]) + sx(a[0])) / 2, (sy(a[3]) + sy(a[2])) / 2), KEYS[i], font=font(k * 2.1), fill=(255, 255, 255), anchor='mm', stroke_width=2, stroke_fill=(20, 30, 40))
    # the numbers: gatehouse lower edge (44), the keys' bottoms (42.5), the tower shafts' inner edges (+-91.8)
    for y, text in ((44.0, 'gatehouse edge 44'), (42.5, 'keys hang to 42.5')):
        for x in range(0, W_, 14):
            d.line((x, sy(y), x + 7, sy(y)), fill=(255, 200, 60), width=1)
        d.text((8, sy(y) - (14 if y == 44.0 else -2)), text, font=font(13), fill=(255, 210, 90), anchor='lm' if False else 'la')
    return img


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# 2. the badges (the real ChestIndex tree, drawn by the R137 renderer)
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
FIXED = os.path.join(S, 'render_index_fixed.py')
open(FIXED, 'w', encoding='utf-8').write(open(RENDER, encoding='utf-8').read().replace('c[0] + c[2], c[1] + c[3]', 'c[0] + max(0, c[2]), c[1] + max(0, c[3])'))


def render(json_file, png, k, crop):
    meta = png + '.crop'
    if os.path.exists(png) and os.path.exists(meta) and open(meta).read() == '%s %s %s' % (k, crop, os.path.getmtime(json_file)):  # (the R137 renderer takes minutes: cached)
        return Image.open(png).convert('RGB')
    env = dict(os.environ, IMGDIR=S)
    subprocess.run([sys.executable, FIXED, json_file, png, str(k), '%d,%d,%d' % BG, ','.join(str(v) for v in crop)], check=True, env=env, stdout=subprocess.DEVNULL)
    open(meta, 'w').write('%s %s %s' % (k, crop, os.path.getmtime(json_file)))
    return Image.open(png).convert('RGB')


def items(path):
    return json.load(open(path))['items']


def find(its, name):
    return [i for i in its if i['n'] == name]


Z = 4


def badge_crops(which):
    nav_json, gui_json = os.path.join(S, 'badge_%s_nav.json' % which), os.path.join(S, 'badge_%s_gui.json' % which)
    nav, gui = items(nav_json), items(gui_json)
    btn = find(nav, 'IndexButton')[0]
    group = [i for i in nav if i['n'] == 'MenuOption2'][0]
    cx, cy, cw, ch = int(btn['x']) - 6, int(btn['y']) - 26, int(btn['w']) + 56, int(btn['h']) + 34
    a = render(nav_json, os.path.join(S, 'fx_%s_a.png' % which), Z, [cx, cy, cw, ch])
    d = ImageDraw.Draw(a)
    gx0, gy0 = (group['x'] - cx) * Z, (group['y'] - cy) * Z
    gx1, gy1 = gx0 + group['w'] * Z, gy0 + group['h'] * Z
    for x in range(int(gx0), int(gx1), 16):
        d.line((x, gy0, min(x + 8, gx1), gy0), fill=(255, 200, 60), width=2)
        d.line((x, gy1, min(x + 8, gx1), gy1), fill=(255, 200, 60), width=2)
    for y in range(int(gy0), int(gy1), 16):
        d.line((gx0, y, gx0, min(y + 8, gy1)), fill=(255, 200, 60), width=2)
        d.line((gx1, y, gx1, min(y + 8, gy1)), fill=(255, 200, 60), width=2)
    hub = find(nav, 'MenuButton')[0]
    c = render(nav_json, os.path.join(S, 'fx_%s_c.png' % which), Z, [int(hub['x'] + hub['w']) - 44, int(hub['y']) - 22, 62, 56])
    tab = find(gui, 'Biome1')[0]
    strip = find(gui, 'BiomeProgress')[0]
    b = render(gui_json, os.path.join(S, 'fx_%s_b.png' % which), Z, [int(tab['x'] + tab['w']) - 56, int(strip['y']) - 16, 76, 64])
    d = ImageDraw.Draw(b)
    ey = (strip['y'] - (int(strip['y']) - 16)) * Z
    for x in range(0, b.width, 16):
        d.line((x, ey, x + 8, ey), fill=(255, 200, 60), width=2)
    return a, b, c


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# 3. the popups on a phone
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
def bolt(d, cx, cy, h, fill, outline):
    w = h * .55
    pts = [(cx + w * .15, cy - h / 2), (cx - w * .5, cy + h * .08), (cx - w * .02, cy + h * .08), (cx - w * .2, cy + h / 2), (cx + w * .5, cy - h * .12), (cx + w * .04, cy - h * .12)]
    d.polygon(pts, fill=fill, outline=outline)


def popup_view(view, key, size_key, icon_key, scale=1.0, label=''):
    W_, H_ = int(view['w'] * scale), int(view['h'] * scale)
    img = Image.new('RGB', (W_, H_), (70, 110, 150))
    d = ImageDraw.Draw(img)
    d.rectangle((0, int(H_ * .78), W_, H_), fill=(78, 128, 82))
    for b in view['hud']:
        if b['n'] in ('OwnerTools',):
            continue
        soft = b['n'] in ('Hotbar',)
        d.rounded_rectangle((b['x'] * scale, b['y'] * scale, (b['x'] + b['w']) * scale, (b['y'] + b['h']) * scale), radius=6, outline=(255, 200, 80) if b['n'].startswith(('Wallet', 'Status')) else (230, 230, 240),
                            fill=(40, 48, 66))
    hx, hy = view['head'][0] * scale, view['head'][1] * scale
    d.ellipse((hx - 14 * scale, hy - 16 * scale, hx + 14 * scale, hy + 16 * scale), fill=(255, 214, 170))
    d.rectangle((hx - 18 * scale, hy + 14 * scale, hx + 18 * scale, hy + 70 * scale), fill=(80, 90, 170))
    text_px = view[size_key]
    icon_px = view[icon_key]
    for f in view[key]:
        tp = text_px * f['s'] * scale
        ip = icon_px * f['s'] * scale
        fnt = font(tp)
        txt = f['text']
        tw = d.textlength(txt, font=fnt)
        iw = ip * .6
        total = iw + 3 * scale + tw
        x0 = hx + f['x'] * scale - total / 2
        cy = hy + f['y'] * scale
        bolt(d, x0 + iw / 2, cy, ip, (255, 222, 66), (17, 26, 42))
        d.text((x0 + iw + 3 * scale, cy), txt, font=fnt, fill=(125, 248, 255), anchor='lm', stroke_width=max(1, int(tp * .11)), stroke_fill=(17, 26, 42))
    return img


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
before_gate = elevation(os.path.join(S, 'refresh_before.json'), '', RED)
after_gate = elevation(os.path.join(S, 'refresh_after.json'), '', GREEN)
ba, bb, bc = badge_crops('before')
aa, ab, ac = badge_crops('after')
pop = json.load(open(os.path.join(S, 'popups.json')))['views']
phone = [v for v in pop if v['w'] == 844][0]
portrait = [v for v in pop if v['w'] == 390][0]
p1 = popup_view(phone, 'r151', 'text151', 'icon151', 1.0)
p2 = popup_view(phone, 'r153', 'text153', 'icon153', 1.0)
q1 = popup_view(portrait, 'r151', 'text151', 'icon151', .62)
q2 = popup_view(portrait, 'r153', 'text153', 'icon153', .62)

pad = 28
gate_w = before_gate.width + after_gate.width + 24
badge_w = ba.width + aa.width + bb.width + ab.width + bc.width + ac.width + 5 * 20
pop_w = p1.width + p2.width + q1.width + q2.width + 3 * 20
W_ = max(gate_w, badge_w, pop_w) + 2 * pad
y = 20
sheet = Image.new('RGB', (W_, 2000), (12, 16, 28))
d = ImageDraw.Draw(sheet)
d.text((pad, y), 'R153: the three fixes after R152, and the 2x speed popups', font=font(32), fill=YELLOW)
y += 50
d.text((pad, y), 'APPROXIMATE: flat elevations / trees drawn from the Roblox mock (the real gate, barrier and ChestIndex of this checkout), DejaVu stands in for Fredoka. Not a Studio screenshot.', font=font(16), fill=GREY)
y += 40
d.text((pad, y), '1. THE NIGHT REFRESH SCREEN FITS THE TRACK GATE (seen from the hub; yellow dashes: the gatehouse edge and the keys\' bottoms)', font=font(22), fill=YELLOW)
y += 62
d.text((pad, y - 26), 'R152: 188 x 53 studs, taller than the opening: the moon and the count sit behind the keys', font=font(16), fill=RED)
d.text((pad + before_gate.width + 24, y - 26), 'R153: 182.8 x 38.4, floor to under the keys, between the shafts; the sign is scaled to it', font=font(16), fill=GREEN)
sheet.paste(before_gate, (pad, y))
sheet.paste(after_gate, (pad + before_gate.width + 24, y))
y += before_gate.height + 34
d.text((pad, y), '2. NOTIFICATION BADGES 1.5x, zoomed 4x (yellow dashes: the edge of what clips them)   INDEX count 24 -> 36 px, MENU "!" 20 -> 30, tab dot 14 -> 21, DAILY 20 -> 30', font=font(22), fill=YELLOW)
y += 62
x = pad
for img, label, col in ((ba, 'R152 INDEX count (24 px)', RED), (aa, 'R153 INDEX count (36 px)', GREEN), (bb, 'R152 tab dot (14)', RED), (ab, 'R153 tab dot (21)', GREEN), (bc, 'R152 MENU "!" (20)', RED), (ac, 'R153 MENU "!" (30)', GREEN)):
    d.text((x, y - 24), label, font=font(15), fill=col)
    sheet.paste(img, (x, y))
    x += img.width + 20
y += max(ba.height, bb.height, bc.height) + 40
d.text((pad, y), '3. SPEED POPUPS 2x (text 22 -> 44, bolt 20 -> 40; the same pop, fling, fade and 10 a second; the fan is wide on a landscape phone, tall on a portrait one)', font=font(22), fill=YELLOW)
y += 62
x = pad
for img, label, col in ((p1, 'R152: 844 x 390 phone', RED), (p2, 'R153: 2x, fan %.2f x %.2f' % tuple(phone['fan']), GREEN), (q1, 'R152: 390 x 844 (62%)', RED), (q2, 'R153: fan %.2f x %.2f (62%%)' % tuple(portrait['fan']), GREEN)):
    d.text((x, y - 24), label, font=font(15), fill=col)
    sheet.paste(img, (x, y))
    x += img.width + 20
y += max(p1.height, q1.height) + 24
sheet = sheet.crop((0, 0, W_, y))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
