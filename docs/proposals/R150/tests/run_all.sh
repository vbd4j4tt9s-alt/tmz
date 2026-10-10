#!/bin/sh
# Usage: sh run_all.sh [scratch dir]. The R150 bonus UI suites (run_bonus_ui.sh) and every older suite that touches TreadmillBonus or HudLayout:
# R123 treadmill bonus (server, client, 26-screen button placement), R128 (HUD), R129 (phone HUD), R137 (packs / pictures: reads the bonus client's
# source), R138 (tutorial layout on 26 screens). With "mutate" as the second argument the R150 mutation check runs as well.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);P=$(cd "$HERE/../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
echo "######## R150 bonus UI";sh "$HERE/run_bonus_ui.sh" "$OUT/r150"
if [ "$2" = "mutate" ];then echo "######## R150 mutations";python3 "$HERE/mutation_check.py" "$OUT/mut";fi
echo "######## R123 treadmill bonus";sh "$P/treadmill_bonus_R123/tests/run.sh" "$OUT/r123"
for r in R128 R129 R137 R138;do echo "######## $r";sh "$P/$r/tests/run.sh" "$OUT/$r";done
echo "all suites passed"
