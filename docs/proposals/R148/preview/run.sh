#!/bin/sh
# Usage: sh run.sh <scratch dir> [node_modules dir with three@0.169 and playwright]. Renders docs/proposals/R148/verity_npc.png (and
# verity_npc_aerial.png, verity_npc_close.png) from the REAL builders on the mock: MarketLayout (the market) and VerityService +
# VerityConfig (Verity: the yellow ball, her dais, the name sign). Needs /opt/luau, node + playwright (global) and three.js
# (npm install three@0.169.0 in the scratch dir, or pass an existing node_modules). Approximate render: no Roblox materials or fonts,
# the smiley is a drawn stand-in (the real picture cannot be downloaded here), seed packs on the market shelves are skipped.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_verity.luau" "$HERE/view.html" "$HERE/render_verity.mjs" "$S/"
sed "s#/home/user/tmz/src#$REPO/src#" "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" > "$S/mkbundle_cl.py"
python3 "$S/mkbundle_cl.py" "$S/rs_bundle.luau" MarketLayout="$REPO/src/ServerScriptService/ChestChaseServer/MarketLayout.lua" VerityService="$REPO/src/ServerScriptService/ChestChaseServer/VerityService.lua" >/dev/null
cd "$S"
if [ -n "$2" ]; then [ -e node_modules ] || ln -s "$2" node_modules
else [ -d node_modules/three ] || npm install three@0.169.0 >/dev/null; [ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright; fi
/opt/luau/luau dump_verity.luau | grep '^{' > scene.json
node render_verity.mjs "$S" "$HERE/.."
