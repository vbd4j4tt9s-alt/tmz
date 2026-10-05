#!/bin/sh
# Usage: sh run_treadmill_preview.sh <scratch dir> [node_modules dir with three@0.169] [place.rbxl] [base commit, default 19d05d4]
# R151 treadmill polish (owner: "works we can implement the treadmill polishes"): draws docs/proposals/R151/treadmills.png, treadmills_all.png
# and treadmills_belt.gif from the REAL src: BEFORE = the base commit (19d05d4: the approved proposal, no game code changed), AFTER = this checkout.
#  1. treadmill_scene.luau runs the REAL start-up builders on Base 1 of the owner's place in the R149 Roblox mock, the REAL treadmill at every level
#     (BiomeVisuals.BuildTreadmillV131, with the R151 dressing in AFTER), the REAL upgrade buttons (GardenUpgradeService, with the sign in AFTER) and
#     the REAL client effects controller (TreadmillFx, with the belt images of TreadmillBeltArt151 drawn by a stand-in EditableImage). It prints the
#     scenes, the budgets and the z-fighting scenes.
#  2. check_treadmill_dress.py: belt collider unchanged, nothing new collides or answers raycasts, budgets, light caps, the "+N/step" text, and the
#     R149 z-fighting detector on the whole base, before vs after (also run by docs/proposals/R151/tests/run_treadmills.sh).
#  3. render_treadmills.mjs draws every scene from the same cameras with three.js (treadmills.html, headless Chromium, software WebGL) and the belt
#     animation frames; make_treadmill_sheet.py composes the sheets and the GIF (Pillow).
# Approximate: no Roblox lighting, bloom or Fredoka font; particles are dots; the belt images are the real patterns (textures/*.png).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${4:-19d05d4}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/scenes" "$S/out" "$S/base_src"
rm -rf "$S/base_src/src";git -C "$REPO" archive "$BASE" src | tar -x -C "$S/base_src"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/place_tree.luau" Workspace/ChestChaseMap >/dev/null
for which in before after;do
 if [ "$which" = before ];then SRC=$S/base_src/src;else SRC=$REPO/src;fi
 D=$S/$which;mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$S/place_tree.luau" "$D/"
 python3 "$REPO/docs/proposals/R149/tests/zfight_bundle.py" "$SRC" "$D" >/dev/null
 (printf "WHICH='%s'\n" "$which";cat "$HERE/treadmill_scene.luau") > "$D/run_scene.luau"
 (cd "$D" && timeout 900 /opt/luau/luau run_scene.luau > "$S/scenes/$which.txt" 2> "$S/scenes/$which.err") || { tail -20 "$S/scenes/$which.err";grep -v "SCENE" "$S/scenes/$which.txt" | grep -v "^WARN" | tail -8 | cut -c1-300;exit 1; }
 grep '^BUDGET' "$S/scenes/$which.txt"
done
python3 "$HERE/check_treadmill_dress.py" "$S/scenes" "$REPO"
[ "${SKIP_RENDER:-0}" = 1 ] && exit 0
cp "$HERE/treadmills.html" "$HERE/render_treadmills.mjs" "$S/";rm -rf "$S/textures";cp -r "$HERE/textures" "$S/textures"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null 2>&1);[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright";fi
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_treadmills.mjs" "$S" "$S/scenes" "$S/out"
python3 "$HERE/make_treadmill_sheet.py" "$S/out" "$S/scenes" "$REPO/docs/proposals/R151"
