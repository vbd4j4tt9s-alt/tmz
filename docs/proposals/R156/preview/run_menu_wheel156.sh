#!/bin/sh
# Usage: sh run_menu_wheel156.sh <scratch dir> [out png, default docs/proposals/R156/menu_wheel_daily.png]
# R156 PREVIEW (not a release; src/ is not touched): DAILY and INVITE move into the menu wheel.
#  1. make_variant156.py writes the PROPOSED scripts (HudLayout, TravelButtons, DailyRewardsClient, ChestIndex) as patched copies of this checkout's src/ into <scratch>/variant;
#  2. menu_wheel_scene156.luau runs the REAL wheel scripts (HudLayout.Navigation, SettingsClient, ChestIndex, GamePassClient), the REAL DailyRewardsClient / TravelButtons and the REAL
#     NotifyBadge151 / PityBars155 under the Roblox mock, twice: "current" = this checkout (R155), "proposed" = the patched copies; on a PC (1920 x 1080), a landscape phone (844 x 390), a
#     portrait phone (390 x 844) and a short landscape phone (750 x 311: an 844 x 390 phone with its safe-area insets). The GUI trees are dumped as JSON (R153's dump_tree153.luau);
#  3. make_menu_wheel_sheet156.py draws them with headless Chromium (R155's render_gui155.mjs) and lays out the sheet;
#  4. sweep_wheel156.luau prints the proposed layout on 20 screen sizes (<scratch>/sweep.tsv: the table of menu_wheel_daily.md).
# The hotbar slots, balances, status card, jump button / stick and Roblox's own top bar buttons are STAND-INS drawn from HudLayout's metrics. APPROXIMATE: not a Studio screenshot.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the fonts, npm (@fontsource/fredoka-one and @fontsource/montserrat in
# <scratch>/fonts; without them DejaVu Sans stands in).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R156/menu_wheel_daily.png}
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
python3 "$HERE/make_variant156.py" "$REPO/src" "$S/variant"
for variant in current proposed;do
 for view in pc land port tiny;do
  D=$S/$variant/$view;mkdir -p "$D"
  cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R153/preview/dump_tree153.luau" "$HERE/sweep_wheel156.luau" "$D/"
  if [ "$variant" = proposed ];then
   python3 "$HERE/mkbundle_menu156.py" "$D" "$REPO/src" HudLayout="$S/variant/HudLayout.lua" TravelButtons="$S/variant/TravelButtons.client.lua" \
    DailyRewardsClient="$S/variant/DailyRewardsClient.client.lua" ChestIndex="$S/variant/ChestIndex.client.lua" >/dev/null
  else
   python3 "$HERE/mkbundle_menu156.py" "$D" "$REPO/src" >/dev/null
  fi
  printf "VIEW='%s'\n" "$view" > "$D/scene.luau"
  cat "$HERE/menu_wheel_scene156.luau" >> "$D/scene.luau"
  (cd "$D" && /opt/luau/luau scene.luau > scene.log 2> scene.err) || { tail -20 "$D/scene.err";exit 1; }
  grep 'LOADFAIL' "$D/scene.log" || true
 done
done
(cd "$S/proposed/pc" && /opt/luau/luau sweep_wheel156.luau) > "$S/sweep.tsv"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 -W ignore "$HERE/make_menu_wheel_sheet156.py" "$S" "$OUT"
