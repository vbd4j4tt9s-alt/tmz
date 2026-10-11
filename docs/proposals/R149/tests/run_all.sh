#!/bin/sh
# Usage: sh run_all.sh [scratch dir]. The R149 weather suites (run_weather.sh) and every older suite that touches the weather or the keyboard:
# R128 (biome particles), R129 (base-only weather, phone HUD), R130 (refresh sky), R131 (weather mutation rate), R147 keyboard. With "mutate" as the
# second argument the R149 mutation checks run as well.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);P=$(cd "$HERE/../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
echo "######## R149";sh "$HERE/run_weather.sh" "$OUT/r149"
if [ "$2" = "mutate" ]; then echo "######## R149 mutations";sh "$HERE/run_weather.sh" "$OUT/r149m" mutate;fi
for r in R128 R129 R130 R131; do echo "######## $r";sh "$P/$r/tests/run.sh" "$OUT/$r";done
echo "######## R147 keyboard";sh "$P/R147/tests/run_keyboard.sh" "$OUT/R147"
echo "all suites passed"
