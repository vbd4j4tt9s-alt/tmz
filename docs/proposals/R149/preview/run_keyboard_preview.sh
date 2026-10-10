#!/bin/sh
# Usage: sh run_keyboard_preview.sh <scratch dir> [before revision, default 766ec4d = the R148 release the owner has live] [r151]
# With "r151" as the third argument (R151: letters on every key, the deeper press, the spacebar names across the track) the views are the R151 set and
# the sheet is docs/proposals/R151/keyboard_fix.png (before = the revision given, e.g. c1e8829 = R150, as it plays live; after = this checkout).
# Renders the keyboard of the R148 release ("before") and of this checkout ("after") from the same cameras and writes, into
# docs/proposals/R149/: keyboard_<view>.png (R149) and keyboard_compare_<view>.png (R148 | R149) for the views runner, overview, closeup,
# long and crystal. dump_keyboard149.luau runs the REAL KeyboardTrack.client.lua of each version on the Roblox mock and prints the parts and
# SurfaceGuis it drew; render_keyboard149.mjs draws them with three.js (headless Chromium via playwright, swiftshader); make_keyboard_sheet.py
# puts them side by side. Needs /opt/luau, git, python3 + Pillow, node + playwright (global) and `npm install three@0.169.0` (done here).
# Approximate: the R142Keycap mesh is drawn as a square frustum with a lighter top, plain lighting, no Roblox materials.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};BEFORE=${2:-766ec4d};MODE=$3
INV=$REPO/docs/proposals/inventory_R113/tests
mkdir -p "$S/out" "$S/before" "$S/after" "$S/before_src"
# the "before" source tree: this checkout's src with the two keyboard files of the before revision
cp -r "$REPO/src/." "$S/before_src/"
git -C "$REPO" show "$BEFORE:src/ReplicatedStorage/KeyboardTrack.lua" > "$S/before_src/ReplicatedStorage/KeyboardTrack.lua"
git -C "$REPO" show "$BEFORE:src/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua" > "$S/before_src/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua"
for v in before after; do
 if [ "$v" = before ]; then SRC=$S/before_src; else SRC=$REPO/src; fi
 cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$HERE/dump_keyboard149.luau" "$S/$v/"
 sed "s#'/home/user/tmz/src'#'$SRC'#" "$INV/mkbundle.py" > "$S/$v/mkbundle.py"
 python3 "$S/$v/mkbundle.py" "$S/$v/rs_bundle.luau" KeyboardTrackClient="$SRC/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua" >/dev/null
 (cd "$S/$v" && /opt/luau/luau dump_keyboard149.luau > scenes.txt)
done
cp "$HERE/keyboard149.html" "$HERE/render_keyboard149.mjs" "$S/"
[ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null)
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
for v in before after; do
 KB_VIEWS=$MODE PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_keyboard149.mjs" "$S" "$S/$v/scenes.txt" "$S/out" "$v"
done
if [ "$MODE" = r151 ]; then python3 "$REPO/docs/proposals/R151/preview/make_fix_sheet.py" "$S/out" "$REPO/docs/proposals/R151" "$BEFORE"
else python3 "$HERE/make_keyboard_sheet.py" "$S/out" "$HERE/.."; fi
