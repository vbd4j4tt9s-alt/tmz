#!/bin/sh
# Usage: sh run_hudlayout_cache157.sh [scratch dir]     (NO_MUTATE=1 skips the teeth; R157_LAYOUT_BASE=<ref> = the commit before the cache, default aef609b: the step-1b differential)
# R157 review fix (performance): HudLayout.Read memoizes its search (wheelArc and the PityBars155.Place search of barsClear: 80 ms on a 640 x 360 PC window, 40 ms at 1920 x 300, 15 ms at 1280 x 320).
# On the Roblox mock (/opt/luau/luau) with the REAL HudLayout / PityBars155 / WorldStatusHud / RarePullCard of this checkout:
#  0. static  - every src script compiles at -O0 within 180 registers per function (check_compile_O0.sh); the frozen hashes hold; no model names in the files of this fix; this suite is
#               registered on line 6 of tools/tests/run_all_suites.sh
#  1. test    - test_hudlayout_cache157.luau: the cached Read is exactly a fresh computation on 46 screens x (computer, phone with its thumb controls, phone without) and the R157 layout
#               from before the cache (a fingerprint per case); the same screen again is the same table, runs no search, costs microseconds and allocates nothing; every input is in
#               the key; a small ring; the answer is frozen and holds none of the caller's tables; the real WorldStatusHud and RarePullCard.SkipBoxes run the search once
#  1b. same   - the differential: HudLayout as it was before the cache (git show $R157_LAYOUT_BASE) and now give the same fingerprint on every phone case (R158, on purpose: not on the computer
#               cases - a computer's layout is the scaled 1920 x 1080 arrangement now; skipped when that commit is not here)
#  2. teeth   - each break of the cache must make the test fail
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
LB=${R157_LAYOUT_BASE:-aef609b}
T=$REPO/tools/tests;P=$REPO/docs/proposals;RSD=$REPO/src/ReplicatedStorage;INV=$P/inventory_R113/tests
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 && echo "ok: $(tail -2 "$OUT/o0.log" | head -1)" || { tail -5 "$OUT/o0.log";fail "the -O0 compile check"; }
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) && echo "ok: the frozen files (R151 frozen.sha256) match" || fail "a frozen file changed"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE/test_hudlayout_cache157.luau" "$HERE/run_hudlayout_cache157.sh" "$RSD/HudLayout.lua" "$P/R157/hud157.md" 2>/dev/null | grep -v "^Binary";then fail "a model name in the files of this fix";else echo "ok: no model names in the files of this fix";fi
sed -n 6p "$T/run_all_suites.sh" | grep -q "docs/proposals/R157/tests/run_hudlayout_cache157.sh" && echo "ok: registered on line 6 of tools/tests/run_all_suites.sh" || fail "run_hudlayout_cache157.sh is not on line 6 of tools/tests/run_all_suites.sh"
# the tests -------------------------------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [Name=path ...]
 d=$1;shift;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_hudlayout_cache157.luau" "$d/"
 python3 "$INV/mkbundle.py" "$d/rs_bundle.luau" "$@" > /dev/null
}
echo "== 1. test_hudlayout_cache157 (the cache)"
build "$OUT/w"
( cd "$OUT/w" && timeout 1200 /opt/luau/luau test_hudlayout_cache157.luau > cache.log 2>&1 ) && echo "ok: $(grep -v '^WARN' "$OUT/w/cache.log" | tail -1)" || { grep -v '^WARN' "$OUT/w/cache.log" | cut -c1-300 | tail -30;fail "test_hudlayout_cache157"; }
grep '^COST\|^(' "$OUT/w/cache.log" | cut -c1-400
echo "== 1b. the layout as it was before the cache ($LB) and now: the same fingerprints"
if git -C "$REPO" cat-file -e "$LB:src/ReplicatedStorage/HudLayout.lua" 2>/dev/null;then
 git -C "$REPO" show "$LB:src/ReplicatedStorage/HudLayout.lua" > "$OUT/HudLayout_before.lua"
 if grep -q "^function L.Read" "$OUT/HudLayout_before.lua" && ! grep -q "CacheSize" "$OUT/HudLayout_before.lua";then
  build "$OUT/wb" "HudLayout=$OUT/HudLayout_before.lua"
  ( cd "$OUT/wb" && timeout 1200 /opt/luau/luau test_hudlayout_cache157.luau -a golden 2>&1 | grep '^GOLDEN' | grep -v ':pc' > golden.txt )
  ( cd "$OUT/w" && timeout 1200 /opt/luau/luau test_hudlayout_cache157.luau -a golden 2>&1 | grep '^GOLDEN' | grep -v ':pc' > golden.txt )
  n=$(wc -l < "$OUT/w/golden.txt")
  [ "$n" -ge 90 ] && cmp -s "$OUT/wb/golden.txt" "$OUT/w/golden.txt" && echo "ok: $n phone cases, HudLayout before the cache and now give the same fingerprint on every one" || fail "the phone layout differs from the one before the cache ($n cases)"
  rm -rf "$OUT/wb"
 else echo "skipped: $LB's HudLayout is not the one before the cache";fi
else echo "skipped: commit $LB is not in this clone";fi
# teeth -------------------------------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 2. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M"
 mutate(){ # name old new
  name=$1;shift
  python3 - "$RSD/HudLayout.lua" "$M/$name.lua" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f,out=sys.argv[1:3];rest=sys.argv[3:];pairs=list(zip(rest[0::2],rest[1::2]))
s=open(f,encoding='utf-8').read()
for old,new in pairs:
    assert s.count(old)==1,old
    s=s.replace(old,new,1)
open(out,'w',encoding='utf-8').write(s)
PY
  build "$M/w_$name" "HudLayout=$M/$name.lua"
  if ( cd "$M/w_$name" && timeout 900 /opt/luau/luau test_hudlayout_cache157.luau > run.log 2>&1 );then fail "mutation $name was NOT noticed";else echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w_$name/run.log") failing checks)";fi
  rm -rf "$M/w_$name"
 }
 mutate never_cached " if hit then return hit.Layout end" " if false then return hit.Layout end"
 mutate no_height "k[1],k[2],k[3]=w,h,touch" "k[1],k[2],k[3]=w,0,touch"
 mutate no_width "k[1],k[2],k[3]=w,h,touch" "k[1],k[2],k[3]=0,h,touch"
 mutate no_jump_x "k[8],k[9],k[10],k[11]=jump.X,jump.Y,jump.W,jump.H" "k[8],k[9],k[10],k[11]=0,jump.Y,jump.W,jump.H"
 mutate no_stick_y "k[4],k[5],k[6],k[7]=stick.X,stick.Y,stick.W,stick.H" "k[4],k[5],k[6],k[7]=stick.X,0,stick.W,stick.H"
 mutate no_stick_w "k[4],k[5],k[6],k[7]=stick.X,stick.Y,stick.W,stick.H" "k[4],k[5],k[6],k[7]=stick.X,stick.Y,0,stick.H"
 mutate no_name_width "k[12],k[13],k[14],k[15],k[16]=L.NameBand,L.NameWidth,L.NameClear,L.PityBarHeight,L.PityGap" "k[12],k[13],k[14],k[15],k[16]=L.NameBand,0,L.NameClear,L.PityBarHeight,L.PityGap"
 mutate no_bar_height "k[12],k[13],k[14],k[15],k[16]=L.NameBand,L.NameWidth,L.NameClear,L.PityBarHeight,L.PityGap" "k[12],k[13],k[14],k[15],k[16]=L.NameBand,L.NameWidth,L.NameClear,false,L.PityGap"
 mutate not_frozen "local m=freeze(readLayout(" "local m=(readLayout("
 mutate keeps_callers_rects "local function rectOf(r)return r and{X=r.X,Y=r.Y,W=r.W,H=r.H}or nil end" "local function rectOf(r)return r end"
 mutate unbounded "cacheAt=cacheAt%CacheSize+1;" "cacheAt=cacheAt+1;"
 mutate minus_zero "if x~=y or(x==0 and 1/x~=1/y)then return false end" "if x~=y then return false end"
 mutate no_floor " local w,h=math.max(240,view.X),math.max(150,view.Y)
 touch=touch and true or false" " local w,h=view.X,view.Y
 touch=touch and true or false"
 mutate shared_probe " local key=table.clone(k)" " local key=k"
 mutate controls_on_computer "  k[4],k[5],k[6],k[7],k[8],k[9],k[10],k[11]=false,false,false,false,false,false,false,false" "  k[4],k[5],k[6],k[7],k[8],k[9],k[10],k[11]=controls and controls.Joystick or false,false,false,false,false,false,false,false"
fi
[ $RC = 0 ] && echo "R157 HUD layout cache: ALL PASS" || echo "R157 HUD layout cache: FAIL"
exit $RC
