#!/bin/sh
# Usage: sh run.sh [scratch dir]. R122 Veiled One / Void Pack offline checks on the Roblox mock (/opt/luau/luau).
#  test_event.luau   - server: 2 packs, survives refreshes, FIFO keeper, last steal despawns, no 2nd event,
#                      3 unstolen refreshes -> reroll (counter rules), drops / leaving / lost copy, VeiledNextAt.
#  test_art.luau     - Void Pack art on every render path (world, carried, dropped, inventory picture,
#                      viewport preview, opening copy) + part budget, bounds, client FX budgets.
#  test_arrival.luau - arrival sound once per spawn, 1 s lights-out restored (interrupt / respawn / 2nd spawn),
#                      late joiner and stale timestamps never replay.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/*.luau "$OUT/"
SS=$REPO/src/ServerScriptService/ChestChaseServer;SP=$REPO/src/StarterPlayer/StarterPlayerScripts
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" \
  ConcurrentKeeperService=$SS/ConcurrentKeeperService.lua VeiledEvent81=$SS/VeiledEvent81.lua \
  VeiledEventClient81=$SP/VeiledEventClient81.client.lua >/dev/null
cd "$OUT"
for t in test_event test_art test_arrival; do
  /opt/luau/luau $t.luau > $t.log 2>&1 || { tail -30 $t.log; echo "$t FAILED"; exit 1; }
  tail -1 $t.log
done
