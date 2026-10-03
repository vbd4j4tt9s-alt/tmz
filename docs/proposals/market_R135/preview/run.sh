#!/bin/sh
# Usage: sh run.sh <scratch dir>. R135 market fruit: renders the market before R135 (from git)
# and the proposal (MarketLayout135) close on the fruit, runs the floating check on both, and draws the fruit lineup
# (every fruit stood on a shelf, with how well it stands). Needs /opt/luau, python3 + numpy + PIL, node + playwright
# (global), three.js (npm install three@0.169.0 in the scratch dir). Approximate renders.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/seeds_R133/preview/seeds.html" "$HERE"/* "$S/"
git -C "$REPO" show f18f674:src/ServerScriptService/ChestChaseServer/MarketLayout.lua > "$S/MarketLayoutR134.lua"  # the market before R135
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$S/rs_bundle.luau" MarketLayoutR131="$S/MarketLayoutR134.lua" MarketLayout="$HERE/../MarketLayout135.lua" >/dev/null
cd "$S";[ -d node_modules/three ] || npm install three@0.169.0 >/dev/null
[ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright
(echo "WHICH='new'";cat dump_market.luau)>d_new.luau;(echo "WHICH='old'";cat dump_market.luau)>d_old.luau
/opt/luau/luau d_new.luau | grep '^{' >new.json;/opt/luau/luau d_old.luau | grep '^{' >old.json
echo "== floating parts (proposal)";python3 check_market.py new.json || true
/opt/luau/luau dump_fruits.luau | grep '^{' > fruits.json;python3 fruit_stand.py fruits.json > fruit_stand.txt
node render_market.mjs "$S" "$HERE/.."
node render_fruits.mjs "$S" fruits.json "$HERE/../fruit_lineup.png"
