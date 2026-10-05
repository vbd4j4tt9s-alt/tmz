#!/bin/sh
# Usage: sh run_bonus_preview.sh <scratch dir>
# R150 previews -> docs/proposals/R150/bonus_button.png, bonus_timer.png, bonus_roll_desktop.png, bonus_roll_phone.png and the overview sheet
# bonus_ui.png (before = R149's TreadmillBonusClient kept in preview/TreadmillBonusClient_R149.lua, after = this checkout's).
# The REAL client scripts run under the Roblox mock (tools/tests/roblox.luau + the R123 world), each is driven into the states named in
# bonus_scenes.luau (button charging / almost / ready / two ready, gift timer mid / almost / ready pop / full, roll screen spinning and the
# Common / Rare / Legendary / Mythic / Secret reveals at 1280x720 and 844x390), the GUI trees are dumped as JSON (dump_tree.luau) and drawn by
# headless Chromium (render_gui.mjs: Roblox-style layout, gradients, strokes, emoji; Montserrat stands in for Gotham). Approximate: pack
# pictures are stand-in drawings, tweens settle at once, effects are caught at a chosen frame.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the font, npm
# (@fontsource/montserrat is installed into the scratch dir; without it the page falls back to DejaVu Sans).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
T=$REPO/docs/proposals/R150/tests
mkdir -p "$S/out"
if [ ! -d "$S/fonts/node_modules/@fontsource/montserrat" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
for side in old new;do
 for view in desktop phone;do
  D=$S/${side}_$view;mkdir -p "$D"
  cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE/dump_tree.luau" "$HERE/bonus_scenes.luau" "$D/"
  if [ $side = old ];then python3 "$T/mkbundle.py" "$D" TreadmillBonusClient="$HERE/TreadmillBonusClient_R149.lua" >/dev/null
  else python3 "$T/mkbundle.py" "$D" >/dev/null;fi
  printf "SIDE='%s';VIEW='%s'\n" "$side" "$view" > "$D/scenes.luau"
  cat "$HERE/bonus_scenes.luau" >> "$D/scenes.luau"
  (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
 done
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_sheets.py" "$S" "$REPO/docs/proposals/R150"
