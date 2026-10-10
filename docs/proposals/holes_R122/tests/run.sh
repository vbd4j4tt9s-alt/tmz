#!/bin/sh
# Usage: sh run.sh [scratch dir]. Runs the R122 track-hole tests under the Roblox mock:
#  test_holes.luau        - real TrackHoleService + real ConcurrentKeeperService Finish/drop path + real RagdollService
#                           (mock R6 rig) + real SecurityGate / HarvestToolService.
#                           R153 (section 19): the hole is 1.5x the radius (5.1 across); every step's whole path is swept against the pit (TrackHoleService.Cross),
#                           so carriers are caught at 50 / 500 / 5,000 / 50,000 studs/s at 15 - 144 Hz, always IN the hole; the trigger radius measured by halving = the drawn
#                           pit; nothing beside it / high over it; digger, tutorial, arming, ragdoll immunity, one hole = one carrier, teleports, early-out.
#  test_holes_client.luau - real TrackHoleClient input routing / hint / effects and GardenShovel hint passthrough (R149: dirt bursts lifted
#                           onto the keyboard's key tops where the keyboard is drawn, at the floor elsewhere). R153: the shovel tip (dig holes + remove plants) shows when
#                           the shovel is pulled out, the first 3 times of a session; the dig animation ends at the configured size.
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
