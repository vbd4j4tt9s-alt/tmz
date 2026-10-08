#!/bin/sh
# Usage: sh run_hub_tidy_preview.sh <scratch dir> [node_modules dir with three@0.169 (and playwright)] [place.rbxl] [before ref, default 006daa1 = the R153 release as the owner installed it]
# R154 hub tidy (owner: "reduce the amount of props in the base area like reduce the amount of lamps and to remove the soil beds and benches beside it just leave those
# parts empty. basically just tidy up the base area"; "make each lamp brighter in its warmth during cloudy season too"). Renders docs/proposals/R154/hub_tidy.png: the hub
# BEFORE (the before ref's src) and AFTER (this checkout) from above and from the plaza under a Clear sky, and the plaza under a Cloudy sky.
#  1. docs/proposals/R149/tools/rbxl_geom.py reads Workspace.ChestChaseMap from the owner's place file.
#  2. the R151 cloudy_scene.luau (the real start-up builders, the real HubLife151.client with the real sky state) runs once per side and sky (SKY = 'clear' | 'cloudy') and dumps
#     the scene: every part, light and the real palette numbers. The before side is a git archive of the ref, bundled by the same bundle_cloudy.py.
#  3. render_cloudy.mjs + cloudy.html (three.js, headless Chromium, software WebGL) draw hub_tidy_views.json; make_hub_tidy_sheet.py puts them on one sheet with the part counts
#     and the lamp numbers read from the dumps.
# APPROXIMATE: no Roblox lighting model, materials, bloom or colour grade. Needs /opt/luau, python3 + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);R151=$REPO/docs/proposals/R151/preview
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/5ea4542b-sapkeee.rbxl};BEFORE=${4:-006daa1}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/b" "$S/scenes" "$S/out" "$S/before"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$R151/cloudy_scene.luau" "$S/t/"
cp "$S"/t/*.luau "$S/b/"
python3 "$REPO/docs/proposals/R151/tests/bundle_cloudy.py" "$REPO/src" "$S/t" >/dev/null
rm -rf "$S/before/src";git -C "$REPO" archive "$BEFORE" src | tar -x -C "$S/before"
python3 "$REPO/docs/proposals/R151/tests/bundle_cloudy.py" "$S/before/src" "$S/b" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
scene() { # $1 = before | after, $2 = clear | cloudy, $3 = dir
 (printf '%s\n' "$OWN;BUILT=true;CLIENT_TIER=3;SKY='$2'";cat "$3/cloudy_scene.luau") > "$3/run_$1_$2.luau"
 (cd "$3" && timeout 900 /opt/luau/luau "run_$1_$2.luau" > "$S/scenes/$1_$2.log" 2>&1) || { tail -20 "$S/scenes/$1_$2.log";exit 1; }
 if grep -q 'FAILED' "$S/scenes/$1_$2.log";then grep FAILED "$S/scenes/$1_$2.log";exit 1;fi
 grep '^SCENE ' "$S/scenes/$1_$2.log" | sed 's/^SCENE //' > "$S/scenes/$1_$2.json"
 echo "scene $1 $2: $(grep '^ZSCENE' "$S/scenes/$1_$2.log" | sed 's/^ZSCENE //')"
}
scene before clear "$S/b";scene before cloudy "$S/b";scene after clear "$S/t";scene after cloudy "$S/t"
cp "$R151/cloudy.html" "$R151/render_cloudy.mjs" "$S/"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_cloudy.mjs" "$S" "$HERE/hub_tidy_views.json" "$S/out" \
 before_clear="$S/scenes/before_clear.json@aerial,plaza,corner" after_clear="$S/scenes/after_clear.json@aerial,plaza,corner" \
 before_cloudy="$S/scenes/before_cloudy.json@plaza,street" after_cloudy="$S/scenes/after_cloudy.json@plaza,street" > /dev/null
python3 "$HERE/make_hub_tidy_sheet.py" "$S/out" "$HERE/hub_tidy_views.json" "$REPO/docs/proposals/R154/hub_tidy.png" "$S/scenes" "$BEFORE"
