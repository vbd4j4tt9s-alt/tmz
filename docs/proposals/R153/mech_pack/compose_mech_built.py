"""R153 Mech pack as BUILT: lays render_mech_built.py's tiles out as docs/proposals/R153/mech_pack_built.png (today next to the built look B, front
three-quarter, side and back, and both at hotbar size) and writes the labels and the part counts read from built_parts.json.

Usage: python3 -I compose_mech_built.py <tile dir> <built_parts.json> <out.png>
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose_mech_pack as C  # noqa: E402  (the proposal sheet's fonts, colours and helpers)


def main(tiles, built_path, out):
    built = json.load(open(built_path, encoding='utf-8'))
    parts = [p for p in built['parts'] if p['shape'] != 'Mesh']
    design = [p for p in parts if p['name'] not in ('BottomSeal',) and not p['name'].startswith('TearStrip')]
    W, H = 2200, 1660
    im = Image.new('RGB', (W, H), C.BG)
    d = ImageDraw.Draw(im)
    d.text((40, 26), 'Mech pack, BUILT: look B "Circuit Mech" from the game\'s own parts (R153)', font=C.font(46, True), fill=C.WHITE)
    sub = ('Blender (Cycles) renders. TODAY: R152\'s 174 parts (SpecialPackArt89) on R151\'s stand-in pouch, as in mech_pack.png. BUILT B: every part the game now builds '
           '(MechPackArt153 through SeedPackVisuals.Bag on the owner\'s templates, dumped on the Roblox mock), each at its own size, frame, colour and material, '
           'on VerityPouch151\'s generated flat pouch (its real triangles). Approximate: no Future lighting, bloom imitated.')
    y = 92
    for ln in C.wrap(d, sub, C.font(21), W - 80):
        d.text((40, y), ln, font=C.font(21), fill=C.MUTED)
        y += 27
    top = y + 18
    # the hero row: today (front + side) | built B (front + side + back)
    panels = [
        ('TODAY (R152)', ['built_today_hero.png', 'built_today_side.png'], [
            'Forest_01 pouch painted white: its print shows through (R151 audit)',
            '174 parts: armour panels, pistons, reactor + turbine; gold seal',
            'Held: 12 orbiting neon scanner pieces']),
        ('BUILT B (R153)', ['built_b_hero.png', 'built_b_side.png', 'built_b_back.png'], [
            'Gunmetal flat pouch (white vertex colours: no print); riveted steel frame',
            'Cyan traces out of R103\'s reactor + turbine; 4 hex corner bolts; MECH plate',
            'Hazard seal: yellow strips, a black stripe through each; antenna + red LED',
            '%d design parts (today 174), both faces; every layer .046 apart' % len(design),
            'Held: a soft cyan hum light + antenna sparks (Attachments on the pack)']),
    ]
    x = 40
    widths = [720, 1380]
    for (title, files, notes), pw in zip(panels, widths):
        ph = 1060
        d.rounded_rectangle((x, top, x + pw, top + ph), 14, fill=C.PANEL, outline=(40, 70, 96) if 'TODAY' in title else C.GOLD, width=3)
        d.text((x + 22, top + 16), title, font=C.font(34, True), fill=C.WHITE)
        ims = [C.tile(tiles, f, 1.0) for f in files]
        boxes = [C.content_box(i) for i in ims]
        crops = [i.crop(b) for i, b in zip(ims, boxes)]
        avail_h = 760
        k = min(avail_h / max(c.height for c in crops), (pw - 40 - 20 * (len(crops) - 1)) / sum(c.width for c in crops))
        cx = x + 20
        total = sum(int(c.width * k) for c in crops) + 20 * (len(crops) - 1)
        cx = x + (pw - total) // 2
        for c in crops:
            r = c.resize((max(1, int(c.width * k)), max(1, int(c.height * k))), Image.LANCZOS)
            im.paste(r, (cx, top + 70 + (avail_h - r.height) // 2))
            cx += r.width + 20
        C.bullets(d, x + 22, top + 70 + avail_h + 24, notes, pw - 44, C.font(22))
        x += pw + 40
    # hotbar size: the two icons at the hotbar's size (and 2x), next to each other
    y2 = top + 1060 + 30
    d.text((40, y2), 'AT HOTBAR SIZE (ItemPictures\' view; the hotbar shows parts and Neon, not bloom)', font=C.font(30, True), fill=C.CYAN)
    xx = 40
    for name, label in (('built_icon_today.png', 'TODAY'), ('built_icon_b.png', 'BUILT B')):
        icon = Image.open(os.path.join(tiles, name)).convert('RGB')
        # (framed like ItemPictures frames a pack: the pack fills the card, a small margin round it)
        b = C.content_box(icon, 10)
        side = max(b[2] - b[0], b[3] - b[1])
        cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
        sq = Image.new('RGB', (side, side), C.TILE_BG)
        sq.paste(icon.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)), (0, 0))
        icon = sq
        for size in (100, 200):
            sm = icon.resize((size, size), Image.LANCZOS)
            d.rounded_rectangle((xx - 6, y2 + 50, xx + size + 6, y2 + 56 + size), 10, outline=(70, 110, 140), width=2, fill=C.PANEL)
            im.paste(sm, (xx, y2 + 53))
            d.text((xx, y2 + 64 + size), '%s %dpx' % (label, size), font=C.font(18), fill=C.MUTED)
            xx += size + 40
        xx += 40
    C.bullets(d, xx + 20, y2 + 60, [
        'The dark body and the yellow / black seal read "machine" at 100 px; the cyan core and traces are the brightest thing on it',
        'The pictures are drawn from the same parts (ItemPictures keeps every visible part, drops lights / emitters / attachments)'],
        W - xx - 60, C.font(22))
    im.save(out)
    print('sheet ->', out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
