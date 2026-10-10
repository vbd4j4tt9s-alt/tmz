#!/bin/sh
# Usage: sh render_title_tips157.sh <scratch dir> [out png, default docs/proposals/R157/title_tips157.png]      (R157_BASE=<commit before the change>, default d1640c1)
# R157: renders the title tips AS BUILT. The REAL src/ReplicatedStorage/TitleScreen104.lua and src/ReplicatedStorage/TitleTips156.lua (no scratch copy, no patch) are started on the Roblox
# mock at each size, stepped through the title's own frame function at 120 fps (title_tips_scene157.luau), their GUI trees are dumped as JSON (R153's dump_tree153.luau) and drawn by headless
# Chromium (R156's render_gui156.mjs); make_sheet157.py lays out the PNG. The title before the change (R157_BASE) is bundled as TitleScreen104Today, only for the "was ... px" logo sizes.
# The scene asserts the pulse (1.03 / 0.97), the 50% fade frame, Reduced Motion (no fade, no pulse), that the line is never moved, and that it is centred and clear of the logo and the button.
# Also: check_tip_fit156.mjs (every tip fits each size, the line never overlaps the logo / pack / button, on the rendered pages) and verify_king_odds.luau (tip 2, on the real odds code).
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the font, npm (@fontsource/fredoka-one in the scratch dir; without it
# DejaVu Sans stands in). APPROXIMATE: not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R157/title_tips157.png}
P156=$REPO/docs/proposals/R156/preview;BASE=${R157_BASE:-d1640c1}
mkdir -p "$S"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/TitleScreen104.lua" > "$S/TitleScreen104_before.lua"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
bundle(){ # dir view [reduced]
 D=$1;mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R153/preview/dump_tree153.luau" "$D/"
 python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" "TitleScreen104Today=$S/TitleScreen104_before.lua" >/dev/null
 printf "VIEW='%s'\n" "$2" > "$D/scenes.luau"
 [ -z "$3" ] || printf "REDUCED=true\n" >> "$D/scenes.luau"
 cat "$HERE/title_tips_scene157.luau" >> "$D/scenes.luau"
 (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
}
for view in pc land port;do
 bundle "$S/$view" "$view"
 awk -F'\t' '$1=="TIP"{print $2,$3,"alpha="$4,"scale="$5,"moved="$6}' "$S/$view/scenes.log"
done
# Reduced Motion: the fade frame must be fully opaque (no fade) and no pulse
bundle "$S/reduced" pc reduced
echo "REDUCED MOTION (the scene asserts no fade, no pulse):";awk -F'\t' '$1=="TIP"{print $2,$3,"alpha="$4,"scale="$5,"moved="$6}' "$S/reduced/scenes.log"
# the king-odds check (real SeedPackRules / PackOdds137 / PackLuck154 under the mock)
K=$S/odds;mkdir -p "$K"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$K/"
python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$K" >/dev/null
cp "$P156/verify_king_odds.luau" "$K/king.luau"
(cd "$K" && /opt/luau/luau king.luau > king.log 2>&1) || tail -5 "$K/king.log"
cp "$K/king.log" "$S/king_odds.txt"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 -W ignore "$HERE/make_sheet157.py" "$S" "$OUT"
# every tip must fit the line on every screen, and the line must not overlap the logo / pack or the button
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$P156/check_tip_fit156.mjs" "$S"
