#!/bin/sh
# Usage: sh run_preview.sh <scratch dir> [reference frame.jpg]. Renders docs/proposals/R148/keyboard_runner.png (a runner's-eye view down the
# track across the Jungle / Desert border, spacebar label ahead) and keyboard_top.png (top view, the whole 180-wide floor, +Z up the image).
# dump_keyboard.luau runs the REAL KeyboardTrack.client.lua on the Roblox mock and prints the parts it drew; render_keyboard.mjs draws them
# with three.js (headless Chromium via playwright, swiftshader). With a reference frame, keyboard_vs_reference.png puts it beside the runner's
# view. Needs /opt/luau, python3 (+ Pillow for the comparison), node + playwright (global) and `npm install three@0.169.0` (done here).
# Approximate: boxes with plain lighting, no Roblox textures; the text orientation follows the SurfaceGui Top-face rule (up = -Z, reads +X).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};REF=$2
INV=$REPO/docs/proposals/inventory_R113/tests
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$HERE/dump_keyboard.luau" "$HERE/keyboard.html" "$HERE/render_keyboard.mjs" "$S/"
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$INV/mkbundle.py" > "$S/mkbundle.py"
python3 "$S/mkbundle.py" "$S/rs_bundle.luau" KeyboardTrackClient="$REPO/src/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua" >/dev/null
/opt/luau/luau "$S/dump_keyboard.luau" > "$S/scenes.txt"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_keyboard.mjs" "$S" "$S/out" >/dev/null
cp "$S/out/runner.png" "$HERE/../keyboard_runner.png";cp "$S/out/top.png" "$HERE/../keyboard_top.png"
if [ -n "$REF" ];then python3 "$HERE/make_compare.py" "$REF" "$HERE/../keyboard_runner.png" "$HERE/../keyboard_vs_reference.png";fi
echo "wrote $HERE/../keyboard_runner.png and keyboard_top.png"
