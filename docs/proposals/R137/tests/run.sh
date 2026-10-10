#!/bin/sh
# Usage: sh run.sh [scratch dir]. R137 checks on the Roblox mock with the real modules:
#  test_packs.luau  - odds version 137 (Legendary/Mythic rarer down the biome list, no pass-up, Desert's floor steps
#                     down) against the approved proposal's model; 112 packs unchanged; the new size table; the hidden
#                     pack-size pity (player + track) with the real PlayerDataService (AddChest, save/load).
#  test_leaderboard.luau - the real LeaderboardClient scrolls (buttons, mouse wheel over the board, drag).
#  test_index.luau - the polished Index (chips, sort, claim pill, total, tab ring).
#  test_pictures.luau - ItemPictures never shows flat icons (Low graphics, 120 holders), Warm, the reel and Index callers.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/docs/proposals/treadmill_bonus_R123/tests
cp "$REPO/tools/tests/roblox.luau" "$T/world.luau" "$HERE"/test_packs.luau "$OUT/"
mkdir -p "$OUT/lb";cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/test_leaderboard.luau "$HERE"/test_pictures.luau "$HERE"/test_index.luau "$OUT/lb/"
C=$REPO/src/StarterPlayer/StarterPlayerScripts
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/lb/rs_bundle.luau" LeaderboardClient="$C/LeaderboardClient.client.lua" TreadmillBonusClient="$C/TreadmillBonusClient.client.lua" ChestIndex="$C/ChestIndex.client.lua" >/dev/null
python3 "$T/mkbundle.py" "$OUT" >/dev/null
python3 "$HERE/gen_expected.py" "$OUT/expected.luau"
cd "$OUT"
for t in test_packs.luau lb/test_leaderboard.luau lb/test_pictures.luau lb/test_index.luau;do echo "== $t";(cd "$(dirname "$t")" && /opt/luau/luau "$(basename "$t")" > "$(basename "$t").log" 2>&1) || { tail -25 "$t.log";exit 1; };tail -1 "$t.log";done
