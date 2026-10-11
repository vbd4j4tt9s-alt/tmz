#!/bin/sh
# Usage: sh run_bag_look.sh <scratch dir> [out.png]   -> docs/proposals/R156/bag_look.png
# R156 preview (a PREVIEW of a look change, not a release; src/ is never touched): the REAL Hotbar / Bag / discard popup on the Roblox mock, twice:
#   current  = this checkout's src/ as it is
#   option2  = a scratch copy of src/ with make_option2_src.py applied (navy sheet, no green anywhere in the Bag, a neutral drag highlight, no hint line)
# Each is driven through R153's engine model at the view's screen size (pc 1280 x 720 with a mouse, landscape phone 844 x 390 with touch) into the scenes of
# bag_scenes156.luau; the GUI trees are dumped (R153's dump_tree153.luau) and drawn by headless Chromium (R155's render_gui155.mjs); make_bag_sheet156.py lays them out.
# Same toolchain as R155's run_inventory_preview.sh: /opt/luau, python3 + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers), fonts from npm
# (@fontsource/montserrat + fredoka-one; without them DejaVu Sans).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R156/bag_look.png}
P=$REPO/docs/proposals;T=$REPO/tools/tests;INV=$P/inventory_R113/tests
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/montserrat" ] || [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/montserrat @fontsource/fredoka-one >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
for variant in current option2;do
 SRC=$S/src_$variant;rm -rf "$SRC";cp -r "$REPO/src" "$SRC"
 if [ "$variant" = option2 ];then python3 "$HERE/make_option2_src.py" "$SRC";fi
 for view in pc phone;do
  D=$S/$variant/$view;rm -rf "$D";mkdir -p "$D"
  cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$D/"
  python3 "$HERE/patch_dump156.py" "$P/R153/preview/dump_tree153.luau" "$D/dump_tree153.luau" # (R153's dump + a TextBox, so the Search box is drawn)
  # (the engine model at this view's screen size and top inset)
  sed "s/local INSET=V2(0,58);local SCREEN=V2(1280,720)/local INSET=opts.Inset and V2(0,opts.Inset) or V2(0,58);local SCREEN=opts.Screen or V2(1280,720)/" "$P/R153/tests/engine153.luau" > "$D/engine155p.luau"
  grep -q "opts.Screen" "$D/engine155p.luau" || { echo "engine153.luau changed: the screen size patch did not apply";exit 1; }
  python3 "$HERE/mkbundle156.py" "$SRC" "$D" all-client NotificationService="$SRC/ServerScriptService/ChestChaseServer/NotificationService.lua" >/dev/null
  { printf "VIEW='%s'\n" "$view";cat "$HERE/bag_scenes156.luau"; } > "$D/scenes.luau"
  (cd "$D" && timeout 900 /opt/luau/luau scenes.luau > scenes.log 2>&1) || { grep -v '^WARN' "$D/scenes.log" | tail -20;exit 1; }
  echo "$variant $view: $(grep -c '^SCENE' "$D/scenes.log") scenes"
 done
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_bag_sheet156.py" "$S" "$OUT"
