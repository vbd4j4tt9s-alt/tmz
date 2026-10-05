"""R151 Index preview: the pictures of the packs for the PACKS tab cards, from the three.js renders of the REAL pack scenes (tests/dump_packs.luau: the pack builders on the Roblox
mock with the owner's pack templates; the pouch meshes are stand-in rounded boxes: their vertices are uploaded assets). The Index draws the DEFAULT pouch, so these are the packs as the
templates have them (no shape variation).
Usage: python3 make_index_packs_pictures.py jobs   <scenes.txt> <jobs_black.json> <jobs_white.json>
       python3 make_index_packs_pictures.py matte  <render dir> <out dir>
jobs : the render jobs (render_packs.mjs) of the 42 designs + Void / Mech / Verity, once on a black and once on a white background.
matte: the two renders of each pack give an exact transparent PNG (alpha = 1 - (white - black) / 255, colour = black / alpha), written as Pic_<key>.png; the starter pack is Forest_01, the
       mystery pack a black silhouette of a Forest_03."""
import json
import os
import sys

from PIL import Image

BIOMES = ['Forest', 'Desert', 'Snow', 'Lava', 'Crystal', 'Jungle', 'Storm']
W, H = 260, 300


def keys():
    out = ['%s_%02d' % (b, d) for b in BIOMES for d in range(1, 7)]
    return out + ['Void', 'Mech', 'Verity']


def jobs(scenes, jk, jw):
    names = set()
    for line in open(scenes, encoding='utf-8'):
        if line.startswith('SCENE '):
            names.add(json.loads(line[6:])['label'])
    black, white = [], []
    for key in keys():
        if key not in names:
            print('no scene', key)
            continue
        if key in ('Void', 'Mech', 'Verity'):
            opts = {'az': 14, 'el': 7, 'fit': 'all' if key == 'Void' else 'nofx', 'outline': False}
        else:
            opts = {'az': 12, 'el': 5, 'fit': 'body', 'outline': False}
        black.append({'scene': key, 'name': 'pic', 'w': W, 'h': H, 'opts': dict(opts, bg=0x000000)})
        white.append({'scene': key, 'name': 'pic', 'w': W, 'h': H, 'opts': dict(opts, bg=0xffffff)})
    json.dump(black, open(jk, 'w'))
    json.dump(white, open(jw, 'w'))
    print('jobs: %d packs' % len(black))


def matte(d, out):
    os.makedirs(out, exist_ok=True)
    made = {}
    for key in keys():
        fk, fw = '%s/k_%s_pic.png' % (d, key), '%s/w_%s_pic.png' % (d, key)
        if not (os.path.exists(fk) and os.path.exists(fw)):
            continue
        k, w = Image.open(fk).convert('RGB'), Image.open(fw).convert('RGB')
        kp, wp = k.load(), w.load()
        img = Image.new('RGBA', k.size)
        ip = img.load()
        for y in range(k.height):
            for x in range(k.width):
                r0, g0, b0 = kp[x, y]
                r1, g1, b1 = wp[x, y]
                a = 1 - ((r1 - r0) + (g1 - g0) + (b1 - b0)) / (3 * 255)
                a = min(1, max(0, a))
                if a < 0.02:
                    ip[x, y] = (0, 0, 0, 0)
                else:
                    ip[x, y] = (min(255, int(r0 / a)), min(255, int(g0 / a)), min(255, int(b0 / a)), int(round(a * 255)))
        img = img.crop(img.getbbox())
        img.save('%s/Pic_%s.png' % (out, key))
        made[key] = img
    # the starter pack is the ordinary Forest pack; the mystery pack a black silhouette of a Forest_03
    made['Forest_01'].save('%s/Pic_Starter.png' % out)
    sil = made['Forest_03'].copy()
    px = sil.load()
    for y in range(sil.height):
        for x in range(sil.width):
            r, g, b, a = px[x, y]
            px[x, y] = (10, 8, 22, a)
    sil.save('%s/Pic_Mystery.png' % out)
    print('pictures:', len(made) + 2)


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'jobs':
        jobs(*sys.argv[2:5])
    elif cmd == 'matte':
        matte(*sys.argv[2:4])
