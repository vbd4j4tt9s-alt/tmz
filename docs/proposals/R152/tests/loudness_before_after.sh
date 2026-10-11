#!/bin/sh
# Usage: sh loudness_before_after.sh <scratch dir> [base commit, default 24ed94b = R151]. Plays every presentation of the R151 code and of this
# checkout on the mock and prints the loudness table of each (test_seed_loudness.luau in report mode): the before / after numbers of
# docs/proposals/R152/seed_opening.md.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:?scratch dir};BASE=${2:-24ed94b};mkdir -p "$OUT/before/tree" "$OUT/before/cl" "$OUT/after/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;INV=$P/inventory_R113/tests
(cd "$REPO" && git archive "$BASE" src docs/proposals/R151/tests/mkbundle_rare.py | tar -x -C "$OUT/before/tree")
for side in before after;do
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$HERE/rare152_env.luau" "$HERE/sound_levels.luau" "$HERE/test_seed_loudness.luau" "$OUT/$side/cl/"
 if [ $side = before ];then python3 "$OUT/before/tree/docs/proposals/R151/tests/mkbundle_rare.py" "$OUT/before/cl" all-client >/dev/null
 else python3 "$P/R151/tests/mkbundle_rare.py" "$OUT/after/cl" all-client >/dev/null;fi
 (cd "$OUT/$side/cl" && { echo "REPORT_ONLY=true";cat test_seed_loudness.luau; } > report.luau && /opt/luau/luau report.luau 2>&1 | grep -v '^WARN' > report.txt) || true
 echo "== $side";cat "$OUT/$side/cl/report.txt" | grep -v "^R152 loudness checks"
done
