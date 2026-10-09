"""R155 Mech pack coats: lays render_mech_coats.py's tiles (and the shop card pictures of run_shop_states.sh) out as docs/proposals/R155/mech_coats.png.

Usage: python3 -I compose_mech_coats.py <tile dir> <shop states dir> <dump.txt> <out.png>
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'R153', 'mech_pack'))
import compose_mech_pack as C  # noqa: E402  (the R153 sheets' fonts, colours and helpers)

GOLD = (255, 205, 84)
ICE = (190, 235, 255)
W = 2200


def panel(d, box, title, color, outline):
    d.rounded_rectangle(box, 14, fill=C.PANEL, outline=outline, width=3)
    d.text((box[0] + 22, box[1] + 14), title, font=C.font(32, True), fill=color)


def paste_fit(im, src, box, pad=0):
    x0, y0, x1, y1 = box
    r = C.fit(src, x1 - x0 - 2 * pad, y1 - y0 - 2 * pad)
    im.paste(r, (x0 + (x1 - x0 - r.width) // 2, y0 + (y1 - y0 - r.height) // 2))


def header(im, d, y, text, color=None):
    f = C.font(28, True)
    for ln in C.wrap(d, text, f, W - 80):
        d.text((40, y), ln, font=f, fill=color or C.CYAN)
        y += 36
    return y + 8


def cropped(tiles, name):
    im = Image.open(os.path.join(tiles, name)).convert('RGB')
    return im.crop(C.content_box(im, 14))


def main(tiles, shop, dump, out):
    items = [json.loads(l[5:]) for l in open(dump, encoding='utf-8') if l.startswith('ITEM ')]
    pack = {i['coat']: i for i in items if i['kind'] == 'pack'}
    count = pack['None']['count']
    H = 7000   # (cropped to what is drawn at the end)
    im = Image.new('RGB', (W, H), C.BG)
    d = ImageDraw.Draw(im)
    d.text((40, 26), 'Mech pack coats (R155): Gold 4.5% / Diamond 0.5% on every pack you buy', font=C.font(46, True), fill=C.WHITE)
    sub = ('Blender (Cycles) renders of the parts the game builds: SeedPackVisuals.Bag (the world packs\' coat treatment) on MechPackArt153, MechPackFx153\'s opening copy and PlantVisuals / MechArt for '
           'the plants, dumped on the Roblox mock with the owner\'s templates and the server\'s generated flat pouch. Each part is drawn at its own size, colour and material (Metal + Reflectance .38 = '
           'polished gold; Glass + Transparency = tinted glass). Approximate: no Future lighting, bloom imitated. Remake it with sh docs/proposals/R155/preview/run_mech_coats_preview.sh.')
    y = 92
    for ln in C.wrap(d, sub, C.font(21), W - 80):
        d.text((40, y), ln, font=C.font(21), fill=C.MUTED)
        y += 27
    y += 14

    # 1. the pack, three coats ------------------------------------------------------------------------------------------------------------------
    cols = [('None', 'PLAIN  95%', C.CYAN, (40, 70, 96), ['Gunmetal pouch, riveted frame, cyan traces, hazard seal, red LED (R153 look B)', 'What every Mech pack was before: still the most common']),
            ('Gold', 'GOLD  4.5%', GOLD, GOLD, ['The pouch, seal, strips, frame, bolts, reactor housing, blades and gears take the world Gold: colour 255,201,70, Metal, Reflectance .38',
                                                 'Kept: the cyan traces, core, MECH letters on their dark plate, the red LED, the black hazard stripes']),
            ('Diamond', 'DIAMOND  0.5%', ICE, ICE, ['The same parts in the world Diamond: colour 213,247,255, Glass, Reflectance .28, Transparency .20 on the pouch and .10 on the parts',
                                                    'Kept: the same lit parts and stripes, so the circuit still shows through the glass'])]
    pw = (W - 80 - 2 * 24) // 3
    ph = 1090
    for k, (coat, title, color, outline, notes) in enumerate(cols):
        x = 40 + k * (pw + 24)
        panel(d, (x, y, x + pw, y + ph), title, color, outline)
        tag = 'plain' if coat == 'None' else coat.lower()
        paste_fit(im, cropped(tiles, 'hero_%s.png' % tag), (x + 10, y + 64, x + pw - 10, y + 64 + 800))
        C.bullets(d, x + 22, y + 884, notes, pw - 44, C.font(21))
    y += ph + 26

    # 2. hotbar --------------------------------------------------------------------------------------------------------------------------------
    y = header(im, d, y, 'IN THE HOTBAR AND THE BAG (ItemPictures builds the picture from the same parts; the hotbar shows parts and Neon, not bloom)')
    xx = 40
    for coat, label in (('None', 'PLAIN'), ('Gold', 'GOLD'), ('Diamond', 'DIAMOND')):
        tag = 'plain' if coat == 'None' else coat.lower()
        icon = Image.open(os.path.join(tiles, 'icon_%s.png' % tag)).convert('RGB')
        b = C.content_box(icon, 10)
        side = max(b[2] - b[0], b[3] - b[1])
        cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
        sq = Image.new('RGB', (side, side), C.TILE_BG)
        sq.paste(icon.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)), (0, 0))
        for size in (100, 200):
            sm = sq.resize((size, size), Image.LANCZOS)
            d.rounded_rectangle((xx - 6, y + 4, xx + size + 6, y + 10 + size), 10, outline=(70, 110, 140), width=2, fill=C.PANEL)
            im.paste(sm, (xx, y + 7))
            d.text((xx, y + 18 + size), '%s %dpx' % (label, size), font=C.font(18), fill=C.MUTED)
            xx += size + 30
        xx += 22
    C.bullets(d, xx + 10, y + 10, [
        'At 100 px the cyan core and traces are still the brightest thing on all three; the gold and the ice read at once next to the gunmetal pack',
        'The Bag and the hotbar key a Gold / Diamond Mech pack apart from a plain one (ItemPictures: "Pack|8|MechLimited|Gold"), and the tool is named "Gold Limited Mech Pack"'],
        W - xx - 50, C.font(21))
    y += 270

    # 3. held + opening ------------------------------------------------------------------------------------------------------------------------
    for title, prefix, notes in (
            ('HELD (the carry: welded to the torso; the hum light and the antenna sparks are as before, the pack and the carrier are drawn from the real parts)', 'held',
             'The coat is on the pack in the hand exactly as on the ground (the same parts at the same places); the cyan hum glow lights the gold and the glass'),
            ('THE OPENING (a real frame of MechPackFx153 on the opening copy: the third scan line of a Mythic reveal in its hint colour, the corner bolts backed out)', 'open',
             'Click 1-4 back out the bolts, each wobble pulse sweeps the scan line, the tear groups steam, the burst rings: all on the coated pack too (the R153 suite runs on a Gold and a Diamond pack)')):
        y = header(im, d, y, title)
        tw = (W - 80 - 2 * 24) // 3
        for k, (coat, label, color) in enumerate((('None', 'PLAIN', C.CYAN), ('Gold', 'GOLD', GOLD), ('Diamond', 'DIAMOND', ICE))):
            x = 40 + k * (tw + 24)
            tag = 'plain' if coat == 'None' else coat.lower()
            d.rounded_rectangle((x, y, x + tw, y + 640), 14, fill=C.PANEL, outline=(40, 70, 96), width=2)
            d.text((x + 18, y + 10), label, font=C.font(26, True), fill=color)
            paste_fit(im, cropped(tiles, '%s_%s.png' % (prefix, tag)), (x + 8, y + 46, x + tw - 8, y + 632))
        y += 656
        C.bullets(d, 40, y, [notes], W - 80, C.font(21))
        y += 54

    # 4. seed, plant, fruit --------------------------------------------------------------------------------------------------------------------
    y = header(im, d, y, 'THE SEED, THE PLANT AND THE FRUIT (the reveal keeps the coat; a coated plant is Gold / Diamond; each fruit has a 20% chance to carry it)')
    bw = (W - 80 - 24) // 2
    for k, (tag, title, color, notes) in enumerate((
            ('plant_gold', 'GOLD PLASMA PEPPER: the plant is gold; one of its 3 peppers came up Gold (the 20% roll), the other two are plain', GOLD,
             'Gold fruit pays x3 of the same fruit, Diamond x6 (BalanceRules; 20% of the fruit of a coated plant, rolled per fruit slot and harvest)'),
            ('plant_diamond', 'DIAMOND PLASMA PEPPER: the plant is glass; one of its 3 peppers came up Diamond, the other two are plain', ICE,
             'The seed is the Bag\'s "Gold Plasma Pepper Seed" / "Diamond Plasma Pepper Seed": the same seed, in its coat'))):
        x = 40 + k * (bw + 24)
        d.rounded_rectangle((x, y, x + bw, y + 1240), 14, fill=C.PANEL, outline=(40, 70, 96), width=2)
        for j, ln in enumerate(C.wrap(d, title, C.font(22, True), bw - 36)):
            d.text((x + 18, y + 12 + j * 28), ln, font=C.font(22, True), fill=color)
        paste_fit(im, cropped(tiles, tag + '.png'), (x + 8, y + 80, x + bw - 8, y + 80 + 780))
        C.bullets(d, x + 18, y + 880, [notes], bw - 36, C.font(20))
        # the seeds, plain next to coated
        sx = x + 18
        seed = ('PlasmaPepperSeed', 'gold') if k == 0 else ('PlasmaPepperSeed', 'diamond')
        for name, label in (('seed_%s_none.png' % seed[0], 'plain seed'), ('seed_%s_%s.png' % seed, '%s seed' % seed[1])):
            s = cropped(tiles, name)
            r = C.fit(s, 150, 150)
            im.paste(r, (sx, y + 1000))
            d.text((sx, y + 1156), label, font=C.font(17), fill=C.MUTED)
            sx += 200
    y += 1264

    # 5. the shop card + the lines -------------------------------------------------------------------------------------------------------------
    y = header(im, d, y, 'THE SHOP CARD (the real GamePassClient on the shop test harness; the 3D previews are placeholders there)')
    cw = (W - 80 - 24) // 2
    for k, (state, title) in enumerate((('live', 'LIVE: the coat line next to the odds, the countdown to 1 Nov 2026 00:00 UTC (the Index LIMITED tab\'s format)'),
                                        ('ended', 'ENDED: "EVENT OVER!", "THANKS FOR PLAYING!", both buy buttons "Event over" and off; the server refuses a new purchase too'))):
        x = 40 + k * (cw + 24)
        png = Image.open(os.path.join(shop, state, 'png', 'pc_1280x720.png')).convert('RGB')
        s = png.width / 1280.0
        card = png.crop((int(168 * s), int(146 * s), int(1108 * s), int(442 * s)))
        d.rounded_rectangle((x, y, x + cw, y + 460), 14, fill=C.PANEL, outline=(40, 70, 96), width=2)
        for j, ln in enumerate(C.wrap(d, title, C.font(20, True), cw - 36)):
            d.text((x + 18, y + 10 + j * 26), ln, font=C.font(20, True), fill=GOLD if state == 'live' else C.MUTED)
        paste_fit(im, card, (x + 10, y + 74, x + cw - 10, y + 452))
    y += 484
    d.rounded_rectangle((40, y, W - 40, y + 330), 14, fill=C.PANEL, outline=(40, 70, 96), width=2)
    d.text((62, y + 12), 'THE WORDS', font=C.font(26, True), fill=C.WHITE)
    # (the game's lines carry an hourglass, a check mark, a sparkle and a gem emoji; the sheet's font has none, so they are named in brackets)
    lines = [
        ('hold tooltip', 'Gold Limited Mech Pack  /  Plasma Pepper: 1/2  ...  Crowncore Tree: 1/200  /  Gold 4.5% / Diamond 0.5% coat   (the last line is new; a plain pack\'s name has no coat word)'),
        ('shop card', 'Gold 4.5% / Diamond 0.5% coat   |   [hourglass] ENDS IN 27d 04h 12m 09s   |   after the end: EVENT OVER!  THANKS FOR PLAYING!'),
        ('"Bought" notice', '[check] Bought: 10 Mech Packs! [sparkle] 1 GOLD + [gem] 1 DIAMOND!   (one pack: Bought: 1 Mech Pack! [sparkle] GOLD MECH PACK!; nothing coated: the plain notice, as before)'),
        ('after the end', 'a purchase the server refuses says: EVENT\'S OVER! THANKS FOR PLAYING!  (nothing is charged, no prompt opens); a Robux receipt for a prompt opened before the end is still granted'),
        ('/test mechshop', 'Gold 4.5% / Diamond 0.5% coat on every pack u buy (each pack rolls its own; free packs stay plain).  Limited event: ends in 27d 04h 12m 09s.'),
    ]
    yy = y + 56
    for name, text in lines:
        d.text((62, yy), name, font=C.font(21, True), fill=C.CYAN)
        for j, ln in enumerate(C.wrap(d, text, C.font(21), W - 80 - 280 - 40)):
            d.text((330, yy + j * 26), ln, font=C.font(21), fill=C.WHITE)
        yy += 26 * max(1, len(C.wrap(d, text, C.font(21), W - 80 - 280 - 40))) + 14
    y += 350
    im = im.crop((0, 0, W, y))
    im.save(out)
    print('sheet ->', out, im.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
