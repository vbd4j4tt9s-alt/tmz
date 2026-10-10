#!/bin/sh
# Usage: sh run_offline.sh [scratch dir]. R151 offline audit (docs/proposals/R151/offline_audit.md):
#  test_plantnotify.luau  - the real SocialService "your plant is ready" queue + Open Cloud call with the real PlayerDataService:
#                           shutdown, no server at the ready time, two servers racing, 250 due at once (paging), the 24 h limit,
#                           retries / setup problems, the rejoin race, the request shape, the owner command, friend-check retry.
#                           R152: a big backlog is delivered in its own budgeted task and never delays the daily reset (a virtual-clock run of SocialService.Start).
#  R140 suite             - test_daily (login week, quests, friend boost, the R140 plant-ready checks) + test_daily_client (opt-in).
#  polish_R124 suite      - test_offline.luau: the "Plants grow offline" rainbow text in the Esc menu (+ the other R124 checks).
#  wiring                 - ChestChaseServerMain binds SocialService:Shutdown to BindToClose.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv"
T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests
grep -q "game:BindToClose(function()social:Shutdown(Players:GetPlayers())end)" "$REPO/src/ServerScriptService/ChestChaseServerMain.server.lua" || { echo "FAIL: SocialService:Shutdown is not bound to BindToClose";exit 1; }
echo "== wiring: BindToClose -> social:Shutdown ok"
cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_plantnotify.luau" "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
(cd "$OUT/srv";echo "== test_plantnotify";/opt/luau/luau test_plantnotify.luau > plantnotify.log 2>&1 || { tail -30 plantnotify.log;exit 1; };tail -1 plantnotify.log)
echo "== R140 suite";sh "$REPO/docs/proposals/R140/tests/run.sh" "$OUT/r140"
echo "== polish_R124 suite";sh "$REPO/docs/proposals/polish_R124/tests/run.sh" "$OUT/r124"
