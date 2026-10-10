#!/bin/sh
# Usage: sh run_dropped_preview158b.sh <scratch dir> [node_modules dir with three@0.169 (and playwright)] [out png]   -> docs/proposals/R158/dropped_pack158.png
# R158b preview (the owner reviews visual changes before they ship): a dropped pack BEFORE and AFTER the highlight, on all seven track floors, from the runner's camera, 15 studs and 165 studs away.
#  1. dump_dropped158b.luau runs the REAL SeedPackVisuals.Bag (the owner's pack templates, R151's pack_world) for the pack, the REAL KeyboardTrack for the floor's key colours and reads
#     DroppedPackLook158b for the look's numbers.
#  2. the pouch meshes are uploaded assets: they are drawn from the design's V120 native render data (git show 38569c5^, the data the approved meshes were made from), as R156's pyramid preview does.
#  3. R156's pyramid.html (three.js, headless Chromium via playwright, software WebGL) + a Beam and a pack-only mask pass (make_dropped158b.py html) draws the world; Pillow draws the Highlight
#     from the mask (an outline and a soft fill over everything, as an AlwaysOnTop Highlight), the marker and the server's own timer label, and lays out the sheet.
# APPROXIMATE: no Roblox lighting / materials / atmosphere / bloom, DejaVu Sans instead of Fredoka. Needs /opt/luau, python3 + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers), three@0.169.0.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);P=$REPO/docs/proposals;T=$REPO/tools/tests
S=${1:?scratch dir};NM=$2;OUT=${3:-$REPO/docs/proposals/R158/dropped_pack158.png}
mkdir -p "$S/pack" "$S/native" "$S/work/scenes" "$S/work/out"
cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$HERE/dump_dropped158b.luau" "$S/pack/"
python3 "$P/R151/tests/mkbundle_packs.py" "$S/pack" "$REPO/src" >/dev/null
(cd "$S/pack" && timeout 600 /opt/luau/luau dump_dropped158b.luau > dump.txt 2>&1) || { tail -20 "$S/pack/dump.txt";exit 1; }
for b in Forest Jungle Desert Snow Lava Crystal Storm;do git -C "$REPO" show 38569c5^:src/ReplicatedStorage/SeedPackArt${b}03.lua > "$S/native/SeedPackArt${b}03.lua";done
python3 "$HERE/make_dropped158b.py" html "$P/R156/preview/pyramid.html" "$S/work/dropped158b.html"
python3 "$HERE/make_dropped158b.py" scenes "$S/pack/dump.txt" "$S/native" "$S/work/scenes"
cp "$HERE/render_dropped158b.mjs" "$S/work/"
if [ -n "$NM" ];then [ -e "$S/work/node_modules" ] || ln -s "$NM" "$S/work/node_modules"
else [ -d "$S/work/node_modules/three" ] || (cd "$S/work" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/work/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/work/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/work/render_dropped158b.mjs" "$S/work" "$S/work/scenes/jobs.json" "$S/work/out" >/dev/null
python3 "$HERE/make_dropped158b.py" compose "$S/work" "$OUT"
