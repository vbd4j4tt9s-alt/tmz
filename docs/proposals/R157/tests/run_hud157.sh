#!/bin/sh
# Usage: sh run_hud157.sh [scratch dir]     (NO_MUTATE=1 skips the teeth; R157_BASE=<ref> = the release R157 is built on, default c432356: R156; R157_HUD=<ref> = the HUD merge, default fae6e8c)
# R157 HUD: the three owner-approved R156 previews built together - the pity bars v2 (8 / 6 px over the slots, the clover, shade 1 "Fresh", the name rows above the bars),
# the reveal fixes (SKIP only for Secret / Cosmic / King and in the corner of a story scene, the card fitted between BASE / TRACK and the bars, the collect hint under the name)
# and DAILY / INVITE in the menu wheel (the five-option half circle, the MENU button's "!", BASE / TRACK alone in the top bar row). On the Roblox mock (/opt/luau/luau):
#  0. static  - every src script compiles at -O0; Hotbar's main chunk is still at 174 of the 180 registers (no top-level local added) and its lines 1 / 2 are the load guards;
#               line 1 of every changed client script is unchanged since the base; the files other branches own are untouched (BackgroundMusic, BiomeMood, Config.lua,
#               TitleScreen104 / the title screen, the Bag's look: InventoryPanel155 / GardenMenuStyle / DiscardDialog155); the frozen hashes hold; no new player-visible
#               words with "u" / "ur"; no model names in the R157 files; the suite is registered in tools/tests/run_all_suites.sh; the speed popups are a world-space
#               BillboardGui (drawn under the MENU button: R153's popup test counts a moved-up MENU button as an info row)
#  1. test    - test_hud157.luau: the layout half (bars, SKIP, the card, the wheel, the overlaps on the R155 36 screens + the previews' sets)
#  2. test    - test_hud157_client.luau: the real wheel / DailyRewardsClient / TravelButtons / Hotbar / PityBars155 (options, badges, the "!", gamepad links, the INVITE hint and
#               chip, the name rows over the real bars)
#  3. fit     - the R156 preview's check_fit156.luau, re-run on the final layout (the card's band ends over the NEW bars)
#  4. teeth   - each break must make a test fail
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R157_BASE:-c432356};HUD=${R157_HUD:-fae6e8c}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;RSD=$S/ReplicatedStorage;C=$S/StarterPlayer/StarterPlayerScripts;INV=$P/inventory_R113/tests
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static (since $BASE)"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 && echo "ok: $(tail -2 "$OUT/o0.log" | head -1)" || { tail -5 "$OUT/o0.log";fail "the -O0 compile check"; }
peak=$(/opt/luau/luau-compile -O0 -g2 --text "$C/Hotbar.client.lua" 2>/dev/null | awk '/^Function [0-9]+ \(/{main=($0 ~ /\(\?\?\)/)} main && /^local [0-9]+ \(.*\): reg [0-9]+,/{s=$0;sub(/.*\): reg /,"",s);sub(/,.*/,"",s);if(s+1>m)m=s+1} END{print m+0}')
[ "$peak" -le 174 ] && echo "ok: Hotbar's main chunk uses $peak local registers at -O0 (174 before R157: no top-level local added; limit 180)" || fail "Hotbar's main chunk uses $peak local registers (was 174)"
head -2 "$C/Hotbar.client.lua" > "$OUT/hb_now.txt";git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" | head -2 > "$OUT/hb_base.txt"
cmp -s "$OUT/hb_now.txt" "$OUT/hb_base.txt" && echo "ok: Hotbar's lines 1 / 2 (the load guards) are as they were" || fail "Hotbar's lines 1 / 2 changed"
n=0
for f in $(git -C "$REPO" diff --name-only "$BASE" -- 'src/StarterPlayer/StarterPlayerScripts/*.client.lua');do
 n=$((n+1))
 if git -C "$REPO" cat-file -e "$BASE:$f" 2>/dev/null;then [ "$(head -1 "$REPO/$f")" = "$(git -C "$REPO" show "$BASE:$f" | head -1)" ] || fail "$f: line 1 (the load guard) changed"
 else head -1 "$REPO/$f" | grep -q "^do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end" || fail "$f (new in R157): line 1 is not the R152 load guard";fi
done
echo "ok: line 1 of the $n changed client scripts is unchanged (the load guard)"
for f in src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua src/ReplicatedStorage/BiomeMood.lua src/ServerScriptService/ChestChaseServer/Config.lua src/ReplicatedStorage/TitleScreen104.lua \
 src/ReplicatedFirst/TitleScreen.client.lua src/ReplicatedStorage/InventoryPanel155.lua src/ReplicatedStorage/GardenMenuStyle.lua src/ReplicatedStorage/DiscardDialog155.lua src/MANIFEST.tsv;do
 git -C "$REPO" diff --quiet "$HUD^" "$HUD" -- "$f" || fail "$f changed in the HUD merge $HUD (another branch owns it / no new script)"
done
echo "ok: the HUD merge ($HUD) left BackgroundMusic, BiomeMood, Config.lua, the title screen (TitleScreen104), the Bag's look and the manifest alone"
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) && echo "ok: the frozen files (R151 frozen.sha256) match" || fail "a frozen file changed"
# the new player-visible words (string literals on the lines R157 adds to src): "you" / "your" in full, never "u" / "ur"
git -C "$REPO" diff -U0 "$BASE" -- src | grep '^+' | grep -v '^+++' | sed 's/--.*$//' > "$OUT/added.txt"
python3 - "$OUT/added.txt" <<'PY' || RC=1
import re,sys
bad=[]
for line in open(sys.argv[1],encoding='utf-8'):
    for lit in re.findall(r"'((?:\\.|[^'\\])*)'|\"((?:\\.|[^\"\\])*)\"",line):
        s=lit[0] or lit[1]
        if re.search(r"(?<![A-Za-z])(u|ur|U|UR|Ur)(?![A-Za-z])",s):bad.append(s)
if bad:print('FAIL: new words with "u" / "ur":',bad);sys.exit(1)
print('ok: no new player-visible words with "u" / "ur" (every string R157 adds to src)')
PY
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$P/R157" 2>/dev/null | grep -v "^Binary";then fail "a model name in the R157 files";else echo "ok: no model names in the R157 files";fi
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R157/tests/run_hud157.sh[; ]" && echo "ok: registered on line 6 of tools/tests/run_all_suites.sh" || fail "run_hud157.sh is not on line 6 of tools/tests/run_all_suites.sh"
grep -q 'Instance.new("BillboardGui")' "$C/SpeedGainPopup.client.lua" && grep -q "gui.Name='GardenNavigation'" "$RSD/HudLayout.lua" && echo "ok: the speed popups are a world-space BillboardGui, the MENU button a ScreenGui (drawn above them)" || fail "the speed popups / the MENU button changed kind"
# the tests -------------------------------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [Name=path ...]
 d=$1;shift;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_hud157.luau" "$HERE/test_hud157_client.luau" "$P/R156/preview/check_fit156.luau" "$d/"
 python3 "$INV/mkbundle.py" "$d/rs_bundle.luau" TravelButtons="$C/TravelButtons.client.lua" DailyRewardsClient="$C/DailyRewardsClient.client.lua" Hotbar="$C/Hotbar.client.lua" \
  ChestIndex="$C/ChestIndex.client.lua" RarePullCinematic="$RSD/RarePullCinematic.lua" "$@" > /dev/null
}
runall(){ # dir -> 0 when all pass
 ( cd "$1" && timeout 1200 /opt/luau/luau test_hud157.luau > layout.log 2>&1 ) || return 1
 ( cd "$1" && timeout 1200 /opt/luau/luau test_hud157_client.luau > client.log 2>&1 ) || return 1
 ( cd "$1" && timeout 600 /opt/luau/luau check_fit156.luau > fit.log 2>&1 ) || return 1
 return 0
}
build "$OUT/w"
echo "== 1. test_hud157 (layout)"
( cd "$OUT/w" && timeout 1200 /opt/luau/luau test_hud157.luau > layout.log 2>&1 ) && echo "ok: $(grep -v '^WARN' "$OUT/w/layout.log" | tail -1)" || { grep -v '^WARN\|^SCREEN\|^FIT\|^NAMEROWS' "$OUT/w/layout.log" | tail -30;fail "test_hud157"; }
grep '^NAMEROWS' "$OUT/w/layout.log"
grep '^SCREEN\|^FIT' "$OUT/w/layout.log" > "$OUT/screens.txt";echo "(every screen's bars / wheel / BONUS / SKIP / card: $OUT/screens.txt)"
echo "== 2. test_hud157_client (the real scripts)"
( cd "$OUT/w" && timeout 1200 /opt/luau/luau test_hud157_client.luau > client.log 2>&1 ) && echo "ok: $(grep -v '^WARN' "$OUT/w/client.log" | tail -1)" || { grep -v '^WARN' "$OUT/w/client.log" | tail -30;fail "test_hud157_client"; }
echo "== 3. check_fit156 (the R156 preview's fit check) on the final layout"
( cd "$OUT/w" && timeout 600 /opt/luau/luau check_fit156.luau > fit.log 2>&1 ) && echo "ok: $(tail -1 "$OUT/w/fit.log" | tr '\t' ' ') (19 screen sizes x ranks 1-8)" || { tail -20 "$OUT/w/fit.log";fail "check_fit156"; }
# teeth -------------------------------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 4. teeth: each break must make a test fail"
 M=$OUT/mut;mkdir -p "$M"
 mutate(){ # name file old new
  name=$1;file=$2;shift 2
  python3 - "$file" "$M/$name.lua" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f,out=sys.argv[1:3];rest=sys.argv[3:];pairs=list(zip(rest[0::2],rest[1::2]))
s=open(f,encoding='utf-8').read()
for old,new in pairs:
    assert s.count(old)==1,old
    s=s.replace(old,new,1)
open(out,'w',encoding='utf-8').write(s)
PY
  mod=$(basename "$file" .lua);mod=${mod%.client}
  build "$M/w_$name" "$mod=$M/$name.lua"
  if runall "$M/w_$name";then fail "mutation $name was NOT noticed";else echo "ok: $name -> fails ($(cat "$M/w_$name/layout.log" "$M/w_$name/client.log" "$M/w_$name/fit.log" 2>/dev/null | grep -c '^FAIL\|!!') failing checks)";fi
  rm -rf "$M/w_$name"
 }
 mutate gap_12 "$RSD/HudLayout.lua" "return phone and(barH<=16 and 5 or 6)or 8 end" "return phone and(barH<=16 and 5 or 6)or 12 end"
 mutate deep_shade "$RSD/PackPity155.lua" "Normal={Light=RGB(110,215,70),Deep=RGB(10,120,36)," "Normal={Light=RGB(80,200,120),Deep=RGB(6,100,64),"
 mutate purple_heart "$RSD/PackPity155.lua" "return group=='Event'and'⭐ LUCKY EVENT PACK! x1.5 luck on this one!'" "return group=='Event'and'💜 LUCKY EVENT PACK! x1.5 luck on this one!'"
 mutate names_shown_360 "$RSD/HudLayout.lua" "and not(portrait and w<370 and h<780)" ""
 mutate rows_below_bars "$C/Hotbar.client.lua" "local row=tonumber(pg:GetAttribute('PityBarsRow'))or 2;" "local row=2;"
 mutate common_skip "$RSD/RarePullRules.lua" "  Letterbox=tier.Letterbox==true,Quick=quick==true}" "  Letterbox=tier.Letterbox==true,Quick=quick==true,SkipFrom=L.CardSkipFrom}"
 mutate skip_hud_boxes "$RSD/RarePullCard.lua" "local boxes=self.HudHidden and Card.ControlBoxes(controls)or Card.SkipBoxes(w,h,touch,controls)" "local boxes=Card.SkipBoxes(w,h,touch,controls)"
 mutate skip_margin12 "$RSD/RarePullCard.lua" " local margin,pad=14,8" " local margin,pad=12,8"
 mutate band_old_bars "$RSD/RarePullCard.lua" "if okB and Bars then local okR,box=pcall(Bars.Reserved,w,h,m,nil);if okR and type(box)=='table'then lowest=math.min(lowest,box.Y)end end" ""
 mutate hint_corner "$RSD/RarePullCard.lua" "  self.Scale(h,'Position',.5,self.Layout.Hint.Y-(self.Lift or 0))" "  self.Scale(h,'Position',.5,.97)"
 mutate wheel_three "$RSD/HudLayout.lua" "assert(index>=1 and index<=WheelSlots and index%1==0,'Invalid navigation slot')" "assert(index>=1 and index<=3 and index%1==0,'Invalid navigation slot')"
 mutate no_links "$RSD/HudLayout.lua" "  links();boostChip()" "  boostChip()"
 mutate no_alert "$RSD/HudLayout.lua" "  local total=(tonumber(pg:GetAttribute('MenuAlertIndex'))or 0)+(tonumber(pg:GetAttribute('MenuAlertDaily'))or 0)" "  local total=tonumber(pg:GetAttribute('MenuAlertIndex'))or 0"
 mutate hint_in_option "$C/DailyRewardsClient.client.lua" "local inviteHint=text(gui,'InviteHint'" "local inviteHint=text(inviteButton,'InviteHint'"
 mutate travel_back "$RSD/HudLayout.lua" " return {Slots=slots,SlotSize=side," " return {Travel={X=70,Y=8,W=112,H=52},Slots=slots,SlotSize=side,"
 mutate daily_badge_r155 "$C/DailyRewardsClient.client.lua" "Badge.Make(dailyButton,'RewardBadge',Badge.Sizes.Count,Badge.Overhang.Count)" "Badge.Make(dailyButton,'RewardBadge',24,10,false,0)"
 mutate no_chip_copy "$C/DailyRewardsClient.client.lua" " pg:SetAttribute('MenuFriendBoost',chip.Visible and chip.Text or nil)" ""
 mutate tag_old_layout "$RSD/PityBars155.lua" "B.TagPlace(st.Kind,phone,view.X,view.Y,B.CardRows(s.TagGui.Parent,view.Y))" "B.TagPlace(st.Kind,phone,view.X,view.Y)"
 mutate wallet_under_wheel "$RSD/HudLayout.lua" "   if compactHeight>=16 then walletH=math.min(walletH,compactHeight);gap=2;walletStack=walletH*3+gap*2;speedY=h-bottom-walletStack end" ""
 mutate skip_no_climb "$RSD/RarePullCard.lua" " for y=math.floor(h*.45)-4,math.floor(h*.2),-4 do for x=x0,math.floor(w*.5),-4 do if clear(x,y)then return x,y,bw,bh end end end" ""
 mutate fit_overflows "$RSD/RarePullRules.lua" "  for key,v in pairs(s)do s[key]=v*f end" ""
 mutate fallback_r156 "$RSD/HudLayout.lua" "    if wheelClear(o,hub,optionSize)and wheelFree(o,y,hub,optionSize,avoid)then r,rx,fan,done=test,x,c,true;break end" "    r,rx,fan,done=test,test<72 and WheelMaxX or test,.7071,true;break"
fi
[ $RC = 0 ] && echo "R157 HUD: ALL PASS" || echo "R157 HUD: FAIL"
exit $RC
