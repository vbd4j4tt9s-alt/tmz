#!/bin/sh
# Usage: sh run_wall.sh [scratch dir]. Refresh wall: real RefreshBarrier / RefreshCountdown / TrackBlackout / TrackRefreshSky.
# Writes wall.json (front-face GUI dump) next to the log; render with: python3 render.py wall.json OUT.png
set -e
HERE=$(cd "$(dirname "$0")" && pwd);SRC=$HERE/../../../../src
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$SRC/../tools/tests/roblox.luau" "$HERE/wall_test.luau" "$OUT/"
python3 - "$OUT" "$SRC" <<'PY'
import sys
out,src=sys.argv[1],sys.argv[2]
def long(s):
    l=1
    while (']'+'='*l+']') in s: l+=1
    return '['+'='*l+'[\n'+s+']'+'='*l+']'
items={k:src+'/ReplicatedStorage/'+k+'.lua' for k in ('RefreshBarrier','RefreshCountdown','TrackBlackout')}
items['TrackRefreshSky']=src+'/StarterPlayer/StarterPlayerScripts/TrackRefreshSky.client.lua'
open(out+'/wall_bundle.luau','w').write('return {'+','.join('%s=%s'%(k,long(open(v).read())) for k,v in items.items())+'}')
PY
cd "$OUT";/opt/luau/luau wall_test.luau > wall.log 2>&1 || { tail -30 wall.log; exit 1; }
grep '^JSON ' wall.log | sed 's/^JSON //' > wall.json;grep -v '^JSON ' wall.log | tail -3
