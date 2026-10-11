#!/bin/sh
# Usage: sh render.sh <scratch dir> [place.rbxl] [node_modules dir with three@0.169]
# R158 design preview (no game code): redraws track_walls.png, outer_track.png and base_walls.png in this folder and runs the z-fighting check.
#  1. the real map: R152's sweep world (build_sweep_env.sh: the owner's place as a Luau tree + this checkout's src on the Roblox mock) and one scene per biome
#     (run_variant.sh: every REAL start-up pass, the REAL keyboard client around a runner at the spot make158.py's SPOTS names) and one of the hub.
#  2. the proposed parts: dump158.luau prints walls158.lua's lists (walls, backdrops, base options A / B / C, the wall restyle, what option B hides).
#  3. checks: make158.py check (the placement rules: how far a piece stands into the track, nothing in the keys, the gatehouse or the Desert
#     walkway, the outer track outside the walls and off the hub) and make158.py zfight (R149's detector, the R152 sweep's rules) on the whole map
#     with every proposed part; writes zfight.txt here.
#  4. the pictures: make158.py scenes cuts each scene to its view and adds the parts; R156's renderer (render_pyramid.mjs + pyramid.html, Ice drawn
#     opaque) draws them in headless Chromium (software WebGL); make158.py sheet composes the three sheets.
# APPROXIMATE: three.js, not Roblox (no Future lighting, PBR materials, bloom); materials are simple detail textures.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);P=$REPO/docs/proposals
S=${1:?scratch dir};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};NM=$3
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/render/out"
if [ ! -f "$S/w/storm.json" ];then
 sh "$P/R152/tests/build_sweep_env.sh" "$S/w" "$PLACE" "$REPO/src" >/dev/null
 RV=$P/R152/tests/run_variant.sh
 sh $RV "$S/w" hub "RUNNER={0,-60};HUB_STATE='champions'" & sh $RV "$S/w" forest "RUNNER={-30,10};HUB_STATE='empty'" & sh $RV "$S/w" jungle "RUNNER={-30,330};HUB_STATE='empty'" & wait
 sh $RV "$S/w" desert "RUNNER={-30,960};HUB_STATE='empty'" & sh $RV "$S/w" snow "RUNNER={-30,1500};HUB_STATE='empty'" & sh $RV "$S/w" lava "RUNNER={-30,2400};HUB_STATE='empty'" & wait
 sh $RV "$S/w" crystal "RUNNER={-30,3600};HUB_STATE='empty'" & sh $RV "$S/w" storm "RUNNER={-30,5620};HUB_STATE='empty'" & wait
 rm -f "$S/w"/*.log "$S/w"/*.steps "$S/w"/run_*.luau
fi
/opt/luau/luau "$HERE/dump158.luau" > "$S/specs.txt"
grep '^BUDGET' "$S/specs.txt"
python3 "$HERE/make158.py" check "$S/specs.txt" || ZRC=1
python3 "$HERE/make158.py" zfight "$S/w" "$S/specs.txt" "$HERE/zfight.txt" || ZRC=1
python3 "$HERE/make158.py" html "$P/R156/preview/pyramid.html" "$S/render/pyramid.html" >/dev/null
cp "$P/R156/preview/render_pyramid.mjs" "$S/render/"
python3 "$HERE/make158.py" scenes "$S/w" "$S/specs.txt" "$S/render/scenes"
if [ -n "$NM" ];then [ -e "$S/render/node_modules" ] || ln -s "$NM" "$S/render/node_modules"
else [ -d "$S/render/node_modules/three" ] || (cd "$S/render" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/render/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/render/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render/render_pyramid.mjs" "$S/render" "$S/render/scenes/views.json" "$S/render/out" $(cat "$S/render/scenes/jobs.txt") >/dev/null
python3 "$HERE/make158.py" sheet "$S/render/out" "$S/specs.txt" "$HERE"
[ -z "$ZRC" ] || { echo "a check FAILED (placement rules above, or zfight.txt)";exit 1; }
