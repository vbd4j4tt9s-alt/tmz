#!/bin/sh
# Usage: sh run_snow_hub_preview.sh <scratch dir> [place.rbxl] [base commit]
# R151 hub snow render (docs/proposals/R151/snow_hub.png): before / after a blizzard in the hub, from a base, from the market and from above.
#  1. docs/proposals/R149/tools/rbxl_geom.py reads Workspace.ChestChaseMap from the owner's place file.
#  2. docs/proposals/R151/tests/hub_snow_scene.luau runs the real start-up builders (+ the R151 festival square) and the REAL weather client for
#     40 s of blizzard with the player at each view's spot, and dumps the scene. AFTER = this checkout; BEFORE = this checkout with the base
#     commit's WeatherWorld149.lua / SnowPatches149.lua / WeatherWorld149.client.lua (the same hub, the R150 snow).
#  3. docs/proposals/R151/preview/render_base_area.mjs + base_area.html (the R151 base-area renderer, three.js in headless Chromium) draws the
#     views of snow_hub_views.json; make_snow_hub_sheet.py puts them on one sheet.
# Needs /opt/luau, python3 + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0 (installed in the scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${3:-ad40efc}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/out" "$S/before"
rm -rf "$S/before/src";cp -r "$REPO/src" "$S/before/src"
for f in src/ReplicatedStorage/WeatherWorld149.lua src/ReplicatedStorage/SnowPatches149.lua src/StarterPlayer/StarterPlayerScripts/WeatherWorld149.client.lua;do
 git -C "$REPO" show "$BASE:$f" > "$S/before/$f"
done
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/place_tree.luau" Workspace/ChestChaseMap >/dev/null
: > "$S/stats.txt"
scene() { # $1 = old|new, $2 = src, $3 = view, $4 = x,z
 W=$S/w_$1_$3;mkdir -p "$W"
 cp "$S/place_tree.luau" "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$W/"
 python3 "$REPO/docs/proposals/R151/tests/bundle_hubsnow.py" "$2" "$W" >/dev/null
 printf '%s\n' "PLAYER={$4};SECONDS=40;TIER=3;DUMP=true" > "$W/run.luau";cat "$REPO/docs/proposals/R151/tests/hub_snow_scene.luau" >> "$W/run.luau"
 (cd "$W" && timeout 900 /opt/luau/luau run.luau > run.log 2>&1) || { tail -20 "$W/run.log";exit 1; }
 grep '^SCENE' "$W/run.log" | sed 's/^SCENE //' > "$S/$1_$3.json"
 grep '^STATS' "$W/run.log" | sed 's/^STATS //' | python3 -c "import json,sys;s=json.loads(sys.stdin.read());print('$1','$3',s['discs'],'%.1f'%(s['coverage']*100),s['zones'])" >> "$S/stats.txt"
}
for v in base:-118,-186 market:44,-316 aerial:0,-150;do
 name=${v%%:*};pos=${v#*:}
 scene new "$REPO/src" "$name" "$pos";scene old "$S/before/src" "$name" "$pos"
done
cat "$S/stats.txt"
cp "$HERE/base_area.html" "$HERE/render_base_area.mjs" "$S/"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null 2>&1)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_base_area.mjs" "$S" "$HERE/snow_hub_views.json" "$S/out" \
 new="$S/new_base.json@base" new="$S/new_market.json@market" new="$S/new_aerial.json@aerial" \
 old="$S/old_base.json@base" old="$S/old_market.json@market" old="$S/old_aerial.json@aerial"
python3 "$HERE/make_snow_hub_sheet.py" "$S/out" "$HERE/snow_hub_views.json" "$REPO/docs/proposals/R151/snow_hub.png" "$S/stats.txt"
