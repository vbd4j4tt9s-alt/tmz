"""R157 DAILY mystery-pack picture and TODAY tag, before / after (see daily_tile157.sh). Usage: python3 daily_tile157.py <scratch dir> <out.png> <render_gui138.py>
Reads <scratch>/before|after/{login,quests}.json (real DailyRewardsClient on the mock), pastes a STAND-IN pouch into the pack's picture slot and draws the sheet.
The stand-in is NOT the real 3D pack (the mock cannot render it): a chip-bag outline with a crimped top and bottom, in the exact silhouette colour (10,9,16); AFTER also
draws the thin light edge ItemPictures builds (a copy 14% bigger, colour 228,222,255, behind the dark pack), the whole picture fitted to the slot as the camera does."""
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

S, OUT, RENDER = sys.argv[1], sys.argv[2], sys.argv[3]
K = 2.0
SIL, RIM, GROW = (10, 9, 16), (228, 222, 255), 1.14
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def pouch(w, h, teeth=8):
    """Polygon of a chip bag filling w x h: crimped (zig-zag) top and bottom, slightly pinched sides."""
    pts = []
    tooth = h * 0.05
    for i in range(teeth + 1):                       # top edge, left to right
        pts.append((w * i / teeth, 0 if i % 2 == 0 else tooth))
    pts += [(w * 0.985, h * 0.30), (w, h * 0.55), (w * 0.985, h * 0.80)]
    for i in range(teeth, -1, -1):                   # bottom edge, right to left
        pts.append((w * i / teeth, h if i % 2 == 0 else h - tooth))
    pts += [(w * 0.015, h * 0.80), (0, h * 0.55), (w * 0.015, h * 0.30)]
    return pts


def stand_in(rim):
    """RGBA picture of the pack: 4x supersampled, the rim (if any) behind the dark body, the bounding box fitted tight."""
    sc = 4;bw, bh = 160 * sc, 200 * sc
    big = (int(bw * (GROW if rim else 1)), int(bh * (GROW if rim else 1)))
    im = Image.new('RGBA', big, (0, 0, 0, 0));d = ImageDraw.Draw(im)
    cx, cy = big[0] / 2, big[1] / 2
    if rim:
        rw, rh = bw * GROW, bh * GROW
        d.polygon([(cx - rw / 2 + x, cy - rh / 2 + y) for x, y in pouch(rw, rh)], fill=RIM + (255,))
    d.polygon([(cx - bw / 2 + x, cy - bh / 2 + y) for x, y in pouch(bw, bh)], fill=SIL + (255,))
    im = im.rotate(-2, resample=Image.BICUBIC, expand=True)  # (the pack is turned a little: CFrame.Angles(0,.22,-.025))
    return im.resize((im.width // sc, im.height // sc), Image.LANCZOS)


def render(tag, which):
    d = os.path.join(S, tag);img = os.path.join(d, 'img');os.makedirs(img, exist_ok=True)
    pic = stand_in(rim=(tag == 'after'))
    pic.save(os.path.join(img, 'Art.png'));pic.save(os.path.join(img, 'PackTile.png'))
    out = os.path.join(d, which + '.png')
    env = dict(os.environ, IMGDIR=img)
    subprocess.run([sys.executable, RENDER, os.path.join(d, which + '.json'), out, str(K), '24,26,48'], check=True, env=env, stdout=subprocess.DEVNULL)
    data = json.load(open(os.path.join(d, which + '.json')))
    return Image.open(out).convert('RGB'), data


def rect(data, name):
    for it in data['items']:
        if it['n'] == name:
            return it['x'], it['y'], it['w'], it['h']
    raise SystemExit('no item ' + name)


def crop(im, r, pad=8):
    x, y, w, h = [v * K for v in r];return im.crop((int(x - pad), int(y - pad), int(x + w + pad), int(y + h + pad)))


def main():
    font = ImageFont.truetype(BOLD, 22);small = ImageFont.truetype(BOLD, 16)
    cells = {}
    for tag in ('before', 'after'):
        q, qd = render(tag, 'quests');l, ld = render(tag, 'login')
        cells[tag] = (crop(q, rect(qd, 'Quest1')), crop(l, rect(ld, 'Day3')))
    cw = max(c.width for t in cells.values() for c in t);rh = [max(cells[t][i].height for t in cells) for i in (0, 1)]
    W = 40 + 2 * (cw + 20);H = 120 + sum(rh) + 3 * 50 + 60
    sheet = Image.new('RGB', (W, H), (14, 18, 30));d = ImageDraw.Draw(sheet)
    d.text((20, 12), 'R157 DAILY: no white tile behind the mystery pack, and a TODAY tag you can read', font=font, fill=(240, 244, 255))
    d.text((20, 44), 'Real DailyRewardsClient on the mock; the pack is a STAND-IN pouch shape in the real silhouette colour (the 3D pack cannot be drawn here).', font=small, fill=(190, 200, 225))
    y = 90
    for i, name in enumerate(('A QUESTS row ("+1 PACK")', 'A LOGIN day card (DAY 3, today: the TODAY tag shows)')):
        d.text((20, y), name, font=font, fill=(255, 226, 90));y += 34
        for j, (tag, label) in enumerate((('before', 'BEFORE: white tile' + (', dark TODAY' if i else '')), ('after', 'AFTER: no tile, light edge' + (', white TODAY with a black outline' if i else '')))):
            x = 20 + j * (cw + 20)
            d.text((x, y), label, font=small, fill=(230, 236, 240))
            sheet.paste(cells[tag][i], (x, y + 24))
        y += 24 + rh[i] + 26
    sheet = sheet.crop((0, 0, W, y))
    sheet.save(OUT);print('wrote', OUT, sheet.size)


main()
