#!/bin/sh
# Usage: sh run.sh [scratch dir]. Runs the R122 track-hole tests under the Roblox mock:
#  test_holes.luau        - real TrackHoleService + real ConcurrentKeeperService Finish/drop path + real RagdollService
#                           (mock R6 rig) + real SecurityGate / HarvestToolService.
#  test_holes_client.luau - real TrackHoleClient input routing / hint / effects and GardenShovel hint passthrough.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE/world.luau" "$HERE/test_holes.luau" "$HERE/test_holes_client.luau" "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT"
cd "$OUT"
/opt/luau/luau test_holes.luau > log.txt 2>&1 || { tail -40 log.txt; exit 1; }
tail -1 log.txt
/opt/luau/luau test_holes_client.luau > client_log.txt 2>&1 || { tail -40 client_log.txt; exit 1; }
tail -1 client_log.txt
