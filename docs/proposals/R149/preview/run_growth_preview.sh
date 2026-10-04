#!/bin/sh
# Usage: sh run_growth_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [out dir, default docs/proposals/R149]
# Renders growth_style.png: Blueberry (bush), Apple (tree) and Watermelon (ground vine) at 8 moments of their life, today vs proposed.
#  1. dump_growth.luau builds every frame with the REAL PlantCatalog / PlantVisuals / PlantGrowth / PlantingEffects of this checkout on the
#     Roblox mock. "today" = Visuals.BeginGrowth + Visuals.UpdateGrowth (the real PlantGrowth.Apply); "proposed" = the same captured state
#     drawn by GrowthStyle149.luau (scratch proposal, bundled in here, NOT in src/), plus the ripe bounce / glints and the harvest pop / puff.
#  2. render_growth.mjs draws the scenes with three.js (fruit_models.html, headless Chromium via playwright, swiftshader).
#  3. make_growth_sheet.py puts them on one labelled sheet.
# Needs /opt/luau, python3 + Pillow, node + playwright (global) and three.js (npm install three@0.169.0 in the scratch dir, or pass a
# node_modules). Approximate: plain materials, no Roblox textures / Future lighting; particles (glints, puffs) are drawn as small parts.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${3:-$REPO/docs/proposals/R149}
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_growth.luau" "$HERE/fruit_models.html" "$HERE/render_growth.mjs" "$S/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/rs_bundle.luau" GrowthStyle149="$HERE/GrowthStyle149.luau" >/dev/null
(cd "$S" && /opt/luau/luau dump_growth.luau > scenes.txt)
grep -E '^INFO' "$S/scenes.txt" || true
if [ -n "$2" ]; then [ -e "$S/node_modules" ] || ln -s "$2" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null); [ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"; fi
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_growth.mjs" "$S" "$S/out"
python3 "$HERE/make_growth_sheet.py" "$S/scenes.txt" "$S/out" "$OUT/growth_style.png"
