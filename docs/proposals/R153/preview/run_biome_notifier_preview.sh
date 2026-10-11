#!/bin/sh
# Usage: sh run_biome_notifier_preview.sh <scratch dir>
# R153 biome notifier PREVIEW (nothing under src/ is touched) -> docs/proposals/R153/biome_notifier.png
#  1. decode_logos.py           the game's real biome logos (BiomeIconData.lua, zstd + base64 RGBA) -> <scratch>/logos/logo_<Kind>.png
#  2. render_biome_notifier.mjs fills biome_notifier_preview.html (now / A / B / C, true pixel size) and draws it with headless Chromium (playwright)
# Needs python3 + zstandard + Pillow, node + playwright (PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers, do not run `playwright install`) and npm
# (@fontsource/fredoka-one and @fontsource/montserrat are installed into the scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);R153=$(cd "$HERE/.." && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S/logos" "$S/fonts"
python3 -I "$HERE/decode_logos.py" "$REPO/src/ReplicatedStorage/BiomeIconData.lua" "$S/logos"
[ -d "$S/fonts/node_modules/@fontsource/fredoka-one" ] || npm install --prefix "$S/fonts" @fontsource/fredoka-one @fontsource/montserrat >/dev/null 2>&1
export PLAYWRIGHT_NODE_ROOT=${PLAYWRIGHT_NODE_ROOT:-$(npm root -g)}
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$HERE/render_biome_notifier.mjs" "$S/logos" "$S/fonts" "$S/biome_notifier.png" "$S/metrics.json"
cp "$S/biome_notifier.png" "$R153/biome_notifier.png"
echo "wrote $R153/biome_notifier.png (numbers: $S/metrics.json)"
