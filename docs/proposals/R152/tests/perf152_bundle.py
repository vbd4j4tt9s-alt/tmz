"""R152 performance patch: bundles a src tree for the perf152 drivers (the same output as R151's mkbundle_rare.py, for ANY src tree: the R152 candidate's
or this checkout's). Usage: python3 perf152_bundle.py <src dir> <out dir> [all-client] [server] [Name=path under src ...]
Writes <out>/rs_bundle.luau: every ReplicatedStorage module, plus every StarterPlayerScripts client script (all-client, by its name without .client.lua),
every ChestChaseServer module (server) and any Name=path given."""
import os, sys

src, out = sys.argv[1], sys.argv[2]
pairs = {}
rs = os.path.join(src, 'ReplicatedStorage')
for f in sorted(os.listdir(rs)):
    if f.endswith('.lua'):
        pairs[f[:-4]] = os.path.join(rs, f)
for arg in sys.argv[3:]:
    if arg == 'all-client':
        d = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
        for f in sorted(os.listdir(d)):
            if f.endswith('.client.lua'):
                pairs[f[:-11]] = os.path.join(d, f)
    elif arg == 'server':
        d = os.path.join(src, 'ServerScriptService', 'ChestChaseServer')
        for f in sorted(os.listdir(d)):
            if f.endswith('.lua') and not f.endswith('.server.lua'):
                pairs[f[:-4]] = os.path.join(d, f)
    else:
        k, v = arg.split('=', 1)
        pairs[k] = v if os.path.isabs(v) else os.path.join(src, v)
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
print(len(pairs), 'modules')
