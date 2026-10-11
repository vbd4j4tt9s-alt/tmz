#!/bin/sh
# Usage: sh run_bunting_preview158.sh <scratch dir> [node_modules dir with three@0.169 (and playwright)] [place.rbxl] [before ref, default 8cae4f1 = the commit before the R158 bunting fix] [out png]
# R158 bunting (owner: "fix the disconnect flags": the hub's white string ran straight from the lamp to the market's roof, but the pennants hung on a curve 2 studs lower,
# floating under it). Renders docs/proposals/R158/bunting158.png: one string BEFORE (the before ref's src) and AFTER (this checkout), four close-ups.
#  1. docs/proposals/R149/tools/rbxl_geom.py reads Workspace.ChestChaseMap from the owner's place file.
#  2. the R151 cloudy_scene.luau (the real start-up builders + the real HubLife151.client, a Clear sky) dumps the scene once per side; the before side is a git archive of the ref.
#  3. render_cloudy.mjs + cloudy.html (three.js, headless Chromium, software WebGL) draw bunting_views158.json; make_bunting_sheet158.py puts them on one sheet with the
#     bunting's part counts and its numbers read from the dumps.
# APPROXIMATE: no Roblox lighting model, materials, bloom or colour grade. Needs /opt/luau, python3 + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../../.." && pwd);R151=$REPO/docs/proposals/R151/preview
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${4:-8cae4f1};OUT=${5:-$REPO/docs/proposals/R158/bunting158.png}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/b" "$S/scenes" "$S/out" "$S/before"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$R151/cloudy_scene.luau" "$S/t/"
cp "$S"/t/*.luau "$S/b/"
python3 "$REPO/docs/proposals/R151/tests/bundle_cloudy.py" "$REPO/src" "$S/t" >/dev/null
rm -rf "$S/before/src";git -C "$REPO" archive "$BEFORE" src | tar -x -C "$S/before"
python3 "$REPO/docs/proposals/R151/tests/bundle_cloudy.py" "$S/before/src" "$S/b" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
scene() { # $1 = before | after, $2 = dir
 (printf '%s\n' "$OWN;BUILT=true;CLIENT_TIER=3;SKY='clear'";cat "$2/cloudy_scene.luau") > "$2/run_$1.luau"
 (cd "$2" && timeout 900 /opt/luau/luau "run_$1.luau" > "$S/scenes/$1.log" 2>&1) || { tail -20 "$S/scenes/$1.log";exit 1; }
 if grep -q 'FAILED' "$S/scenes/$1.log";then grep FAILED "$S/scenes/$1.log";exit 1;fi
 grep '^SCENE ' "$S/scenes/$1.log" | sed 's/^SCENE //' > "$S/scenes/$1.json"
 echo "scene $1: $(grep '^ZSCENE' "$S/scenes/$1.log" | sed 's/^ZSCENE //')"
}
scene before "$S/b";scene after "$S/t"
cp "$R151/cloudy.html" "$R151/render_cloudy.mjs" "$S/"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_cloudy.mjs" "$S" "$HERE/bunting_views158.json" "$S/out" \
 before="$S/scenes/before.json@string,close,along,avenue" after="$S/scenes/after.json@string,close,along,avenue" > /dev/null
python3 "$HERE/make_bunting_sheet158.py" "$S/out" "$HERE/bunting_views158.json" "$OUT" "$S/scenes" "$BEFORE"
