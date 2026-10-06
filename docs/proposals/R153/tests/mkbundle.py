"""R153: bundle every ReplicatedStorage module and every ChestChaseServer module of a source tree into OUT/rs_bundle.luau for the Roblox mock, plus the client scripts the
4 Leaf Clover tests load (GamePassClient, PurchaseCelebration), and write OUT/srv_names.luau (the server module names, moved under ServerScriptService.ChestChaseServer by the test).
Usage: python3 mkbundle.py OUTDIR [--src SRC_DIR] [--font FONT.ttf] [Name=path ...]
  --src SRC_DIR   the tree to bundle (default: this checkout's src). run_clover.sh gives the R152 release (git archive) for the old-server test.
  --font F.ttf    also write OUTDIR/metrics.luau: the advance widths of the font (Fredoka One) for the mock TextService, as the R120 shop test does.
  Name=path       an extra / replacing module (e.g. a client script of another tree)."""
import os
import sys

args = sys.argv[1:]
out = args.pop(0)
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
if '--src' in args:
    i = args.index('--src')
    src = os.path.abspath(args[i + 1])
    del args[i:i + 2]
font = None
if '--font' in args:
    i = args.index('--font')
    font = args[i + 1]
    del args[i:i + 2]
pairs, server = {}, []
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs[f[:-4]] = src + '/ReplicatedStorage/' + f
for f in sorted(os.listdir(src + '/ServerScriptService/ChestChaseServer')):
    if f.endswith('.lua') and not f.endswith('.server.lua'):
        pairs[f[:-4]] = src + '/ServerScriptService/ChestChaseServer/' + f
        server.append(f[:-4])
for name in ('GamePassClient', 'PurchaseCelebration'):
    p = src + '/StarterPlayer/StarterPlayerScripts/' + name + '.client.lua'
    if os.path.exists(p):
        pairs[name] = p
for arg in args:
    name, path = arg.split('=', 1)
    pairs[name] = path
parts = ['return {']
for name, path in pairs.items():
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
os.makedirs(out, exist_ok=True)
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
open(os.path.join(out, 'srv_names.luau'), 'w').write('return {' + ','.join('"%s"' % n for n in server) + '}')
print(len(pairs), 'modules')
if font:
    from PIL import ImageFont
    f = ImageFont.truetype(font, 100)
    open(os.path.join(out, 'metrics.luau'), 'w').write('return {' + ','.join('[%d]=%.4f' % (c, f.getlength(chr(c)) / 100) for c in range(32, 127)) + '}')
