#!/bin/sh
# Usage: sh run_holo_preview158d.sh <scratch dir> [out dir, default docs/proposals/R158b]
# Renders holo_rework158d.png: the Holo Melon's three forms and the Holo Apple Tree before (the BASE commit, HOLO_BASE default 1258821 = R158d starter gift)
# | after (this checkout), both built by dump_holo158d.luau with the REAL modules on the Roblox mock; three.js (headless Chromium via playwright) draws them
# (approximate: Neon unlit, no Roblox bloom or lighting). Needs /opt/luau, python3 + Pillow, node + playwright (global) and three@0.169.0 in <scratch>/node_modules
# (`npm install --prefix <scratch> three@0.169.0`).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${HOLO_BASE:-1258821};S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R158b}
mkdir -p "$S/srcbase" "$S/before/out" "$S/after/out"
[ -d "$S/srcbase/src" ] || git -C "$REPO" archive "$BASE" src | tar -x -C "$S/srcbase"
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$S/srcbase/src/ReplicatedStorage" "$S/before/rs_bundle.luau" >/dev/null
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$S/after/rs_bundle.luau" >/dev/null
[ -d "$S/node_modules/three" ] || npm install --prefix "$S" three@0.169.0 >/dev/null
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
for d in before after;do
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/fruit_mesh_mock.luau" \
  "$HERE/dump_holo158d.luau" "$HERE/holo158d.html" "$HERE/render_holo158d.mjs" "$S/$d/"
 ln -sfn "$S/node_modules" "$S/$d/node_modules"
 (cd "$S/$d" && /opt/luau/luau dump_holo158d.luau -a $d > scenes_all.txt)
 grep '^MESHDATA ' "$S/$d/scenes_all.txt" | sed 's/^MESHDATA //' > "$S/$d/generated_meshes.json" || true
 [ -s "$S/$d/generated_meshes.json" ] || rm -f "$S/$d/generated_meshes.json"
 grep -v '^MESHDATA ' "$S/$d/scenes_all.txt" > "$S/$d/scenes.txt"
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/$d/render_holo158d.mjs" "$S/$d" "$S/$d/out"
 cp "$S/$d/scenes.txt" "$S/$d/out/"
done
python3 "$HERE/make_holo_sheet158d.py" "$S/after/out" "$S/before/out" "$OUT" 2>&1 | tail -3
