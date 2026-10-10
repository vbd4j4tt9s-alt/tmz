#!/bin/sh
# R158e tutorial storyboard: sh run_preview158e.sh <scratch dir> -> docs/proposals/R158e/tutorial158e.png
# The REAL BeginnerTutorial (+ BeginnerGuide, HudLayout, PropCache152) runs on the tools/tests mock (scenes158e.luau drives the ten steps on a PC 1280x720 and a landscape phone
# 844x390), its GUI is dumped (R150 dump_tree.luau) and drawn by headless Chromium (R150 render_gui.mjs, FredokaOne, Noto Color Emoji); the world (block scenery + the tutorial's own
# 3D arrow, chevrons, ring and beam as the script placed them) is projected by a perspective camera behind the player and drawn by make_sheet158e.py. Approximate.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
T=$REPO/tools/tests;SRC=$REPO/src
mkdir -p "$S/fonts";cp "$REPO/docs/proposals/shop_R120/tests/FredokaOne.ttf" "$S/fonts/montserrat-latin-500-normal.woff2"
for view in pc phone;do
 D=$S/$view;mkdir -p "$D"
 cp "$T/roblox.luau" "$D/"
 { echo "local Color3=require('./roblox').Color3 -- (R150 dump_tree reads Color3 as a global)";cat "$REPO/docs/proposals/R150/preview/dump_tree.luau"; } > "$D/dump_tree.luau"
 python3 "$T/bundle.py" "$D/tut_bundle.luau" BeginnerTutorial="$SRC/StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua" BeginnerGuide="$SRC/ReplicatedStorage/BeginnerGuide.lua" \
  HudLayout="$SRC/ReplicatedStorage/HudLayout.lua" PropCache152="$SRC/ReplicatedStorage/PropCache152.lua" >/dev/null
 { printf "VIEW_NAME='%s'\n" "$view";sed -n '1,/^-- Run ---/p' "$T/test_tutorial.luau";cat "$HERE/scenes158e.luau"; } > "$D/preview.luau"
 (cd "$D" && /opt/luau/luau preview.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
done
export PLAYWRIGHT_NODE_ROOT=${PLAYWRIGHT_NODE_ROOT:-$(npm root -g)}
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_sheet158e.py" "$S" "$REPO/docs/proposals/R158e/tutorial158e.png"
