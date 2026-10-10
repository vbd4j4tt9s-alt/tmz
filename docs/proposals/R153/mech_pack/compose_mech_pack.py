"""R153 Mech pack proposal: lays the rendered tiles (render_mech_pack.py) out as docs/proposals/R153/mech_pack.png and writes the labels.

Usage: python3 -I compose_mech_pack.py <tile dir> <out.png>
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

BG = (9, 18, 30)
PANEL = (14, 30, 48)
WHITE = (240, 244, 248)
MUTED = (160, 180, 200)
CYAN = (34, 231, 255)
GOLD = (255, 205, 84)
PINK = (230, 125, 255)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def wrap(draw, text, f, width):
    out, line = [], ''
    for word in text.split(' '):
        test = (line + ' ' + word).strip()
        if draw.textlength(test, font=f) <= width:
            line = test
        else:
            out.append(line)
            line = word
    if line:
        out.append(line)
    return out


def bullets(draw, x, y, items, width, f, color=WHITE, gap=6):
    for item in items:
        lines = wrap(draw, item, f, width - 22)
        draw.text((x, y), '•', font=f, fill=CYAN)
        for i, ln in enumerate(lines):
            draw.text((x + 20, y), ln, font=f, fill=color)
            y += f.size + 4
        y += gap
    return y


TILE_BG = (14, 30, 48)   # render_mech_pack.BG


def content_box(im, margin=18):
    """The box around everything that is not the plain backdrop (the bloom halo counts a little)."""
    diff = ImageChops.difference(im, Image.new('RGB', im.size, TILE_BG)).convert('L').point(lambda v: 255 if v > 22 else 0)
    b = diff.getbbox() or (0, 0, im.width, im.height)
    return (max(0, b[0] - margin), max(0, b[1] - margin), min(im.width, b[2] + margin), min(im.height, b[3] + margin))


def union(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def fit(im, w, h):
    k = min(w / im.width, h / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def tile(tiles, name, scale):
    im = Image.open(os.path.join(tiles, name)).convert('RGB')
    return im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)


LOOKS = [
    ('today', 'TODAY', 'Limited Mech Pack as built', None, [
        'White pouch (Forest_01 painted 231,237,239), gold seal and tear strips',
        '5 x 6 fitted armour panels, 2 pistons, reactor + turbine; 174 parts, 34 move',
        'Held: 10 orbiting scanner teeth + 2 scan bars',
        'At hotbar size it reads pale, close to a Snow pack; Forest_01\'s print shows through the white (R151 audit)',
    ]),
    ('a', 'A  REFIT', 'low effort, ~0.5 day', None, [
        'Same rig, same motion: a repaint',
        'Gunmetal pouch, darker steel panels, the gold panels become a hazard-yellow band',
        'Yellow / black block seal: the 8 tear strips alternate (no texture)',
        'Bigger bright hex bolt heads; part count unchanged',
    ]),
    ('b', 'B  CIRCUIT MECH', 'medium, ~2-3 days', 'RECOMMENDED', [
        'Gunmetal pouch, riveted steel frame, cyan circuit traces from the reactor (a pulse runs along them)',
        'Keeps today\'s reactor + turbine; drops the panels and pistons (about the same part count)',
        '4 hex corner bolts (the reveal unscrews them), hazard-stripe seal, small antenna + LED, MECH plate',
        'Held: a soft cyan hum glow + antenna sparks instead of the 10 teeth',
    ]),
    ('c', 'C  HOLO-CHROME', 'medium-high, ~3-5 days', None, [
        'Holographic chrome pouch: the rainbow shifts as it turns (like the Holo plants)',
        'Round scanner window with a seed hologram and a scan ring',
        'Chrome seal with a cyan light line',
        'Needs a foil texture (upload, or drawn on the client); iridescence cannot be checked offline',
    ]),
]

STORY = [
    ('story_1_held.png', '1  HELD', 'idle, any time', [
        'Hum glow + a few sparks at the antenna; the LED blinks',
        'Sound: none',
    ]),
    ('story_2_clicks.png', '2  CLICKS 1-4', 'before the reveal clock', [
        'Each click backs out one corner bolt (here after click 3); click 5 opens as now',
        'Sound: UpgradeClick (a ratchet tick) instead of Bubble04, same volume',
    ]),
    ('story_3_scan.png', '3  SCAN', 'the wobble pulses (Mythic: .35 .66 .94 1.16 s)', [
        'A scan line sweeps the face on each pulse, in the R152 hint colour; the core and traces show it too',
        'Sound: the PackShake already there; nothing added',
    ]),
    ('story_4_unlatch.png', '4  UNLATCH', 'the tear groups (2, 3, 3 strips at 0 / .38 / .72)', [
        'The hazard seal flips open group by group with a puff of steam each',
        'Sound: Flight whoosh pitched up as a soft hiss, under the -30 LUFS whoosh cap',
    ]),
    ('story_5_burst.png', '5  BURST', 'BurstAt (Mythic 1.30 s)', [
        'Steam ring, the turbine spins down, the seed comes out',
        'Then the normal R152 card / Secret+ story scene, unchanged',
    ]),
]

VALUE = [
    ('1A', 'Secret+ pity: at least one Secret+ in every 10 Mech packs opened (saved per player, meter on the pack)', '10% -> 15.4%', '+16%', 'medium', True),
    ('1B', '10-pack guarantee: every 10-PACK purchase has at least one Secret+', '10% -> 13.5% (10-packs)', '+11% (10-pack)', 'low-med', False),
    ('1C', 'Coats: Gold 4.5% / Diamond 0.5% Mech packs; the seed keeps the coat (Mech plants already draw it)', 'same', '+2.3%', 'low-med', True),
    ('1D', 'A 7th, Mech-only seed (new plant art, Index set grows)', 'same', 'n/a', 'high', False),
]


def timeline(draw, x, y, w):
    """The Mythic suspense on the R152 clock (RarePullRules: Pulses, Heartbeats, TearTicks, BurstAt), with the Mech cues on its beats."""
    at = 1.3
    pulses = [at * (1 - (1 - i / 5) ** 1.4) for i in range(1, 5)]
    tears = [0, .38 * at, .72 * at]
    sx = lambda t: x + 150 + (t + 0.6) / (at + 0.9) * (w - 170)  # noqa: E731
    f = font(17)
    fb = font(17, True)
    draw.text((x, y - 2), 'Mythic, on the', font=f, fill=MUTED)
    draw.text((x, y + 20), 'R152 clock (s)', font=f, fill=MUTED)
    draw.line((sx(-0.6), y + 30, sx(at + 0.3), y + 30), fill=MUTED, width=2)
    for t in (0, 0.5, 1.0, at):
        draw.line((sx(t), y + 24, sx(t), y + 36), fill=MUTED, width=2)
        draw.text((sx(t) + 6, y + 36), '%.2g s' % t if t != at else '1.3 s', font=f, fill=MUTED)
    for i, t in enumerate((-0.5, -0.38, -0.26, -0.14)):
        draw.ellipse((sx(t) - 7, y + 23, sx(t) + 7, y + 37), outline=WHITE, width=2)
    draw.text((sx(-0.55), y - 6), 'clicks 1-4: bolts', font=fb, fill=WHITE)
    for t in pulses:
        draw.rectangle((sx(t) - 3, y + 16, sx(t) + 3, y + 44), fill=PINK)
    draw.text((sx(pulses[0]) - 10, y - 6), 'scan on each pulse', font=fb, fill=PINK)
    for t in tears:
        draw.polygon([(sx(t), y + 62), (sx(t) - 8, y + 76), (sx(t) + 8, y + 76)], fill=GOLD)
    draw.text((sx(tears[0]) - 300, y + 60), 'unlatch + steam (tear groups)', font=fb, fill=GOLD)
    draw.line((sx(at), y + 8, sx(at), y + 50), fill=CYAN, width=5)
    draw.text((sx(at) + 10, y - 6), 'burst: steam ring', font=fb, fill=CYAN)
    draw.text((x, y + 92), 'No beat is added and nothing gets longer: every Mech cue sits on a beat the reveal already has (one clock), at most 2 extra voices, each quieter '
              'than the hit (the R152 loudness test keeps running).', font=f, fill=MUTED)


def main(tiles, out):
    W = 2640
    sheet = Image.new('RGB', (W, 3600), BG)
    d = ImageDraw.Draw(sheet)
    y = 26
    d.text((40, y), 'Mech pack: three looks, a Mech reveal and the value options (R153 proposal, previews only)', font=font(44, True), fill=WHITE)
    y += 62
    sub = ('Blender (Cycles) on R151\'s stand-in chip-bag pouch. TODAY is the game\'s own 174 parts (SpecialPackArt89, dumped on the mock) placed on the stand-in; '
           'A / B / C and the storyboard are built from plain parts the same way. Approximate: no Roblox textures, no Future lighting, bloom imitated. '
           'Nothing in the game is changed.')
    for ln in wrap(d, sub, font(20), W - 80):
        d.text((40, y), ln, font=font(20), fill=MUTED)
        y += 27
    y += 18
    # LOOKS -----------------------------------------------------------------------------------------------------------------------------
    d.text((40, y), '1. THE LOOK  (front three-quarter + side; both faces carry the design, as in the game)', font=font(28, True), fill=CYAN)
    y += 48
    colw = (W - 80 - 3 * 24) // 4
    top = y
    heroes = {k: Image.open(os.path.join(tiles, 'hero_%s.png' % k)).convert('RGB') for k, *_ in LOOKS}
    sides = {k: Image.open(os.path.join(tiles, 'side_%s.png' % k)).convert('RGB') for k, *_ in LOOKS}
    hb = union([content_box(im) for im in heroes.values()])   # one crop for all four: the same scale, a fair comparison
    sb = union([content_box(im) for im in sides.values()])
    art_h = 620
    k = min(art_h / (hb[3] - hb[1]), (colw - 44) / ((hb[2] - hb[0]) + 0.85 * (sb[2] - sb[0])))
    art_h = int((hb[3] - hb[1]) * k)
    texts_h = []
    for *_, items in LOOKS:
        scratch = ImageDraw.Draw(Image.new('RGB', (10, 10)))
        texts_h.append(bullets(scratch, 0, 0, items, colw - 30, font(18)))
    panel_h = 84 + art_h + 20 + max(texts_h) + 14
    for i, (key, title, effort, badge, items) in enumerate(LOOKS):
        x = 40 + i * (colw + 24)
        d.rounded_rectangle((x, top, x + colw, top + panel_h), 14, fill=PANEL, outline=GOLD if badge else (40, 60, 84), width=4 if badge else 2)
        d.text((x + 18, top + 14), title, font=font(30, True), fill=WHITE)
        d.text((x + 18, top + 52), effort, font=font(19), fill=MUTED)
        if badge:
            bw = d.textlength(badge, font=font(18, True)) + 24
            d.rounded_rectangle((x + colw - bw - 16, top + 16, x + colw - 16, top + 46), 8, fill=GOLD)
            d.text((x + colw - bw - 4, top + 20), badge, font=font(18, True), fill=(30, 20, 0))
        hero = heroes[key].crop(hb)
        hero = hero.resize((int(hero.width * k), int(hero.height * k)), Image.LANCZOS)
        side = sides[key].crop(sb)
        side = side.resize((int(side.width * k * 0.85), int(side.height * k * 0.85)), Image.LANCZOS)
        hx = x + max(10, (colw - hero.width - side.width - 10) // 2)
        sheet.paste(hero, (hx, top + 84))
        sheet.paste(side, (hx + hero.width + 10, top + 84 + art_h - side.height))
        bullets(d, x + 18, top + 84 + art_h + 20, items, colw - 30, font(18))
    y = top + panel_h + 30
    # HOTBAR ---------------------------------------------------------------------------------------------------------------------------
    d.text((40, y), '2. AT HOTBAR SIZE', font=font(28, True), fill=CYAN)
    y += 46
    icons = [('today', 'TODAY'), ('a', 'A'), ('b', 'B'), ('c', 'C'), ('context', 'a Snow pack (colour only)')]
    x = 40
    for key, label in icons:
        im = Image.open(os.path.join(tiles, 'icon_%s.png' % key)).convert('RGB')
        im = fit(im.crop(content_box(im, 6)), 116, 116)   # the hotbar fits the item to its slot
        d.rounded_rectangle((x, y, x + 140, y + 140), 12, fill=TILE_BG, outline=(90, 100, 116), width=3)
        sheet.paste(im, (x + 70 - im.width // 2, y + 70 - im.height // 2))
        d.text((x + 70 - d.textlength(label, font=font(17)) / 2 if len(label) < 12 else x, y + 148), label, font=font(17), fill=WHITE)
        x += 170
    note = ['Today\'s white body and pale panels sit close to the pale Snow packs at 120 px; the cyan core is the only cue.',
            'A and B read as "machine" at a glance (dark body, yellow / black seal); C reads as "special" (shiny) but less as "robot".',
            'The hotbar, Bag and Index pictures are ViewportFrames: they show the parts (and Neon), not the bloom.']
    bullets(d, x + 90, y + 6, note, W - x - 130, font(19))
    y += 200
    # REVEAL ---------------------------------------------------------------------------------------------------------------------------
    d.text((40, y), '3. THE OPENING: a Mech touch on the R152 reveal (drawn on option B; A and today have bolts and a reactor too)', font=font(28, True), fill=CYAN)
    y += 46
    sw = (W - 80 - 4 * 18) // 5
    frames = [Image.open(os.path.join(tiles, n)).convert('RGB') for n, *_ in STORY]
    fb = union([content_box(im, 10) for im in frames])
    frames = [fit(im.crop(fb), sw - 16, 640) for im in frames]
    fh = max(im.height for im in frames)
    th = max(bullets(ImageDraw.Draw(Image.new('RGB', (10, 10))), 0, 0, it, sw - 24, font(17)) for *_, it in STORY)
    ph = 70 + fh + 12 + th + 10
    for i, (name, title, when, items) in enumerate(STORY):
        x = 40 + i * (sw + 18)
        d.rounded_rectangle((x, y, x + sw, y + ph), 12, fill=PANEL, outline=(40, 60, 84), width=2)
        im = frames[i]
        sheet.paste(im, (x + (sw - im.width) // 2, y + 70))
        d.text((x + 16, y + 10), title, font=font(26, True), fill=WHITE)
        d.text((x + 16, y + 42), when, font=font(16), fill=MUTED)
        bullets(d, x + 14, y + 70 + fh + 12, items, sw - 24, font(17))
    y += ph + 24
    timeline(d, 40, y + 10, W - 80)
    y += 150
    # VALUE ----------------------------------------------------------------------------------------------------------------------------
    d.text((40, y), '4. VALUE OPTIONS AT A GLANCE  (per-seed odds stay 48 / 26 / 16 / 7 / 2.5 / 0.5 %; price stays 80 / 375 / 700 gems = Robux)', font=font(28, True), fill=CYAN)
    y += 50
    cols = [(40, 'Opt'), (120, 'What'), (1520, 'Secret+ rate'), (1860, 'Value / pack'), (2080, 'Effort'), (2260, 'Pick')]
    for cx, label in cols:
        d.text((cx, y), label, font=font(19, True), fill=MUTED)
    y += 32
    for key, what, rate, ev, effort, pick in VALUE:
        d.rounded_rectangle((32, y - 6, W - 40, y + 38), 8, fill=PANEL)
        d.text((40, y), key, font=font(20, True), fill=GOLD if pick else WHITE)
        d.text((120, y), what, font=font(19), fill=WHITE)
        d.text((1520, y), rate, font=font(19), fill=WHITE)
        d.text((1860, y), ev, font=font(19), fill=WHITE)
        d.text((2080, y), effort, font=font(19), fill=WHITE)
        d.text((2260, y), 'recommended' if pick else '', font=font(19, True), fill=GOLD)
        y += 52
    d.text((40, y + 4), 'Value / pack = average cash per second of the plant (fruit value x fruits / regrow, EconomyBalance90) at size 1x; today 5.05M/s per Mech pack. '
           'Pity and coats are their own lines next to the odds, so the shown per-seed rates (and the Void / Verity Mech branches, which use the same table) do not move.',
           font=font(17), fill=MUTED)
    y += 50
    sheet = sheet.crop((0, 0, W, y))
    sheet.save(out, optimize=True)
    print('sheet ->', out, sheet.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
