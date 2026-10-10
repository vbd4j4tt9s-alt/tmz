#!/bin/sh
# Usage: sh run.sh [scratch dir]. R124 hide bushes: real HideBushes124 on the place's bush geometry + real HideBushClient.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);SRC=$HERE/../../../../src
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE/bush_fixture.luau" "$HERE/test_bushes.luau" "$OUT/"
python3 - "$OUT" "$SRC" <<'PY'
import sys
out,src=sys.argv[1],sys.argv[2]
def long(s):
    l=1
    while (']'+'='*l+']') in s: l+=1
    return '['+'='*l+'[\n'+s+']'+'='*l+']'
items={'HideBushes124':src+'/ServerScriptService/ChestChaseServer/HideBushes124.lua','HideBushClient':src+'/StarterPlayer/StarterPlayerScripts/HideBushClient.client.lua'}
open(out+'/bundle.luau','w').write('return {'+','.join('%s=%s'%(k,long(open(v).read())) for k,v in items.items())+'}')
PY
cd "$OUT";/opt/luau/luau test_bushes.luau
