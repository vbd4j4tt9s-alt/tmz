#!/bin/sh
# Usage: sh run_giveaway_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [place.rbxl] [out.png]
# Renders docs/proposals/R152/void_giveaway.png: the free Void Pack pedestal in the middle of the owner's real hub (the plaza where the fountain stood):
#   * a wide aerial view of the hub's middle, a player's view coming from the market, the close-up with "487 / 500 LEFT", the stone (lettering, pylons), the same at dusk (the violet
#     glow), and a plan with the plaza, plus the pedestal at 0 left ("0 / 500 LEFT", ALL CLAIMED).
#  1. make_giveaway_scene.py patches R149's whole-map scene (tests/zfight_scene.luau): the place file's map is loaded into the Roblox mock, the real start-up builders run on it (MapService.new:
#     the market, the festival streets and plazas, Verity's dais ...), then the REAL VoidGiveaway152 builds the pedestal (an in-memory counter, like Studio without API access) and the REAL
#     VoidGiveawayClient152 runs as a player standing in the plaza (the number, the Void Pack built by SeedPackVisuals / EclipsePackArt, VoidPackFx's glow and particles), twice (13 claimed /
#     all 500 claimed). The dump has every part of the map and the client's emitters, lights and the number's layout.
#  2. giveaway_scenes.py turns it into scenes + camera views. 3. render_giveaway.mjs draws them with three.js (giveaway.html, headless Chromium via playwright, swiftshader: parts as Roblox
#     shapes, neon as glowing unlit colour, particles as sparkle dots, the number drawn like the BillboardGui lays it out). 4. make_giveaway_sheet.py composes the sheet (Pillow).
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers; never run `playwright install`) and three.js (pass a node_modules dir, or `npm install
# three@0.169.0` is run in the scratch dir). Approximate: plain materials, no Roblox textures or lighting; the pack art (the approved meshes) is not available offline, so the pack's body is a
# stand-in pouch under the Void art's own parts; the hub's trees, benches and lamps are client scripts of other agents and are not drawn; the font is not Fredoka.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};OUT=${4:-$REPO/docs/proposals/R152/void_giveaway.png}
W=$S/scene
[ -f "$PLACE" ] || { echo "no place file: $PLACE";exit 1; }
mkdir -p "$W" "$S/out"
GEOM=$REPO/docs/proposals/R149/tools/rbxl_geom.py
python3 "$GEOM" --tree "$PLACE" "$W/place_tree.luau" Workspace/ChestChaseMap > /dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R150/preview/preview_dump.luau" "$W/"
python3 "$HERE/make_giveaway_scene.py" "$REPO/docs/proposals/R149/tests/zfight_scene.luau" "$W/giveaway_scene.luau" > /dev/null
python3 "$REPO/docs/proposals/R152/tests/bundle_giveaway.py" "$REPO/src" "$W" > /dev/null
cd "$W"
for state in open empty; do
  (printf 'SKIP_CLIENT=true;GIVE_STATE="%s"\n' $state; cat giveaway_scene.luau) > run_$state.luau
  timeout 600 /opt/luau/luau run_$state.luau > $state.log 2>&1 || { tail -20 $state.log;exit 1; }
  grep '^SCENE ' $state.log | sed 's/^SCENE //' > scene_$state.json
  grep '^GSCENE ' $state.log | sed 's/^GSCENE //' > gscene_$state.json
  grep '^GPLAQUE ' $state.log | sed 's/^GPLAQUE //' > gplaque_$state.jsonl
  grep -v '^SCENE \|^GSCENE ' $state.log > $state.steps
  if grep -q ' FAILED ' $state.steps;then grep ' FAILED ' $state.steps;exit 1;fi
  grep -E 'GINFO|ZSCENE' $state.steps
done
cd "$REPO"
python3 "$HERE/giveaway_scenes.py" "$W" "$S/giveaway_views.json"
cp "$HERE/giveaway.html" "$HERE/render_giveaway.mjs" "$S/"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null);fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_giveaway.mjs" "$S" "$S/giveaway_views.json" "$S/out" > /dev/null
python3 "$HERE/make_giveaway_sheet.py" "$S/out" "$OUT"
