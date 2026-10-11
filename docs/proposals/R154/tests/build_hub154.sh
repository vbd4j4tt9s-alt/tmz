#!/bin/sh
# Usage: sh build_hub154.sh <scratch dir> <place.rbxl> [src dir, default this checkout's src] ['x,z x,z ...' = blizzard scenes with the player there]
# R154 hub z-fighting, the scenes (the "SCENE" json zfight.py reads):
#  <scratch>/hub.json     the whole hub (make_hub_scene154.py: the real start-up builders with HubDecor151 + the trampolines, the treadmills, fences,
#                         pedestals, Verity's dais, leaderboards, the keyboard at the gate, the HubLife151 client with every detail level shown, the
#                         two hub displays with both champions, the Void giveaway pedestal);
#  <scratch>/snow_N.json  the hub in a blizzard (R151's hub_snow_scene.luau: the real WeatherWorld149 client laying HubSnow151's hub-wide drifts,
#                         tier 3, every lobe within 120 studs of the player), one per spot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);P=$REPO/docs/proposals
S=${1:?scratch dir};PLACE=${2:?place.rbxl};SRC=${3:-$REPO/src};SPOTS=${4:-}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$S/hub"
python3 "$P/R149/tools/rbxl_geom.py" --tree "$PLACE" "$S/hub/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$P/R151/preview/standin_tree.luau" "$P/R151/tests/hub_rig.luau" "$S/hub/"
python3 "$P/R151/preview/bundle_r151.py" "$SRC" "$S/hub" >/dev/null
python3 "$HERE/make_hub_scene154.py" "$P/R151/preview/base_area_scene.luau" "$S/hub/hub154_scene.luau" >/dev/null
(printf '%s\n' 'OWNERS={"Ben","Mia","Leo","Zoe","Sam"};RUNNER={0,-60};BUILT=true;CLIENT_TIER=3;HUB_STATE="champions"';cat "$S/hub/hub154_scene.luau") > "$S/hub/run.luau"
(cd "$S/hub" && timeout 900 /opt/luau/luau run.luau > run.log 2>&1) || { tail -20 "$S/hub/run.log";exit 1; }
if grep -q 'FAILED' "$S/hub/run.log";then grep FAILED "$S/hub/run.log";exit 1;fi
grep '^SCENE ' "$S/hub/run.log" | sed 's/^SCENE //' > "$S/hub.json"
echo "hub scene: $(grep '^ZSCENE' "$S/hub/run.log" | sed 's/^ZSCENE //')"
[ -n "$SPOTS" ] || exit 0
mkdir -p "$S/snow"
cp "$S/hub/place_tree.luau" "$REPO/tools/tests/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$S/snow/"
python3 "$P/R151/tests/bundle_hubsnow.py" "$SRC" "$S/snow" >/dev/null
n=0
for spot in $SPOTS;do
 n=$((n+1))
 (printf '%s\n' "PLAYER={$spot};SECONDS=30;TIER=3;DUMP=true";cat "$P/R151/tests/hub_snow_scene.luau") > "$S/snow/run_$n.luau"
 (cd "$S/snow" && timeout 900 /opt/luau/luau "run_$n.luau" > "run_$n.log" 2>&1) || { tail -20 "$S/snow/run_$n.log";exit 1; }
 if grep -q 'FAILED' "$S/snow/run_$n.log";then grep FAILED "$S/snow/run_$n.log";exit 1;fi
 grep '^SCENE ' "$S/snow/run_$n.log" | sed 's/^SCENE //' > "$S/snow_$n.json"
 echo "snow scene $n (player at $spot): $(grep '^STATS' "$S/snow/run_$n.log" | sed 's/^STATS //' | cut -c1-110)"
done
