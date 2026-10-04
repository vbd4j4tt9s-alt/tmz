#!/bin/sh
# Usage: sh run.sh [scratch dir]. R147 checks on the Roblox mock with the real scripts:
#  test_mystery.luau      - the base's mystery pack pedestal (MysteryPackRules + MysteryPackService + PlayerDataService,
#                           SeedPackVisuals, the real treadmill for the clearance): rules / sanitising / rolls / odds /
#                           stage, pedestal position and clearance, the black silhouette, locked at 899 s and ready at
#                           900 s, claims (owner only, once, AddChest {Luck=true} + SyncTools), saved and loaded,
#                           leaving / rejoining, the next UTC day, carry-over into the Bag, a full Bag, the owner command
#                           `mystery`; the review fixes: Persistent pedestal model, the prompt Enabled only while Ready,
#                           UnlockAt republished on drift, a full Bag at midnight (owed list: kept, capped at 3, saved,
#                           granted once when there is room); plus the keeper tagging (ChaseService._preparePersistentGuardian, VeiledEvent81
#                           EnsureGuardian, KeeperPursuit.EscapeSpeed).
#  test_r147_client.luau  - the real MysteryPackClient (label, bar, prompt, burst, spin, and under StreamingEnabled: late and
#                           re-streamed pedestals / parts, non-owners never see an enabled prompt), KeeperSpeedLabels (the
#                           "SPEED NEEDED" pill: texts, colours, ANY, friend boost, The Darkened) and
#                           Progression81.PointsFor / PointsText against Progression81.Speed over BalanceValues81.PointCurve.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv" "$OUT/cl"
T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
MAIN=$REPO/src/ServerScriptService/ChestChaseServerMain.server.lua
# The wiring in the main script: the service is built and started, joins / leaves reach it (leaving before the profile is
# finalized), and the owner command finds it through the chase service.
grep -q "require(modules.MysteryPackService).new(Config,playerData,baseService,chestService,notifications,mapService):Start()" "$MAIN"
grep -q "mystery:Setup(player)" "$MAIN"
grep -q "mystery:Leaving(player)" "$MAIN"
grep -q "chaseService.Mystery=mystery" "$MAIN"
LEAVE=$(grep -n "mystery:Leaving(player)" "$MAIN" | head -1 | cut -d: -f1);FINAL=$(grep -n 'playerData:FinalizePlayer(player, "PlayerRemoving")' "$MAIN" | head -1 | cut -d: -f1)
[ -n "$LEAVE" ] && [ -n "$FINAL" ] && [ "$LEAVE" -lt "$FINAL" ]
test -f "$C/MysteryPackClient.client.lua";test -f "$C/KeeperSpeedLabels.client.lua"
cp "$T/roblox.luau" "$TB/world.luau" "$INV/fixtures.luau" "$HERE"/test_mystery.luau "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_r147_client.luau "$OUT/cl/"
# (the R113 bundler has this checkout's path hard-coded: point a copy of it at this worktree's src)
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
grep -q "src = '$REPO/src'" "$OUT/mkbundle_cl.py" # (the client bundle must be this worktree's src, never another checkout's)
python3 "$OUT/mkbundle_cl.py" "$OUT/cl/rs_bundle.luau" MysteryPackClient="$C/MysteryPackClient.client.lua" KeeperSpeedLabels="$C/KeeperSpeedLabels.client.lua" >/dev/null
cd "$OUT/srv";echo "== test_mystery";timeout 300 /opt/luau/luau test_mystery.luau > mystery.log 2>&1 || { tail -25 mystery.log;exit 1; };tail -1 mystery.log
cd "$OUT/cl";echo "== test_r147_client";timeout 300 /opt/luau/luau test_r147_client.luau > client.log 2>&1 || { tail -25 client.log;exit 1; };tail -1 client.log
