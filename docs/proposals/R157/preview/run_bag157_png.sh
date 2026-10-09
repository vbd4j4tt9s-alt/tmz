#!/bin/sh
# Usage: sh run_bag157_png.sh <scratch dir> [out.png]   -> docs/proposals/R157/bag157.png
# R157: the picture of the shipped Bag look, rendered from the REAL src of this checkout (not a scratch copy). It is docs/proposals/R156/preview/run_bag_look.sh with its src variable pointed at src/ and only
# that one variant: R156 drew CURRENT (src) next to OPTION 2 (a scratch copy with make_option2_src.py applied); R157 ships OPTION 2 in src/ itself, so there is nothing left to apply.
# Same steps and same helpers (R156's bag_scenes156.luau, patch_dump156.py, mkbundle156.py; R153's dump_tree153.luau and engine153.luau; R155's render_gui155.mjs): the real Hotbar / Bag / discard
# popup on the Roblox mock, driven at the view's screen size (pc 1280 x 720 with a mouse, landscape phone 844 x 390 with touch) into the scenes, the GUI trees dumped and drawn by headless Chromium.
# make_bag157_sheet.py lays out the rows: at rest, an item dragged over the Bag, the Discard bin targeted, the discard popup; PC on the left, the phone on the right.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R157/bag157.png}
P=$REPO/docs/proposals;T=$REPO/tools/tests;INV=$P/inventory_R113/tests;R156=$P/R156/preview
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/montserrat" ] || [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/montserrat @fontsource/fredoka-one >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
SRC=$REPO/src # (the real src: nothing is copied or patched)
for view in pc phone;do
 D=$S/real/$view;rm -rf "$D";mkdir -p "$D"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$D/"
 python3 "$R156/patch_dump156.py" "$P/R153/preview/dump_tree153.luau" "$D/dump_tree153.luau" # (R153's dump + a TextBox, so the Search box is drawn)
 # (the engine model at this view's screen size and top inset)
 sed "s/local INSET=V2(0,58);local SCREEN=V2(1280,720)/local INSET=opts.Inset and V2(0,opts.Inset) or V2(0,58);local SCREEN=opts.Screen or V2(1280,720)/" "$P/R153/tests/engine153.luau" > "$D/engine155p.luau"
 grep -q "opts.Screen" "$D/engine155p.luau" || { echo "engine153.luau changed: the screen size patch did not apply";exit 1; }
 python3 "$R156/mkbundle156.py" "$SRC" "$D" all-client NotificationService="$SRC/ServerScriptService/ChestChaseServer/NotificationService.lua" >/dev/null
 { printf "VIEW='%s'\n" "$view";cat "$R156/bag_scenes156.luau"; } > "$D/scenes.luau"
 (cd "$D" && timeout 900 /opt/luau/luau scenes.luau > scenes.log 2>&1) || { grep -v '^WARN' "$D/scenes.log" | tail -20;exit 1; }
 echo "$view: $(grep -c '^SCENE' "$D/scenes.log") scenes"
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_bag157_sheet.py" "$S" "$OUT"
