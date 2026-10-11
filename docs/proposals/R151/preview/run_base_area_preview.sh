#!/bin/sh
# Usage: sh run_base_area_preview.sh <scratch dir> [place.rbxl]
# R151 base area + walls redesign (owner: "take a look at a redesign of the base area and the walls what can we add to liven up the base area").
# DESIGN PREVIEW ONLY - nothing in src/ is changed or needed beyond this checkout's src (read-only).
#  1. tools: docs/proposals/R149/tools/rbxl_geom.py reads Workspace.ChestChaseMap from the owner's place file; the R149 Roblox mock
#     (tools/tests/roblox.luau + docs/proposals/inventory_R113/tests/world.luau + docs/proposals/R149/tests/zfight_world.luau) loads it.
#  2. base_area_scene.luau runs the REAL start-up builders of this checkout (MapService.new: MarketLayout, GardenBaseLayout, TrackExpansion83 ...;
#     the treadmills, garden fences, mystery pedestals, Verity's dais, the leaderboards; the keyboard client) and, for the redesign, the
#     scratch builder HubDressing151.luau (this folder). Four scenes: before (today), p1 (Phase 1: server-built walls, murals, gate, paths,
#     base arches), after (Phase 1 + 2: the client "life" layer, with the reserved slots drawn as ghosts), low (owner option: low visible wall +
#     biome skyline).
#  3. counts.txt: parts per group and phase. check_base_area_zfight.py: the R149 z-fighting detector on the redesign scenes (fails on any
#     counted finding with an R151 part).
#  4. render_base_area.mjs draws the views of base_area_views.json with three.js (base_area.html, headless Chromium via playwright,
#     swiftshader); make_base_area_sheets.py writes docs/proposals/R151/base_area_*.png.
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers, no `playwright install`) and
# three@0.169.0 (npm install in the scratch dir, done here). Approximate: no Roblox lighting / PBR materials / bloom / Fredoka font.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
[ -f "$PLACE" ] || { echo "needs the owner's place file (Workspace.ChestChaseMap): $PLACE";exit 1; }
mkdir -p "$S/w" "$S/out" "$S/scenes"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/w/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/base_area_scene.luau" "$S/w/"
python3 "$HERE/bundle_r151.py" "$REPO/src" "$S/w" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
scene() { # $1 = name, $2 = globals
 (printf '%s\n' "$OWN;$2";cat "$S/w/base_area_scene.luau") > "$S/w/run_$1.luau"
 (cd "$S/w" && timeout 900 /opt/luau/luau "run_$1.luau" > "$S/scenes/$1.log" 2>&1) || { tail -20 "$S/scenes/$1.log";exit 1; }
 grep '^SCENE ' "$S/scenes/$1.log" | sed 's/^SCENE //' > "$S/scenes/$1.json"
 if grep -q 'FAILED' "$S/scenes/$1.log";then grep FAILED "$S/scenes/$1.log";exit 1;fi
 echo "scene $1: $(grep '^ZSCENE' "$S/scenes/$1.log" | sed 's/^ZSCENE //')"
}
scene before 'REDESIGN=false'
scene p1 'REDESIGN=true;PHASE=1;WALL="tall"'
scene after 'REDESIGN=true;PHASE=2;WALL="tall";SLOTS=true'
scene low 'REDESIGN=true;PHASE=2;WALL="low"'
python3 "$HERE/count_base_area_parts.py" "$S/scenes/p1.json" "$S/scenes/after.json" "$S/scenes/low.json" > "$S/counts.txt";cat "$S/counts.txt"
echo "== z-fighting (R149 detector)"
python3 "$HERE/check_base_area_zfight.py" "$S/scenes/before.json" "$S/scenes/after.json" "$S/scenes/low.json" > "$S/zfight.txt" || { cat "$S/zfight.txt";exit 1; }
cat "$S/zfight.txt"
echo "== renders"
cp "$HERE/base_area.html" "$HERE/render_base_area.mjs" "$S/"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_base_area.mjs" "$S" "$HERE/base_area_views.json" "$S/out" \
 before="$S/scenes/before.json" p1="$S/scenes/p1.json@spawn,gate,aerial,plan" after="$S/scenes/after.json" low="$S/scenes/low.json@walls,street,aerial"
python3 "$HERE/make_base_area_sheets.py" "$S/out" "$HERE/base_area_views.json" "$REPO/docs/proposals/R151" "$S/counts.txt"
