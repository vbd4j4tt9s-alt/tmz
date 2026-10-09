#!/bin/sh
# Usage: sh run_pyramid_preview156.sh <scratch dir> [node_modules dir with three@0.169 (and playwright)] [place.rbxl] [before ref, default e650788 = the branch before the pyramid]
# R156 preview: docs/proposals/R156/pyramid.png, the Desert's secret pyramid built by the REAL game code on the owner's place, drawn with R151's three.js map preview
# (pyramid.html = base_area.html + a cut-away plane, triangle meshes and a ProximityPrompt; headless Chromium via playwright, software WebGL):
#  1. BEFORE / AFTER: R152's sweep world (build_sweep_env.sh + run_variant.sh: the owner's place after every real start-up pass, the REAL keyboard client around a runner
#     beside the pyramid) on the before ref's src (the Sunscar Pyramid) and on this checkout's (the Classic Pyramid).
#  2. the floating pack: dump_pack156.luau runs the REAL SecretPyramidClient156 in the REAL pyramid (pack_world.luau: SeedPackVisuals.Bag with the owner's pack
#     templates) and prints its parts; its three pouch meshes (uploaded assets) are drawn from Desert_06's V120 native render data (git show 38569c5^, the data the
#     approved meshes were made from).
#  3. the numbers on the sheet: run_pyramid156.sh's map scene (pyramid_map156.luau, GEO line).
#  4. render_pyramid.mjs draws pyramid_views.json; make_pyramid_preview156.py composes the sheet.
# APPROXIMATE: no Roblox lighting, PBR materials or bloom; the prompt is drawn like Roblox's default style.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);P=$REPO/docs/proposals;T=$REPO/tools/tests
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${4:-e650788}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/before" "$S/pack" "$S/render/out"
rm -rf "$S/before/src";git -C "$REPO" archive "$BEFORE" src | tar -x -C "$S/before"
sh "$P/R152/tests/build_sweep_env.sh" "$S/zb" "$PLACE" "$S/before/src" >/dev/null
sh "$P/R152/tests/run_variant.sh" "$S/zb" pyramid "RUNNER={-20,1005};HUB_STATE='empty'"
sh "$P/R152/tests/build_sweep_env.sh" "$S/za" "$PLACE" "$REPO/src" >/dev/null
sh "$P/R152/tests/run_variant.sh" "$S/za" pyramid "RUNNER={-20,1005};HUB_STATE='empty'"
cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$HERE/dump_pack156.luau" "$S/pack/"
python3 "$P/R151/tests/mkbundle_packs.py" "$S/pack" "$REPO/src" --server SecretPyramidClient156="$REPO/src/StarterPlayer/StarterPlayerScripts/SecretPyramidClient156.client.lua" >/dev/null
(cd "$S/pack" && timeout 600 /opt/luau/luau dump_pack156.luau > pack.txt 2>&1) || { tail -20 "$S/pack/pack.txt";exit 1; }
git -C "$REPO" show 38569c5^:src/ReplicatedStorage/SeedPackArtDesert06.lua > "$S/SeedPackArtDesert06.lua"
sh "$P/R156/tests/run_pyramid156.sh" "$S/suite" "$PLACE" > "$S/suite.log" 2>&1 || { tail -20 "$S/suite.log";exit 1; }
python3 "$HERE/make_pyramid_preview156.py" scenes "$S/zb/pyramid.json" "$S/za/pyramid.json" "$S/pack/pack.txt" "$S/SeedPackArtDesert06.lua" "$S/render"
cp "$HERE/pyramid.html" "$HERE/render_pyramid.mjs" "$S/render/"
if [ -n "$NM" ];then [ -e "$S/render/node_modules" ] || ln -s "$NM" "$S/render/node_modules"
else [ -d "$S/render/node_modules/three" ] || (cd "$S/render" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/render/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/render/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render/render_pyramid.mjs" "$S/render" "$HERE/pyramid_views.json" "$S/render/out" \
 before="$S/render/before.json@overview" after="$S/render/after.json@overview,cut,pack,prompt,plan" claimed="$S/render/claimed.json@cut" >/dev/null
python3 "$HERE/make_pyramid_preview156.py" sheet "$S/render/out" "$REPO/docs/proposals/R156/pyramid.png" "$S/suite/map/map.log"
