"""Lay the Cycles renders out as the proposal images (plain Python 3 + Pillow).

Usage: python3 compose_sheets.py PANEL_DIR OUT_DIR
Writes OUT_DIR/keeper_<name>.png, keepers_faces.png, keepers_before_after.png, keepers_lineup.png.
"""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont

PANELS, OUT = sys.argv[1], sys.argv[2]
META = json.load(open(os.path.join(PANELS, 'meta.json')))
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
INK, MUTED, PAPER = (28, 32, 40), (92, 98, 112), (247, 248, 250)
NEW_C, OLD_C = (24, 120, 70), (150, 40, 40)
STATES = ['Chase', 'Asleep']
STATE_LABEL = {'Chase': 'Awake / chase face', 'Asleep': 'Asleep face'}


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


ORDER = ['timber_golem', 'jungle_king', 'sand_snake', 'ice_fang', 'lava_dragon', 'crystal_knight', 'storm_colossus', 'the_darkened']
STAGE_OF = {1: 'timber_golem', 6: 'jungle_king', 2: 'sand_snake', 3: 'ice_fang', 4: 'lava_dragon', 5: 'crystal_knight',
            7: 'storm_colossus', 0: 'the_darkened'}
NATIVE_TODAY = {'timber_golem', 'crystal_knight', 'storm_colossus', 'the_darkened'}
FROM_SCREENSHOTS = {'jungle_king', 'sand_snake'}
TODAY_PARTS = {'timber_golem': '63 blocks + 3 accents', 'jungle_king': '23 mesh parts', 'sand_snake': '17 mesh parts + 3 accents',
               'ice_fang': '21 mesh parts + 41 accent/armour parts', 'lava_dragon': '27 mesh parts', 'crystal_knight': '50 blocks + 3 accents',
               'storm_colossus': '30 blocks + 5 accents', 'the_darkened': '43 blocks'}
REF = {
    'timber_golem': "Owner note: improve today's in-game golem. Today's exact parts, as crisp bevelled blocks: brown trunk, split-bark beard, green stepped leaf hood, hollow face, root knuckles, wide root legs. New: a clean glowing-slit face, today's chest rune in a knothole, moss, bark grooves, a bird's nest. Still sleeps as a tree.",
    'jungle_king': 'Owner note: improve today\'s in-game gorilla (owner screenshots). Kept: dark brown fur, the grey-green face mask and chest, glowing yellow eyes, mossy shoulders, the hunched knuckle-walking build. New: chunkier blocks, a clean flat-mask face, vine bands, a moss-and-leaf crown.',
    'sand_snake': 'Owner note: improve today\'s in-game snake (owner screenshots). Kept: tan with the brown diamond back, the wedge viper head with yellow eyes and a dark eye stripe, golden brow horns, the golden lower jaw, the rattle. New: chunkier segments, a bigger head, a clean face on its flat sides.',
    'ice_fang': 'Owner note: a thicker, sturdier torso. Rev 6: a broad deep chest with a big white ruff, a thick barrel torso, heavy haunches and thick legs with big paws, in the clunky style of the other keepers; the rev 5 fox head and huge crystal-tipped tail kept.',
    'lava_dragon': 'Owner note: a longer body to fit the Ice and Fire proportions (14.4 studs, was 10.6), the tail moved back with it. Otherwise as rev 4: fanned finger-strut wings, a crown of horns and frills, a long stepped neck, bone spikes to the tail tip, lava colours.',
    'crystal_knight': "Owner note: a real knight's longsword, not a dagger: a long straight double-edged blade (15 studs, longer than his leg) with a short point, a wide crossguard with crystal quillons, a wrapped grip, a gold pommel. Bulk as rev 4.",
    'storm_colossus': "Owner note: an actual stone giant, not plain. Today's identity (slate colours, chest bolt, tilted shoulder rocks with V-prongs, charged joints, banded fists, floating cloud crown) as an ancient colossus: rugged boulders, glowing storm cracks, moss and lichen, a carved rune belt, a craggy brow, a jagged stone crown, lightning.",
    'the_darkened': 'Owner note: keep it as it is. Unchanged from rev 3: today\'s slim black head and glowing line, polished (crisp bevelled blocks, angular cores for the ball joints, a pulsing void slit, tattered cloak, claws, wisps).',
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
    fw = 384
    cols = 4
    W = cols * pw + 5 * 12
    head = 150
    d0 = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    fnote = font(18)
    notes = ['Personality: ' + m['personality'], 'Idle fidget: ' + m['fidget'], 'Effects (particles in game): ' + m['fx'], REF[key]]
    note_x = 12 + 2 * (fw + 12) + 20
    note_lines = []
    for n in notes:
        note_lines += ['- ' + l if i == 0 else '  ' + l for i, l in enumerate(wrap(d0, n, fnote, W - note_x - 30))]
        note_lines.append('')
    face_h = max(fw, 25 * len(note_lines)) + 40
    H = head + 2 * (ph + 12) + face_h + 30
    img = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.text((24, 16), '%s  -  %s keeper' % (m['name'], m['biome']), font=font(34, True), fill=INK)
    tag(d, (W - 210, 24), 'PROPOSED', fill=(220, 242, 228), ink=NEW_C, f=font(20, True))
    d.text((24, 62), 'Real Blender model, Cycles render, studs on. Chase / attack / asleep use the game\'s own pose frames.', font=font(18), fill=MUTED)
    d.text((24, 88), '%s triangles on screen (%s with both faces)  |  %d mesh parts (today: %s)' % (
        format(m['tris_visible'], ','), format(m['tris'], ','), m['parts'], TODAY_PARTS[key]), font=font(18), fill=MUTED)
    d.text((24, 114), 'Moving groups (same names the game animates today): ' + ', '.join(m['groups']), font=font(15), fill=MUTED)
    for i, (name, label) in enumerate(LABELS):
        p = Image.open(os.path.join(PANELS, '%s_%s.png' % (key, name))).convert('RGB').resize((pw, ph), Image.LANCZOS)
        x = 12 + (i % cols) * (pw + 12)
        y = head + (i // cols) * (ph + 12)
        img.paste(p, (x, y))
        tag(d, (x + 12, y + 10), label, f=font(15, True))
    y = head + 2 * (ph + 12)
    d.text((24, y + 4), 'Two faces (swappable face pieces): awake / chase and asleep', font=font(20, True), fill=INK)
    y += 34
    for j, st in enumerate(STATES):
        p = Image.open(os.path.join(PANELS, 'face_%s_%s.png' % (key, st))).convert('RGB').resize((fw, fw), Image.LANCZOS)
        x = 12 + j * (fw + 12)
        img.paste(p, (x, y))
        tag(d, (x + 10, y + 10), STATE_LABEL[st], f=font(15, True))
    yy = y + 6
    for l in note_lines:
        d.text((note_x, yy), l, font=fnote, fill=INK)
        yy += 25
    path = os.path.join(OUT, 'keeper_%s.png' % key)
    img.save(path, optimize=True)
    return path


def faces_sheet():
    """One row of the 8 keepers, each with its awake / chase face above its asleep face."""
    fw = 270
    left = 120
    W = left + 8 * (fw + 10) + 14
    head = 150
    H = head + 2 * (fw + 10) + 60
    img = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.text((24, 16), 'Keeper faces: awake / chase vs asleep (close-ups, Cycles)', font=font(32, True), fill=INK)
    d.text((24, 60), 'Two swappable face pieces per keeper, flat decals on a flat face plane. The Golem and the Colossus have no human face '
                     '(glowing slits, a crack); the Knight keeps a closed helm; The Darkened keeps today\'s line.', font=font(16), fill=MUTED)
    d.text((24, 82), 'The sleep "Z" is left out of the close-ups (it is in each keeper sheet\'s asleep view). Asleep faces are shown on the '
                     'standing pose, from the front.', font=font(16), fill=MUTED)
    for j, key in enumerate(ORDER):
        x = left + j * (fw + 10)
        for li, line in enumerate(wrap(d, META[key]['name'], font(17, True), fw - 8)[:2]):
            d.text((x + 4, head - 44 + li * 20), line, font=font(17, True), fill=INK)
    for i, st in enumerate(STATES):
        y = head + i * (fw + 10)
        for li, line in enumerate(wrap(d, STATE_LABEL[st], font(16, True), left - 24)):
            d.text((14, y + fw / 2 - 20 + li * 20), line, font=font(16, True), fill=INK)
        for j, key in enumerate(ORDER):
            p = Image.open(os.path.join(PANELS, 'face_%s_%s.png' % (key, st))).convert('RGB').resize((fw, fw), Image.LANCZOS)
            img.paste(p, (left + j * (fw + 10), y))
    path = os.path.join(OUT, 'keepers_faces.png')
    img.save(path, optimize=True)
    return path


def before_after():
    pw, ph = 400, 315
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
    d.text((26, 80), 'TODAY for the Gorilla and Snake = the hull of the game\'s own sample points plus its exact details, coloured from the owner\'s screenshots; for the Tiger and Dragon = STAND-INS (same hulls, assumed colour).',
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
                t = 'TODAY - exact parts' if key in NATIVE_TODAY else ('TODAY - from owner screenshots' if key in FROM_SCREENSHOTS else 'TODAY - stand-in')
                tag(d, (px + 10, y + 44), t, fill=(250, 228, 228), ink=OLD_C, f=font(14, True))
            else:
                tag(d, (px + 10, y + 44), 'PROPOSED - %s tris on screen' % format(m['tris_visible'], ','), fill=(220, 242, 228), ink=NEW_C, f=font(14, True))
    d.text((26, H - 50), 'Cycles renders of real Blender scenes, standing pose from the game\'s pose code, awake face. Proposed models shown with the stud texture.',
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
        top = max(0, int(info['ground_y'] - 47 * info['px_per_stud']))
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
        title = 'TODAY (Tiger, Dragon: stand-ins; Gorilla, Snake: from owner screenshots)' if which == 'today' else 'PROPOSED'
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
            key = STAGE_OF[it['stage']]
            cx = 80 + (it['px0'] + it['px1']) / 2 * scale
            for t, f, dy in ((META[key]['name'], font(15, True), 0), ('%.0f studs tall' % it['height'], font(14), 20)):
                tw = d.textlength(t, font=f)
                d.text((cx - tw / 2, y + dy), t, font=f, fill=INK if dy == 0 else MUTED)
        y += lab
    path = os.path.join(OUT, 'keepers_lineup.png')
    img.save(path, optimize=True)
    return path


if __name__ == '__main__':
    for key in ORDER:
        if key in META and 'tris' in META[key] and os.path.exists(os.path.join(PANELS, 'face_%s_Asleep.png' % key)):
            print(keeper_sheet(key))
    if all(os.path.exists(os.path.join(PANELS, 'face_%s_Asleep.png' % k)) and k in META and 'personality' in META[k] for k in ORDER):
        print(faces_sheet())
    if all(k in META and 'today_tris_standin' in META[k] for k in ORDER):
        print(before_after())
    if 'lineup_new' in META and 'lineup_today' in META:
        print(lineup())
