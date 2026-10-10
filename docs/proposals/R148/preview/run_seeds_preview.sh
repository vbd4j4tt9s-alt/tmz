#!/bin/sh
# Usage: sh run_seeds_preview.sh <scratch dir> [out dir, default docs/proposals/R148]. Renders seeds_new.png: for the Aloe (Desert, Rare) and the Sand Fruit
# round cactus (Desert, Legendary) the seed, the plant growing (50%), fully grown and one harvested fruit; for Fire Pepper (Lava, now Mythic) the new seed and
# the plant before / after the x2 size bump (it already reuses the existing red pepper model at x2). dump_seeds_new.luau builds the seeds and plants with the REAL modules of this checkout on the Roblox mock
# and prints the parts; render_seeds_new.mjs draws them with three.js (headless Chromium via playwright, swiftshader); make_seeds_sheet.py (Pillow)
# composes the sheet. Needs /opt/luau, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here).
# Approximate: boxes / wedges / balls / cylinders with plain materials, no Roblox textures or Future lighting; Fire Pepper's baked meshes (ServerStorage,
# not in the repo) are stand-in ellipsoids of their bounding boxes, so for that plant the SIZE is what the preview shows. The "before" art is the
# commit before the change (ROSTER_BASE, default cba4032).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
BASE=${ROSTER_BASE:-cba4032}
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_seeds_new.luau" "$HERE/seeds_new.html" "$HERE/render_seeds_new.mjs" "$S/"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/ApprovedPlantArt.lua" > "$S/ApprovedPlantArtBase.lua"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/rs_bundle.luau" ApprovedPlantArtBase="$S/ApprovedPlantArtBase.lua" >/dev/null
/opt/luau/luau "$S/dump_seeds_new.luau" > "$S/scenes.txt"
grep '^INFO' "$S/scenes.txt" || true
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_seeds_new.mjs" "$S" "$S/out" >/dev/null
OUT=${2:-$REPO/docs/proposals/R148};mkdir -p "$OUT"
python3 "$HERE/make_seeds_sheet.py" "$S/out" "$OUT"
