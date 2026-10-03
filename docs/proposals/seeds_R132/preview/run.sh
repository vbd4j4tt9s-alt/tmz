#!/bin/sh
# Usage: sh run.sh <scratch dir>. Renders docs/proposals/seeds_R132/seeds_{now,proposed}.png from the REAL seed builders on
# the mock (SeedPackVisuals now; SeedPackVisuals132 + SeedSignatures132 proposed). Needs /opt/luau, node + playwright
# (global) and three.js (npm install three@0.169.0). Approximate renders. Mech seeds are separate models, not shown.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/* "$S/"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$S/rs_bundle.luau" SeedPackVisuals132="$HERE/../SeedPackVisuals132.lua" SeedSignatures132="$HERE/../SeedSignatures132.lua" SeedShapes132="$HERE/../SeedShapes132.lua" >/dev/null
cd "$S";[ -d node_modules/three ] || npm install three@0.169.0 >/dev/null
[ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright
(echo "WHICH='new'";cat dump_seeds.luau)>d_new.luau;(echo "WHICH='old'";cat dump_seeds.luau)>d_old.luau
/opt/luau/luau d_new.luau>seeds_new.json;/opt/luau/luau d_old.luau>seeds_old.json
node render_seeds.mjs "$S" "$HERE/.."
