#!/bin/sh
# Usage: sh run_cloudy_preview.sh <scratch dir> [place.rbxl]
# R151 Cloudy sky render (docs/proposals/R151/cloudy.png): the owner's hub under a Clear and under a Cloudy default sky, from Base 1, from the market and at the
# market's front, with the lamps and lanterns glowing warm under Cloudy.
#  1. docs/proposals/R149/tools/rbxl_geom.py reads Workspace.ChestChaseMap from the owner's place file.
#  2. cloudy_scene.luau (a copy of base_area_scene.luau with SKY = 'clear' | 'cloudy') runs the real start-up builders (MapService.new with the market and the R151
#     festival square), the real HubLife151.client (lamps, wall lanterns, the market's warm lights) with the REAL sky state, and dumps the scene plus the real
#     BiomeMood palette numbers for the base ("look").
#  3. cloudy.html + render_cloudy.mjs (three.js in headless Chromium) draw the views of cloudy_views.json; make_cloudy_sheet.py puts them on one sheet.
# APPROXIMATE: no Roblox lighting model, materials, bloom or colour grade (the saturation drop is not drawn). Needs /opt/luau, python3 + Pillow, node + playwright
# (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0 (installed in the scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/scenes" "$S/out"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/cloudy_scene.luau" "$S/t/"
python3 "$REPO/docs/proposals/R151/tests/bundle_cloudy.py" "$REPO/src" "$S/t" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
scene() { # $1 = clear | cloudy
 (printf '%s\n' "$OWN;BUILT=true;CLIENT_TIER=3;SKY='$1'";cat "$S/t/cloudy_scene.luau") > "$S/t/run_$1.luau"
 (cd "$S/t" && timeout 900 /opt/luau/luau "run_$1.luau" > "$S/scenes/$1.log" 2>&1) || { tail -20 "$S/scenes/$1.log";exit 1; }
 if grep -q 'FAILED' "$S/scenes/$1.log";then grep FAILED "$S/scenes/$1.log";exit 1;fi
 grep '^SCENE ' "$S/scenes/$1.log" | sed 's/^SCENE //' > "$S/scenes/$1.json"
 echo "scene $1: $(grep '^ZSCENE' "$S/scenes/$1.log" | sed 's/^ZSCENE //')"
}
scene clear;scene cloudy
cp "$HERE/cloudy.html" "$HERE/render_cloudy.mjs" "$S/"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null 2>&1)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_cloudy.mjs" "$S" "$HERE/cloudy_views.json" "$S/out" \
 clear="$S/scenes/clear.json" cloudy="$S/scenes/cloudy.json"
python3 "$HERE/make_cloudy_sheet.py" "$S/out" "$HERE/cloudy_views.json" "$REPO/docs/proposals/R151/cloudy.png" "$S/scenes/clear.json" "$S/scenes/cloudy.json"
