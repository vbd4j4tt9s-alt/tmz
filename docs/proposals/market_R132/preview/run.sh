#!/bin/sh
# Usage: sh run.sh <scratch dir>. Renders docs/proposals/market_R132/market_*.png from the REAL builders on the mock
# (MarketLayout = the polished R132 market, MarketLayoutR131 = the market before, taken from git). Needs /opt/luau,
# node + playwright (global) and three.js (npm install three@0.169.0 in the scratch dir). Approximate renders: no
# Roblox materials or fonts; seed packs are skipped (their approved meshes only exist in the place).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/* "$S/"
git -C "$REPO" show 624da26:src/ServerScriptService/ChestChaseServer/MarketLayout.lua > "$S/MarketLayoutR131.lua"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$S/rs_bundle.luau" MarketLayoutR131="$S/MarketLayoutR131.lua" MarketLayout="$REPO/src/ServerScriptService/ChestChaseServer/MarketLayout.lua" >/dev/null
cd "$S";[ -d node_modules/three ] || npm install three@0.169.0 >/dev/null
[ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright
(echo "WHICH='new'";cat dump_market.luau)>d_new.luau;(echo "WHICH='old'";cat dump_market.luau)>d_old.luau
/opt/luau/luau d_new.luau | grep '^{' >new.json;/opt/luau/luau d_old.luau | grep '^{' >old.json
node render_market.mjs "$S" "$HERE/.."
