#!/bin/sh
# Usage: sh run_seed_collect_preview.sh <scratch dir> [node_modules dir with three@0.169.0 and the @fontsource fonts]
# R154 preview: docs/proposals/R154/seed_collect.png - the result waits (its hint, still there 30 s later), the click, the seed's flight into the
# hotbar slot, its landing (the pop and the slot's flash), the seed in the hotbar. A Legendary card and a King story scene, desktop.
# Built on R152's pipeline (docs/proposals/R152/preview/run_seed_opening_preview.sh, unchanged): run with no set, it prepares the mock bundle of
# THIS checkout, the client-drawn images, three.js / the fonts and its GUI renderer; then R152's preview_frames152.luau with
# collect_frames154.luau appended (SET='collect') prints the FRAME lines; render_frames152.mjs / render_gui152.mjs draw them; compose152.py lays
# them out as strips. Needs what R152's runner needs (/opt/luau, python3 + Pillow, node + playwright).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};NM=$2
P=$REPO/docs/proposals;R152=$P/R152/preview
sh "$R152/run_seed_opening_preview.sh" "$S" "$NM" " " # (no set: the bundle, the images, the renderers)
(cd "$S/cl" && { printf "SET='collect'\n";cat preview_frames152.luau "$HERE/collect_frames154.luau"; } > set_collect.luau && timeout 1800 /opt/luau/luau set_collect.luau > frames_collect.txt 2> set_collect.err) || { tail -20 "$S/cl/set_collect.err";exit 1; }
echo "collect: $(grep -c '^FRAME' "$S/cl/frames_collect.txt") frames"
cd "$S"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g);export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$S/render_frames152.mjs" "$S" "$S/cl/frames_collect.txt" "$S/out_collect" >/dev/null
node "$S/render_gui152.mjs" "$S/out_collect/gui_scenes.json" "$S/out_collect" "$S/node_modules/@fontsource/montserrat/files" >/dev/null
python3 "$R152/compose152.py" "$S/out_collect" "$P/R154/seed_collect.png" strips 'R154 seed collect: the result waits until the player clicks, then the seed flies into its hotbar slot (desktop 1280x720)'
