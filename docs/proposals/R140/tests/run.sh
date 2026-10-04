#!/bin/sh
# Usage: sh run.sh [scratch dir]. R140 checks on the Roblox mock with the real scripts:
#  (updated for the live R141 numbers: login days 1-4 = random seed pack, day 5 = 2 Gems, day 6 = 3 Gems, day 7 = Mech
#  pack; quests 2 Gems each, 6 Gems a day cap, claims need data.CanSave)
#  test_daily.luau        - login week (day 7 = Mech pack), daily quests (2 Gems each) with the real PlayerDataService,
#                           ChestService.Bank and OpenSeedPack; save/load; the friend boost (SocialService; R149: the walk
#                           speed stays x1, BaseService treadmill gain x1.1 / x1.2 / x1.3, purchases not boosted, MovementGuard); the shared "your plant is ready" queue and the Open Cloud call
#                           (faked MemoryStore / HttpService); the midnight rollover; the owner's daily command.
#  test_daily_client.luau - the real TravelButtons + DailyRewardsClient: DAILY / INVITE in the top bar row on many
#                           screens, the window (LOGIN week, QUESTS), claims, badges, auto-open, invite (R149 wording: speed gain), friend chip,
#                           the notification opt-in.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv" "$OUT/cl"
T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
cp "$T/roblox.luau" "$TB/world.luau" "$HERE"/test_daily.luau "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
grep -q "social:Leaving(player)" "$REPO/src/ServerScriptService/ChestChaseServerMain.server.lua"
grep -q "social:Setup(player)" "$REPO/src/ServerScriptService/ChestChaseServerMain.server.lua"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_daily_client.luau "$OUT/cl/"
python3 "$INV/mkbundle.py" "$OUT/cl/rs_bundle.luau" TravelButtons="$C/TravelButtons.client.lua" DailyRewardsClient="$C/DailyRewardsClient.client.lua" >/dev/null
cd "$OUT/srv";echo "== test_daily";/opt/luau/luau test_daily.luau > daily.log 2>&1 || { tail -25 daily.log;exit 1; };tail -1 daily.log
cd "$OUT/cl";echo "== test_daily_client";/opt/luau/luau test_daily_client.luau > client.log 2>&1 || { tail -25 client.log;exit 1; };tail -1 client.log
