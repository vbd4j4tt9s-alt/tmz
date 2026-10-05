#!/bin/sh
# Usage: sh run_hub_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [place.rbxl] [out.png]
# Renders docs/proposals/R151/hub_displays.png: the two hub displays (BEST PULL TODAY, BIGGEST FRUIT TODAY) in the owner's real hub, empty and with a champion each:
#   * an overview from above the hub, wide shots from Base 4's and Base 3's spawn, close-ups, the podium / item / avatar in detail, the empty boards, and a plan of the hub.
#  1. tests/build_hub_scenes.sh loads the place file's map into the Roblox mock, runs the real start-up builders and the REAL HubDisplayService (real HubDisplayArt, real
#     HubDisplayAvatar on a mock rig posed by HubAvatarPose.Static) twice (nobody / a champion each), and dumps every part plus the signs' words (HUBSIGN lines).
#  2. hub_scenes.py turns the dump into the renderer's scenes and camera views. 3. render_hub.mjs draws them with three.js (hub.html, headless Chromium via playwright,
#  swiftshader): parts as Roblox shapes, neon as glowing unlit colour, the signs drawn like the SurfaceGui lays them out. 4. make_hub_sheet.py composes the sheet (Pillow).
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers; never run `playwright install`) and three.js (pass a node_modules dir,
# or `npm install three@0.169.0` is run in the scratch dir). Approximate: plain materials, no Roblox textures or lighting, the font is not Fredoka; the avatar is the mock's
# stand-in rig (the real one is the player's own, loaded by Players:CreateHumanoidModelFromDescription in Studio); the client's motion (spin, sparkles, cheer, pop) is not drawn.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};OUT=${4:-$REPO/docs/proposals/R151/hub_displays.png}
mkdir -p "$S/out"
sh "$REPO/docs/proposals/R151/tests/build_hub_scenes.sh" "$S" "$PLACE"
python3 "$HERE/hub_scenes.py" "$S/scene" "$S/hub_views.json"
cp "$HERE/hub.html" "$HERE/render_hub.mjs" "$S/"
if [ -n "$NM" ];then [ -e "$S/node_modules" ] || ln -s "$NM" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null);fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_hub.mjs" "$S" "$S/hub_views.json" "$S/out" > /dev/null
python3 "$HERE/make_hub_sheet.py" "$S/out" "$S/scene" "$OUT"
