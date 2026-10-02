#!/bin/sh
# Reproduce the R123 keeper-look previews. W = a scratch folder holding cfmath.luau and loader.luau (from the
# R113 keeper test kit), node_modules/{three,playwright}, and a module bundle of current src (R113 mkbundle.py).
set -e
W=${W:-/tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/r123}
HERE=$(cd "$(dirname "$0")" && pwd)
python3 - "$W" "$HERE" <<'PY'
import sys;W,H=sys.argv[1],sys.argv[2]
s=open(H+'/../BeastModelsRefined.lua').read();lvl=1
while ']'+'='*lvl+']' in s: lvl+=1
eq='='*lvl;d=open(H+'/dump_refined.luau').read().replace('--!nocheck\n','')
open(W+'/run_dump.luau','w').write('REFINED_SRC=[%s[\n%s]%s]\n'%(eq,s,eq)+d)
PY
cd "$W" && /opt/luau/luau run_dump.luau > scenes.json
python3 -c "import json;print(json.load(open('$W/scenes.json'))['report'])"
cp "$HERE/render.html" "$HERE/render.mjs" "$W/" && node render.mjs "$HERE/../renders"
