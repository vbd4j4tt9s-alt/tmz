#!/bin/sh
# R151: builds the finished hub with the two displays on the Roblox mock, twice (both boards empty / a champion and an avatar on each), for check_hub_scene.py and the
# preview (docs/proposals/R151/preview). The owner's place file is loaded (its Workspace.ChestChaseMap), every real start-up builder runs on it, then the REAL
# HubDisplayService builds the displays (docs/proposals/R151/tests/make_hub_scene.py on top of R149's zfight_scene.luau).
# Usage: sh build_hub_scenes.sh <scratch dir> <place.rbxl> [src dir, default this checkout's src]
# Writes <scratch>/scene/: scene_empty.json, scene_champions.json, empty.steps, champions.steps (the HUBINFO / HUBTEXT lines), place_geom.json (every saved part of the map,
# invisible spawns included). Exits 1 when a scene fails to build.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:?place file};SRC=${3:-$REPO/src};W=$S/scene
[ -f "$PLACE" ] || { echo "no place file: $PLACE";exit 1; }
mkdir -p "$W"
GEOM=$REPO/docs/proposals/R149/tools/rbxl_geom.py
python3 "$GEOM" --tree "$PLACE" "$W/place_tree.luau" Workspace/ChestChaseMap > /dev/null
python3 "$GEOM" "$PLACE" "$W/place_geom.json" Workspace/ChestChaseMap > /dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/hub_rig.luau" "$W/"
python3 "$HERE/make_hub_scene.py" "$REPO/docs/proposals/R149/tests/zfight_scene.luau" "$W/hub_scene.luau" > /dev/null
python3 "$REPO/docs/proposals/R149/tests/zfight_bundle.py" "$SRC" "$W" > /dev/null
cd "$W"
for state in empty champions; do
  (printf 'SKIP_CLIENT=true;HUB_STATE="%s"\n' $state; cat hub_scene.luau) > run_$state.luau
  timeout 600 /opt/luau/luau run_$state.luau > $state.log 2>&1 || { tail -20 $state.log;exit 1; }
  grep '^SCENE ' $state.log | sed 's/^SCENE //' > scene_$state.json
  grep -v '^SCENE ' $state.log > $state.steps
  if grep -q ' FAILED ' $state.steps;then grep ' FAILED ' $state.steps;exit 1;fi
  grep -E 'HUBINFO|ZSCENE' $state.steps
done
