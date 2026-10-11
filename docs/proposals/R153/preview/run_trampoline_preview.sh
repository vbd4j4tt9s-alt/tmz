#!/bin/sh
# Usage: sh run_trampoline_preview.sh <scratch dir> [place.rbxl] [before ref, default e36b71b = R152 as released]
# R153 preview: builds the hub twice (R152's preview/run_hub_scenes.sh: BEFORE = the before ref's src, AFTER = this checkout, both with the real HubDecor151 (+ the
# trampolines) + HubLife151 client on the owner's place in the R149 Roblox mock), renders trampoline_views.json with R151's three.js preview (an approximation: no
# Roblox lighting / PBR materials / bloom) and composes docs/proposals/R153/trampoline.png.
# Needs /opt/luau, python3 + Pillow, node + playwright (global; PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three@0.169.0 (npm install in the scratch dir, or
# THREE_MODULES=<a node_modules dir that has three>).
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
node "$S/render/render_base_area.mjs" "$S/render" "$HERE/trampoline_views.json" "$S/render/out" before="$S/scenes/before.json@nook_top,nook" after="$S/scenes/after.json" >/dev/null
python3 "$HERE/make_trampoline_sheet.py" "$S/render/out" "$HERE/trampoline_views.json" "$REPO/docs/proposals/R153"
