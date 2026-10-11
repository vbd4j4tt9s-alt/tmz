#!/bin/sh
# Usage: sh run.sh <scratch dir>. Renders docs/proposals/R136/reveal_legendary_mythic.gif: a Legendary and a Mythic
# seed pull over 2.4 s with the real RevealFlourish, seed and held-seed effects (approximate render).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S/frames";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/* "$REPO/docs/proposals/seeds_R133/preview/seeds.html" "$REPO/docs/proposals/market_R135/preview/render_fruits.mjs" "$S/"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$S/rs_bundle.luau" >/dev/null
cd "$S";[ -e node_modules ] || ln -s "$(npm root -g)" node_modules
i=0;for t in 0 .15 .3 .45 .6 .7 .78 .86 .95 1.0 1.08 1.18 1.3 1.45 1.6 1.8 2.0 2.2 2.4;do
 (echo "T=$t";cat dump_reveal.luau)>d.luau;/opt/luau/luau d.luau | grep '^{' > f.json;node render_fruits.mjs "$S" f.json "frames/$(printf %02d $i).png" >/dev/null;i=$((i+1))
done
python3 - "$S" "$HERE/.." <<'PY'
import sys,glob
from PIL import Image
S,out=sys.argv[1],sys.argv[2]
frames=[Image.open(f).convert('RGB') for f in sorted(glob.glob(S+'/frames/*.png'))]
frames[0].save(out+'/reveal_legendary_mythic.gif',save_all=True,append_images=frames[1:],duration=120,loop=0)
frames[9].save(out+'/reveal_burst.png');print('gif',len(frames))
PY
