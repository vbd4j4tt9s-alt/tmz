#!/bin/sh
# Usage: sh run_mesh_preview.sh <scratch dir> [out dir, default docs/proposals/R149]
# Renders fruit_meshes.png: the Watermelon, Snow Melon and Ember Pumpkin before (the R149 part-built fruit: what FruitMeshes149 falls back to)
# | after (the baked mesh bodies), both built by dump_fruit_meshes.luau with the REAL modules of this checkout on the Roblox mock. In the
# "after" run the server bake runs on the mock AssetService (tests/fruit_mesh_mock.luau) and the renderer draws the meshes from the vertex
# data FruitMeshes149 generated (MESHDATA). three.js in headless Chromium (playwright), like run_built_preview.sh.
# Needs /opt/luau, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R149}
mkdir -p "$S"
[ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 >/dev/null
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
for d in parts mesh;do
 mkdir -p "$S/$d/out"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/fruit_mesh_mock.luau" \
  "$HERE/dump_fruit_meshes.luau" "$HERE/fruit_models.html" "$HERE/render_fruit_models.mjs" "$S/$d/"
 python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$S/$d/rs_bundle.luau" >/dev/null
 ln -sfn "$S/node_modules" "$S/$d/node_modules"
 (cd "$S/$d" && /opt/luau/luau dump_fruit_meshes.luau -a $d > scenes.txt)
 grep '^MESHDATA ' "$S/$d/scenes.txt" | sed 's/^MESHDATA //' > "$S/$d/generated_meshes.json" || true
 [ -s "$S/$d/generated_meshes.json" ] || rm -f "$S/$d/generated_meshes.json"
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/$d/render_fruit_models.mjs" "$S/$d" "$S/$d/out"
 grep -v '^MESHDATA ' "$S/$d/scenes.txt" > "$S/$d/out/scenes.txt"
done
python3 "$HERE/make_mesh_sheet.py" "$S/mesh/out" "$S/parts/out" "$OUT" 2>&1 | tail -3
