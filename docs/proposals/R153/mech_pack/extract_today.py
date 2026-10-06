"""R153 Mech pack proposal: today's Mech pack parts (one face) for the Blender preview.

Input: the SCENE lines that R151's docs/proposals/R151/tests/dump_packs.luau prints (the REAL SeedPackVisuals / SpecialPackArt89 build on the
Roblox mock; see run_mech_pack_preview.sh). Output: today_parts.json, the parts of the 'Mech' scene that sit on the FRONT face (Roblox z < 0,
the reactor side the shop camera sees) plus the bottom seal and the eight tear strips, in the pack's root frame (Roblox axes, scale 1).
The pouch MeshPart itself is left out: the preview draws R151's stand-in pouch (its real vertices are an uploaded asset).

Usage: python3 -I extract_today.py <scenes.txt> <today_parts.json>
"""
import json
import sys


def main(src, out):
    scene = None
    with open(src, encoding='utf-8') as f:
        for line in f:
            if line.startswith('SCENE '):
                d = json.loads(line[6:])
                if d.get('label') == 'Mech':
                    scene = d
    if scene is None:
        raise SystemExit('no Mech scene in ' + src)
    keep = []
    for p in scene['parts']:
        name = p['name']
        seal = name == 'BottomSeal' or name.startswith('TearStrip')
        if p['class'] == 'MeshPart':
            continue
        if not seal and p['p'][2] >= 0:
            continue
        keep.append({k: p[k] for k in ('name', 'shape', 'material', 'color', 'p', 'r', 'size')})
    with open(out, 'w', encoding='utf-8') as f:
        json.dump({'source': 'R151 dump_packs.luau, scene Mech (SpecialPackArt89 on the mock), front face + seal', 'attrs': scene['attrs'],
                   'pouch': {'color': [231, 237, 239]}, 'parts': keep}, f, indent=0)
    print('%d of %d parts -> %s' % (len(keep), len(scene['parts']), out))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
