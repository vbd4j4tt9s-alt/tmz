#!/bin/sh
# Usage: sh run_announce_preview.sh <scratch dir>
# R151 preview -> docs/proposals/R151/announcements.png: the pull-announcement banner for Legendary / Mythic / Secret / Cosmic / King (gold coat), the small other-server banner and the
# record banner, on a desktop (1280x720), a landscape phone (844x390) and a portrait phone (390x844), plus the top of the screen with a notice row pushed below the banner.
# The REAL PullAnnouncerClient and HudNotices run under the Roblox mock (tools/tests/roblox.luau + the R123 world), the GUI trees are dumped as JSON (R150's dump_tree.luau) and
# drawn by headless Chromium (R150's render_gui.mjs: Roblox-style layout, gradients, strokes, emoji; Montserrat stands in for Gotham). Approximate: the seed picture and the
# headshot are stand-in drawings, tweens settle at once, sparkles and the shine sweep are caught half a second in.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and npm (@fontsource/montserrat is installed into the scratch dir; without it
# the page falls back to DejaVu Sans).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
R150=$REPO/docs/proposals/R150
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/montserrat" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
for view in desktop phone portrait;do
 D=$S/$view;mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$R150/preview/dump_tree.luau" "$HERE/announce_scenes.luau" "$D/"
 python3 "$HERE/../tests/mkbundle.py" "$D" >/dev/null
 printf "VIEW='%s'\n" "$view" > "$D/scenes.luau"
 cat "$HERE/announce_scenes.luau" >> "$D/scenes.luau"
 (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
done
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_sheet.py" "$S" "$REPO/docs/proposals/R151/announcements.png"
