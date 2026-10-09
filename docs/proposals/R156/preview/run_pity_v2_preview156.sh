#!/bin/sh
# Usage: sh run_pity_v2_preview156.sh <scratch dir> [out png, default docs/proposals/R156/pity_bars_v2.png]
# R156 preview of the pity bars' redesign (owner: closer to the hotbar, the clover as the icon, green colours). src/ is NOT changed: the proposal lives in pity_bars_v2.patch, which is applied to
# SCRATCH COPIES of PityBars155.lua and PackPity155.lua; the Roblox mock gets them in place of the real ones (mkbundle's Name=path overrides), so everything that asks for the bars
# (RarePullCard's SKIP pill, the BONUS ROLL button's ButtonSpot, ItemTooltip155) asks the proposed ones. Three views (PC 1920x1080, landscape phone 844x390, portrait phone 390x844) x
# three modes: current (R155 as it is), fresh and deep (the proposal, the owner's pick in its two shades). The GUI trees are dumped as JSON (R153's dump_tree153.luau) and drawn by headless
# Chromium (R155's render_gui155.mjs); make_pity_v2_sheet156.py lays out the sheet. The clover is the game's CloverPassImage153 picture, decoded by decode_clover156.py.
# The rest of the HUD (hotbar slots, name rows, tooltip, balances, status, MENU, jump / stick, BONUS ROLL) is a STAND-IN. APPROXIMATE: not a Studio screenshot.
# Needs /opt/luau, python3 + Pillow + numpy, patch, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the fonts, npm (@fontsource/fredoka-one and
# @fontsource/montserrat in the scratch dir; without them DejaVu Sans stands in).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R156/pity_bars_v2.png}
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
# the proposal: scratch copies of the two modules the patch changes (src/ stays as it is)
rm -rf "$S/v2";mkdir -p "$S/v2/src/ReplicatedStorage"
cp "$REPO/src/ReplicatedStorage/PityBars155.lua" "$REPO/src/ReplicatedStorage/PackPity155.lua" "$S/v2/src/ReplicatedStorage/"
patch -s -p1 -d "$S/v2" < "$HERE/pity_bars_v2.patch"
python3 -I "$HERE/decode_clover156.py" "$REPO/src/ReplicatedStorage/CloverPassImage153.lua" "$S/clover.png"
: > "$S/places.log"
for view in pc land port;do
 for mode in current fresh deep;do
  D=$S/$view-$mode;mkdir -p "$D"
  cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R153/preview/dump_tree153.luau" "$D/"
  if [ "$mode" = current ];then
   python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" >/dev/null
  else
   python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" "PityBars155=$S/v2/src/ReplicatedStorage/PityBars155.lua" "PackPity155=$S/v2/src/ReplicatedStorage/PackPity155.lua" >/dev/null
  fi
  printf "VIEW='%s'\nMODE='%s'\n" "$view" "$mode" > "$D/scenes.luau"
  cat "$HERE/pity_scene156.luau" >> "$D/scenes.luau"
  (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
  grep '^PLACE\|^CHECK\|^CARD' "$D/scenes.log" >> "$S/places.log" || true
 done
done
cat "$S/places.log"
# the bars' place on 36 screens, R155 and the proposal (and whether the name rows, which sit above the bars now, run into another HUD box)
: > "$S/screens.log"
for mode in current fresh;do
 D=$S/pc-$mode
 printf "MODE='%s'\n" "$mode" > "$D/screens.luau"
 cat "$HERE/screens156.luau" >> "$D/screens.luau"
 (cd "$D" && /opt/luau/luau screens.luau > screens.log 2>&1) || { tail -20 "$D/screens.log";exit 1; }
 grep '^SCREEN' "$D/screens.log" >> "$S/screens.log"
done
python3 -I "$HERE/summarize_screens156.py" "$S/screens.log"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 -W ignore "$HERE/make_pity_v2_sheet156.py" "$S" "$OUT"
