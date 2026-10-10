#!/bin/sh
# Usage: sh run_preview.sh <scratch dir> [place.rbxl] [out dir, default docs/proposals/R149]
# Renders fruit_models_today.png (every active fruit as the hotbar / sell viewport builds it) and fruit_models_proposed.png
# (cocoa / pepper references, 8 part-based prototypes next to today's fruit, 2 mesh-based Phase-2 demos, plants before / after).
#  1. extract_meshes.py reads the baked meshes (ServerStorage, NOT in the repo) from the place file, if one is given;
#     without it every baked mesh (Cocoa pod, Fire / Prism Pepper, Worldroot heart) is drawn as a stand-in ellipsoid.
#  2. gen_meshes.py generates the two Phase-2 meshes in ApprovedPlantMeshData format.
#  3. dump_fruit_models.luau builds everything with the REAL modules of this checkout on the Roblox mock (FruitModels149.luau is
#     bundled in as a scratch module) and prints scenes + AUDIT / INFO / PLANT rows (scenes.txt).
#  4. render_fruit_models.mjs draws the scenes with three.js (headless Chromium via playwright, swiftshader); make_sheets.py composes.
# Needs /opt/luau, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here). Approximate: plain
# materials, no Roblox textures / decals / Future lighting.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};PLACE=${2:-};OUT=${3:-$REPO/docs/proposals/R149}
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_fruit_models.luau" "$HERE/fruit_models.html" "$HERE/render_fruit_models.mjs" "$S/"
python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$S/rs_bundle.luau" FruitModels149="$HERE/FruitModels149.luau" >/dev/null
rm -f "$S/meshes.json"
if [ -n "$PLACE" ]; then python3 "$HERE/extract_meshes.py" "$PLACE" "$S/meshes.json"; else echo 'no place file: baked meshes are stand-in ellipsoids'; fi
python3 "$HERE/gen_meshes.py" "$S"
(cd "$S" && /opt/luau/luau dump_fruit_models.luau > scenes.txt)
grep -E '^(INFO|PLANT)' "$S/scenes.txt" || true
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_fruit_models.mjs" "$S" "$S/out"
python3 "$HERE/make_sheets.py" "$S/scenes.txt" "$S/out" "$OUT"
