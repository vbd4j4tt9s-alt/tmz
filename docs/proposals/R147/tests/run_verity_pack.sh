#!/bin/sh
# Usage: sh run_verity_pack.sh [scratch dir]. R147 Verity pack / Verity seed (data + server side) on the Roblox mock
# (/opt/luau/luau) with the real modules:
#  test_verity_pack.luau - constants, the Verity pack odds (every odds version, the hold tooltip), the Void pack's odds against a
#                          snapshot of the unmodified code, 2M Monte Carlo rolls, PlayerDataService.ConvertVoidPack (+ save / load /
#                          gift round trips, opening, planting, harvesting), Index category 9, ChestService.ConvertVoidPack,
#                          the owner commands (odds verity, verity N, rarepacks verity) and the help rows.
#  The server world is docs/proposals/treadmill_bonus_R123/tests/world.luau + mkbundle.py (every ReplicatedStorage and
#  ChestChaseServer module, so the new VerityPackOdds is picked up automatically).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests
cp "$T/roblox.luau" "$TB/world.luau" "$HERE"/test_verity_pack.luau "$OUT/";python3 "$TB/mkbundle.py" "$OUT" >/dev/null
cd "$OUT";echo "== test_verity_pack";timeout 300 /opt/luau/luau test_verity_pack.luau > verity.log 2>&1 || { tail -40 verity.log;exit 1; };tail -1 verity.log
