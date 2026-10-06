#!/bin/sh
# Usage: sh run_barrier_zfight.sh <scratch dir> [place.rbxl]
# R153 refresh barrier z-fighting: builds the finished hub with the track CLOSED (the REAL start-up builders on the owner's place file in the R149 Roblox mock, then
# MapService:SetBiomeRefreshing(true): the blackout cover and the barrier in the gate's opening, docs/proposals/R151/preview/base_area_scene.luau with REFRESH = true) and runs
# the R149 detector (docs/proposals/R149/tools/zfight.py, all tiers) through check_barrier_zfight.py: no counted finding (coplanar / near / far) and no tight (< 0.1 stud) pair
# between the barrier and anything else.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);R151=$REPO/docs/proposals/R151/preview
S=${1:?scratch dir};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/t" "$S/scenes"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$R151/base_area_scene.luau" "$R151/standin_tree.luau" "$S/t/"
python3 "$R151/bundle_r151.py" "${SRC:-$REPO/src}" "$S/t" >/dev/null
OWN='OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60}'
(printf '%s\n' "$OWN;BUILT=true;CLIENT_TIER=3;REFRESH=true";cat "$S/t/base_area_scene.luau") > "$S/t/run_refresh.luau"
(cd "$S/t" && timeout 900 /opt/luau/luau run_refresh.luau > "$S/scenes/refresh.log" 2>&1) || { tail -20 "$S/scenes/refresh.log";exit 1; }
if grep -q 'FAILED' "$S/scenes/refresh.log";then grep FAILED "$S/scenes/refresh.log";exit 1;fi
grep '^SCENE ' "$S/scenes/refresh.log" | sed 's/^SCENE //' > "$S/scenes/refresh.json"
echo "scene refresh: $(grep '^ZSCENE' "$S/scenes/refresh.log" | sed 's/^ZSCENE //')"
python3 "$HERE/check_barrier_zfight.py" "$S/scenes/refresh.json"
