#!/bin/sh
# Usage: sh run_base_area_built_preview.sh <scratch dir> [place.rbxl] [before commit, default e5211cc = the branch before R151's hub code]
# R151 as built: renders the REAL src builders (ChestChaseServer.HubDecor151 via MapService.new; HubLife151.client + HubLifeArt151 on the
# client) on the owner's place, from the proposal's cameras, into docs/proposals/R151/base_area_built_*.png:
#   scenes  before  - the before commit's src (no R151 hub code)
#           built   - this checkout, client at the desktop tier (every detail level shown, for the cameras)
#           tier1   - this checkout, client at tier 1 (phones on low / FastMode: the core level only)
#           night   - this checkout with the lamp lights on (The Darkened's blackout)
#           trees   - this checkout, desktop tier, with two STAND-IN studded tree models (standin_tree.luau; not the owner's) in
#                     ReplicatedStorage.HubTreeTemplates151 -> base_area_built_studded.png (base_area_studded_views.json)
#   views   base_area_views.json (the proposal's) + base_area_variety_views.json (close-ups of the tree / prop variety)
# The part budget lines come from the test suite's log when it is given as BUDGET=<docs/proposals/R151/tests run dir>/test.log.
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0 (npm install
# in the scratch dir, done here). Approximate: no Roblox lighting / PBR materials / bloom / Fredoka font; the approved pack mesh is missing
# offline, so the fountain shows its part-built fallback pack.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${3:-e5211cc}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/b" "$S/out" "$S/scenes" "$S/before"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/base_area_scene.luau" "$HERE/standin_tree.luau" "$S/t/"
cp "$S"/t/*.luau "$S/b/"
python3 "$HERE/bundle_r151.py" "$REPO/src" "$S/t" >/dev/null
rm -rf "$S/before/src";git -C "$REPO" archive "$BEFORE" src | tar -x -C "$S/before"
python3 "$HERE/bundle_r151.py" "$S/before/src" "$S/b" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
scene() { # $1 = name, $2 = dir, $3 = globals
 (printf '%s\n' "$OWN;$3";cat "$2/base_area_scene.luau") > "$2/run_$1.luau"
 (cd "$2" && timeout 900 /opt/luau/luau "run_$1.luau" > "$S/scenes/$1.log" 2>&1) || { tail -20 "$S/scenes/$1.log";exit 1; }
 if grep -q 'FAILED' "$S/scenes/$1.log";then grep FAILED "$S/scenes/$1.log";exit 1;fi
 grep '^SCENE ' "$S/scenes/$1.log" | sed 's/^SCENE //' > "$S/scenes/$1.json"
 echo "scene $1: $(grep '^ZSCENE' "$S/scenes/$1.log" | sed 's/^ZSCENE //')"
}
scene before "$S/b" 'REDESIGN=false'
scene built "$S/t" 'BUILT=true;CLIENT_TIER=3'
scene tier1 "$S/t" 'BUILT=true;CLIENT_TIER=1'
scene night "$S/t" 'BUILT=true;CLIENT_TIER=3;NIGHT=true'
scene trees "$S/t" 'BUILT=true;CLIENT_TIER=3;STANDIN=true'
cp "$HERE/base_area.html" "$HERE/render_base_area.mjs" "$S/"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
VIEWS_ALL=spawn,street,entrance,walls,backwall,gate,aerial,avenue,darkened,plan
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$S/render_base_area.mjs" "$S" "$HERE/base_area_views.json" "$S/out" before="$S/scenes/before.json@$VIEWS_ALL" built="$S/scenes/built.json@$VIEWS_ALL" \
 tier1="$S/scenes/tier1.json@spawn,street,entrance,walls,backwall,gate,aerial,avenue" night="$S/scenes/night.json@darkened" >/dev/null
node "$S/render_base_area.mjs" "$S" "$HERE/base_area_variety_views.json" "$S/out" built="$S/scenes/built.json" >/dev/null
node "$S/render_base_area.mjs" "$S" "$HERE/base_area_studded_views.json" "$S/out" trees="$S/scenes/trees.json@s_oaks,s_blossoms,s_fruit,s_close,s_avenue" \
 built="$S/scenes/built.json@s_oaks,s_blossoms,s_fruit,s_close,s_avenue,p_desert,p_lava,p_snow" tier1="$S/scenes/tier1.json@s_avenue" >/dev/null
if [ -n "$BUDGET" ] && [ -f "$BUDGET" ];then grep '^BUDGET' "$BUDGET" > "$S/budget.txt";fi
STUDDED_VIEWS="$HERE/base_area_studded_views.json" python3 "$HERE/make_base_area_built_sheets.py" "$S/out" "$HERE/base_area_views.json" "$HERE/base_area_variety_views.json" "$REPO/docs/proposals/R151" ${BUDGET:+"$S/budget.txt"}
