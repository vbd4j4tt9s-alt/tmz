#!/bin/sh
# Usage: sh run_speed_popups_preview.sh <scratch dir>
# R151 speed popups PREVIEW (nothing under src/ is touched) -> docs/proposals/R151/speed_popups.png and speed_popups.gif
#  1. reference_fit.py   the numbers measured from the owner's reference clip (hand-tracked samples inside the script; the clip itself is not
#                        needed and not kept) -> reference_numbers.json
#  2. (the curves are checked by docs/proposals/R151/tests/test_speed_popups_style.luau through run_speed_popups.sh)
#  3. sim_popups.luau    1.5 s of a run through the popups of before R151 (constants of the old SpeedGainPopup.client.lua) and the real SpeedPopupStyle, per 1/30 s
#  4. render_preview.mjs the sheet (strip.png) and the side by side animation frames, drawn by headless Chromium (playwright)
#  5. make_gif.py        the animation as one small GIF
# Needs /opt/luau, python3 + numpy + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and, for the font, npm
# (@fontsource/fredoka-one is installed into the scratch dir; without it the page falls back to DejaVu Sans).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);R151=$(cd "$HERE/.." && pwd);S=${1:?scratch dir}
mkdir -p "$S/out"
python3 "$HERE/reference_fit.py" "$HERE/reference_numbers.json" 2>&1 | sed 's/^/reference: /'
mkdir -p "$S/sim";cp "$HERE/sim_popups.luau" "$R151/../../../src/ReplicatedStorage/SpeedPopupStyle.lua" "$S/sim/"
(cd "$S/sim" && /opt/luau/luau sim_popups.luau > "$S/frames.log")
grep '^STAT' "$S/frames.log"
if [ ! -d "$S/fonts/node_modules/@fontsource/fredoka-one" ];then
 mkdir -p "$S/fonts";npm install --prefix "$S/fonts" @fontsource/fredoka-one >/dev/null 2>&1 || echo "no font package: falling back to DejaVu Sans"
fi
export PLAYWRIGHT_NODE_ROOT=${PLAYWRIGHT_NODE_ROOT:-$(npm root -g)}
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$HERE/render_preview.mjs" "$S/frames.log" "$HERE/reference_numbers.json" "$S/out" "$S/fonts"
python3 "$HERE/make_gif.py" "$S/out" "$R151/speed_popups.gif" 96
cp "$S/out/strip.png" "$R151/speed_popups.png"
echo "wrote $R151/speed_popups.png and speed_popups.gif"
