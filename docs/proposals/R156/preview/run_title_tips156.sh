#!/bin/sh
# Usage: sh run_title_tips156.sh <scratch dir> [out png, default docs/proposals/R156/title_tips.png]
# R156 preview: the REAL title screen (src/ReplicatedStorage/TitleScreen104.lua) with Style B, the rotating "tip:" line floating between the logo and Click to play!, under the Roblox mock, on a PC (1920 x 1080), a
# landscape phone (844 x 390) and a portrait phone (390 x 844). src/ is NOT changed: patch_title156.py writes a SCRATCH copy of TitleScreen104 with the tip line (and the diff the real change
# would be, title_tips156.diff next to the sheet's inputs), the draft list TitleTips156.lua is bundled as a ReplicatedStorage module, the title is started and stepped through its own frame
# function (title_tips_scene156.luau), its GUI trees are dumped as JSON (R153's dump_tree153.luau) and drawn by headless Chromium (R155's render_gui155.mjs); make_sheet156.py lays out the PNG.
# Also: verify_king_odds.luau (the "mythic packs ... king seed" check on the real odds code) is run and its output kept in the scratch dir.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the font, npm (@fontsource/fredoka-one in the scratch dir; without it
# DejaVu Sans stands in). APPROXIMATE: not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R156/title_tips.png}
mkdir -p "$S"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font package: DejaVu Sans stands in"
fi
python3 "$HERE/patch_title156.py" "$REPO" "$S/TitleScreen104_tips.lua" "$S/title_tips156.diff"
for view in pc land port;do
 D=$S/$view;mkdir -p "$D"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R153/preview/dump_tree153.luau" "$D/"
 python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" "TitleScreen104=$S/TitleScreen104_tips.lua" "TitleScreen104Today=$REPO/src/ReplicatedStorage/TitleScreen104.lua" "TitleTips156=$HERE/TitleTips156.lua" >/dev/null
 printf "VIEW='%s'\n" "$view" > "$D/scenes.luau"
 cat "$HERE/title_tips_scene156.luau" >> "$D/scenes.luau"
 (cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
 awk -F'\t' '$1=="TIP"{print $2,$3,"alpha="$4,"scale="$5,"bob="$6}' "$D/scenes.log" 
done
# Reduced Motion: the same title with GuiService.ReducedMotionEnabled = true: the fade frame must be fully opaque (no fade) and the text must still change every 5 s
D=$S/reduced;mkdir -p "$D"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R153/preview/dump_tree153.luau" "$D/"
python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$D" "TitleScreen104=$S/TitleScreen104_tips.lua" "TitleScreen104Today=$REPO/src/ReplicatedStorage/TitleScreen104.lua" "TitleTips156=$HERE/TitleTips156.lua" >/dev/null
printf "VIEW='pc'\nREDUCED=true\n" > "$D/scenes.luau"
cat "$HERE/title_tips_scene156.luau" >> "$D/scenes.luau"
(cd "$D" && /opt/luau/luau scenes.luau > scenes.log 2>&1) || { tail -20 "$D/scenes.log";exit 1; }
echo "REDUCED MOTION (the scene asserts no fade, no pulse, no bob):";awk -F'\t' '$1=="TIP"{print $2,$3,"alpha="$4,"scale="$5,"bob="$6}' "$D/scenes.log" 
# the king-odds check (real SeedPackRules / PackOdds137 / PackLuck154 under the mock)
K=$S/odds;mkdir -p "$K"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$K/"
python3 "$REPO/docs/proposals/R150/tests/mkbundle.py" "$K" >/dev/null
cp "$HERE/verify_king_odds.luau" "$K/king.luau"
(cd "$K" && /opt/luau/luau king.luau > king.log 2>&1) || tail -5 "$K/king.log"
cp "$K/king.log" "$S/king_odds.txt"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 -W ignore "$HERE/make_sheet156.py" "$S" "$OUT"
# every tip must fit the line on every screen, and the line must not overlap the logo / pack or the button
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$HERE/check_tip_fit156.mjs" "$S"
