#!/bin/sh
# Usage: sh run_pity_preview155.sh <scratch dir> [out png, default docs/proposals/R155/pity_bars.png]
# R155 preview: the REAL pack pity bars (PityBars155), the real top notices (NoticeFeed83) and the real reveal card (RarePullCard) under the Roblox mock, driven into the
# owner's states (3/10, 9/10 glow, the held pack's highlight, the lucky pop, the lucky pack's reveal, Reduced Motion) on a PC, a landscape phone and a portrait phone;
# the GUI trees are dumped as JSON (R153's dump_tree153.luau) and drawn by headless Chromium (render_gui155.mjs); make_pity_sheet155.py lays out the sheet.
# The rest of the HUD (hotbar slots, balances, status, MENU, BASE / TRACK, jump / stick) is a STAND-IN drawn from HudLayout's metrics.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the fonts, npm (@fontsource/fredoka-one and
# @fontsource/montserrat in the scratch dir; without them DejaVu Sans stands in). APPROXIMATE: not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R155/pity_bars.png}
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
for view in pc land port;do
 D=$S/$view;mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R153/preview/dump_tree153.luau" "$D/"
 python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" >/dev/null
 printf "VIEW='%s'\n" "$view" > "$D/scenes.luau"
 cat "$HERE/pity_scene155.luau" >> "$D/scenes.luau"
 (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
 grep '^PLACE\|^CARD' "$D/scenes.log" || true
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 -W ignore "$HERE/make_pity_sheet155.py" "$S" "$OUT"
