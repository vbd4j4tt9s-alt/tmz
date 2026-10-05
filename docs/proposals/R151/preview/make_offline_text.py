"""R151 preview: the Esc-menu "Plants grow offline" text -> docs/proposals/R151/offline_text.png.
Reads the SCENE lines of offline_text_scenes.luau (the real OfflineGrowthNotice under the mock), draws each screen with Chromium
(render_offline_text.mjs): a stand-in game view, the game GUI, then a stand-in of Roblox's menu on top (the dimming over the whole
screen and the menu panel, sized from CoreScripts SettingsHub/Theme: 840 x 734 centred 10 px low on a 1920x1080 computer; a sheet over
the whole height on phones), and lays the three screens out with a 1:1 crop of the computer text.
Usage: python3 make_offline_text.py SCRATCH OUTPNG (run_offline_text_preview.sh calls it)."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource')
FREDOKA = os.path.join(FONTS, 'fredoka-one', 'files', 'fredoka-one-latin-400-normal.woff2')
MONT = os.path.join(FONTS, 'montserrat', 'files')

GAME = ('<div style="position:absolute;inset:0;background:linear-gradient(180deg,#7cc4ef 0%,#bfe6fa 44%,#7cc463 45%,#4f9d4a 100%)"></div>'
        '{plots}'
        '<div style="position:absolute;left:{hx}px;top:{hy}px;width:{hw}px;height:{hh}px;border-radius:12px;background:#ffd34d;border:3px solid #fff"></div>')


def game(w, h):
    plots = ''
    for i in range(6):
        x = w * (0.12 + 0.14 * i)
        y = h * (0.62 + 0.05 * (i % 2))
        r = max(18, int(min(w, h) * 0.05))
        plots += ('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;border-radius:8px;background:#7a4a2a"></div>'
                  '<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;border-radius:50%%;background:#3fae4a;border:3px solid #2b7d33"></div>'
                  % (x - r, y, 2 * r, r * 0.7, x - r * 0.7, y - r * 1.1, r * 1.4, r * 1.4))
    hw, hh = int(w * 0.18), max(30, int(h * 0.05))
    return GAME.format(plots=plots, hx=int(w / 2 - hw / 2), hy=int(h * 0.09), hw=hw, hh=hh)


TAB = ('<div style="display:flex;flex-direction:column;align-items:center;gap:4px;color:#e8e8ea;font:500 {fs}px UiFont,DejaVu Sans,sans-serif">'
       '<div style="width:{ic}px;height:{ic}px;border-radius:6px;border:2px solid #d8d8dc"></div>{label}</div>')
ROW = ('<div style="display:flex;align-items:center;gap:12px;height:{rh}px;padding:0 14px;border-radius:8px;background:rgba(255,255,255,.06);'
       'color:#eee;font:500 {fs}px UiFont,DejaVu Sans,sans-serif"><div style="width:{av}px;height:{av}px;border-radius:50%;background:#8a8f99"></div>{name}</div>')
BTN = ('<div style="display:flex;align-items:center;gap:8px;padding:0 16px;height:{bh}px;border-radius:8px;border:1px solid #c6c6c6;color:#eee;'
       'font:500 {fs}px UiFont,DejaVu Sans,sans-serif"><span style="border:1px solid #c6c6c6;border-radius:4px;padding:0 6px;font-size:{ks}px">{key}</span>{label}</div>')


def menu(w, h, panel, tabs_h, fs, rows, buttons):
    x, y, pw, ph = panel
    tabs = ''.join(TAB.format(fs=fs, ic=int(fs * 1.5), label=l) for l in ('People', 'Settings', 'Report', 'Help', 'Captures'))
    names = ''.join(ROW.format(rh=int(fs * 2.6), fs=fs, av=int(fs * 1.8), name=n) for n in ['Ava', 'Ben', 'Cai', 'Dee', 'Eli', 'Fay', 'Gus', 'Hal'][:rows])
    btns = ''.join(BTN.format(bh=int(fs * 2.4), fs=fs, ks=int(fs * .8), key=k, label=l) for k, l in (('R', 'Reset Character'), ('L', 'Leave'), ('Esc', 'Resume'))) if buttons else ''
    return ('<div style="position:absolute;inset:0;background:rgba(0,0,0,.5)"></div>'  # Roblox's DarkenBackground (Overlay) over everything
            '<div style="position:absolute;left:12px;top:10px;width:44px;height:44px;border-radius:12px;background:rgba(0,0,0,.55)"></div>'
            '<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx;border-radius:10px;background:rgba(22,23,26,.78);'
            'box-sizing:border-box;padding:%dpx 20px 14px;display:flex;flex-direction:column;gap:%dpx">'
            '<div style="display:flex;justify-content:space-around;height:%dpx;align-items:center;border-bottom:1px solid rgba(255,255,255,.2)">%s</div>'
            '<div style="flex:1;display:flex;flex-direction:column;gap:8px;overflow:hidden">%s</div>'
            '<div style="display:flex;justify-content:center;gap:24px">%s</div></div>'
            % (x, y, pw, ph, int(fs * .6), int(fs * .7), tabs_h, tabs, names, btns))


lines = {}
log = os.path.join(S, 'scenes.log')
for line in open(log, encoding='utf-8'):
    if line.startswith('SCENE '):
        _, name, w, h, ox, oy, payload = line.rstrip('\n').split(' ', 6)
        lines[name] = (int(w), int(h), int(ox), int(oy), payload)
    elif line.startswith('INFO '):
        print(line.strip())
scenes = []
for name, (w, h, ox, oy, payload) in lines.items():
    if name == 'desktop':  # 840 x 734 panel, centred 10 px below the middle (SettingsHub: 800 + 2x20 padding; 600 page + 60 + 60 + 14)
        over = menu(w, h, (int(w / 2 - 420), int(h / 2 + 10 - 367), 840, 734), 60, 17, 8, True)
    elif name == 'phone':  # small touch screen: bottom sheet, HubBar width = screen - 60, anchored at the bottom (+8)
        over = menu(w, h, (18, -8, w - 36, h + 16), 52, 13, 4, True)
    else:
        over = menu(w, h, (8, -8, w - 16, h + 16), 54, 13, 9, True)
    scenes.append({'name': name, 'json': payload, 'screen': [w, h], 'offset': [ox, oy], 'under': game(w, h), 'over': over, 'scale': 1})
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
subprocess.run(['node', os.path.join(HERE, 'render_offline_text.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FREDOKA, MONT], check=True)


def font(px):
    for p in (os.path.join(MONT, 'montserrat-latin-700-normal.woff'), '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        try:
            return ImageFont.truetype(p, px)
        except Exception:
            pass
    return ImageFont.load_default()


def shot(name, scale):
    im = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')
    return im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS) if scale != 1 else im


desk = shot('desktop', .5)
full = Image.open(os.path.join(S, 'png', 'desktop.png')).convert('RGB')
crop = full.crop((360, 905, 1560, 1075))  # the band under the menu panel at 1:1
land = shot('phone', .8)
port = shot('portrait', .62)
BG, TXT, DIM = (18, 21, 32), (236, 238, 248), (160, 166, 186)
pad, cap = 24, 34
W = pad * 3 + desk.width + port.width
H = pad * 4 + cap * 3 + desk.height + crop.height // 2 + land.height + 40
sheet = Image.new('RGB', (W, H), BG)
d = ImageDraw.Draw(sheet)
d.text((pad, 12), 'R151  "Plants grow offline" while the Roblox menu is open (Esc)  -  approximate preview', fill=TXT, font=font(22))
y = 12 + cap + 8
d.text((pad, y), 'Computer 1920x1080 (half size): in the free band under the menu panel', fill=DIM, font=font(16))
sheet.paste(desk, (pad, y + 24))
d.text((pad * 2 + desk.width, y), 'Phone, portrait 390x844', fill=DIM, font=font(16))
sheet.paste(port, (pad * 2 + desk.width, y + 24))
y2 = y + 24 + desk.height + pad
d.text((pad, y2), 'The same computer text at 1:1 (half the crop height shown)', fill=DIM, font=font(16))
c2 = crop.resize((desk.width, int(crop.height * desk.width / crop.width)), Image.LANCZOS)
sheet.paste(c2, (pad, y2 + 24))
y3 = y2 + 24 + c2.height + pad
d.text((pad, y3), 'Phone, landscape 844x390: the menu sheet covers the screen, so the line sits on the bottom edge and shows through it', fill=DIM, font=font(16))
sheet.paste(land, (pad, y3 + 24))
d.text((pad * 2 + land.width, y3 + 24), 'Roblox draws its menu (and the\ndimming) above every game GUI:\nthe text can only sit beside or\nbehind it. Animated rainbow\n(still with Reduced Motion),\nFredoka One, dark outline.', fill=DIM, font=font(15))
sheet = sheet.crop((0, 0, W, y3 + 24 + land.height + pad))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
