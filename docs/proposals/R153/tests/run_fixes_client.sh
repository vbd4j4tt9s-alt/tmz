#!/bin/sh
# Usage: sh run_fixes_client.sh [scratch dir] [mutate]. R153 client bug review (docs/proposals/R153/bug_review_client.md), findings 3, 5, 6, 7, 8, 9 and 10, on the Roblox mock
# (/opt/luau/luau) with the REAL scripts of this checkout. Where each finding is tested:
#   3  the trampoline mat dipped for good when the folder was read again mid-squash   test_hub_gardens.luau   (run_nooks.sh: "re-read mid-squash")
#   5  KeeperFollow153 anchors built and moved every frame for nothing (module gone)  test_jitter_keepers / test_jitter_misc   (run_jitter.sh)
#   6  a trampoline launch seen late pulled back by MovementGuard                     test_guard_trampoline.luau   (THIS suite)
#   7  the 1.5x tab dot covered the Index biome tabs' count                           R151 test_indexbadge.luau   (run_badges.sh)
#   8  the pending ring pulsed with Reduced Motion        9  a queued hotbar press never expired / could not be cancelled   test_hotbar_real.luau   (run_hotbar.sh)
#  10  the ALMOST THERE! wiggle hid the BONUS ROLL button's ready pop                 R150 test_bonus_ui.luau   (run_bonus_ui.sh)
# This runner holds finding 6 (the server's launch allowance: HubTrampolineRules153.LaunchRise inside MovementGuard) and the static checks for all of them: the touched scripts
# compile, line 1 of every client script is still the R152 load guard (Hotbar: its Backpack line, then the guard), KeeperFollow153 is gone from src and the manifest, Config.Version
# is unchanged, no model names in the R153 files.
# "mutate" breaks a copy of the server code in four ways (no launch allowance at all; no collider / footprint rule; no cap on the rise; no once-per-cooldown rule) and expects the
# test to FAIL on each.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;BASE=${BASE:-e36b71b}
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;SP=$S/StarterPlayer/StarterPlayerScripts;INV=$REPO/docs/proposals/inventory_R113/tests;LUAU=${LUAU:-/opt/luau/luau}
mkdir -p "$OUT"
fail=0;bad() { echo "FAIL: $1";fail=1; }
echo "== static checks"
for f in "$SP/HubTrampoline153.client.lua" "$SP/BeastAnimation.client.lua" "$SP/VeiledEventClient81.client.lua" "$SP/TreadmillBonusClient.client.lua" "$SP/ChestIndex.client.lua" "$SP/Hotbar.client.lua" \
 "$S/ReplicatedStorage/HubTrampolineRules153.lua" "$S/ReplicatedStorage/NotifyBadge151.lua" "$SS/MovementGuard.lua";do
 $LUAU-compile --null "$f" >/dev/null 2>&1 || bad "$f does not compile"
done
for f in "$HERE"/test_guard_trampoline.luau;do $LUAU-compile --null "$f" >/dev/null 2>&1 || bad "$f does not compile";done
GUARD='R152: start once the whole game has arrived'
for n in HubTrampoline153 BeastAnimation VeiledEventClient81 TreadmillBonusClient ChestIndex;do
 head -1 "$SP/$n.client.lua" | grep -q "$GUARD" || bad "$n.client: line 1 is not the R152 load guard"
 [ "$(grep -c "$GUARD" "$SP/$n.client.lua")" = 1 ] || bad "$n.client: the guard must appear exactly once"
done
head -1 "$SP/Hotbar.client.lua" | grep -q "SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)" || bad "Hotbar line 1 must hide Roblox's backpack (the R152 load guard follows it)"
sed -n 2p "$SP/Hotbar.client.lua" | grep -q "$GUARD" || bad "Hotbar line 2 must be the R152 load guard"
# 5: KeeperFollow153 and its anchors are gone
[ ! -e "$S/ReplicatedStorage/KeeperFollow153.lua" ] || bad "KeeperFollow153.lua is still in src"
if grep -rn "KeeperFollow153\|_KeeperFollow153" "$S" >/dev/null 2>&1;then grep -rn "KeeperFollow153\|_KeeperFollow153" "$S" | head -3;bad "something in src still names KeeperFollow153";fi
if grep -n "Follow\.\(Drive\|Push\|Release\|Get\|Listen\)" "$SP/BeastAnimation.client.lua" "$SP/VeiledEventClient81.client.lua" "$SP/KeeperSpeedLabels.client.lua" >/dev/null 2>&1;then bad "a keeper script still drives a follow anchor";fi
# 6: MovementGuard asks the shared rule
grep -q "Tramp.LaunchRise" "$SS/MovementGuard.lua" || bad "MovementGuard does not ask HubTrampolineRules153.LaunchRise"
grep -q "local riseAllowance=18+math.max(jump,48,ceiling\*.65)\*elapsed\*1.5" "$SS/MovementGuard.lua" || bad "MovementGuard's ordinary rise allowance changed"
# 7 / 8 / 9 / 10 / 3: the fixes are in the scripts
grep -q "Badge.Overhang.Dot,true)" "$SP/ChestIndex.client.lua" || bad "the Index tab dot is not on the tab's top-left corner"
grep -q "ReducedMotionEnabled and .25" "$SP/Hotbar.client.lua" || bad "the pending ring ignores Reduced Motion"
grep -q "QUEUED_SECONDS=8" "$SP/Hotbar.client.lua" || bad "a queued hotbar press has no 8 s limit"
grep -q "cancelEffect(almostEffect)" "$SP/TreadmillBonusClient.client.lua" || bad "leaving ALMOST THERE! does not stop the wiggle"
grep -q "local rest=setmetatable" "$SP/HubTrampoline153.client.lua" || bad "the trampoline mat's rest pose is not recorded once per part"
grep -q "	ReplicatedStorage/KeeperFollow153	" "$S/MANIFEST.tsv" && bad "src/MANIFEST.tsv still lists KeeperFollow153"
[ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" 2>/dev/null | grep 'Config.Version')" = "$(grep 'Config.Version' "$SS/Config.lua")" ] || bad "Config.Version changed"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|anthrop[i]c|gp[t]-?[0-9]" "$HERE" 2>/dev/null;then bad "a model name in the R153 files";fi
BG=$SP/BackgroundMusic.client.lua
[ -z "$(git -C "$REPO" status --porcelain -- "$BG")" ] || bad "BackgroundMusic.client.lua was touched"
[ "$fail" = 0 ]
echo "ok: the touched scripts compile, line 1 of every client script is the R152 load guard (Hotbar: its Backpack line, then the guard), KeeperFollow153 is gone, the fixes are in place, Config.Version unchanged, no model names"
# --- finding 6: the server's launch allowance ----------------------------------------------------------------------------------------------------------------
guard() { # $1 = run dir, $2 = MovementGuard file, $3 = HubTrampolineRules153 file
 d=$1;mkdir -p "$d"
 cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_guard_trampoline.luau" "$d/"
 sed "s#'/home/user/tmz/src'#'$S'#" "$INV/mkbundle.py" > "$d/mkbundle.py"
 python3 "$d/mkbundle.py" "$d/rs_bundle.luau" MovementGuard="$2" HubTrampolineRules153="$3" >/dev/null
 (cd "$d" && timeout 900 $LUAU test_guard_trampoline.luau > guard.log 2>&1)
}
echo "== test_guard_trampoline (the real MovementGuard + HubTrampolineRules153)"
guard "$OUT/guard" "$SS/MovementGuard.lua" "$S/ReplicatedStorage/HubTrampolineRules153.lua" || { grep -v '^WARN' "$OUT/guard/guard.log" | tail -30;exit 1; }
grep -v '^WARN' "$OUT/guard/guard.log" | tail -1
if [ "$MODE" = mutate ];then
 echo "== mutants (each must make test_guard_trampoline fail)"
 mut() { # $1 = name, $2 = file (MovementGuard or Rules), $3 = old text, $4 = new text
  rm -rf "$OUT/mut";mkdir -p "$OUT/mut"
  cp "$SS/MovementGuard.lua" "$OUT/mut/MovementGuard.lua";cp "$S/ReplicatedStorage/HubTrampolineRules153.lua" "$OUT/mut/HubTrampolineRules153.lua"
  python3 - "$OUT/mut/$2.lua" "$3" "$4" <<'PY'
import sys
path,old,new=sys.argv[1:]
t=open(path,encoding='utf-8').read();assert t.count(old)==1,(path,old,t.count(old))
open(path,'w',encoding='utf-8').write(t.replace(old,new,1))
PY
  if guard "$OUT/mut/run" "$OUT/mut/MovementGuard.lua" "$OUT/mut/HubTrampolineRules153.lua";then echo "FAIL: mutant $1 passed the test";exit 1
  else echo "ok: mutant $1 fails ($(grep -c '^FAIL' "$OUT/mut/run/guard.log") checks)";fi
 }
 mut noallowance MovementGuard "if offset.Y>riseAllowance and not launch(c,h,r,state,now,p,elapsed)then" "if offset.Y>riseAllowance then"
 mut anywhere HubTrampolineRules153 "return dx*dx+dz*dz<=r*r and feetY>=T.Floor-.6" "return true"
 mut nocap HubTrampolineRules153 "if toFeetY>T.Top()+.35+T.Height()+T.GuardMargin then return false end" ""
 mut nocooldown HubTrampolineRules153 "if elapsed>T.GuardWindow or sinceLaunch<T.Cooldown then return false end" "if elapsed>T.GuardWindow then return false end"
fi
echo "R153 client fixes suite passed"
