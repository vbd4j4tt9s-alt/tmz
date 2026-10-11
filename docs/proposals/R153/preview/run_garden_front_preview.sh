#!/bin/sh
# Usage: sh run_garden_front_preview.sh <scratch dir> [place.rbxl] [before ref, default e36b71b = the R152 release]
# R153 garden fronts: builds the hub twice (R152's run_hub_scenes.sh: BEFORE = the ref's src, AFTER = this checkout), renders garden_views.json with
# R151's three.js preview (base_area.html) and composes docs/proposals/R153/garden_front.png (before | after). Needs /opt/luau, python3 + Pillow, node +
# playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0 (THREE_MODULES=<a node_modules dir that has three>, else npm install).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);R151=$REPO/docs/proposals/R151/preview
S=${1:?scratch dir};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${3:-e36b71b}
sh "$REPO/docs/proposals/R152/preview/run_hub_scenes.sh" "$S" "$PLACE" "$BEFORE"
mkdir -p "$S/render/out"
cp "$R151/base_area.html" "$R151/render_base_area.mjs" "$S/render/"
if [ -n "$THREE_MODULES" ];then ln -sfn "$THREE_MODULES" "$S/render/node_modules"
else
 [ -d "$S/render/node_modules/three" ] || (cd "$S/render" && npm install three@0.169.0 >/dev/null)
 [ -e "$S/render/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/render/node_modules/playwright"
fi
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$S/render/render_base_area.mjs" "$S/render" "$HERE/garden_views.json" "$S/render/out" before="$S/scenes/before.json" after="$S/scenes/after.json" >/dev/null
python3 "$HERE/make_garden_front.py" "$S/render/out" "$HERE/garden_views.json" "$REPO/docs/proposals/R153"
