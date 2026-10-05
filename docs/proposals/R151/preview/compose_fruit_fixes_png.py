"""Usage: python3 compose_fruit_fixes_png.py <before out dir> <after out dir> <fruit_fixes.png> [base revision]
Composes docs/proposals/R151/fruit_fixes.png from render_fruit_models.mjs's PNGs of dump_fruit_fixes.luau (the base revision "before", this checkout "after") and the INFO rows
(<out dir>/info.txt) of the two dumps. Approximate renders (three.js): plain materials, no Roblox textures / decals / Future lighting; the three baked fruit are drawn from the vertex data
the server bake generated on the mock, every other baked plant mesh is a stand-in ellipsoid, and Verity's face (a Decal) is a stand-in smiley of dark balls on the side(s) it is on."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

before_dir, after_dir, out, base = sys.argv[1], sys.argv[2], sys.argv[3], (sys.argv[4] if len(sys.argv) > 4 else 'a669234')
BG, PANEL, INK, SUB = (18, 30, 26), (28, 44, 38), (255, 255, 255), (200, 216, 206)
BEFORE, AFTER, WARN = (240, 150, 120), (150, 226, 170), (255, 214, 120)


def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def info(d):
    rows = {}
    p = os.path.join(d, 'info.txt')
    if os.path.exists(p):
        for line in open(p, encoding='utf-8'):
            f = line.rstrip('\n').split('\t')
            if f[0] == 'INFO' and len(f) >= 5:
                rows[f[1]] = {'name': f[2], 'fruit': int(f[3]), 'plant': int(f[4])}
    return rows


def standins(d):
    p = os.path.join(d, 'standins.json')
    return json.load(open(p)) if os.path.exists(p) else {}


IB, IA = info(before_dir), info(after_dir)
SB, SA = standins(before_dir), standins(after_dir)


def load(d, name, size):
    im = Image.open(os.path.join(d, name + '.png')).convert('RGB')
    scale = max(size / im.width, size / im.height)
    im = im.resize((int(im.width * scale + .5), int(im.height * scale + .5)), Image.LANCZOS)
    x, y = (im.width - size) // 2, (im.height - size) // 2
    return im.crop((x, y, x + size, y + size))


def pair(name, title, size, kind, id_=None, tags=('', '')):
    """before | after of one scene, a title above, a caption under each tile."""
    gap, head, foot = 6, 34, 46
    w = size * 2 + gap
    t = Image.new('RGB', (w, head + size + foot), PANEL)
    d = ImageDraw.Draw(t)
    d.text((w // 2, 8), title, font=font(17), fill=INK, anchor='ma')
    for i, (src, label, colour, st, tag) in enumerate(((before_dir, 'before', BEFORE, SB, tags[0]), (after_dir, 'after', AFTER, SA, tags[1]))):
        x = i * (size + gap)
        t.paste(load(src, name, size), (x, head))
        d.rectangle([x, head, x + size - 1, head + size - 1], outline=colour, width=3)
        d.text((x + size // 2, head + size + 5), label + (': ' + tag if tag else ''), font=font(14), fill=colour, anchor='ma')
        if name in st:
            d.text((x + size // 2, head + size + 25), 'stand-in mesh drawn', font=font(12, False), fill=WARN, anchor='ma')
    return t


def counts(id_, key):
    b, a = IB.get(id_), IA.get(id_)
    if not b or not a:
        return ('', '')
    return (plural(b[key]), plural(a[key]))


FRUITS = [('SunflowerSeed', 'Watermelon'), ('SnowdropSeed', 'Snow Melon'), ('EmberBloomSeed', 'Ember Pumpkin'), ('AppleSeed', 'Apple'), ('ElderbloomSeed', 'Elderbloom apple'),
          ('BluebellSeed', 'Blueberry'), ('IceberrySeed', 'Iceberry'), ('MoonflowerSeed', 'Moon Melon')]
VERITY = [('verity_item_front', 'Verity fruit, hotbar / Bag / Index (from -Z)', 'fruit'), ('verity_item_back', 'the same fruit from the other side (+Z)', 'fruit'),
          ('verity_path', 'planted Verity, seen from the path (+Z)', 'plant'), ('verity_behind', 'planted Verity, seen from behind (-Z)', 'plant')]


def grid(items, cols, gap=12):
    rows = [items[i:i + cols] for i in range(0, len(items), cols)]
    w = max(sum(t.width for t in r) + gap * (len(r) - 1) for r in rows)
    h = sum(max(t.height for t in r) for r in rows) + gap * (len(rows) - 1)
    g = Image.new('RGB', (w, h), BG)
    y = 0
    for r in rows:
        rw = sum(t.width for t in r) + gap * (len(r) - 1)
        x = (w - rw) // 2
        for t in r:
            g.paste(t, (x, y))
            x += t.width + gap
        y += max(t.height for t in r) + gap
    return g


def wrap(text, f, width):
    d = ImageDraw.Draw(Image.new('RGB', (4, 4)))
    lines, line = [], ''
    for word in text.split():
        trial = (line + ' ' + word).strip()
        if d.textlength(trial, font=f) > width and line:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line] if line else lines


def banner(w, text, sub=None):
    lines = wrap(sub, font(14, False), w) if sub else []
    top = 38 if text else 4
    h = top + 19 * len(lines) + 4
    b = Image.new('RGB', (w, h), BG)
    d = ImageDraw.Draw(b)
    if text:
        d.text((0, 6), text, font=font(24), fill=AFTER)
    for i, line in enumerate(lines):
        d.text((0, top + 19 * i), line, font=font(14, False), fill=SUB)
    return b


def plural(n):
    return '%d part%s' % (n, '' if n == 1 else 's')


T = 232
fruit = grid([pair('fruit_' + i, n, T, 'fruit', i, counts(i, 'fruit')) for i, n in FRUITS], 3)
plant = grid([pair('plant_' + i, n + ', ripe plant', T, 'plant', i, counts(i, 'plant')) for i, n in FRUITS], 3)
V = 290
verity = grid([pair(n, t, V, k, 'VeritySeed', counts('VeritySeed', 'fruit' if k == 'fruit' else 'plant')) for n, t, k in VERITY], 2)
W = max(fruit.width, plant.width, verity.width) + 40
parts = [
    banner(W - 40, 'R151: no white shine parts on the fruit, one face on the Verity fruit',
           'before = the branch head %s, after = this change; both built by the real game modules on the Roblox mock, drawn by three.js (approximate: plain materials, no textures)' % base),
    banner(W - 40, 'The fruit as the hotbar / Bag / Index see it', 'the white gloss / glint patches are gone (the parts themselves, colours, stripes, sizes and pivots are unchanged)'),
    fruit,
    banner(W - 40, 'The same fruit on the plant', 'ripe plants: the Watermelon, Snow Melon, Ember Pumpkin and Apple lose their gloss parts, Blueberry / Iceberry their glints'),
    plant,
    banner(W - 40, 'The Verity fruit has ONE face',
           'item / hotbar / Bag / Index and the harvest flight: the face looks to -Z, where those cameras are. Planted: the face looks to +Z, the side of the plot the player stands on (the Verity PACK keeps both faces)'),
    verity,
    banner(W - 40, '', 'Not Roblox renders. The Watermelon, Snow Melon and Ember Pumpkin are drawn from the baked vertex data; any other baked mesh would be a stand-in ellipsoid. Verity\'s face is a Decal the renderer cannot load: the small dark smiley marks the side(s) it is on. The soft highlight on a plain ball is the renderer\'s own lighting, not a part.')
]
H = sum(p.height for p in parts) + 18 * len(parts) + 20
canvas = Image.new('RGB', (W, H), BG)
y = 14
for p in parts:
    canvas.paste(p, ((W - p.width) // 2 if p.width != W - 40 else 20, y))
    y += p.height + 18
canvas.save(out, optimize=True)
print('wrote %s (%dx%d)' % (out, canvas.width, canvas.height))
