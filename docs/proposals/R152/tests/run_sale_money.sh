#!/bin/sh
# Usage: sh run_sale_money.sh [scratch dir]
# R152 (owner: "when u sell something u no longer need to hover over it to collect it, it just auto flies towards the players balance ... the same for gems
# and every other feature that has the money animations"). On the Roblox mock (/opt/luau/luau), with the REAL modules / scripts of this checkout:
#  1. static checks   - the helper has no hover / button / hint; no "hover to collect" text anywhere outside the tutorial files; the callers' remote is the only
#                       claim path; the server's claim has no clock (no timeout awards) and the only PendingSales writers are the ones that make receipts
#  2. test_sale_money.luau        - SaleMoneyEffects (the one helper behind every cash / gem reward): claimed by itself on arrival, the flight, reduced motion,
#                                   caps + overflow, retries, a stalled / hidden screen, exploits, the real wallet on desktop + phones, the hint gone
#  3. test_sale_claim_server.luau - the real PlayerDataService:CollectSaleCash (cut out of the source): exact amounts, once, invalid / foreign ids, limits, no clock;
#                                   and the helper against it (retries, overflow, repeated polls credit exactly what was owed)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;SP=$S/StarterPlayer/StarterPlayerScripts
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== static checks"
F=$S/ReplicatedStorage/SaleMoneyEffects.lua
/opt/luau/luau-compile --null "$F" >/dev/null || fail "SaleMoneyEffects does not compile"
for w in CollectCashHint MouseEnter MouseLeave Activated TextButton Hovered; do grep -q "$w" "$F" && fail "SaleMoneyEffects still has $w"; done
echo "ok: the helper has no hover handler, no button and no hint label"
# no instruction to hover / tap to collect in game text (tutorial files are another round's; listed, not checked)
# (R154: the seed reveal's "click / tap to collect!" hint, RarePullCard's CollectText, is the seed collect, not sale money)
if grep -rniE "hover over|hover to collect|tap to collect|hover.{0,12}(cash|coin|money|gem)|(cash|coin|money|gem).{0,24}hover" "$S" --include=*.lua | grep -v "BeginnerTutorial\|BeginnerGuide\|TutorialProgress\|TutorialTargets" | grep -v "RarePullCard.lua:[0-9]*:function Card.CollectText" | grep -v "^[^:]*:[0-9]*:\s*--" | grep -viE "hovering|hovers|hover pose|hoverClock|HoverOrigin|ShovelHover|HOVER_RANGE|hover checks|hover sway|hover frame|HoverPhase|hover and the turn|hover \(studs\)|PackBob|hover.{0,4}$" ;then fail "a hover-to-collect text is left in src";else echo "ok: no hover / tap-to-collect text left in src (tutorial files excepted)";fi
if grep -rnE "Collect your (Gems|Cash)|COLLECT YOUR FLOATING" "$S" --include=*.lua;then fail "an old collect hint is left";else echo "ok: the 'Collect your Gems / Cash.' hints and 'COLLECT YOUR FLOATING REWARDS' are gone";fi
# the claim remote: one caller (the helper's callback), one server handler, validation untouched
n=$(grep -rn "CollectSaleCash" "$S" --include=*.lua | grep -c "InvokeServer\|WaitForChild" || true)
[ "$n" = 1 ] && echo "ok: the client has one use of the CollectSaleCash remote (the helper's callback)" || fail "CollectSaleCash used from $n client places"
# no timeout awards: PendingSales is written only where a receipt is made / removed by a claim; nothing there is on a timer
if grep -rn "PendingSales" "$SS" --include=*.lua | grep -E "task\.(delay|wait)|os\.(time|clock)|tick\(" ;then fail "a PendingSales line has a timer in it";else echo "ok: no PendingSales line runs on a clock (no timeout awards)";fi
# the load guard stays on line 1 of every client script I touched
for f in "$SP/EconomyClient.client.lua";do head -1 "$f" | grep -q "R152: start once the whole game has arrived" || fail "$(basename $f): line 1 is not the load guard";done
echo "ok: EconomyClient keeps the load guard on line 1"
# worlds
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/test_sale_money.luau" "$HERE/test_sale_claim_server.luau" "$OUT/cl/"
python3 "$P/R150/tests/mkbundle_sfx.py" "$OUT/cl" all-client >/dev/null
python3 - "$SS/PlayerDataService.lua" "$OUT/cl/claim_fn.luau" <<'PY'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
a=s.index('function PlayerDataService:CollectSaleCash(')
b=s.index('\nend\n',a)+5
fn=s[a:b]
assert ']==]' not in fn
open(sys.argv[2],'w',encoding='utf-8').write('return [==[\n'+fn+']==]\n')
print('cut the real CollectSaleCash (%d lines)'%fn.count('\n'))
PY
cd "$OUT/cl"
for t in test_sale_money test_sale_claim_server; do
 echo "== $t"
 timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -60;exit 1; }
 grep -v '^WARN' $t.log | tail -1
done
[ "$RC" = 0 ] || exit 1
echo "R152 sale money suites passed"
