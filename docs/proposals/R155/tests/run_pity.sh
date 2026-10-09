#!/bin/sh
# Usage: sh run_pity.sh [scratch dir]      (NO_MUTATE=1 skips the teeth; R155_BASE=<ref> = the commit this was built on, default f4f9702)
# R155 pack pity (owner: "every 10th pack" x1.5 luck; "make the pity separate an event pity and a normal pity the event pity only counts for void, verity and mech";
# "2 separate bars above the hot bar one coloured gold the other coloured purple", "always visible and polished properly"). On the Roblox mock (/opt/luau/luau):
#  0. static  - the new / changed scripts compile at -O0; the four new scripts are in src/MANIFEST.tsv (sorted); the frozen odds files match R151's frozen.sha256 and the
#               R155 pity changes carry their notes; Config.lua (but its Version), Hotbar.client.lua, RarePullCinematic, RarePullCard and BackgroundMusic are untouched since the base;
#               the R152 load guard is line 1 of every client script; the wiring (the open plans before its roll and commits after it went through, the save and the
#               load, the hold tooltip, /test odds, the Mech shop card's line, COMMANDS.md and the F4 help); no model names in the R155 pity files
#  1. test    - test_pity155.luau (the R153 clover world, the real server code): rules, clamps, lucky odds, real opens per group, TEST / refused opens, saving, commands
#               R155 review: a held pack's tooltip is rebuilt when a pity count or the boots luck changes (section 7: the real ChestService on the mock; teeth tip_*)
#  2. test    - test_pity_bars155.luau (the real client bars): always there, values, 9/10 glow, the held pack, the lucky pop and the card tag, Reduced Motion, 36 screens;
#               R155 review: the SKIP pill and the treadmill BONUS ROLL button never touch the bars (60 screen / controls cases), the bars start with the tutorial card up / a
#               pack in hand / a reveal card / a menu (no error), a bar at 9/10 writes its glow and nothing else, a hidden / dimmed bar costs nothing
#  3. teeth   - the same tests on broken copies (each must FAIL)
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R155_BASE:-f4f9702}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;RSD=$S/ReplicatedStorage;C=$S/StarterPlayer/StarterPlayerScripts
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
n=0
for f in "$RSD/PackPity155.lua" "$RSD/PityBars155.lua" "$SS/PackPityData155.lua" "$C/PityBarsClient155.client.lua" "$RSD/PackOdds112.lua" "$RSD/PackOdds137.lua" "$RSD/PackLuck154.lua" \
 "$RSD/BalanceValues81.lua" "$RSD/WorldStatusHud.lua" "$RSD/StudioTestHelp.lua" "$SS/PlayerDataService.lua" "$SS/ChestService.lua" "$SS/HubDisplayService.lua" "$SS/OwnerUpdateCommands82.lua" "$C/GamePassClient.client.lua";do
 n=$((n+1));/opt/luau/luau-compile -O0 --null "$f" >/dev/null 2>"$OUT/compile.err" || { fail "$f does not compile at -O0";cat "$OUT/compile.err"; }
done
echo "ok: $n new / changed scripts compile at -O0"
for row in "ModuleScript	ReplicatedStorage/PackPity155	ReplicatedStorage/PackPity155.lua" "ModuleScript	ReplicatedStorage/PityBars155	ReplicatedStorage/PityBars155.lua" \
 "ModuleScript	ServerScriptService/ChestChaseServer/PackPityData155	ServerScriptService/ChestChaseServer/PackPityData155.lua" \
 "LocalScript	StarterPlayer/StarterPlayerScripts/PityBarsClient155	StarterPlayer/StarterPlayerScripts/PityBarsClient155.client.lua";do
 grep -qx "$row" "$S/MANIFEST.tsv" || fail "not in src/MANIFEST.tsv: $row"
done
python3 - "$S/MANIFEST.tsv" <<'PY' || fail "src/MANIFEST.tsv is not sorted"
import sys
rows=open(sys.argv[1]).read().splitlines()[1:]
assert rows==sorted(rows,key=lambda l:l.split('\t')[1])
PY
echo "ok: the four new scripts are in the manifest (sorted)"
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) || fail "a frozen file differs from R151's frozen.sha256"
for f in PackOdds112 PackLuck154;do grep -q "^# R155 (on purpose): .*$f.lua.*pack pity" "$P/R151/tests/frozen.sha256" || fail "frozen.sha256 has no R155 pity note for $f";done
echo "ok: the frozen odds files match their hashes; PackOdds112 / 137 and PackLuck154 carry their R155 pity notes"
# (after the R155 merges the cinematic, the card, the hotbar and SeedPackRules change for other R155 work, and the card's SKIP pill now keeps clear of the bars; these two never change)
# (the R155 release sets Config.Version: that one value may change, nothing else in Config.lua)
git -C "$REPO" diff --quiet "$BASE" -- src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua || fail "BackgroundMusic changed since $BASE (the music stays as it is)"
[ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | sed "s/Config\.Version='[^']*'/Config.Version=V/")" = "$(sed "s/Config\.Version='[^']*'/Config.Version=V/" "$SS/Config.lua")" ] || fail "Config.lua changed beyond Config.Version since $BASE (ProfileVersion stays)"
grep -qE "Config\.Version='V150 R15[0-9a-z]*'" "$SS/Config.lua" || fail "Config.Version must be a V150 R15x release number (the release step sets it)"
grep -q "Config.ProfileVersion=22" "$SS/Config.lua" || fail "ProfileVersion is not 22"
echo "ok: Config.lua (all but its Version; ProfileVersion 22) and BackgroundMusic untouched since $BASE"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: the R152 load guard is still line 1 of every client script (the new one too)" || { fail "the load guard test fails";tail -5 "$OUT/guard.log"; }
python3 - "$SS/PlayerDataService.lua" <<'PY' || fail "OpenSeedPack does not plan the pity before its roll and commit it after the open went through"
import re,sys
t=open(sys.argv[1],encoding='utf-8').read()
body=t[t.index('function PlayerDataService:OpenSeedPack'):t.index('function PlayerDataService:CheckVoidPack')]
plan=body.index('self:PlanPackPity(player,pack,testSeed~=nil or pack.TestGrant==true or luckTest)');roll=body.index('self:PackPityRoll(pity,PackRules.Roll,')
fails=[body.index('return nil, "REJOIN TO OPEN THIS PACK!"'),body.index('if not rewardCash then return nil,reason end')]
commit=body.index('self:CommitPackPity(player,pity)');swap=body.index('records[index] = reward')
assert plan<roll<min(fails) and max(fails)<swap<commit, 'order'
assert body.count('CommitPackPity')==1 and body.count('PlanPackPity')==1
PY
grep -q "PackPity = self:CopyPackPity(player)," "$SS/PlayerDataService.lua" && grep -q "self:LoadPackPity(player,type(storedData)=='table'and storedData.PackPity or nil)" "$SS/PlayerDataService.lua" || fail "the counts are not saved and loaded"
grep -q "require(script.Parent.PackPityData155).Install(PlayerDataService)" "$SS/PlayerDataService.lua" || fail "PackPityData155 is not installed"
grep -q "self.PlayerData:PackPityTooltip(player,record," "$SS/ChestService.lua" || fail "the hold tooltip does not ask the pity"
grep -q "table.insert(lines,'pity: '..Pity.Disclosure)" "$SS/OwnerUpdateCommands82.lua" || fail "/test odds does not list the pity rule"
grep -q "PackPity155')).EventDisclosure" "$C/GamePassClient.client.lua" || fail "the Mech shop card does not list the pity rule"
grep -q "every 10th pack u open is lucky: x1.5 luck (event packs count separately)" "$RSD/PackPity155.lua" || fail "the rule's words changed"
grep -q '`pity @name`, `pity set 9 9 @name`' "$REPO/docs/COMMANDS.md" && grep -q "/test pity @username" "$RSD/StudioTestHelp.lua" || fail "the pity commands are not in COMMANDS.md / the F4 help"
grep -q ".Scoped,info.Lucky==true,PackRules.SeedOdds,self.Config,info.Stage,info.Variant,info.Luck,info.Version,info.Boost,info.PassLuck)" "$SS/HubDisplayService.lua" || fail "BEST PULL does not read a lucky pull's odds the lucky way"
echo "ok: the wiring (plan before the roll, commit after the open, save / load, tooltip, /test odds, the Mech card, BEST PULL, COMMANDS.md and the F4 help)"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE" "$P/R155/pity.md" "$P/R155/preview" "$RSD/PackPity155.lua" "$RSD/PityBars155.lua" "$SS/PackPityData155.lua" 2>/dev/null | grep -v '/run_pity.sh:' | grep -q .;then fail "a model name in the R155 pity files";else echo "ok: no model names in the R155 pity files";fi
# the tests ---------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [Name=path ...]
 d=$1;shift;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R153/tests/clover_env.luau" "$HERE/test_pity155.luau" "$HERE/test_pity_bars155.luau" "$d/"
 python3 "$P/R153/tests/mkbundle_clover.py" "$d" "$@" > /dev/null
}
both(){ # dir -> 0 when both pass
 ( cd "$1" && timeout 900 /opt/luau/luau test_pity155.luau > server.log 2>&1 ) || return 1
 ( cd "$1" && timeout 900 /opt/luau/luau test_pity_bars155.luau > bars.log 2>&1 ) || return 1
 return 0
}
echo "== 1. test_pity155 (server)  == 2. test_pity_bars155 (client)"
build "$OUT/w"
( cd "$OUT/w" && timeout 900 /opt/luau/luau test_pity155.luau > server.log 2>&1 ) && echo "ok: $(grep -v '^WARN\|^TABLE' "$OUT/w/server.log" | tail -1)" || { grep -v '^WARN' "$OUT/w/server.log" | tail -30;fail "test_pity155"; }
grep '^TABLE ' "$OUT/w/server.log" || true
( cd "$OUT/w" && timeout 900 /opt/luau/luau test_pity_bars155.luau > bars.log 2>&1 ) && echo "ok: $(grep -v '^WARN\|^LAYOUT' "$OUT/w/bars.log" | tail -1)" || { grep -v '^WARN\|^LAYOUT' "$OUT/w/bars.log" | tail -30;fail "test_pity_bars155"; }
grep '^LAYOUT ' "$OUT/w/bars.log" > "$OUT/layouts.txt" || true
echo "(the bars on 30 screens: $OUT/layouts.txt)"
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 3. teeth: each break must make a test fail"
 M=$OUT/mut;mkdir -p "$M"
 mutate(){ # name file old new [old2 new2 ...]
  name=$1;file=$2;shift 2
  python3 - "$file" "$M/$name.lua" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f,out=sys.argv[1:3];rest=sys.argv[3:];pairs=list(zip(rest[0::2],rest[1::2]))
s=open(f,encoding='utf-8').read()
for old,new in pairs:
    assert old in s,old
    s=s.replace(old,new,1)
open(out,'w',encoding='utf-8').write(s)
PY
  mod=$(basename "$file" .lua)
  build "$M/w_$name" "$mod=$M/$name.lua"
  if both "$M/w_$name";then fail "mutation $name was NOT noticed";else echo "ok: $name -> fails ($(cat "$M/w_$name/server.log" "$M/w_$name/bars.log" 2>/dev/null | grep -c '^FAIL') failing checks)";fi
 }
 mutate mech_is_normal "$RSD/PackPity155.lua" "P.EventVariants={EclipseReliquary=true,MechLimited=true," "P.EventVariants={EclipseReliquary=true,"
 mutate every_11th "$RSD/PackPity155.lua" "local P={Version=155,Every=10," "local P={Version=155,Every=11,"
 mutate no_reset "$RSD/PackPity155.lua" "return n>=P.Every and 0 or n" "return n>=P.Every and 1 or n"
 mutate boost_twice "$SS/PackPityData155.lua" "return Pity.Luck(luck,lucky),Pity.Luck(passLuck,lucky)" "return Pity.Luck(Pity.Luck(luck,lucky),lucky),Pity.Luck(passLuck,lucky)"
 mutate no_lucky_cap "$RSD/PackPity155.lua" "if depth>0 and type(base)=='number'then return base*P.Boost end" "if false then return base end"
 mutate lucky_cap_always "$RSD/PackPity155.lua" "if depth>0 and type(base)=='number'then return base*P.Boost end" "if type(base)=='number'then return base*P.Boost end"
 mutate test_packs_count "$SS/PackPityData155.lua" "if test or type(pack)~='table'then return nil end" "if type(pack)~='table'then return nil end"
 mutate count_before_success "$SS/PlayerDataService.lua" "        self:CommitPackPity(player,pity) -- R155: the open went through: its group's count moves on (the lucky one back to 0)
" "" "        local luck,passLuck=self:PackPityLuck(pity," "        self:CommitPackPity(player,pity);local luck,passLuck=self:PackPityLuck(pity,"
 mutate not_saved "$SS/PlayerDataService.lua" "        PackPity = self:CopyPackPity(player), -- R155 (optional; an R154 server drops it)
" ""
 mutate not_loaded "$SS/PlayerDataService.lua" "self:LoadPackPity(player,type(storedData)=='table'and storedData.PackPity or nil)" "self:LoadPackPity(player,nil)"
 mutate no_tooltip_rule "$SS/PackPityData155.lua" "return odds,lines,{Pity.Disclosure}" "return odds,lines,{}"
 mutate no_odds_rule "$SS/OwnerUpdateCommands82.lua" "  table.insert(lines,'pity: '..Pity.Disclosure) -- R155: the rule, listed with the odds
" ""
 # R155 review: a held pack's tooltip follows the pity counts and the boots luck
 mutate tip_never_refreshed "$SS/ChestService.lua" "    if player then watchPackTooltips(self,player) end -- R155 (review)
" ""
 mutate tip_ignores_pity "$SS/ChestService.lua" "for _,name in ipairs({'PackPityNormal','PackPityEvent','ChestLuckMultiplier'})do" "for _,name in ipairs({'ChestLuckMultiplier'})do"
 mutate tip_ignores_luck "$SS/ChestService.lua" "for _,name in ipairs({'PackPityNormal','PackPityEvent','ChestLuckMultiplier'})do" "for _,name in ipairs({'PackPityNormal','PackPityEvent'})do"
 mutate tip_not_debounced "$SS/ChestService.lua" "        if queued then return end;queued=true
        task.defer(function()" "        task.defer(function()"
 mutate tip_for_unheld_packs "$SS/ChestService.lua" "and tool:GetAttribute('OddsTooltip155')==true then" "then"
 mutate tip_one_bad_stops_all "$SS/ChestService.lua" "then pcall(function()tool.ToolTip=ChestService._packTooltip(self,player,record)end)end" "then tool.ToolTip=ChestService._packTooltip(self,player,record)end"
 mutate hud_lucky_always "$RSD/WorldStatusHud.lua" " if lucky==true then return speed," " if true then return speed,"
 mutate no_highlight "$RSD/PityBars155.lua" " local function held()local g=heldGroup();if g~=s.Held then s.Held=g;wake()end end" " local function held()end"
 mutate no_glow "$RSD/PityBars155.lua" " elseif Pity.IsLucky(bar.Count)then glow=reduced and .55 or .58+.17*math.sin(now*4.2)end" " end"
 mutate reduced_pop "$RSD/PityBars155.lua" " if popping and not reduced then
  if popAge<.12" " if popping then
  if popAge<.12"
 mutate no_card_tag "$RSD/PityBars155.lua" "cardKind=kind;s.TagState={Group=group,Kind=kind,At=clock()}" "cardKind=kind"
 mutate over_the_hud "$RSD/PityBars155.lua" "  for _,b in ipairs(boxes)do if overlaps(e,b,B.Pad)then return false end end
  return true" "  return true"
 # R155 review: the start order, the SKIP pill and BONUS button over the bars, the per-frame cost
 mutate step_before_layout "$RSD/PityBars155.lua" "local moving=s.Placement~=nil and step(s,dt or 1/60,clock())" "local moving=step(s,dt or 1/60,clock())" " if s.Placement and s.Root.Visible then" " if s.Root.Visible then" "local placement=s.Placement;if not placement then return end" "local placement=s.Placement" " local stopLayout=Hud.Watch(gui,layout)
 local charConns={}" " local charConns={}" " con(pg.ChildAdded,function(c)if c.Name=='ChestToolHotbar'" " local stopLayout=Hud.Watch(gui,layout)
 con(pg.ChildAdded,function(c)if c.Name=='ChestToolHotbar'"
 mutate no_placement_guard "$RSD/PityBars155.lua" "local moving=s.Placement~=nil and step(s,dt or 1/60,clock())" "local moving=step(s,dt or 1/60,clock())" " if s.Placement and s.Root.Visible then" " if s.Root.Visible then" "local placement=s.Placement;if not placement then return end" "local placement=s.Placement"
 mutate skip_over_bars "$RSD/RarePullCard.lua" "if okB and Bars then local okR,box=pcall(Bars.Reserved,w,h,m,nil);if okR and type(box)=='table'then list[#list+1]=box end end" ""
 mutate bonus_over_bars "$RSD/PityBars155.lua" " return rules.Place(setmetatable({HotbarBottom=m.HotbarBottom+rise},{__index=m}),w,h,boxes,more)" " return rules.Place(m,w,h,boxes,extra)"
 mutate bonus_not_lifted "$RSD/PityBars155.lua" " return rules.Place(setmetatable({HotbarBottom=m.HotbarBottom+rise},{__index=m}),w,h,boxes,more)" " return rules.Place(m,w,h,boxes,more)"
 mutate paints_every_frame "$RSD/PityBars155.lua" "   local changed=bar.Rev~=s.Rev" "   local changed=true"
 mutate hidden_paints "$RSD/PityBars155.lua" " if s.Placement and s.Root.Visible then" " if s.Placement then"
 mutate dimmed_pulses "$RSD/PityBars155.lua" " and not dimmed and bar.Pending==0" " and bar.Pending==0"
 mutate words_every_paint "$RSD/PityBars155.lua" " if bar.WordCount~=bar.Count or bar.WordPop~=pop or bar.WordW~=w or bar.WordH~=h then" " if true then"
 mutate menu_does_not_wake "$RSD/PityBars155.lua" "function()root.Visible=visible();wake()end" "function()root.Visible=visible()end"
fi
[ $RC = 0 ] && echo "R155 pack pity: ALL PASS" || echo "R155 pack pity: FAIL"
exit $RC
