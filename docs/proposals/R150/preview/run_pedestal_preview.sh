#!/bin/sh
# Usage: sh run_pedestal_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [base commit, default 3ae5bb4 = R149] [place.rbxl]
# Renders docs/proposals/R150/pedestal.png: the base's mystery pack pedestal BEFORE (the base commit = R149: no fx, its own sign) and AFTER (this checkout) -
#   * the three states (LOCKED, UNLOCKED, TAKEN) as a player sees them,  * close-ups (the padlock on the column, the pack / halo / sign),
#   * the unlock moment and the take flight as frames,  * the pedestal in each biome's colours,  * the base-wide view from the entrance (the owner's real base from
#   the place file, with its treadmill across the aisle; skipped without the place file).
#  1. dump_pedestal.luau / dump_base.luau run the REAL MysteryPackService, MysteryPedestalArt, MysteryPackClient and MysteryPedestalFx on the Roblox mock (the R149
#     zfight_world mock + tests/pedestal_harness.luau) and print the parts, emitters, lights and the sign's layout of each view ("SCENE name json"); with the BEFORE
#     src (git archive of the base commit) the same scripts show R149's pedestal.
#  2. render_pedestal.mjs draws the scenes with three.js (pedestal.html, headless Chromium via playwright, swiftshader): parts as blocks / balls / cylinders, neon as
#     glowing unlit colour, particles as sparkle dots, the sign as a camera-facing sprite drawn like Roblox lays it out (pill, outline, text, bar).
#  3. make_pedestal_sheet.py composes the sheet (Pillow).
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js (pass a node_modules dir, or `npm install
# three@0.169.0` is run in the scratch dir). Approximate: plain materials, no Roblox textures or lighting; the pack art (approved meshes) is not available offline, so the
# pack is a stand-in pouch in its biome's paper colour (black silhouette while Locked); sparkles are dots; the font is not Fredoka.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2;BASE=${3:-3ae5bb4};PLACE=${4:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
T=$REPO/docs/proposals/R150/tests
mkdir -p "$S/out" "$S/before" "$S/after"
rm -rf "$S/base_src";mkdir -p "$S/base_src";git -C "$REPO" archive "$BASE" src | tar -x -C "$S/base_src"
HAVE_PLACE=0;if [ -f "$PLACE" ];then HAVE_PLACE=1;python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/place_tree.luau" Workspace/ChestChaseMap >/dev/null;fi
for which in before after;do
 if [ "$which" = before ];then SRC=$S/base_src/src;else SRC=$REPO/src;fi
 D=$S/$which
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$T/pedestal_harness.luau" "$HERE/preview_dump.luau" "$HERE/dump_pedestal.luau" "$HERE/dump_base.luau" "$D/"
 python3 "$T/bundle_pedestal.py" "$SRC" "$D" >/dev/null
 (cd "$D" && timeout 600 /opt/luau/luau dump_pedestal.luau > scenes_pedestal.txt 2> err_pedestal.txt) || { tail -20 "$D/err_pedestal.txt";exit 1; }
 if [ "$HAVE_PLACE" = 1 ];then
  cp "$S/place_tree.luau" "$D/"
  (cd "$D" && timeout 900 /opt/luau/luau dump_base.luau > scenes_base.txt 2> err_base.txt) || { tail -20 "$D/err_base.txt";exit 1; }
 fi
 echo "$which: $(grep -c '^SCENE' "$D/scenes_pedestal.txt") pedestal scenes, $( [ -f "$D/scenes_base.txt" ] && grep -c '^SCENE' "$D/scenes_base.txt" || echo 0) base scenes"
done
cp "$HERE/pedestal.html" "$HERE/render_pedestal.mjs" "$S/"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null);[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright";fi
for which in before after;do
 PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_pedestal.mjs" "$S" "$S/$which/scenes_pedestal.txt" "$S/out" "$which" >/dev/null
 if [ -f "$S/$which/scenes_base.txt" ];then PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_pedestal.mjs" "$S" "$S/$which/scenes_base.txt" "$S/out" "$which" >/dev/null;fi
done
python3 "$HERE/make_pedestal_sheet.py" "$S/out" "$REPO/docs/proposals/R150/pedestal.png" "$BASE"
