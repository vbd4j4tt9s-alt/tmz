"""Bundle every ReplicatedStorage module + GamePassClient into rs_bundle.luau, and write font
metrics (FredokaOne advance widths) to metrics.luau. Usage: python3 mkbundle.py OUTDIR [font.ttf]"""
import sys, os
out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
pairs = []
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs.append((f[:-4], src + '/ReplicatedStorage/' + f))
pairs.append(('GamePassClient', src + '/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua'))
parts = ['return {']
for name, path in pairs:
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s: level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
# Advance widths per 1px of font size, so the mock TextService measures like Fredoka One.
font = sys.argv[2] if len(sys.argv) > 2 else None
rows = []
if font:
    from PIL import ImageFont
    f = ImageFont.truetype(font, 100)
    for c in range(32, 127):
        rows.append('[%d]=%.4f' % (c, f.getlength(chr(c)) / 100))
open(os.path.join(out, 'metrics.luau'), 'w').write('return {' + ','.join(rows) + '}')
print(len(pairs), 'modules')
