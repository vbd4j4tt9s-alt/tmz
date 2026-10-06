"""R153 preview: the SCENE lines of bonus_scenes153.luau (one log per view) -> PNGs with Chromium (render_gui153.mjs) -> docs/proposals/R153/bonus_roll.png.
The pack picture is decoded here from src/ReplicatedStorage/BonusPackImage153.lua with the same layout the game's decoder reads (and its Adler-32 checked), so the
sheet shows what the embedded data really holds. Usage: python3 make_sheet153.py SCRATCH OUT.png   (run_preview153.sh calls it)"""
import base64
import io
import json
import os
import re
import subprocess
import sys
import zlib

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'montserrat', 'files')
SKY = 'linear-gradient(180deg,#8fd0f6 0%,#cdeafb 46%,#78c060 47%,#4e9c48 100%)'
WORLD = 'linear-gradient(180deg,#5da4d6 0%,#a9d8f0 40%,#6fb85c 41%,#3f8a46 100%)'


def font(px, weight='900'):
    for name in ('montserrat-latin-%s-normal.woff' % weight,):
        try:
            return ImageFont.truetype(os.path.join(FONTS, name), px)
        except Exception:
            pass
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


# 1. the embedded picture, decoded the way EmbeddedImage153.Decode does --------------------------------------------------------------------------------------------
text = open(os.path.join(REPO, 'src/ReplicatedStorage/BonusPackImage153.lua'), encoding='utf-8').read()
w, h, colors, nbytes, check = [int(re.search(k + r'=(\d+)', text).group(1)) for k in ('Width', 'Height', 'Colors', 'Bytes', 'Check')]
b64 = ''.join(re.findall(r"^ '([A-Za-z0-9+/=]+)'", text, re.M))
raw = zlib.decompress(base64.b64decode(b64), -15)
assert len(raw) == nbytes and (zlib.adler32(raw) & 0xffffffff) == check, 'the embedded data does not decode to what its header says'
pal = [raw[i * 3:i * 3 + 3] for i in range(colors)]
idx0, a0 = colors * 3, colors * 3 + w * h
pic = Image.new('RGBA', (w, h))
pic.putdata([tuple(pal[raw[idx0 + i]]) + (raw[a0 + i],) for i in range(w * h)])
buf = io.BytesIO()
pic.save(buf, 'PNG')
DATA_URI = 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()
print('picture', w, 'x', h, 'decoded, Adler-32 ok,', len(raw), 'raw bytes')

# 2. parse the logs and render ----------------------------------------------------------------------------------------------------------------------------------------
scenes = []
for view in ('desktop', 'phone'):
    for line in open(os.path.join(S, view, 'scenes.log'), encoding='utf-8'):
        if not line.startswith('SCENE '):
            continue
        parts = line.rstrip('\n').split(' ', 7)
        name, x, y, cw, ch, scale = parts[1:7]
        scenes.append({'name': '%s_%s' % (view, name), 'json': parts[7], 'scale': float(scale), 'img': DATA_URI,
                       'bg': WORLD if name.startswith('roll_') else SKY, 'crop': [int(x), int(y), int(cw), int(ch)]})
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
subprocess.run(['node', os.path.join(HERE, 'render_gui153.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)


def load(view, name, width):
    p = os.path.join(S, 'png', '%s_%s.png' % (view, name))
    im = Image.open(p).convert('RGBA')
    return im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)


# 3. the sheet -----------------------------------------------------------------------------------------------------------------------------------------------------
BG, TXT, DIM = (16, 20, 34), (235, 238, 250), (160, 172, 205)
PAD = 18
BUTTON_W = 392
ROLL_W = 640
buttons = [('button_charging', 'NEXT 5:41 (the fill grows from the left)'), ('button_half', 'half way'), ('button_almost', 'ALMOST THERE! (last 30 s, caught in a pulse)'),
           ('button_almost2', 'ALMOST THERE! 0:02'), ('button_readypop', 'a roll completes: BONUS READY! / OPEN IT!'), ('button_ready', 'BONUS ROLL / READY!'), ('button_ready2', 'two ready')]
rolls = [('roll_early', 'the spin: "Unwrapping ur gift..." and nothing under it'), ('roll_secret_passing', 'the Secret pack flies by (this roll is a Common)'),
         ('roll_common', 'it stops on the server\'s result: Common'), ('roll_secret_won', 'a real Secret result: the reel stops on the Void pack')]
W_ = PAD + 4 * (BUTTON_W + PAD)
rows_b = 2
btn_imgs = [load('desktop', n, BUTTON_W) for n, _ in buttons]
ph_imgs = [load('phone', n, BUTTON_W) for n in ('button_charging', 'button_almost2', 'button_readypop', 'button_ready')]
bh = max(i.height for i in btn_imgs + ph_imgs)
roll_imgs = [load('desktop', n, ROLL_W) for n, _ in rolls]
rh = max(i.height for i in roll_imgs)
H_ = 120 + 2 * (bh + 44) + 70 + (bh + 44) + 70 + 2 * (rh + 44) + PAD
sheet = Image.new('RGB', (max(W_, 2 * ROLL_W + 3 * PAD), H_), BG)
d = ImageDraw.Draw(sheet)
d.text((PAD, 14), 'R153 bonus roll: the pack on the button, its countdown phases, the fill, the Secret pack on the reel', font=font(30), fill=(255, 226, 96))
d.text((PAD, 58), 'REAL TreadmillBonusClient + EmbeddedImage153 + BonusPackImage153 on the Roblox mock, drawn by headless Chromium (approximate: Montserrat stands in for Gotham; reel pictures are stand-in drawings)', font=font(14, '700'), fill=DIM)
y = 100
d.text((PAD, y), 'HUD button, desktop (1280 x 720)', font=font(22), fill=TXT)
y += 38


def cell(img, x, y, caption):
    d.rounded_rectangle((x - 2, y - 2, x + img.width + 2, y + img.height + 2), 8, fill=(26, 32, 52))
    sheet.paste(img, (x, y), img)
    d.text((x, y + img.height + 6), caption, font=font(14, '700'), fill=DIM)


for i, (img, (_, cap)) in enumerate(zip(btn_imgs, buttons)):
    cell(img, PAD + (i % 4) * (BUTTON_W + PAD), y + (i // 4) * (bh + 44), cap)
y += 2 * (bh + 44) + 12
d.text((PAD, y), 'HUD button, phone (844 x 390)', font=font(22), fill=TXT)
y += 38
for i, (img, cap) in enumerate(zip(ph_imgs, ('NEXT 5:41', 'ALMOST THERE! 0:02', 'BONUS READY! / OPEN IT!', 'READY!'))):
    cell(img, PAD + i * (BUTTON_W + PAD), y, cap)
y += bh + 44 + 12
d.text((PAD, y), 'Roll screen, desktop', font=font(22), fill=TXT)
y += 38
for i, (img, (_, cap)) in enumerate(zip(roll_imgs, rolls)):
    cell(img, PAD + (i % 2) * (ROLL_W + PAD), y + (i // 2) * (rh + 44), cap)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
