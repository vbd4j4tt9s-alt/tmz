"""R152 hub previews: compose render_base_area.mjs output (before_<view>.png / after_<view>.png) into docs/proposals/R152/hub_*.png.
Usage: python3 make_hub_sheets.py <render out dir> <hub_views.json> <docs/proposals/R152 dir>
  hub_aerial.png            the whole hub: R151 as handed over | R152, and R152 large
  hub_rook_gate.png         the track gate from the hub: before | after, and the east rook tower up close (after, large)
  hub_wall_corner.png       a wall corner and a straight run of battlement: before | after (both)
  hub_old_fountain_spot.png the south plaza where the Seed Fountain stood: before | after, after large
  hub_entrance.png          a base entrance and the view leaving a base: before | after (both)"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT, VIEWS, DOCS = sys.argv[1:4]
V = {v['name']: v for v in json.load(open(VIEWS))['views']}
BG, INK, SUB = (27, 29, 35), (238, 240, 245), (170, 176, 190)
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'


def font(n, bold=False):
    return ImageFont.truetype(F % ('-Bold' if bold else ''), n)


T1, T2, T3 = font(28, True), font(18), font(16, True)
BEFORE, AFTER = (150, 60, 60), (40, 140, 90)


def wrap(d, text, width, f):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur:
        lines.append(cur)
    return lines


def tag(d, xy, text, fill):
    x, y = xy; w = d.textlength(text, font=T3)
    d.rectangle([x, y, x + w + 12, y + 28], fill=fill); d.text((x + 6, y + 3), text, font=T3, fill=INK)


def sheet(name, title, caption, rows):
    """rows: list of rows; a row is a list of (label, png, colour) drawn side by side at 640 x 360 (one image = 1280 x 720)."""
    gap, W = 14, 1294
    dd = ImageDraw.Draw(Image.new('RGB', (W, 10)))
    cap = wrap(dd, caption, W - 2 * gap, T2)
    H = 58 + 24 * len(cap) + 8
    for r in rows:
        H += (720 if len(r) == 1 else 360) + gap
    im = Image.new('RGB', (W, H), BG); d = ImageDraw.Draw(im)
    d.text((gap, 12), title, font=T1, fill=INK)
    y = 52
    for line in cap:
        d.text((gap, y), line, font=T2, fill=SUB); y += 24
    y += 8
    for r in rows:
        w, h = (1280, 720) if len(r) == 1 else (640, 360)
        for i, (label, png, colour) in enumerate(r):
            x = gap + i * (w + gap)
            p = os.path.join(OUT, png)
            if os.path.exists(p):
                im.paste(Image.open(p).convert('RGB').resize((w, h), Image.LANCZOS), (x, y))
            else:
                d.rectangle([x, y, x + w, y + h], outline=SUB); d.text((x + 20, y + 20), 'missing ' + png, font=T2, fill=SUB)
            tag(d, (x + 8, y + 8), label, colour)
        y += h + gap
    im.save(os.path.join(DOCS, 'hub_%s.png' % name), optimize=True)
    print('wrote hub_%s.png' % name, im.size)


def pair(view):
    return [('BEFORE (R151)', 'before_%s.png' % view, BEFORE), ('AFTER (R152)', 'after_%s.png' % view, AFTER)]


sheet('aerial', 'The hub from above',
      V['aerial']['caption'], [pair('aerial'), [('AFTER (R152)', 'after_aerial.png', AFTER)]])
sheet('rook_gate', 'The track gate: two chess rooks and a castle gatehouse',
      V['gate']['caption'], [pair('gate'), [('AFTER (R152): the east rook up close', 'after_rook.png', AFTER)]])
sheet('wall_corner', 'The wall top: a chess-rook battlement round the whole base area',
      V['corner']['caption'] + ' ' + V['run']['caption'], [pair('corner'), pair('run')])
sheet('old_fountain_spot', 'The old fountain spot',
      V['plaza']['caption'] + ' The 18-stud circle round x = 0, z = -392 is kept clear for the free Void Pack pedestal.', [pair('plaza'), [('AFTER (R152)', 'after_plaza.png', AFTER)]])
sheet('entrance', 'Base entrances: no arch, no guard pots',
      V['entrance']['caption'] + ' ' + V['spawn']['caption'], [pair('entrance'), pair('spawn')])
