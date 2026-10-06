#!/bin/sh
# Usage: sh run_biome_notifier_built.sh <scratch dir>
# R153: the B (text only) column of the preview, redrawn from the REAL implementation -> docs/proposals/R153/biome_notifier_built.png
#  1. dump_built_notifier.luau   runs the real BiomeEntryNotifier / HudNoticeLayout / BiomeTitleStyle / BiomeMood on the Roblox mock (/opt/luau/luau, tools/tests/roblox.luau, polish_R124's world.luau + bundle)
#                                for every biome on three screens and prints the numbers (sizes, UIStroke, shadow copies, row, fade timeline, skies) as one JSON line
#  2. render_built_notifier.mjs  draws biome_notifier_built.html from those numbers with headless Chromium (playwright)
# Needs node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers, do not run `playwright install`) and npm (@fontsource/fredoka-one and @fontsource/montserrat are installed into the scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);R153=$(cd "$HERE/.." && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S/fonts" "$S/dump"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/polish_R124/tests/world.luau" "$HERE/dump_built_notifier.luau" "$S/dump/"
python3 "$REPO/docs/proposals/polish_R124/tests/mkbundle.py" "$S/dump" >/dev/null
(cd "$S/dump" && /opt/luau/luau dump_built_notifier.luau > dump.out)
grep '^JSON ' "$S/dump/dump.out" | sed 's/^JSON //' > "$S/built.json"
[ -d "$S/fonts/node_modules/@fontsource/fredoka-one" ] || npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1
export PLAYWRIGHT_NODE_ROOT=${PLAYWRIGHT_NODE_ROOT:-$(npm root -g)}
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$HERE/render_built_notifier.mjs" "$S/built.json" "$S/fonts" "$S/biome_notifier_built.png"
cp "$S/biome_notifier_built.png" "$R153/biome_notifier_built.png"
echo "wrote $R153/biome_notifier_built.png (numbers: $S/built.json)"
