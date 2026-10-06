#!/bin/sh
# Usage: sh run_hub_scenes.sh <scratch dir> [place.rbxl] [before ref, default 24ed94b = R151 as handed over]
# R152 hub decor: builds the finished hub (the REAL HubDecor151 via MapService.new + the real HubLife151.client with every detail level shown,
# desktop tier, on the owner's place in the R149 Roblox mock) twice - BEFORE = the src of the before ref, AFTER = this checkout - with the R151
# preview scene (docs/proposals/R151/preview/base_area_scene.luau). Writes <scratch>/scenes/{before,after}.json (the "SCENE" dumps every
# renderer / z-fight check reads) and the logs. Used by run_hub_preview.sh and run_hub_zfight.sh.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);R151=$REPO/docs/proposals/R151/preview
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${3:-24ed94b}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/b" "$S/scenes" "$S/before"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$R151/base_area_scene.luau" "$R151/standin_tree.luau" "$S/t/"
cp "$S"/t/*.luau "$S/b/"
python3 "$R151/bundle_r151.py" "$REPO/src" "$S/t" >/dev/null
rm -rf "$S/before/src";git -C "$REPO" archive "$BEFORE" src | tar -x -C "$S/before"
python3 "$R151/bundle_r151.py" "$S/before/src" "$S/b" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
scene() { # $1 = name, $2 = dir, $3 = globals
 (printf '%s\n' "$OWN;$3";cat "$2/base_area_scene.luau") > "$2/run_$1.luau"
 (cd "$2" && timeout 900 /opt/luau/luau "run_$1.luau" > "$S/scenes/$1.log" 2>&1) || { tail -20 "$S/scenes/$1.log";exit 1; }
 if grep -q 'FAILED' "$S/scenes/$1.log";then grep FAILED "$S/scenes/$1.log";exit 1;fi
 grep '^SCENE ' "$S/scenes/$1.log" | sed 's/^SCENE //' > "$S/scenes/$1.json"
 echo "scene $1: $(grep '^ZSCENE' "$S/scenes/$1.log" | sed 's/^ZSCENE //')"
}
scene before "$S/b" 'BUILT=true;CLIENT_TIER=3'
scene after "$S/t" 'BUILT=true;CLIENT_TIER=3'
