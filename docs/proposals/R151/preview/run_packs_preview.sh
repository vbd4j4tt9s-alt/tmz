#!/bin/sh
# Usage: sh run_packs_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [out dir, default docs/proposals/R151]
# Renders packs_audit.png: every one of the 42 ordinary pack designs (front and side), the Void / Mech / Verity packs and the defects fixed in R151, before -> after, circled.
#  1. tests/dump_packs.luau builds every design with the REAL SeedPackVisuals / SeedPackRenderer / EclipsePackArt / SpecialPackArt89 / VerityPackArt on the
#     Roblox mock with the REAL templates of the owner's place (tests/pack_templates.luau), once on the base commit's src (PACKS_BASE, default c1e8829 = the
#     branch before the R151 pack fixes) and once on this checkout's, and prints the scenes (parts in the pack's frame).
#  2. make_packs_sheet.py jobs writes the views; render_packs.mjs draws them with three.js (packs.html, headless Chromium via playwright, swiftshader).
#  3. make_packs_sheet.py sheet composes the PNG (Pillow).
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js 0.169 (npm install three@0.169.0 in the
# scratch dir, or pass a node_modules). Approximate: plain materials, no Roblox textures / Future lighting; the pouch meshes are stand-in rounded boxes (their
# vertices are uploaded assets, not available offline). Do not use a scratch dir that holds other .py files (a stray bisect.py shadows the stdlib).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${3:-$REPO/docs/proposals/R151}
BASE=${PACKS_BASE:-c1e8829}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;TESTS=$HERE/../tests
mkdir -p "$S/after" "$S/before" "$S/out" "$S/base_src"
for d in after before;do
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$TESTS/pack_world.luau" "$TESTS/pack_templates.luau" "$TESTS/dump_packs.luau" "$S/$d/"
done
git -C "$REPO" archive "$BASE" src | tar -x -C "$S/base_src"
python3 "$TESTS/mkbundle_packs.py" "$S/after" "$REPO/src" >/dev/null
python3 "$TESTS/mkbundle_packs.py" "$S/before" "$S/base_src/src" >/dev/null
for d in before after;do (cd "$S/$d" && /opt/luau/luau dump_packs.luau > scenes.txt);done
cp "$HERE/packs.html" "$HERE/render_packs.mjs" "$S/"
if [ -n "$2" ];then [ -e "$S/node_modules" ] || ln -s "$2" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null);fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
python3 "$HERE/make_packs_sheet.py" jobs "$S/after/scenes.txt" "$S/jobs_before.json" "$S/jobs_after.json"
for d in before after;do
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_packs.mjs" "$S" "$S/$d/scenes.txt" "$S/out" "$d" "$S/jobs_$d.json"
done
python3 "$HERE/make_packs_sheet.py" sheet "$S/out" "$S/after/scenes.txt" "$OUT/packs_audit.png"
