#!/bin/sh
# Usage: sh run_hud158.sh [scratch dir]     (NO_MUTATE=1 skips the teeth; R158_BASE=<ref> = the commit before the PC rework, default c0af9d6: the touch fingerprints were taken from it)
# R158 PC HUD lock (owner, 10 Oct: "this should be the absolute layout of gui for all devices throughout ... except for mobile which the layout is currently ok and frozen. menu can
# also be higher"; "Menu should sit at A"; "make sure menu size is not too small and somewhat consistent with the original sizes"). On the Roblox mock (/opt/luau/luau) with the REAL scripts:
#  0. static  - every src script compiles at -O0 within 180 registers; Hotbar's main chunk is still at 174 of 180 (no top-level local added) and its lines 1 / 2 (the load guards) are as they
#               were; line 1 of every changed client script is unchanged; Config.lua is untouched; the frozen hashes hold (R151's list, R150's TreadmillBonusRules); no model names in the R158 files;
#               this suite is registered on line 6 of tools/tests/run_all_suites.sh
#  1. touch   - touch_lock158.sh: every touch screen (phones and tablets, landscape and portrait, with insets: 25 screens) gives the byte-for-byte HudLayout / HudBoxes / GUI trees of the real
#               Hotbar, wallet, status HUD, pity bars, wheel, DAILY and travel scripts / pity, BONUS ROLL, SKIP, card band and tutorial numbers it gave before the PC rework (fingerprints
#               taken from the base commit)
#  2. pc      - pc_hud158.sh: the computer HUD on 14 windows (the owner's 1920x1080, 1366x768, 1280x720, 1024x768, 800x600 and 9 more): scale min(1, w/1920, h/720), the same arrangement in HUD px,
#               every real GUI object where HudLayout says, MENU a third of the way down at max(scale, 85%), nothing overlapping with the wheel open (the five options, the balances, the
#               hotbar and name rows, the bars, the status stack, BONUS ROLL, the SKIP pill, BASE / TRACK, Roblox's top-left buttons, the friend chip), the badges inside their groups, the tutorial's
#               boxes; fingerprints of the five owner windows
#               R158 review follow-ups (section 7 of the PC test): every readable-text minimum (slot names 7, the held item's name 8, the bars' words 8) holds in REAL px under the HUD
#               scale, the short words where the full ones do not fit the real bar; BONUS ROLL 7 px over the bars at every window; a menu 12+ real px over the slots; the SKIP
#               corner's 80 px is real; replacing HudLayout.PcScales changes no layout; B.Extent has three parameters
#  3. teeth   - each break must make the touch or the PC test fail
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R158_BASE:-c0af9d6}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;RSD=$S/ReplicatedStorage;C=$S/StarterPlayer/StarterPlayerScripts
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static (since $BASE)"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 && echo "ok: $(tail -2 "$OUT/o0.log" | head -1)" || { tail -5 "$OUT/o0.log";fail "the -O0 compile check"; }
peak=$(/opt/luau/luau-compile -O0 -g2 --text "$C/Hotbar.client.lua" 2>/dev/null | awk '/^Function [0-9]+ \(/{main=($0 ~ /\(\?\?\)/)} main && /^local [0-9]+ \(.*\): reg [0-9]+,/{s=$0;sub(/.*\): reg /,"",s);sub(/,.*/,"",s);if(s+1>m)m=s+1} END{print m+0}')
[ "$peak" -le 174 ] && echo "ok: Hotbar's main chunk uses $peak local registers at -O0 (at most 174: no top-level local added; limit 180)" || fail "Hotbar's main chunk uses $peak local registers (was 174)"
if git -C "$REPO" cat-file -e "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" 2>/dev/null;then
 head -2 "$C/Hotbar.client.lua" > "$OUT/hb_now.txt";git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" | head -2 > "$OUT/hb_base.txt"
 cmp -s "$OUT/hb_now.txt" "$OUT/hb_base.txt" && echo "ok: Hotbar's lines 1 / 2 (the load guards) are as they were" || fail "Hotbar's lines 1 / 2 changed"
 n=0
 for f in $(git -C "$REPO" diff --name-only "$BASE" -- 'src/StarterPlayer/StarterPlayerScripts/*.client.lua');do
  n=$((n+1))
  [ "$(head -1 "$REPO/$f")" = "$(git -C "$REPO" show "$BASE:$f" | head -1)" ] || fail "$f: line 1 (the load guard) changed"
 done
 echo "ok: line 1 of the $n changed client scripts is unchanged (the load guard)"
 cfgnorm(){ sed "s/Config.Version='V150 R1[0-9a-z]*'/Config.Version='V150 R1xx'/"; } # (every release bumps the Version line; nothing else in Config may change)
 git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | cfgnorm > "$OUT/cfg_base.txt"
 cfgnorm < "$REPO/src/ServerScriptService/ChestChaseServer/Config.lua" | cmp -s - "$OUT/cfg_base.txt" && echo "ok: Config.lua is untouched (apart from the release's Version line)" || fail "Config.lua changed since $BASE (beyond the Version line)"
 git -C "$REPO" diff --quiet "$BASE" -- src/ReplicatedStorage/TreadmillBonusRules.lua && echo "ok: TreadmillBonusRules (frozen by R150) is untouched" || fail "TreadmillBonusRules changed since $BASE"
else echo "skipped: commit $BASE is not in this clone (the load guard / Config checks)";fi
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) && echo "ok: the frozen files (R151 frozen.sha256) match" || fail "a frozen file changed"
(cd "$REPO" && grep -v '^#' "$P/R150/tests/frozen.sha256" | sha256sum -c --quiet -) && echo "ok: the frozen files (R150 frozen.sha256: TreadmillBonusRules / Service) match" || fail "a R150 frozen file changed"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$P/R158" --include=*.md --include=*.sh --include=*.luau --include=*.py --include=*.txt 2>/dev/null;then fail "a model name in the R158 files";else echo "ok: no model names in the R158 files";fi
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R158/tests/run_hud158.sh[; ]" && echo "ok: registered on line 6 of tools/tests/run_all_suites.sh" || fail "run_hud158.sh is not on line 6 of tools/tests/run_all_suites.sh"
grep -q "Layout.RulesView(m)" "$C/TreadmillBonusClient.client.lua" && echo "ok: BONUS ROLL's fallback (no PityBars155) asks the rules through HudLayout.RulesView" || fail "TreadmillBonusClient's fallback does not use HudLayout.RulesView"
echo "== 1. touch lock: every phone and tablet as before the PC rework"
sh "$HERE/touch_lock158.sh" "$OUT/touch" > "$OUT/touch.log" 2>&1 && echo "ok: $(tail -1 "$OUT/touch.log")" || { tail -20 "$OUT/touch.log";fail "the touch lock"; }
echo "== 2. the PC HUD on 14 windows"
sh "$HERE/pc_hud158.sh" "$OUT/pc" > "$OUT/pc.log" 2>&1 && echo "ok: $(tail -1 "$OUT/pc.log")" || { tail -20 "$OUT/pc.log";fail "the PC HUD"; }
grep '^PC ' "$OUT/pc.log" | sed -n 1,5p | cut -c1-260
# teeth -------------------------------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 3. teeth: each break must make a test fail"
 M=$OUT/mut;mkdir -p "$M"
 mutate(){ # kind(touch|pc) name file old new [old new ...]
  kind=$1;name=$2;file=$3;shift 3
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
  if [ "$kind" = touch ];then
   if BUNDLE_ARGS="$mod=$M/$name.lua" CASES="phone_844x390 phone_750x311_insets portrait_390x844 portrait_320x568 tablet_1024x768" sh "$HERE/touch_lock158.sh" "$M/w_$name" > "$M/$name.log" 2>&1;then fail "mutation $name was NOT noticed (touch lock)";else echo "ok: $name -> the touch lock fails ($(grep -c '^FAIL' "$M/$name.log") failing pieces)";fi
  else
   if BUNDLE_ARGS="$mod=$M/$name.lua" CASES="1920x1080 1280x720 800x600 1920x300" sh "$HERE/pc_hud158.sh" "$M/w_$name" > "$M/$name.log" 2>&1;then fail "mutation $name was NOT noticed (PC HUD)";else echo "ok: $name -> the PC test fails ($(grep -c '^FAIL' "$M/$name.log") failing checks)";fi
  fi
  rm -rf "$M/w_$name"
 }
 # a touch screen must not move: a phone number, a stray UIScale, the status scale, the bars' slot gap, the tutorial's rows, the wheel's offsets
 mutate touch phone_wallet_height "$RSD/HudLayout.lua" " local walletHeight=44;local walletGap=2;local walletW=144" " local walletHeight=43;local walletGap=2;local walletW=144"
 mutate touch touch_ui_scale "$RSD/HudLayout.lua" "  if s==1 then return end
  u=Instance.new('UIScale')" "  u=Instance.new('UIScale')"
 mutate touch status_scale "$RSD/WorldStatusHud.lua" "  scale.Scale=m.StatusScale*hudScale
  -- R129" "  scale.Scale=m.StatusScale*hudScale*1.01
  -- R129"
 mutate touch dock_gap "$RSD/PityBars155.lua" " local side=m.SlotSize;local width=(m.Slots+1)*side+m.Slots*6" " local side=m.SlotSize;local width=(m.Slots+1)*side+m.Slots*5"
 mutate touch guide_detail "$RSD/BeginnerGuide.lua" "math.max(44,math.ceil(-rows.Y))" "math.max(44,math.ceil(-rows.Y)+1)"
 mutate touch wheel_offset "$RSD/HudLayout.lua" "  return UDim2.new(0,(m.MenuX+(m.MenuSize" "  return UDim2.new(0,(1+m.MenuX+(m.MenuSize"
 mutate touch hotbar_reserve "$C/Hotbar.client.lua" " if hudScale~=1 then reserve=math.ceil(reserve*hudScale)end" " reserve=math.ceil(reserve*hudScale)+1"
 # the PC HUD must stay the scaled 1920 x 1080 arrangement with a MENU that keeps close to its size
 mutate pc menu_floor_60 "$RSD/HudLayout.lua" "local PcWidth,PcHeight,MenuFloor=1920,720,.85" "local PcWidth,PcHeight,MenuFloor=1920,720,.6"
 mutate pc pc_height_800 "$RSD/HudLayout.lua" "local PcWidth,PcHeight,MenuFloor=1920,720,.85" "local PcWidth,PcHeight,MenuFloor=1920,800,.85"
 mutate pc menu_centre_half "$RSD/HudLayout.lua" "margin,wallet.Y-8,mh/3,false,mw,{hotbar,status})" "margin,wallet.Y-8,mh/2,false,mw,{hotbar,status})"
 mutate pc wallet_shortened "$RSD/HudLayout.lua" " local walletW,walletH,walletGap=290,56,7" " local walletW,walletH,walletGap=290,40,7"
 mutate pc wallet_no_scale "$RSD/GardenWallet.lua" "[i]*k,({m.SpeedY,m.CashY,m.GemY})[i]*k)" "[i],({m.SpeedY,m.CashY,m.GemY})[i])"
 mutate pc wallet_no_uiscale "$RSD/GardenWallet.lua" ";shared.ApplyScale(r.Root,k)" ""
 mutate pc status_no_scale "$RSD/WorldStatusHud.lua" "1,-(m.StatusRight or 12)*hudScale,1,-m.StatusBottom*hudScale)" "1,-(m.StatusRight or 12),1,-m.StatusBottom)"
 mutate pc dock_no_uiscale "$C/Hotbar.client.lua" ";require(RS.HudLayout).ApplyScale(dock,hudScale)" ""
 mutate pc bars_root_no_uiscale "$RSD/PityBars155.lua" "Hud.ApplyScale(root,hudScale)" ""
 mutate pc bars_reserved_unscaled "$RSD/PityBars155.lua" " local box=sc(reservedHud(m.VW,m.VH,m,dock and sc(dock,1/s)or nil),s);box.N='PityBars'" " local box=reservedHud(m.VW,m.VH,m,dock and sc(dock,1/s)or nil)"
 mutate pc real_menu_unscaled "$RSD/HudLayout.lua" "if m[key]~=nil then r[key]=m[key]*ms end end
 if m.MenuOffsets" "if m[key]~=nil then r[key]=m[key] end end
 if m.MenuOffsets"
 mutate pc hub_no_uiscale "$RSD/HudLayout.lua" ";L.ApplyScale(hub,ms)" ""
 mutate pc groups_no_uiscale "$RSD/HudLayout.lua" ";L.ApplyScale(entry.Group,ms);styleOption" ";styleOption" ";L.ApplyScale(group,state.Metrics.MenuScale or 1)" ""
 mutate pc guide_not_real "$RSD/BeginnerGuide.lua" " local layout=m;m=real(m)" " local layout=m"
 # the review follow-ups: each fix, taken out, must be noticed
 mutate pc text_floor_off "$RSD/GardenTextFit.lua" " if not k or k>=1 or minimum>M.RealCap then return minimum end" " do return minimum end"
 mutate pc bars_words_hud_px "$RSD/PityBars155.lua" "local text=B.Words(bar.Group,bar.Count,w,h,pop,hk);bar.Words=text;bar.WordSize=B.TextSize(text,w,h,hk)" "local text=B.Words(bar.Group,bar.Count,w,h,pop);bar.Words=text;bar.WordSize=B.TextSize(text,w,h)"
 mutate pc skip_zone_hud_px "$RSD/PityBars155.lua" " boxes[#boxes+1]=hk==1 and B.SkipZone(w,h)or sc(B.SkipZone(math.floor(w*hk+.5),math.floor(h*hk+.5)),1/hk)" " boxes[#boxes+1]=B.SkipZone(w,h)"
 mutate pc bonus_rise_clamped "$RSD/PityBars155.lua" " if not scaled then rise=math.max(0,rise)end" " rise=math.max(0,rise)"
 mutate pc menu_54_unscaled "$RSD/GardenMenuStyle.lua" "(pg:GetAttribute('ChestHotbarReserve')or 134)-54*hudScale)" "(pg:GetAttribute('ChestHotbarReserve')or 134)-54)"
 mutate pc hud_scale_unpublished "$C/Hotbar.client.lua" " if pg:GetAttribute('ChestHudScale')~=scaleAttr then pg:SetAttribute('ChestHudScale',scaleAttr)end" ""
 mutate pc slot_name_min_hud_px "$C/Hotbar.client.lua" "local lo=Fit.Floor(7,hudScale,nameHeight/2+1);" "local lo=7;"
 mutate pc status_scale_unnamed "$RSD/WorldStatusHud.lua" "  if(scale.Name=='HudScale')~=(hudScale~=1)then scale.Name=hudScale~=1 and'HudScale'or'UIScale'end" ""
 mutate pc pcscales_read_public "$RSD/HudLayout.lua" " local s,ms=pcScales(w,h)" " local s,ms=L.PcScales(w,h)"
 mutate pc rules_view_plain "$RSD/HudLayout.lua" "v=table.clone(r);v.HotbarBottom=r.HotbarBottom-44*(1-s)" "v=table.clone(r)"
 mutate pc statusright_12 "$RSD/HudLayout.lua" "X=w-(m.StatusRight or 12)-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh}
  b[#b+1]={N='OwnerTools'" "X=w-12-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh}
  b[#b+1]={N='OwnerTools'"
fi
[ $RC = 0 ] && echo "R158 PC HUD lock: ALL PASS" || echo "R158 PC HUD lock: FAIL"
exit $RC
