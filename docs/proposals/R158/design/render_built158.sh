#!/bin/sh
# Usage: sh render_built158.sh <scratch dir> <plain world dir> <built world dir> [node_modules dir with three@0.169]
# R158: redraws track_walls.png and base_walls.png in this folder from the BUILT code. The two worlds are the ones docs/proposals/R158/tests/run_walls158.sh builds in its scratch folder
# (<scratch>/plain = the owner's place after every real start-up pass WITHOUT the R158 passes, <scratch>/built = WITH them; one scene per biome + the hub).
# The renderer is R156's three.js map renderer in headless Chromium (software WebGL; Ice drawn opaque): APPROXIMATE, not Roblox lighting / materials / bloom.
# (outer_track.png is the old design preview: the backdrop objects are the owner's models now, it is redrawn when they are all in.)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);P=$REPO/docs/proposals
S=${1:?scratch dir};PLAIN=${2:?plain world};BUILT=${3:?built world};NM=$4
mkdir -p "$S/render/out"
python3 "$HERE/make158.py" html "$P/R156/preview/pyramid.html" "$S/render/pyramid.html" >/dev/null
cp "$P/R156/preview/render_pyramid.mjs" "$S/render/"
python3 "$HERE/make_built158.py" scenes "$PLAIN" "$BUILT" "$S/render/scenes"
if [ -n "$NM" ];then [ -e "$S/render/node_modules" ] || ln -s "$NM" "$S/render/node_modules"
else [ -d "$S/render/node_modules/three" ] || (cd "$S/render" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/render/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/render/node_modules/playwright"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render/render_pyramid.mjs" "$S/render" "$S/render/scenes/views.json" "$S/render/out" $(cat "$S/render/scenes/jobs.txt") >/dev/null
mkdir -p "$S/specs"
cp "$REPO/src/ServerScriptService/ChestChaseServer/TrackWallSpecs158.lua" "$P/R158/tests/dump_specs158.luau" "$S/specs/"
(cd "$S/specs" && /opt/luau/luau dump_specs158.luau > specs.txt)
python3 "$HERE/make_built158.py" sheet "$S/render/out" "$S/specs/specs.txt" "$HERE"
