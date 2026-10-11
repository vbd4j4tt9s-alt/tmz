#!/bin/sh
# Usage: sh run_keyboard.sh [scratch dir]. The keyboard suite moved with R149 (bigger, taller keys, one look out to long range, biome colours,
# steady clicks): docs/proposals/R149/tests/run_keyboard.sh + test_keyboard.luau. The R148 suite that lived here (test_keyboard.luau,
# 293 checks on the retired layered pitch-3 design) is in git history (commit adb3e0f); test_keyboard.luau in R149 lists which of its
# checks were kept, changed or removed and why. This runner stays so older scripts (R149/tests/run_all.sh) keep running the keyboard suite.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
exec sh "$HERE/../../R149/tests/run_keyboard.sh" "$@"
