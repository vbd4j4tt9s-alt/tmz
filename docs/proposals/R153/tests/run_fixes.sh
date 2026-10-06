#!/bin/sh
# Usage: sh run_fixes.sh [scratch dir] [place.rbxl] [mutate]
# R153: the three fixes the owner found after installing R152, on the Roblox mock (/opt/luau/luau) with the REAL scripts of this checkout:
#  1. badges   - "increase the size of the notification bubble": every badge 1.5x (INDEX count 36, MENU alert 30, DAILY 30, tab dots 21 px), whole reach on screen on 8 layouts (+ 9 for
#                DAILY), held by the wheel's CanvasGroup, "9+" fits: the R151 badge suites (docs/proposals/R151/tests/run_badges.sh, which carry the R153 checks)
#  2. barrier  - "the night refresh screen must fit under the track gate": test_barrier153.luau against the REAL rook gate (HubDecor151) and, with the owner's place file, the R149
#                z-fighting detector on the finished hub + the barrier (check_barrier_zfight.py)
#  3. belt     - "the whole treadmill belt must move, not just the arrows": test_belt153.luau (REAL TreadmillFx + TreadmillBeltArt151 + BiomeVisuals on every base, every quality tier)
#  static      - the touched scripts compile, the line-1 load guard stays, no model names in the R153 files, frozen hashes hold
# "mutate" breaks a copy of src in the ways of mutate153.py and expects the suite that guards each to fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
S=$REPO/src;P=$REPO/docs/proposals;T=$REPO/tools/tests;INV=$P/inventory_R113/tests
LUAU=${LUAU:-/opt/luau/luau}
mkdir -p "$OUT"
fail(){ echo "FAIL: $1";exit 1; }
echo "== static"
for f in ReplicatedStorage/NotifyBadge151 ReplicatedStorage/RefreshBarrier ReplicatedStorage/HubDecorKit151 ReplicatedStorage/HudLayout ReplicatedStorage/TreadmillFx ReplicatedStorage/TreadmillLook151 \
 ServerScriptService/ChestChaseServer/HubDecor151 ServerScriptService/ChestChaseServer/BiomeVisuals StarterPlayer/StarterPlayerScripts/ChestIndex.client StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client;do
 /opt/luau/luau-compile --null "$S/$f.lua" >/dev/null 2>&1 || fail "$f does not compile"
done
for f in "$HERE"/test_*.luau;do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || fail "$f does not compile";done
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|anthrop[i]c|gp[t]-?[0-9]" "$HERE" "$P/R153.md" 2>/dev/null;then fail "a model name in the R153 files";fi
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 || { cat "$OUT/guard.log";fail "the R152 load guard (line 1 of every client script)"; }
echo "ok: the touched scripts and the R153 tests compile; line 1 of every client script is still the R152 load guard; no model names"
echo "== 1. badges (R151 run_badges.sh: sizes, reach on screen, clipping, daily)"
sh "$P/R151/tests/run_badges.sh" "$OUT/badges" > "$OUT/badges.log" 2>&1 || { tail -30 "$OUT/badges.log";fail "badges"; }
grep -E "checks|passed" "$OUT/badges.log" | tail -6
echo "== 2. barrier"
B=$OUT/barrier;mkdir -p "$B"
cp "$T/roblox.luau" "$INV/world.luau" "$P/R149/tests/zfight_world.luau" "$HERE/test_barrier153.luau" "$B/"
python3 "$P/R149/tests/zfight_bundle.py" "$S" "$B" > /dev/null
(cd "$B" && $LUAU test_barrier153.luau > barrier.log 2>&1) || { grep -v '^WARN' "$B/barrier.log" | tail -30;fail "barrier"; }
grep -v '^WARN' "$B/barrier.log" | tail -3
echo "== 3. belt"
# belt MODE SRC DIR: the REAL TreadmillFx / BiomeVisuals / BeltArt + the chevrons' own code of SRC, test_belt153.luau in MODE (before = the R152 src measured for the root cause)
belt() {
 mode=$1;src=$2;d=$3;mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$P/R149/tests/zfight_world.luau" "$d/"
 (echo "MODE='$mode'";cat "$HERE/test_belt153.luau") > "$d/test_belt153.luau"
 python3 "$HERE/mkbundle_belt.py" "$src" "$d" > /dev/null
 (cd "$d" && timeout 900 $LUAU test_belt153.luau > belt.log 2>&1)
}
BASE152=${BASE152:-e36b71b}
if git -C "$REPO" cat-file -e "$BASE152" 2>/dev/null;then
 rm -rf "$OUT/base152";mkdir -p "$OUT/base152";git -C "$REPO" archive "$BASE152" src | tar -x -C "$OUT/base152"
 belt before "$OUT/base152/src" "$OUT/belt_before" || { grep -v '^WARN' "$OUT/belt_before/belt.log" | tail -20;fail "belt (R152 root cause)"; }
 grep -v '^WARN' "$OUT/belt_before/belt.log" | tail -5
else echo "(no $BASE152 here: the R152 root-cause measurement was skipped)";fi
belt after "$S" "$OUT/belt" || { grep -v '^WARN' "$OUT/belt/belt.log" | tail -30;fail "belt"; }
grep -v '^WARN' "$OUT/belt/belt.log" | tail -8
echo "all R153 checks passed"
