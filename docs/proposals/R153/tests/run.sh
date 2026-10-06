#!/bin/sh
# Usage: sh run.sh [scratch dir]. R153 (owner: "index gem gain is halved"; the 7-day login track's Gems stay) on the Roblox mock (/opt/luau/luau) with the real modules of this checkout:
#  static            - the Index change is only the halfway / completion Gems (BalanceValues81, VerityCatalog) and the two lines in PremiumProgress that halve a pending backpay; ChestIndex.client.lua is untouched
#                      (it reads the amounts from BalanceValues81 and the server's backpay attribute); the daily login Gems (days 5 and 6: 2 and 3) are not touched
#  test_index_gems   - every category's halfway / completion Gems, once each, collected through CollectSaleCash; the backpay (shown = paid); already-claimed rewards stay claimed; the cash and every
#                      other BalanceValues81 number equal the R152 file
# (the Index displays are in R148's test_index_limited / test_roster_art: +5 / +10 / +50, and the daily suites are R140's.)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv"
BASE=${R152_BASE:-e36b71b};T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== static checks"
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 git -C "$REPO" show "$BASE:src/ReplicatedStorage/BalanceValues81.lua" > "$OUT/BalanceValues81Base.lua"
 PP=$REPO/src/ServerScriptService/ChestChaseServer/PremiumProgress.lua;CI=$REPO/src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua
 if [ "$(grep -c "T.HalveGems(pending)" "$PP")" = 1 ] && [ "$(grep -c "T.HalveGems(backpay)" "$PP")" = 1 ];then echo "ok: PremiumProgress halves a pending backpay where it is shown and where it is claimed (one line each)";else fail "PremiumProgress: the backpay is not halved in both places";fi
 if grep -q "amount=T.HalfwayGems" "$PP" && grep -q "T.CompletionGems\[stage\]" "$PP";then echo "ok: the halfway and completion claims still read BalanceValues81";else fail "the Index claims no longer read BalanceValues81";fi
 if grep -q "tuning.HalfwayGems" "$CI" && grep -q "tuning.CompletionGems\[stage\]" "$CI" && ! grep -qE "HalfGems=(5|10)[,}]|Gems=(10|20|50|100)[,}]" "$CI";then echo "ok: ChestIndex shows the amounts BalanceValues81 and the server say (no number written into it)";else fail "ChestIndex has its own gem numbers";fi
 if git -C "$REPO" show "$BASE:src/ReplicatedStorage/VerityCatalog.lua" | grep -q "HalfwayGems=10,CompletionGems=100" && grep -q "HalfwayGems=5,CompletionGems=50" "$REPO/src/ReplicatedStorage/VerityCatalog.lua";then echo "ok: the Verity catalog Gems went 10 / 100 -> 5 / 50";else fail "VerityCatalog Gems are not 5 / 50 (R152: 10 / 100)";fi
 if git -C "$REPO" show "$BASE:src/ReplicatedStorage/DailyRewards.lua" | grep -q '{Gems=2},{Gems=3}' && grep -q '{Gems=2},{Gems=3}' "$REPO/src/ReplicatedStorage/DailyRewards.lua";then echo "ok: the login track still has 2 Gems, 3 Gems on days 5 and 6 (as in R152)";else fail "the login Gems days changed";fi
else echo "(R152 commit $BASE not in this checkout: the diff checks are skipped)";rm -f "$OUT/BalanceValues81Base.lua";fi
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE";then fail "a model name in the R153 files";else echo "ok: no model names in the R153 files";fi
cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_index_gems.luau" "$OUT/srv/"
python3 "$HERE/mkbundle_index.py" "$OUT/srv" "$OUT/BalanceValues81Base.lua" >/dev/null
cd "$OUT/srv";echo "== test_index_gems"
/opt/luau/luau test_index_gems.luau > index.log 2>&1 || { tail -30 index.log;exit 1; };tail -1 index.log
[ "$RC" = 0 ] || exit 1
echo "R153 Index gems suites passed"
