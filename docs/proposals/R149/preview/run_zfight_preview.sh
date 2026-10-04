#!/bin/sh
# Usage: sh run_zfight_preview.sh <scratch dir> [place.rbxl] [base commit]
# Renders docs/proposals/R149/zfight.png: six close-ups of the shop / market (roof courses and gable, porch awning, produce stand steps,
# counter crates, side door and window frames, Fruit of the Hour pedestal), before (base commit, default 3484f31 = R148 + the other
# R149 work) and after (this checkout), with every spot tools/zfight.py flags drawn on top (magenta: fixed here; orange: inside a fruit
# model, left for the plant-art files). The scenes are the REAL MarketLayout / map builders run on the owner's place in the Roblox mock
# (tests/zfight_scenes.sh). Needs /opt/luau, python3 + Pillow, node + playwright (global; browsers in /opt/pw-browsers) and three.js
# (npm install three@0.169.0 in the scratch dir, done here). Approximate: plain lighting, no Roblox materials.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${3:-3484f31}
mkdir -p "$S/out"
sh "$REPO/docs/proposals/R149/tests/zfight_scenes.sh" "$S/scenes" "$PLACE" "$BASE"
python3 "$HERE/zfight_views.py" "$S/scenes/before_start.json" "$S/scenes/after_start.json" "$S/views.json"
cp "$HERE/zfight.html" "$HERE/render_zfight.mjs" "$S/"
cd "$S";[ -d node_modules/three ] || npm install three@0.169.0 >/dev/null
[ -e node_modules/playwright ] || ln -s "$(npm root -g)/playwright" node_modules/playwright
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node render_zfight.mjs "$S" "$S/out"
python3 "$HERE/make_zfight_sheet.py" "$S/out" "$S/views.json" "$HERE/../zfight.png"
