#!/bin/sh
# Usage: sh run.sh [scratch dir]. R130 checks on the Roblox mock:
#  test_keeper_idle.luau - idle keeper upkeep (real ConcurrentKeeperService): far fewer full prepares, same result.
#  test_refresh_sky.luau - track refresh sky (real RefreshSky + TrackRefreshSky + WorldEvents): dark with or
#                          without the black-sky image, everything restored exactly, no weather clouds meanwhile.
#  test_micro.luau       - MovementGuard reuses one RaycastParams and still blocks at the barriers.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/test_*.luau "$OUT/"
SS=$REPO/src/ServerScriptService/ChestChaseServer;P=$REPO/src/StarterPlayer/StarterPlayerScripts
# mkbundle.py reads /home/user/tmz/src; bundle THIS checkout's src (a worktree has its own).
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" > "$OUT/mkbundle.py"
python3 "$OUT/mkbundle.py" "$OUT/rs_bundle.luau" ConcurrentKeeperService=$SS/ConcurrentKeeperService.lua \
  MovementGuard=$SS/MovementGuard.lua WorldEvents=$P/WorldEvents.client.lua TrackRefreshSky=$P/TrackRefreshSky.client.lua >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { tail -20 "$t.log";exit 1; };tail -1 "$t.log";done
