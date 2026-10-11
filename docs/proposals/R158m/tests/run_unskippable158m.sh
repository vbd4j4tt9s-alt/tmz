#!/bin/sh
# Usage: sh run_unskippable158m.sh [scratch dir]   (needs /opt/luau/luau + luau-compile, python3, git)
# R158m (owner: "pack opening animations are still really skippable if clicking very fast make sure they always play and only way to skip them is the bottom right button the
# click to collect for after the pack opens and the seed shows is still the same"), on the Roblox mock (/opt/luau/luau) with the REAL scripts of this checkout:
#  0. static   everything compiles at -O0 (no function over 180 local registers), Config.lua and the R151 frozen files are untouched, nothing of the server and no client script
#              changed, registered on line 6 of tools/tests/run_all_suites.sh before the pyramid suite, no model names in the R158m files
#  1. test_unskippable158m.luau   every tier (1..8) and every presentation (the Common..Mythic card normal and Quick, the Secret / Cosmic / King story scene Full and Calm, the compact card
#              in place by a keeper and by "Skip pack animations", the result card of a cut-short scene): a burst of clicks / taps (every route: the world, a touch, TouchTapInWorld, the scene's
#              full-screen button, Space / A, M.Tap, M.Collect) and of Enter / B / R2 from the first frame to just before CollectFrom (the seed shown AND its animation played out) +
#              CollectAfter never collects and never moves the clock; a press that begins at / after it collects; the SKIP button and its keys still jump to the hit on Secret+; no
#              SKIP button on Common..Mythic; the collect hint never shows while a click does nothing; death, a teleport, a chase, the next pack still collect at once; a menu before
#              CollectFrom is ignored; the next pack put in the hand mid-reveal is held that very frame
#  2. the teeth   the same test against the commit before this fix (R158M_BASE, default 384dc75: git archive) and against 18 mutated copies of the source (mutate158m.py: each
#              gate, each route, the hint, the latch, the hold, the SKIP button, the ladder, the immediate endings): it must FAIL on every one
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R158M_BASE:-384dc75}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;RSD=$S/ReplicatedStorage;INV=$P/inventory_R113/tests
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 && echo "ok: $(tail -1 "$OUT/o0.log")" || { tail -5 "$OUT/o0.log";fail "the -O0 compile check (no function over 180 local registers)"; }
(cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | grep -v '^$' | sha256sum -c --quiet) && echo "ok: the R151 frozen hashes hold (Config.lua and the rest)" || fail "the R151 frozen hash check fails"
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R158m/tests/run_unskippable158m.sh docs/proposals/R156/tests/run_pyramid156.sh;" && echo "ok: registered on line 6 of tools/tests/run_all_suites.sh, before the pyramid suite" || fail "not registered on line 6 of tools/tests/run_all_suites.sh before run_pyramid156.sh"
for f in RarePullCinematic RarePullCard RarePullRules;do grep -q "R158m" "$RSD/$f.lua" || fail "$f has no R158m note";done
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 for dir in src/ServerScriptService src/StarterPlayer;do
  c=$(git -C "$REPO" diff --name-only "$BASE" -- "$dir" | tr '\n' ' ')
  [ -z "$c" ] && echo "ok: nothing under $dir changed since $BASE" || echo "note: $dir changed since $BASE: $c(this fix touches only RarePullCinematic, RarePullCard and RarePullRules)"
 done
else echo "skip: $BASE is not in this checkout (the changed-files checks and the teeth against it need it)";fi
# (real model names / ids only; the brackets keep this very line from matching itself)
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE" 2>/dev/null | grep -v "^Binary";then fail "a model name in the R158m files";else echo "ok: no model names in the R158m files";fi
[ $RC = 0 ] || exit 1
prep() { # $1 = a src tree, $2 = the run dir, $3 = fast: the mock, the harness, the test and a bundle of that tree's modules and scripts
 mkdir -p "$2"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$2/"
 if [ "$3" = fast ];then sed 's/^local FAST=false/local FAST=true/' "$HERE/test_unskippable158m.luau" > "$2/test_unskippable158m.luau";else cp "$HERE/test_unskippable158m.luau" "$2/";fi
 sed "s#^src = .*#src = '$1'#" "$P/R151/tests/mkbundle_rare.py" > "$2/mkbundle_rare.py"
 python3 "$2/mkbundle_rare.py" "$2" all-client >/dev/null
}
echo "== 1. test_unskippable158m (this checkout)"
prep "$S" "$OUT/run"
if (cd "$OUT/run" && timeout 1800 /opt/luau/luau test_unskippable158m.luau > test.log 2>&1);then grep -v '^WARN' "$OUT/run/test.log" | tail -2
else grep -v '^WARN' "$OUT/run/test.log" | tail -40;fail "test_unskippable158m";fi
[ $RC = 0 ] || exit 1
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 echo "== 2a. the teeth: the same test against $BASE (it must fail there)"
 rm -rf "$OUT/base";mkdir -p "$OUT/base"
 git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base"
 prep "$OUT/base/src" "$OUT/base/run"
 (cd "$OUT/base/run" && timeout 1800 /opt/luau/luau test_unskippable158m.luau > test.log 2>&1) && fail "the test passes on $BASE: it does not see the bug" || true
 n=$(grep -c '^FAIL' "$OUT/base/run/test.log" || true)
 if [ "$n" -ge 100 ];then echo "ok: on $BASE the test fails $n checks (a burst of clicks collects the result 0.25 s after the seed first shows, in every presentation): the bug is real and the test sees it"
 else fail "on $BASE only $n checks fail (want at least 100)";fi
fi
[ $RC = 0 ] || exit 1
echo "== 2b. the teeth: mutated copies of the source (each must fail the test)"
for id in $(python3 "$HERE/mutate158m.py" list);do
 d=$OUT/mut_$id;rm -rf "$d";mkdir -p "$d/src";cp -r "$S/ReplicatedStorage" "$S/StarterPlayer" "$d/src/"
 desc=$(python3 "$HERE/mutate158m.py" apply "$id" "$d/src") || { fail "mutation $id does not apply (the text it edits moved)";continue; }
 prep "$d/src" "$d/run" fast
 if (cd "$d/run" && timeout 900 /opt/luau/luau test_unskippable158m.luau > test.log 2>&1);then fail "mutation $id survived: $desc"
 else n=$(grep -c '^FAIL' "$d/run/test.log" || true)
  if [ "$n" -ge 1 ];then echo "ok: $id caught by $n checks ($desc)";else grep -v '^WARN' "$d/run/test.log" | tail -5;fail "mutation $id broke the test by an error, not a failed check ($desc)";fi
 fi
 rm -rf "$d"
done
[ $RC = 0 ] || exit 1
echo "R158m unskippable suite passed"
