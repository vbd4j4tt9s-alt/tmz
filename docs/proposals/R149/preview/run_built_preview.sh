#!/bin/sh
# Usage: sh run_built_preview.sh <scratch dir> [out dir, default docs/proposals/R149]
# Renders fruit_models_built.png: the redesigned fruit before (the BASE commit, FRUIT_BASE default 38b1afa) | after (this checkout), both built by
# dump_fruit_built.luau with the REAL modules on the Roblox mock; three.js (headless Chromium via playwright) draws them like run_preview.sh does.
# Needs /opt/luau, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${FRUIT_BASE:-38b1afa};S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R149}
mkdir -p "$S/srcbase" "$S/before/out" "$S/after/out"
git -C "$REPO" archive "$BASE" src | tar -x -C "$S/srcbase"
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$S/srcbase/src/ReplicatedStorage" "$S/before/rs_bundle.luau" >/dev/null
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$S/after/rs_bundle.luau" >/dev/null
[ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 >/dev/null
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
for d in before after;do
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/dump_fruit_built.luau" "$HERE/fruit_models.html" "$HERE/render_fruit_models.mjs" "$S/$d/"
 ln -sfn "$S/node_modules" "$S/$d/node_modules"
 (cd "$S/$d" && /opt/luau/luau dump_fruit_built.luau > scenes.txt)
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/$d/render_fruit_models.mjs" "$S/$d" "$S/$d/out"
 cp "$S/$d/scenes.txt" "$S/$d/out/"
done
python3 "$HERE/make_built_sheet.py" "$S/after/out" "$S/before/out" "$OUT" 2>&1 | tail -3
