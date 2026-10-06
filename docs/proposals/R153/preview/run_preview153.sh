#!/bin/sh
# Usage: sh run_preview153.sh <scratch dir> [out.png]   -> docs/proposals/R153/bonus_roll.png
# R153 preview: the REAL TreadmillBonusClient (+ EmbeddedImage153 decoding BonusPackImage153) under the Roblox mock is driven into the HUD button's charging / half / almost / ready states
# and the roll screen's spin (with the Secret pack flying by) and reveals; the GUI trees are dumped as JSON (dump_tree153.luau) and drawn by headless Chromium (render_gui153.mjs).
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers; no `playwright install`) and, for the font, npm (@fontsource/montserrat in the scratch dir;
# without it the page falls back to DejaVu Sans).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R153/bonus_roll.png}
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/montserrat" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
for view in desktop phone;do
 D=$S/$view;mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE/dump_tree153.luau" "$HERE/bonus_scenes153.luau" "$D/"
 python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" >/dev/null
 printf "VIEW='%s'\n" "$view" > "$D/scenes.luau"
 cat "$HERE/bonus_scenes153.luau" >> "$D/scenes.luau"
 (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 -W ignore "$HERE/make_sheet153.py" "$S" "$OUT"
