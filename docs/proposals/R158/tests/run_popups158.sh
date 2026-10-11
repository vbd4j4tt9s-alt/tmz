#!/bin/sh
# Usage: sh run_popups158.sh [scratch dir] [mutate]
# R158 (owner: "increase the size of the speed popups as they are too small right now"): the treadmill speed popups are 1.5x bigger, on the Roblox mock (/opt/luau/luau) with the REAL SpeedPopupStyle,
# HudLayout and SpeedGainPopup client of this checkout:
#  static      - the changed scripts and the tests compile at -O0 (Roblox's 200-locals limit shows only there); line 1 of every client script is still the R152 load guard; Config.lua is the
#                frozen one (Config.Version untouched); the client asks Style.Layout once, in spawnPopup, never per frame (check_layout_site158.py); no model names in the R158 popup files
#  1. test_popups158   - the numbers (1.5x R154's sizes / fan / field / outline; the motion, timing, rate, caps, colours and the zoom's distances as they were), the size share of a small screen, the
#                        phone rule at 17 screens now vs R154 (inside the screen, clear of the HUD, the balance rows, the pile-up), the face, the zoom and the field at the 1.3 cap, no allocation, the
#                        real client on 7 screens
#  2. alloc            - the real client's heap growth over a stream, the build this round started from (BASE158) vs this checkout: no more (skipped, with a note, when that commit is not in this clone)
#  3. R154 / R153 / R151 popup suites, which follow the new numbers (docs/proposals/R154/tests/test_popups154.luau, R153 test_popups153.luau, R151 run_speed_popups.sh)
# "mutate" breaks a copy of the style / client in the ways of mutate_popups158.py and expects a failing suite each time.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2
S=$REPO/src;P=$REPO/docs/proposals;T=$REPO/tools/tests
LUAU=${LUAU:-/opt/luau/luau}
BASE158=${BASE158:-93ce597};BASE152=${BASE152:-e36b71b} # (BASE158: the commit this round started from: R157b + the R158 pyramid)
mkdir -p "$OUT"
fail(){ echo "FAIL: $1";exit 1; }
CLIENT=$S/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua;STYLE=$S/ReplicatedStorage/SpeedPopupStyle.lua
echo "== static"
for f in "$STYLE" "$CLIENT";do /opt/luau/luau-compile -O0 --null "$f" >/dev/null 2>&1 || fail "$f does not compile at -O0";done
for f in "$HERE"/test_*.luau "$HERE"/alloc_stream158.luau "$P"/R154/tests/test_popups154.luau "$P"/R153/tests/test_popups153.luau "$P"/R151/tests/test_speed_popups_style.luau "$P"/R151/tests/test_speed_popups_client.luau;do
 /opt/luau/luau-compile -O0 --null "$f" >/dev/null 2>&1 || fail "$f does not compile at -O0"
done
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 || { cat "$OUT/guard.log";fail "the R152 load guard (line 1 of every client script)"; }
want=$(grep ' src/ServerScriptService/ChestChaseServer/Config.lua$' "$P/R151/tests/frozen.sha256" | cut -d' ' -f1);have=$(sha256sum "$S/ServerScriptService/ChestChaseServer/Config.lua" | cut -d' ' -f1)
[ -n "$want" ] && [ "$want" = "$have" ] || fail "Config.lua is not the frozen one (Config.Version must stay as it is: the release step is not this round's)"
python3 "$HERE/check_layout_site158.py" "$CLIENT" || fail "the client's call of Style.Layout"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|anthrop[i]c|gp[t]-?[0-9]" "$HERE"/test_popups158.luau "$HERE"/alloc_stream158.luau "$HERE"/run_popups158.sh "$HERE"/mutate_popups158.py "$HERE"/check_layout_site158.py "$P/R158/speed_popups158.md" "$P/R158/preview/popups_scene158.luau" "$P/R158/preview/run_popups_preview158.sh" "$P/R158/preview/compose_popups158.py" 2>/dev/null;then fail "a model name in the R158 speed popup files";fi
echo "ok: the scripts and tests compile at -O0; line 1 of every client script is still the R152 load guard; Config.lua is the frozen one; the client asks Style.Layout once (spawnPopup); no model names"

echo "== 1. test_popups158 (the REAL style, HudLayout and client)"
D=$OUT/popups158;mkdir -p "$D"
cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R151/tests/speed_popups_world.luau" "$HERE/test_popups158.luau" "$D/"
python3 "$P/R151/tests/mkbundle_speed_popups.py" "$D" > /dev/null
(cd "$D" && timeout 900 $LUAU test_popups158.luau > popups158.log 2>&1) || { grep -v '^WARN' "$D/popups158.log" | tail -40;fail "test_popups158"; }
grep -v '^WARN' "$D/popups158.log" | grep -E "^popups R158:|checks"
cp "$D/popups158.log" "$OUT/popups158_full.log"

echo "== 2. no per-frame allocation added (heap growth of the real client over a stream, before this round vs now)"
if git -C "$REPO" cat-file -e "$BASE158" 2>/dev/null;then
 A=$OUT/alloc;mkdir -p "$A/new" "$A/old"
 git -C "$REPO" show "$BASE158:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$A/StyleOld.lua"
 git -C "$REPO" show "$BASE158:src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua" > "$A/PopupOld.lua"
 for w in new old;do
  cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R151/tests/speed_popups_world.luau" "$HERE/alloc_stream158.luau" "$A/$w/"
 done
 python3 "$P/R151/tests/mkbundle_speed_popups.py" "$A/new" > /dev/null
 python3 "$P/R151/tests/mkbundle_speed_popups.py" "$A/old" SpeedPopupStyle="$A/StyleOld.lua" SpeedGainPopup="$A/PopupOld.lua" > /dev/null
 (cd "$A/new" && $LUAU alloc_stream158.luau 2>&1 | grep '^ALLOC ' > "$A/new.txt") || fail "alloc (this checkout)"
 (cd "$A/old" && $LUAU alloc_stream158.luau 2>&1 | grep '^ALLOC ' > "$A/old.txt") || fail "alloc (R154)"
 python3 - "$A/old.txt" "$A/new.txt" <<'EOF' || fail "the popups allocate more than before this round over a stream"
import sys
old = {l.split()[1]: float(l.split()[2]) for l in open(sys.argv[1])}
new = {l.split()[1]: float(l.split()[2]) for l in open(sys.argv[2])}
assert old and set(old) == set(new), (old, new)
ok = True
for k in old:
    allowed = old[k] * 1.005 + 4
    print('%s: heap growth over 900 frames %.1f KB now, %.1f KB before (allowed %.1f)' % (k, new[k], old[k], allowed))
    if new[k] > allowed:
        ok = False
sys.exit(0 if ok else 1)
EOF
else echo "(no $BASE158 in this clone: the allocation comparison with the build this round started from was skipped)";fi

echo "== 3. the R154 / R153 / R151 popup suites (sizes, fan, zoom, phone rule, pool, belt arrows block)"
D4=$OUT/popups154;mkdir -p "$D4"
cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R151/tests/speed_popups_world.luau" "$P/R154/tests/test_popups154.luau" "$D4/"
python3 "$P/R151/tests/mkbundle_speed_popups.py" "$D4" > /dev/null
(cd "$D4" && timeout 900 $LUAU test_popups154.luau > popups154.log 2>&1) || { grep -v '^WARN' "$D4/popups154.log" | tail -30;fail "test_popups154"; }
grep -v '^WARN' "$D4/popups154.log" | tail -1
if git -C "$REPO" cat-file -e "$BASE152" 2>/dev/null;then
 D3=$OUT/popups153;mkdir -p "$D3"
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R153/tests/test_popups153.luau" "$D3/"
 git -C "$REPO" show "$BASE152:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$D3/ref_style.luau"
 python3 "$P/R149/tests/zfight_bundle.py" "$S" "$D3" > /dev/null
 (cd "$D3" && $LUAU test_popups153.luau > popups153.log 2>&1) || { grep -v '^WARN' "$D3/popups153.log" | tail -30;fail "test_popups153"; }
 grep -v '^WARN' "$D3/popups153.log" | tail -1
else echo "(no $BASE152 in this clone: the R153 popup test, which compares with the R152 style, was skipped)";fi
sh "$P/R151/tests/run_speed_popups.sh" "$OUT/speed_popups" > "$OUT/speed_popups.log" 2>&1 || { tail -30 "$OUT/speed_popups.log";fail "R151 speed popups"; }
grep -E "checks|passed" "$OUT/speed_popups.log" | tail -3

if [ "$MODE" = "mutate" ];then
 echo "== mutations: the suites that guard each must fail on a broken copy"
 python3 "$HERE/mutate_popups158.py" "$OUT/mut"
fi
echo "all R158 speed popup checks passed"
