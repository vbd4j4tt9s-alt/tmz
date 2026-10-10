#!/bin/sh
# Usage: sh run_offline_text_preview.sh <scratch dir>
# R151 preview -> docs/proposals/R151/offline_text.png: the Esc-menu "Plants grow offline" rainbow text on a 1920x1080 computer, an 844x390
# landscape phone and a 390x844 portrait phone, with a stand-in of Roblox's menu drawn on top (Roblox draws its menu above every game GUI).
# The REAL OfflineGrowthNotice runs under the Roblox mock (polish_R124 world), its GUI tree is dumped (R150's dump_tree.luau) and drawn by
# headless Chromium (render_offline_text.mjs: rainbow gradient on the letters, outline outside them, Fredoka One, emoji). Approximate: the
# game view and the Roblox menu are stand-ins (sizes from CoreScripts SettingsHub/Theme), the rainbow is caught 1/3 s after opening.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and npm (@fontsource/fredoka-one
# and @fontsource/montserrat are installed into the scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
P=$REPO/docs/proposals/polish_R124/tests
mkdir -p "$S/fonts"
[ -d "$S/fonts/node_modules/@fontsource/fredoka-one" ] || npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1 || echo "no font packages: falling back to DejaVu Sans"
cp "$REPO/tools/tests/roblox.luau" "$P/world.luau" "$REPO/docs/proposals/R150/preview/dump_tree.luau" "$HERE/offline_text_scenes.luau" "$S/"
python3 "$P/mkbundle.py" "$S" >/dev/null
(cd "$S" && /opt/luau/luau offline_text_scenes.luau > scenes.log 2>&1) || { tail -20 "$S/scenes.log";exit 1; }
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} python3 "$HERE/make_offline_text.py" "$S" "$REPO/docs/proposals/R151/offline_text.png"
