"""Lay the Cycles renders out as the proposal images (plain Python 3 + Pillow).

Usage: python3 compose_sheets.py PANEL_DIR OUT_DIR
Writes OUT_DIR/keeper_<name>.png, keepers_before_after.png, keepers_lineup.png.
"""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont

PANELS, OUT = sys.argv[1], sys.argv[2]
META = json.load(open(os.path.join(PANELS, 'meta.json')))
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
INK, MUTED, PAPER = (28, 32, 40), (92, 98, 112), (247, 248, 250)
NEW_C, OLD_C = (24, 120, 70), (150, 40, 40)


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


ORDER = ['timber_golem', 'jungle_king', 'sand_snake', 'ice_fang', 'lava_dragon', 'crystal_knight', 'storm_colossus', 'the_darkened']
NATIVE_TODAY = {'timber_golem', 'crystal_knight', 'storm_colossus', 'the_darkened'}
TODAY_PARTS = {'timber_golem': '63 blocks + 3 accents', 'jungle_king': '23 mesh parts', 'sand_snake': '17 mesh parts + 3 accents',
               'ice_fang': '21 mesh parts + 41 accent/armour parts', 'lava_dragon': '27 mesh parts', 'crystal_knight': '50 blocks + 3 accents',
               'storm_colossus': '30 blocks + 5 accents', 'the_darkened': '43 blocks'}
NOTES = {
    'timber_golem': ['Same tree golem, and it still sleeps disguised as a tree: each new piece follows today\'s tree pose.',
                     'Round barrel trunk with carved bark grooves, a big cloud-shaped leaf crown, glowing green eyes in carved sockets and a jagged wooden grin.',
                     'The chest rune and the mushrooms (extra accent parts today) are now part of the model.'],
    'jungle_king': ['Same silverback gorilla king: a bigger head with a heavy angry brow, glowing amber eyes and fangs.',
                    'Huge shaped arms with knuckle fists, a silver saddle on the back, a vine sash and vine bracers, and a gold leaf crown with a glowing orchid.'],
    'sand_snake': ['Same desert viper: a raised neck and a wide hood with spectacle marks, big amber slit eyes, little horns, fangs and a forked tongue.',
                   'A diamond saddle pattern runs down all 9 body segments. The tail rattle stays as it is (it still buzzes while it hunts).'],
    'ice_fang': ['Same snow sabre-tiger, still in its silver-and-sapphire armour (helm, collar, pauldrons, saddle) with ice spines.',
                 'The armour and spines are now part of the model (today they are 41 extra parts). Rounder head, big ice-blue eyes, cheek ruffs, sabre fangs, crisp stripes, thick legs and big paws.'],
    'lava_dragon': ['Same lava dragon: a big head with bone horns, glowing red eyes and a toothy jaw; a round body with gold belly plates.',
                    'Glowing lava spine, nostrils and tail flame (Neon parts, like today\'s glow parts). Bat wings with bones and scalloped orange skin, at today\'s in-game wing size.'],
    'crystal_knight': ['Same crystal knight: a rounded helm with a T-visor and two glowing eyes, a crystal crest, crystal clusters on the shoulders and a glowing crystal heart.',
                       'A crystal blade with a glowing core. The three orbiting crystal shards stay as they are.'],
    'storm_colossus': ['Same floating storm colossus: a boulder body and head with an angry brow and glowing eyes, a lightning bolt in the chest.',
                       'Floating fists with glowing bands, glowing joints, thunder prongs on the shoulders. The drifting storm-cloud crown stays as it is.'],
    'the_darkened': ['Same tall veiled figure: a pale mask with glowing violet eyes and the glowing cleft, a hood, a tattered cloak and long claws.',
                     'Hit shapes stay today\'s boxes: every body piece fits inside the box of the part it replaces. Hood, cloak and claws are cosmetic (never hit).'],
}
LABELS = [('front', 'Front'), ('three_quarter', 'Three-quarter'), ('side', 'Side'), ('back', 'Back'),
          ('chase', 'Chase (real run frame)'), ('windup', 'Attack wind-up (real frame)'), ('strike', 'Attack impact (real frame)'),
          ('asleep', 'Asleep (real frame)')]


def tag(d, xy, text, fill=(255, 255, 255), ink=INK, f=None):
    f = f or font(17, True)
    x, y = xy
    bb = d.textbbox((x, y), text, font=f)
    d.rounded_rectangle((bb[0] - 7, bb[1] - 5, bb[2] + 7, bb[3] + 5), 6, fill=fill)
    d.text((x, y), text, font=f, fill=ink)


def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def keeper_sheet(key):
    m = META[key]
    pw, ph = 480, 360
    cols, rows = 4, 2
    W = cols * pw + 5 * 12
    head = 118
    d0 = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    fnote = font(19)
    note_lines = []
    for n in NOTES[key]:
        note_lines += ['- ' + l if i == 0 else '  ' + l for i, l in enumerate(wrap(d0, n, fnote, W - 60))]
    foot = 30 + 27 * len(note_lines) + 16
    H = head + rows * ph + 3 * 12 + foot
    img = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.text((24, 16), '%s  -  %s keeper' % (m['name'], m['biome']), font=font(34, True), fill=INK)
    tag(d, (W - 210, 24), 'PROPOSED', fill=(220, 242, 228), ink=NEW_C, f=font(20, True))
    sub = ('Real Blender model, Cycles render. Poses use the game\'s own pose frames for this keeper.   '
           '%s triangles  |  %d mesh parts (today: %s)' % (format(m['tris'], ','), m['parts'], TODAY_PARTS[key]))
    d.text((24, 62), sub, font=font(18), fill=MUTED)
    d.text((24, 88), 'Moving groups (same names the game animates today): ' + ', '.join(m['groups']), font=font(16), fill=MUTED)
    for i, (name, label) in enumerate(LABELS):
        p = Image.open(os.path.join(PANELS, '%s_%s.png' % (key, name))).convert('RGB').resize((pw, ph), Image.LANCZOS)
        x = 12 + (i % cols) * (pw + 12)
        y = head + (i // cols) * (ph + 12)
        img.paste(p, (x, y))
        tag(d, (x + 12, y + 10), label, f=font(15, True))
    y = head + rows * (ph + 12) + 14
    d.text((24, y), 'What changes', font=font(20, True), fill=INK)
    y += 30
    for l in note_lines:
        d.text((30, y), l, font=fnote, fill=INK)
        y += 27
    path = os.path.join(OUT, 'keeper_%s.png' % key)
    img.save(path, optimize=True)
    return path


def before_after():
    pw, ph = 400, 314
    gap = 14
    pairw = 2 * pw + 8
    cols = 2
    W = cols * pairw + (cols + 1) * 26
    head = 110
    rowh = ph + 76
    H = head + 4 * rowh + 70
    img = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.text((26, 16), 'Keepers: TODAY vs PROPOSED (same camera, same scale, 5-stud player for size)', font=font(28, True), fill=INK)
    d.text((26, 56), 'TODAY for the Golem, Knight, Colossus and The Darkened = their exact native parts (materials approximate).', font=font(17), fill=MUTED)
    d.text((26, 80), 'TODAY for the Snake, Tiger, Dragon and Gorilla = STAND-INS: their uploaded meshes cannot be downloaded here, so each part is the hull of the game\'s own sample points, in an assumed colour.',
           font=font(15), fill=OLD_C)
    for i, key in enumerate(ORDER):
        m = META[key]
        x = 26 + (i % cols) * (pairw + 26)
        y = head + (i // cols) * rowh
        d.text((x, y + 4), '%s (%s)' % (m['name'], m['biome']), font=font(20, True), fill=INK)
        for j, which in enumerate(('today', 'new')):
            p = Image.open(os.path.join(PANELS, 'ba_%s_%s.png' % (key, which))).convert('RGB').resize((pw, ph), Image.LANCZOS)
            px = x + j * (pw + 8)
            img.paste(p, (px, y + 34))
            if which == 'today':
                t = 'TODAY - exact parts' if key in NATIVE_TODAY else 'TODAY - stand-in'
                tag(d, (px + 10, y + 44), t, fill=(250, 228, 228), ink=OLD_C, f=font(14, True))
            else:
                tag(d, (px + 10, y + 44), 'PROPOSED - %s tris' % format(m['tris'], ','), fill=(220, 242, 228), ink=NEW_C, f=font(14, True))
    d.text((26, H - 50), 'Cycles renders of real Blender scenes. Keepers in their standing pose from the game\'s pose code; accents shown where the game shows them.',
           font=font(15), fill=MUTED)
    path = os.path.join(OUT, 'keepers_before_after.png')
    img.save(path, optimize=True)
    return path


def lineup():
    scale = 0.75
    rows = []
    for which in ('today', 'new'):
        info = META['lineup_%s' % which]
        im = Image.open(os.path.join(PANELS, 'lineup_%s.png' % which)).convert('RGB')
        top = max(0, int(info['ground_y'] - 47 * info['px_per_stud']))  # crop the empty sky above 47 studs
        im = im.crop((0, top, im.width, im.height))
        info = dict(info, ground_y=info['ground_y'] - top)
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
        rows.append((which, im, info))
    W = rows[0][1].width + 90
    head = 96
    lab = 58
    H = head + sum(r[1].height + lab + 40 for r in rows) + 20
    img = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.text((24, 14), 'Keeper line-up next to a 5-stud Roblox player (orthographic: true relative sizes)', font=font(30, True), fill=INK)
    d.text((24, 56), 'Biome order Forest, Jungle, Desert, Snow, Lava, Crystal, Storm, then The Darkened. Each keeper turned to three-quarter view, standing pose. Ruler in studs.',
           font=font(17), fill=MUTED)
    y = head
    for which, im, info in rows:
        title = 'TODAY (Snake, Tiger, Dragon, Gorilla are stand-ins)' if which == 'today' else 'PROPOSED'
        tag(d, (24, y + 6), title, fill=(250, 228, 228) if which == 'today' else (220, 242, 228), ink=OLD_C if which == 'today' else NEW_C,
            f=font(18, True))
        y += 38
        img.paste(im, (80, y))
        ppx5 = 5 * info['px_per_stud'] * scale
        gy = y + info['ground_y'] * scale
        d.line((62, gy, 62, y + 6), fill=INK, width=2)
        k = 0
        while gy - k * ppx5 > y + 8:
            yy = gy - k * ppx5
            d.line((54 if k % 2 == 0 else 58, yy, 66, yy), fill=INK, width=2)
            if k % 2 == 0:
                d.text((14, yy - 9), '%d' % (k * 5), font=font(14), fill=INK)
            k += 1
        y += im.height + 4
        for it in info['items']:
            key = ORDER[[1, 6, 2, 3, 4, 5, 7, 0].index(it['stage'])]
            cx = 80 + (it['px0'] + it['px1']) / 2 * scale
            name = META[key]['name']
            t1 = name
            t2 = '%.0f studs tall' % it['height']
            for t, f, dy in ((t1, font(15, True), 0), (t2, font(14), 20)):
                tw = d.textlength(t, font=f)
                d.text((cx - tw / 2, y + dy), t, font=f, fill=INK if dy == 0 else MUTED)
        y += lab
    path = os.path.join(OUT, 'keepers_lineup.png')
    img.save(path, optimize=True)
    return path


if __name__ == '__main__':
    for key in ORDER:
        if key in META and 'tris' in META[key]:
            print(keeper_sheet(key))
    if all(k in META and 'today_tris_standin' in META[k] for k in ORDER):
        print(before_after())
    if 'lineup_new' in META and 'lineup_today' in META:
        print(lineup())
