"""R148 preview: docs/proposals/R148/index_limited.png = the new icon large, the tab row before (R147: ... MECH 12 / 12, VERITY 0 / 2)
and after (R148: ... LIMITED 12 / 14) next to the other tabs, and the LIMITED panel (the two reward rows).

The GUI is the REAL ChestIndex under the mock (limited_preview.luau), drawn with Pillow by the R137 renderer (approximate: DejaVu stands in
for Fredoka, no seed pictures); the tab logos are the REAL pixels decoded from BiomeIconData (base64 -> zstd), pasted into the logo slots.

Usage: python3 render_preview.py OLD.json NEW.json OUT.png        (run.sh makes the two JSONs)"""
import base64, json, os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
RENDER = os.path.join(REPO, 'docs', 'proposals', 'R137', 'preview', 'render_index.py')
old_json, new_json, out_png = sys.argv[1:4]
tmp = os.path.dirname(os.path.abspath(old_json))
try:
    import zstandard
except ImportError:
    sys.exit('needs python zstandard (pip install zstandard)')
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(px):
    return ImageFont.truetype(BOLD, px)


# real icons
src = open(os.path.join(REPO, 'src', 'ReplicatedStorage', 'BiomeIconData.lua'), encoding='utf-8').read()
icons = {}
for kind, field in re.findall(r'^(\w+)=\{Size=96,TinyWidth=24,TinyHeight=24,RGBA="([^"]+)"', src, re.M):
    icons[kind] = Image.frombytes('RGBA', (96, 96), zstandard.ZstdDecompressor().decompress(base64.b64decode(field)))
KIND = {'Biome1': 'Forest', 'Biome6': 'Jungle', 'Biome2': 'Desert', 'Biome3': 'Snow', 'Biome5': 'Crystal', 'Biome4': 'Lava', 'Biome7': 'Storm',
        'Biome8': 'Mech', 'BiomeLimited': 'Limited'}


def render(json_path, png):
    # (the preview's font has no hourglass emoji: it is left out of the picture)
    clean_json = json_path + '.noemoji.json'
    open(clean_json, 'w', encoding='utf-8').write(open(json_path, encoding='utf-8').read().replace('\u23f3 ', ''))
    subprocess.run([sys.executable, RENDER, clean_json, png, '1', '18,26,40'], check=True, stdout=subprocess.DEVNULL)
    im = Image.open(png).convert('RGBA')
    data = json.load(open(json_path))
    tab = None
    for it in data['items']:
        if it['n'] in KIND:
            tab = it['n']
        elif it['n'] == 'BiomeLogo' and tab:
            pic = icons[KIND[tab]].resize((int(round(it['w'])), int(round(it['h']))), Image.LANCZOS)
            im.alpha_composite(pic, (int(round(it['x'])), int(round(it['y']))))
            tab = None
    return im, data


def find(data, name):
    return [it for it in data['items'] if it['n'] == name]


before, bdata = render(old_json, os.path.join(tmp, 'before.png'))
after, adata = render(new_json, os.path.join(tmp, 'after.png'))
panel = find(adata, 'IndexPanel')[0]
px, py, pw = int(panel['x']), int(panel['y']), int(panel['w'])
strip = find(adata, 'BiomeProgress')[0]
rows = find(adata, 'LimitedRewards')[0]
tabs_y0 = int(strip['y']) - 6
tabs_y1 = int(strip['y'] + strip['h']) + 2
row_end = int(rows['y'] + rows['h']) + 10
CW = 1162 + 24                                       # the old row is 9 tabs wide (the new one 8); on screen the row scrolls sideways
tab_before = before.crop((px, tabs_y0, px + CW, tabs_y1))
tab_after = after.crop((px, tabs_y0, px + CW, tabs_y1))
panel_after = after.crop((px, py, px + pw, row_end))

# layout
BG = (12, 16, 28)
big = icons['Limited'].resize((384, 384), Image.NEAREST)
LEFT = 440
W_ = 24 + LEFT + 28 + CW + 24
H_ = max(60 + 384 + 24 + 120 + 140, 60 + 24 + 20 + tab_before.height + 28 + 20 + tab_after.height + 28 + 20 + panel_after.height + 24)
sheet = Image.new('RGB', (W_, H_), BG)
d = ImageDraw.Draw(sheet)
d.text((24, 16), 'Index tab LIMITED (R148): MECH + VERITY combined, with its own icon', font=font(26), fill=(255, 226, 96))
# the icon, large, on the tab blue and on the dark panel
tile = Image.new('RGBA', (384, 384), (73, 109, 204, 255))
tile.alpha_composite(big)
sheet.paste(tile.convert('RGB'), (24, 60))
d.text((24, 60 + 390), 'the icon: 96 x 96 RGBA (shown at 4x)', font=font(16), fill=(210, 220, 245))
# actual tab size, next to the other logos (44 x 44 as the tabs draw them)
y0 = 60 + 384 + 50
d.text((24, y0), 'at tab size (44 x 44), next to the other logos:', font=font(16), fill=(210, 220, 245))
order = ['Forest', 'Jungle', 'Desert', 'Snow', 'Crystal', 'Lava', 'Storm', 'Mech', 'Limited']
strip_img = Image.new('RGBA', (len(order) * 46 + 4, 54), (73, 109, 204, 255))
for i, k in enumerate(order):
    strip_img.alpha_composite(icons[k].resize((44, 44), Image.LANCZOS), (4 + i * 46, 5))
sheet.paste(strip_img.convert('RGB'), (24, y0 + 26))
d.text((24, y0 + 26 + 60), 'Mech ... Limited: the old MECH logo, then the new one', font=font(13), fill=(150, 165, 200))
# right: tab rows and the panel
x0 = 24 + LEFT + 28
y = 60
d.text((x0, y), 'tab row NOW (R147):  ... MECH 12 / 12 | VERITY 0 / 2', font=font(18), fill=(255, 150, 150))
y += 26
sheet.paste(tab_before.convert('RGB'), (x0, y))
y += tab_before.height + 28
d.text((x0, y), 'tab row R148:  ... STORM | LIMITED 12 / 14   (the row scrolls sideways on screen, as before)', font=font(18), fill=(150, 255, 110))
y += 26
sheet.paste(tab_after.convert('RGB'), (x0, y))
y += tab_after.height + 28
d.text((x0, y), 'LIMITED open: countdown (hourglass left out here), MECH SET and VERITY, each with its own progress and gems', font=font(17), fill=(150, 255, 110))
y += 26
sheet.paste(panel_after.convert('RGB'), (x0, y))
sheet.save(out_png)
print('wrote', out_png, sheet.size)
