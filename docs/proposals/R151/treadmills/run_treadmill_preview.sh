#!/bin/sh
# Usage: sh run_treadmill_preview.sh <scratch dir> [node_modules dir with three@0.169] [place.rbxl]
# R151 treadmill look PROPOSAL (owner: "keep the shape of the treadmills that we hve but just see what we can improve and addd from the
# references above" / "show previews before implementation"). Nothing in src/ is changed: this draws docs/proposals/R151/treadmills.png,
# treadmills_all.png and treadmills_belt.gif.
#  1. treadmill_scene.luau runs the REAL start-up builders on Base 1 of the owner's place in the R149 Roblox mock, the REAL treadmill at every
#     level (BiomeVisuals.BuildTreadmillV131), the REAL upgrade buttons and the REAL client effects controller (TreadmillFx), once as today
#     (BEFORE) and once with the proposal prototype TreadmillDress151.luau on top (AFTER). It prints the scenes, the budgets and the
#     z-fighting scenes.
#  2. check_treadmill_dress.py: budgets, collision / query of every new part, the belt collider and prompt unchanged, the "+N/step" text,
#     and the R149 z-fighting detector (tools/zfight.py) on the whole base, before vs after: no new finding.
#  3. render_treadmills.mjs draws every scene from the same cameras with three.js (treadmills.html, headless Chromium, software WebGL), and
#     the belt animation frames; make_treadmill_sheet.py composes the sheets and the GIF (Pillow).
# Approximate: no Roblox lighting, bloom or Fredoka font; the grid texture (asset 6372755229) is drawn from a guess of its look; particles are dots.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/scenes" "$S/out"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/treadmill_scene.luau" "$S/t/"
python3 "$HERE/bundle_treadmills.py" "$REPO/src" "$S/t" >/dev/null
for which in before after;do
 if [ "$which" = after ];then G='DRESS=true';else G='DRESS=false';fi
 (printf '%s\n' "$G";cat "$S/t/treadmill_scene.luau") > "$S/t/run_$which.luau"
 (cd "$S/t" && timeout 900 /opt/luau/luau "run_$which.luau" > "$S/scenes/$which.txt" 2> "$S/scenes/$which.err") || { tail -20 "$S/scenes/$which.err";grep -v "^[SZ]*SCENE" "$S/scenes/$which.txt" | grep -v "^WARN" | tail -8 | cut -c1-300;exit 1; }
 grep '^BUDGET' "$S/scenes/$which.txt"
done
python3 "$HERE/check_treadmill_dress.py" "$S/scenes" "$REPO"
[ "${SKIP_RENDER:-0}" = 1 ] && exit 0
cp "$HERE/treadmills.html" "$HERE/render_treadmills.mjs" "$S/";rm -rf "$S/textures";cp -r "$HERE/textures" "$S/textures"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null 2>&1);[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright";fi
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_treadmills.mjs" "$S" "$S/scenes" "$S/out"
python3 "$HERE/make_treadmill_sheet.py" "$S/out" "$S/scenes" "$REPO/docs/proposals/R151"
