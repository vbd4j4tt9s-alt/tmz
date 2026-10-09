#!/bin/sh
# Usage: sh run_inventory_preview.sh <scratch dir> [out.png]   -> docs/proposals/R155/inventory.png
# R155 preview: the REAL Hotbar / Bag / discard popup of this checkout on the Roblox mock, driven through R153's engine model (engine153.luau with the view's screen
# size: pc 1280 x 720 with a mouse, phone 844 x 390 with touch) into each state of the storyboard; the GUI trees are dumped (R153's dump_tree153.luau) and drawn by
# headless Chromium (R153's render_gui153.mjs); make_inventory_sheet155.py lays them out with their captions.
# Needs /opt/luau, python3 + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the font, @fontsource/montserrat (npm; without it DejaVu Sans).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R155/inventory.png}
P=$REPO/docs/proposals;T=$REPO/tools/tests;INV=$P/inventory_R113/tests
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/montserrat" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
for view in pc phone;do
 D=$S/$view;mkdir -p "$D"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$D/"
 { echo "local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end} -- (R155: a label without a stroke colour)";cat "$P/R153/preview/dump_tree153.luau"; } > "$D/dump_tree153.luau"
 # (the engine model at this view's screen size and top inset)
 sed "s/local INSET=V2(0,58);local SCREEN=V2(1280,720)/local INSET=opts.Inset and V2(0,opts.Inset) or V2(0,58);local SCREEN=opts.Screen or V2(1280,720)/" "$P/R153/tests/engine153.luau" > "$D/engine155p.luau"
 grep -q "opts.Screen" "$D/engine155p.luau" || { echo "engine153.luau changed: the screen size patch did not apply";exit 1; }
 python3 "$P/R150/tests/mkbundle_sfx.py" "$D" all-client NotificationService="$REPO/src/ServerScriptService/ChestChaseServer/NotificationService.lua" >/dev/null
 { printf "VIEW='%s'\n" "$view";cat "$HERE/inventory_scenes155.luau"; } > "$D/scenes.luau"
 (cd "$D" && timeout 900 /opt/luau/luau scenes.luau > scenes.log 2>&1) || { grep -v '^WARN' "$D/scenes.log" | tail -20;exit 1; }
 echo "$view: $(grep -c '^SCENE' "$D/scenes.log") scenes"
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_inventory_sheet155.py" "$S" "$OUT"
