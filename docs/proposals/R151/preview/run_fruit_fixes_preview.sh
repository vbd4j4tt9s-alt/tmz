#!/bin/sh
# Usage: sh run_fruit_fixes_preview.sh <scratch dir> [base revision, default a669234 = the branch head before this change] [out dir, default docs/proposals/R151]
# Renders fruit_fixes.png: the fruit the owner pointed at (Watermelon, Snow Melon, Ember Pumpkin, Apple, Elderbloom's apples, Blueberry, Iceberry, Moon Melon) before | after (no white shine
# parts), and the Verity fruit before | after (one face: front for the item, hotbar, Bag and Index, the side that looks at the path for the planted fruit). Both sides are built by
# dump_fruit_fixes.luau with the REAL modules of their own tree on the Roblox mock (the base revision is read with `git archive`). The server bake of the three melons / pumpkin
# runs on the mock AssetService (tests/fruit_mesh_mock.luau) and the renderer draws the meshes from the vertex data FruitMeshes149 generated (MESHDATA); every OTHER baked plant mesh
# (the cocoa pod, the peppers, ...) is a stand-in ellipsoid, and Verity's face (a Decal, a picture the renderer cannot load) is a small stand-in smiley of dark balls on the side(s) the
# Decal is on. three.js in headless Chromium (playwright, swiftshader): approximate plain materials, not Roblox screenshots.
# Needs /opt/luau, git, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};BASE=${2:-a669234};OUT=${3:-$REPO/docs/proposals/R151}
mkdir -p "$S"
[ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 >/dev/null
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
rm -rf "$S/srcbase";mkdir -p "$S/srcbase"
git -C "$REPO" archive "$BASE" src | tar -x -C "$S/srcbase"
for d in before after;do
 mkdir -p "$S/$d/out"
 if [ "$d" = before ];then SRC=$S/srcbase/src/ReplicatedStorage;else SRC=$REPO/src/ReplicatedStorage;fi
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/fruit_mesh_mock.luau" \
  "$HERE/dump_fruit_fixes.luau" "$REPO/docs/proposals/R149/preview/fruit_models.html" "$REPO/docs/proposals/R149/preview/render_fruit_models.mjs" "$S/$d/"
 python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$SRC" "$S/$d/rs_bundle.luau" >/dev/null
 ln -sfn "$S/node_modules" "$S/$d/node_modules"
 (cd "$S/$d" && /opt/luau/luau dump_fruit_fixes.luau -a mesh > scenes.txt) || { grep -v '^WARN\|^SCENE\|^MESHDATA' "$S/$d/scenes.txt" | cut -c1-240 | tail -20;exit 1; }
 grep '^MESHDATA ' "$S/$d/scenes.txt" | sed 's/^MESHDATA //' > "$S/$d/generated_meshes.json" || true
 [ -s "$S/$d/generated_meshes.json" ] || rm -f "$S/$d/generated_meshes.json"
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/$d/render_fruit_models.mjs" "$S/$d" "$S/$d/out"
 grep -v '^MESHDATA \|^SCENE ' "$S/$d/scenes.txt" > "$S/$d/out/info.txt" || true
done
python3 "$HERE/compose_fruit_fixes_png.py" "$S/before/out" "$S/after/out" "$OUT/fruit_fixes.png" "$BASE"
