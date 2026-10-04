#!/bin/sh
# Usage: sh run_weather_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright]. Renders docs/proposals/R149/weather.png: the REAL
# WeatherWorld149.client.lua / SnowBiome149.client.lua / KeyboardTrack.client.lua run on the Roblox mock (dump_weather.luau prints the emitters
# and patches as JSON), render_weather.mjs simulates the particles from the emitter numbers and draws everything with three.js (headless
# Chromium via playwright, swiftshader), make_sheet.py puts rain / blizzard / snow biome / tile top view on one sheet.
# Needs /opt/luau, python3 + Pillow, node + playwright (global) and three.js (npm install three@0.169.0 in the scratch dir, or pass a node_modules).
# Approximate: no Roblox lighting, materials or textures; particles are simulated, so their look is a stand-in (see the notes in weather.html).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
mkdir -p "$S/out"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$HERE/dump_weather.luau" "$HERE/weather.html" "$HERE/render_weather.mjs" "$S/"
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$INV/mkbundle.py" > "$S/mkbundle.py"
python3 "$S/mkbundle.py" "$S/rs_bundle.luau" WeatherWorld="$C/WeatherWorld149.client.lua" SnowBiome="$C/SnowBiome149.client.lua" KeyboardTrackClient="$C/KeyboardTrack.client.lua" >/dev/null
(cd "$S" && /opt/luau/luau dump_weather.luau | grep '^SCENE' > scenes.txt)
if [ -n "$2" ]; then [ -e "$S/node_modules" ] || ln -s "$2" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null); [ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"; fi
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_weather.mjs" "$S" "$S/out"
python3 "$HERE/make_sheet.py" "$S/out" "$HERE/../weather.png"
