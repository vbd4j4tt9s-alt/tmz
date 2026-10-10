#!/bin/sh
# Usage: sh run_lag153.sh [scratch dir] [place.rbxl]
# R153 lag audit measurements (docs/proposals/R153/lag_audit.md), all offline:
#  1. place_census.py on the owner's place: the saved Workspace by area (parts, shadow casters, glass / neon, lights, emitters, SurfaceGuis,
#     unanchored parts), the Lighting service and its effects, the Workspace streaming settings.
#  2. lag153_census.luau on the Roblox mock (/opt/luau/luau): the owner's place with every real start-up builder (R152 perf152_world.py: MapService,
#     MarketLayout, treadmills, fences, mystery pedestals, Verity, leaderboards, HubDecor151, the two hub displays, the Void giveaway pedestal) and
#     the clients that build in the world (KeyboardTrack, SnowBiome149, HubLife151, HubDisplayClient, VoidGiveawayClient152), per tier 3 / 2 / 1,
#     standing at the hub plaza and on the track (Crystal Wilds, z 1300): counts per area, within 1024 / 400 / 150 studs, the per-frame loops alive,
#     property writes per frame by area and the Lua ms per client on the mock.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
mkdir -p "$OUT"
python3 -I "$HERE/../tools/place_census.py" "$PLACE" "$OUT/place_census.json" > "$OUT/place_census.txt"
echo "place census: $OUT/place_census.txt"
python3 -I "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place_tree.luau" Workspace/ChestChaseMap > /dev/null
python3 "$HERE/lag153_world.py" "$REPO/src" "$OUT/cw" "$OUT/place_tree.luau" > /dev/null
cd "$OUT/cw"
for t in 3 2 1;do
 for spot in hub track;do
  z=1300;[ "$spot" = hub ] && z=-60
  echo "TIER=$t;SPOT='$spot';RUNNER={0,$z};ALLCLIENT=true" > "run_t${t}_$spot.luau"
  cat census.luau >> "run_t${t}_$spot.luau"
 done
done
for f in run_t*_*.luau;do
 n=${f#run_};n=${n%.luau}
 ( timeout 900 /opt/luau/luau "$f" > "$n.out" 2> "$n.err" || echo "FAILED $n" ) &
done
wait
grep -a -h "^CENSUS\|^RADIUS\|^SUB\|^GUI\|^FALLBACK\|^CLIENT\|^HANDLERERR\|^WRITES\|^TOPWRITES\|^LUAMS\|^LOOPS" t*_*.out > "$OUT/census.txt"
grep -a -h "^CENSUS_TOTAL\|^RADIUS\|^GUI \|^FALLBACK\|^WRITES\|^LUAMS" t*_*.out | cut -c1-400
echo "census: $OUT/census.txt"
