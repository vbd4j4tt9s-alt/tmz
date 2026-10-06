#!/bin/sh
# Usage: sh run_void_giveaway.sh [scratch dir] [mutate]
# R152 (owner: "add a pedestal in the middle that gives a player 1 void pack. it will be a limited time for 500 players only and its in every server ... once serverwide 500 claims have
# been done it will go to 0 and will not be claimable any more. there is a number above that shows how many is left"): the free Void Pack giveaway pedestal, on the Roblox mock (/opt/luau/luau
# and tools/tests/roblox.luau, the R150 pedestal harness / R149 zfight_world on top) with the REAL scripts of this checkout (every module bundled from THIS checkout's src):
#  wiring                    - the files, src/MANIFEST.tsv, the main script's one guarded line, the owner command (Actions, dispatcher, server-wide, F4 help, docs/COMMANDS.md), ProfileVersion
#                              22 and Config.Version unchanged, the gameplay files byte-identical (R151's frozen.sha256), the shared key / topic / store names, no live-data command, the
#                              flag is an optional Premium field, DataStore / MessagingService used by the giveaway alone (plus the announcer's own MessagingService), no new sound asset;
#  test_giveaway_server      - the rule, a claim (ONE real Void Pack, count + 1, the flag, the save), a second claim refused, two servers racing at 499 (only one gets it: a compare-and-set DataStore
#                              mock), at 500 every claim refused / prompt off / ALL CLAIMED / for ever, a full Bag (nothing reserved), an interrupted grant (given again once, never twice), DataStore
#                              failures (no pack, retries with backoff, "try again"), messaging (another server's claim lowers the number here), polling, the Studio fallback (own store, in-memory
#                              counter, one warn), the owner commands (status; reset me / left N Studio only; live refuses), guards;
#  test_giveaway_real        - the real PlayerDataService (the R123 world): the pack is a real Void Pack (not TestGrant, the Bag limit is the game's), Verity takes it, the flag survives a save and
#                              a load, a profile without the flag, a profile that cannot save, a pack lost with an unsaved profile is given again once;
#  test_giveaway_art         - the pedestal: part budget, solid / glow, anchors, prompt, lettering on four faces, heights, the plaza centre and floor, the beam stops under the pack, states;
#  dump_giveaway_zscene + check_giveaway_zfight.py - the pedestal, the pack, its effects on the plaza through the R149 detector (docs/proposals/R149/tools/zfight.py): no counted finding;
#  test_giveaway_client      - the local player's screen: the number ("487 / 500 LEFT", live), the pop on a change, "CLAIMED ✓", ALL CLAIMED at 0, the sign's size / range (studs, stops growing
#                              close up), the Void Pack built the game's way and its glow / particles attached to it, the slow turn, the prompt for the one who claimed, the claim moment
#                              (the game's chime, no new sound), quality tiers, reduced motion, streaming, cost (nothing per frame when far), teardown.
# With "mutate" as the 2nd argument, broken copies of src must each make a suite fail (the tests have teeth; ONLY=<words of one mutation's name> runs just that one).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
S=$REPO/src
prep() { # $1 = src dir, $2 = work dir (the pedestal harness world)
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R150/tests/pedestal_harness.luau" "$REPO/docs/proposals/R151/tests/announce_env.luau" "$HERE"/*.luau "$2/"
 python3 "$HERE/bundle_giveaway.py" "$1" "$2" >/dev/null
}
prep_real() { # the real PlayerDataService needs the R123 world (as the R151 hub hook suite does)
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R151/tests/announce_env.luau" "$HERE/test_giveaway_real.luau" "$2/"
 python3 "$HERE/bundle_giveaway.py" "$1" "$2" >/dev/null
}
suite() { # $1 = work dir, $2 = test, $3 = log
 (cd "$1" && timeout 600 /opt/luau/luau "$2" > "$3" 2>&1) || { grep -v '^WARN' "$3" | tail -30;return 1; }
 grep -v '^WARN' "$3" | tail -1
}
zfight() { # $1 = work dir
 (cd "$1" && timeout 600 /opt/luau/luau dump_giveaway_zscene.luau > zscene.txt 2> zscene.err) || { tail -15 "$1/zscene.err";return 1; }
 python3 "$HERE/check_giveaway_zfight.py" "$1/zscene.txt" > "$1/zfight.log" || { tail -8 "$1/zfight.log";return 1; }
 tail -2 "$1/zfight.log"
}
wiring() { # $1 = the src tree to check (this checkout's, or a mutated copy)
 S=$1;SRV=$S/ServerScriptService/ChestChaseServer;CL=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
 for f in ReplicatedStorage/VoidGiveawayRules152 ServerScriptService/ChestChaseServer/VoidGiveaway152 ServerScriptService/ChestChaseServer/VoidGiveawayArt152 ServerScriptService/ChestChaseServer/VoidGiveawayStore152 StarterPlayer/StarterPlayerScripts/VoidGiveawayClient152;do
  test -f "$S/$f.lua" -o -f "$S/$f.client.lua" || { echo "missing $f";return 1; }
  grep -q "	$f	" "$S/MANIFEST.tsv" || { echo "$f is not in src/MANIFEST.tsv";return 1; }
  /opt/luau/luau-compile --null "$S/$f.lua" >/dev/null 2>&1 || /opt/luau/luau-compile --null "$S/$f.client.lua" >/dev/null 2>&1 || { echo "$f does not compile";return 1; }
 done
 grep -q "VoidGiveawayClient152	StarterPlayer/StarterPlayerScripts/VoidGiveawayClient152.client.lua" "$S/MANIFEST.tsv" || { echo "the client script's manifest row is wrong";return 1; }
 M=$S/ServerScriptService/ChestChaseServerMain.server.lua
 [ "$(grep -c "VoidGiveaway152" "$M")" = 1 ] || { echo "the main script must mention VoidGiveaway152 on exactly one line";return 1; }
 grep -q "pcall(function()require(modules.VoidGiveaway152).new(Config,playerData,chestService,notifications,mapService):Start()end)" "$M" || { echo "the main script does not start the giveaway (guarded: a failure must never stop the server)";return 1; }
 grep -q "X.Actions.voidgift=true" "$SRV/OwnerUpdateCommands82.lua" && grep -q "VoidGiveaway152).Command(ctx,p,a)" "$SRV/OwnerUpdateCommands82.lua" || { echo "voidgift is not wired into OwnerUpdateCommands82";return 1; }
 grep -q "voidgift" "$SRV/OwnerCommandTargets82.lua" || { echo "voidgift is not a server-wide command";return 1; }
 grep -q "voidgift" "$RSD/StudioTestHelp.lua" && grep -q "voidgift" "$REPO/docs/COMMANDS.md" || { echo "voidgift is not in the F4 help / docs/COMMANDS.md";return 1; }
 # the numbers the owner asked for
 grep -q "R.Cap=500" "$RSD/VoidGiveawayRules152.lua" && grep -q "R.StoreName='VoidGiveaway152'" "$RSD/VoidGiveawayRules152.lua" && grep -q "R.Key='Claims'" "$RSD/VoidGiveawayRules152.lua" || { echo "cap / store / key are not 500 / VoidGiveaway152 / Claims";return 1; }
 grep -q "UpdateAsync" "$SRV/VoidGiveawayStore152.lua" || { echo "the reservation must be an UpdateAsync";return 1; }
 # the live key is never written by a command or by Studio: edits are Studio-only and the Studio store has its own name
 grep -q "if not self.Studio then return false,'Studio only'end" "$SRV/VoidGiveawayStore152.lua" || { echo "Store:Edit must refuse outside Studio";return 1; }
 grep -q "studio and Rules.StudioStoreName or Rules.StoreName" "$SRV/VoidGiveawayStore152.lua" || { echo "Studio must use its own store";return 1; }
 for f in VoidGiveawayStore152 VoidGiveaway152;do if sed 's/--.*$//' "$SRV/$f.lua" | grep -n "SetAsync\|RemoveAsync\|IncrementAsync";then echo "the giveaway must only ever UpdateAsync / GetAsync the shared key ($f)";return 1;fi;done
 # no per-frame loop on the server
 for f in VoidGiveaway152 VoidGiveawayStore152 VoidGiveawayArt152;do if sed 's/--.*$//' "$SRV/$f.lua" | grep -n -E "Heartbeat|RenderStepped|Stepped";then echo "the giveaway has a per-frame loop on the server ($f)";return 1;fi;done
 # the saved flag is an optional field of the existing Premium table: no profile version change (an older server copies it)
 grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" && grep -q "Config.Version='V150 R152'" "$SRV/Config.lua" || { echo "Config.ProfileVersion / Version changed";return 1; }
 if grep -q "VoidGift152" "$SRV/PlayerDataService.lua";then echo "PlayerDataService must not know the flag (it is an optional Premium field)";return 1;fi
 # the real, announcing pack: no TestGrant anywhere in the giveaway's code
 if sed 's/--.*$//' "$SRV/VoidGiveaway152.lua" | grep -n "TestGrant";then echo "the giveaway pack must not be a TestGrant pack";return 1;fi
 # no new sound asset: the client has no sound id and makes no Sound; the chime is the game's (InteractionAudio GemClaim)
 for f in "$CL/VoidGiveawayClient152.client.lua" "$RSD/VoidGiveawayRules152.lua" "$SRV/VoidGiveawayArt152.lua";do if sed 's/--.*$//' "$f" | grep -n "rbxassetid\|Instance.new('Sound')";then echo "the giveaway adds a sound or an asset id: $f";return 1;fi;done
 grep -q "Audio.Play,'GemClaim'" "$CL/VoidGiveawayClient152.client.lua" || { echo "the claim moment must play the game's own chime (InteractionAudio GemClaim)";return 1; }
 # the server never talks to the client directly: no remote of its own (attributes only)
 for f in "$SRV/VoidGiveaway152.lua" "$SRV/VoidGiveawayArt152.lua" "$CL/VoidGiveawayClient152.client.lua";do if sed 's/--.*$//' "$f" | grep -n "RemoteEvent\|FireClient\|FireAllClients\|OnServerEvent";then echo "the giveaway has a remote (it must use attributes only): $f";return 1;fi;done
 # DataStore / MessagingService: the giveaway's own, nobody else's
 m=$(grep -rl "GetService('MessagingService')" "$S" --include=*.lua | xargs -n1 basename | sort | tr '\n' ' ')
 [ "$m" = "PullAnnouncer.lua VoidGiveaway152.lua " ] || { echo "MessagingService is used by [$m] (expected the announcer and the giveaway)";return 1; }
 echo "wiring ok"
}
frozen() {
 (cd "$REPO" && sha256sum -c "$REPO/docs/proposals/R151/tests/frozen.sha256" > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "the gameplay files are byte-identical ($(wc -l < "$REPO/docs/proposals/R151/tests/frozen.sha256") in R151's frozen.sha256)"
}
if [ "$MODE" != "mutate" ];then
 echo "== wiring";wiring "$S";frozen
 prep "$S" "$OUT/w";prep_real "$S" "$OUT/r"
 echo "== test_giveaway_server";suite "$OUT/w" test_giveaway_server.luau "$OUT/server.log"
 echo "== test_giveaway_real";suite "$OUT/r" test_giveaway_real.luau "$OUT/real.log"
 echo "== test_giveaway_art";suite "$OUT/w" test_giveaway_art.luau "$OUT/art.log"
 echo "== test_giveaway_client";suite "$OUT/w" test_giveaway_client.luau "$OUT/client.log"
 echo "== giveaway z-fighting (the pedestal, the pack, its effects, on the plaza: R149 detector)";zfight "$OUT/w"
 echo "R152 giveaway suites passed"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src; the named check must fail ----------------------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text, $5 = the check that must catch it: server | real | art | client | zfight | wiring
 if [ -n "$ONLY" ];then case "$1" in *"$ONLY"*);;*) return 0;; esac;fi
 rm -rf "$M";mkdir -p "$M";cp -r "$S/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 total=$((total+1))
 case "$5" in
  wiring) (wiring "$M") >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  real) prep_real "$M" "$OUT/mr" 2>/dev/null;(cd "$OUT/mr" && timeout 600 /opt/luau/luau test_giveaway_real.luau) >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  zfight) prep "$M" "$OUT/mw" 2>/dev/null;(zfight "$OUT/mw") >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  *) prep "$M" "$OUT/mw" 2>/dev/null;(cd "$OUT/mw" && timeout 600 /opt/luau/luau test_giveaway_$5.luau) >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
 esac
 if [ "$r" = 0 ];then echo "MUTATION SURVIVED: $1";else echo "mutation caught: $1";caught=$((caught+1));fi
}
RU=ReplicatedStorage/VoidGiveawayRules152.lua;ST=ServerScriptService/ChestChaseServer/VoidGiveawayStore152.lua;SV=ServerScriptService/ChestChaseServer/VoidGiveaway152.lua
AR=ServerScriptService/ChestChaseServer/VoidGiveawayArt152.lua;CLI=StarterPlayer/StarterPlayerScripts/VoidGiveawayClient152.client.lua
mutate "the cap is 501" $RU "R.Cap=500" "R.Cap=501" server
mutate "the cap is not checked in the transform" $RU " if v.Count>=(cap or R.Cap)then return nil,'full',v end" "" server
mutate "a user already listed is counted again" $RU " if v.Users[key]~=nil then return nil,'already',v end" "" server
mutate "the reservation is not one UpdateAsync" $ST "local ok,err=pcall(function()return store:UpdateAsync(self.Key,transform)end)" "local ok,err=pcall(function()local cur=store:GetAsync(self.Key);local v=transform(cur);if v then store:UpdateAsync(self.Key,function()return v end)end end)" server
mutate "a pack is given when the store failed" $SV "  if not ok then
   if outcome~='backoff'then" "  if not ok then outcome,value='new',Rules.Clean(nil)end
  if false then
   if outcome~='backoff'then" server
mutate "the giveaway pack is not GiftLocked" $SV ";pack.GiftLocked=true" "" server
mutate "AddChest drops the lock" ServerScriptService/ChestChaseServer/PlayerDataService.lua "        GiftLocked = chest.GiftLocked == true or nil," "" real
mutate "a save drops the lock" ServerScriptService/ChestChaseServer/PlayerDataService.lua "            GiftLocked=(chestRecord.Kind==\"Pack\" and chestRecord.GiftLocked==true) or nil," "" real
mutate "a load drops the lock" ServerScriptService/ChestChaseServer/PlayerDataService.lua "                GiftLocked=(savedChest.Kind==\"Pack\" and savedChest.GiftLocked==true) or nil," "" real
mutate "Verity drops the lock" ServerScriptService/ChestChaseServer/PlayerDataService.lua "			GiftLocked = pack.GiftLocked == true or nil," "" real
mutate "the lock is not exactly true" ServerScriptService/ChestChaseServer/PlayerDataService.lua "GiftLocked=(savedChest.Kind==\"Pack\" and savedChest.GiftLocked==true) or nil" "GiftLocked=savedChest.GiftLocked" real
mutate "the account age rule is never checked" $SV " if not owed and minAge>0 and" " if false and" server
mutate "the account age rule is on by default" $RU "R.MinAccountAgeDays=0" "R.MinAccountAgeDays=7" server
mutate "claims ignore the store's backoff" $ST " if self.Mode~='Memory'and self.Clock()<self.NextTryAt then return false,'backoff'" " if false then return false,'backoff'" server
mutate "the service does not look at the backoff first" $SV " if not owed then local wait=self:_wait(player);if wait>0 then" " if false then local wait=self:_wait(player);if wait>0 then" server
mutate "no cooldown after a store failure" $SV "self.Cool[player]=self.Clock()+S.StoreCooldown end" "end" server
mutate "the loop tells the player on every retry" $SV " if not auto or not f.Told then" " if true then" server
mutate "no backoff after a pack could not be added" $SV "if fail and self.Clock()<fail.Until then return false,'backoff'end" "" server
mutate "_run is not told it is the loop" $SV "pcall(self._run,self,player,owed,auto)" "pcall(self._run,self,player,owed)" server
mutate "a full Bag still reserves" $SV " if not self:_room(player)then" " if false then" server
mutate "no room check at the grant (the Bag can pass the limit)" $SV " if before>=self.Config.MaxSavedChests then return nil,'room'end" "" server
mutate "the giveaway pack is a TestGrant pack" $SV "pcall(function()return data:AddChest(player,pack)end)" "pcall(function()return data:AddChest(player,pack,{TestGrant=true})end)" server
mutate "the profile flag is not set" $SV " premium[Rules.Flag]=true
 data:MarkDirty(player)" " data:MarkDirty(player)" server
mutate "a flagged profile gets a second pack" $SV " if premium[Rules.Flag]==true then return nil,'claimed'end" "" server
mutate "a flagged player is not refused at the door" $SV " if self:_flag(player)then self:_state(player,'Claimed');return refuse('✅ U already grabbed ur free Void Pack!','claimed')end" "" server
mutate "the grant is not saved" $SV " data:MarkDirty(player);data:QueueGardenSave(player)
 pcall(function()self.Chests:SyncTools(player)end)" " pcall(function()self.Chests:SyncTools(player)end)" server
mutate "an owed player is never given the pack" $SV "  if self.Ready[player]and not self.Busy[player]and self.Data:IsLoaded(player)and self:_owed(player)then task.spawn(self.Claim,self,player,true)end" "" server
mutate "an owed player at the cap is refused" $SV " if not owed and self:Full()then" " if self:Full()then" server
mutate "a claim and the loop can both give (no busy lock)" $SV " if self.Busy[player]then return false,'busy'end" "" server
mutate "the count can go down (the highest does not win)" $SV " if self.Count~=nil and count<=self.Count then return false end" "" server
mutate "the prompt stays on at 0" $SV "if prompt and prompt.Enabled~=(state=='Open')then prompt.Enabled=state=='Open'end" "if prompt and not prompt.Enabled then prompt.Enabled=true end" server
mutate "the pedestal does not say ALL CLAIMED" $SV "self.Art.SetPlaque(self.Pedestal,state=='Empty')" "self.Art.SetPlaque(self.Pedestal,false)" server
mutate "a cap refusal still asks the DataStore" $SV " if not owed and self:Full()then return refuse" " if false then return refuse" server
mutate "messages from other servers are ignored" $SV " self.Received+=1" " if true then return end" server
mutate "a message above the cap is believed" $SV "if not count or count>Rules.Cap then return end" "if not count then return end" server
mutate "every claim publishes at once (no gap)" $SV "S.PublishGap=1.5" "S.PublishGap=0" server
mutate "the poll runs every step" $SV "if now>=self.NextPoll and not self.ReadFull then" "if not self.ReadFull then" server
mutate "the poll never stops at the cap" $SV "if now>=self.NextPoll and not self.ReadFull then" "if now>=self.NextPoll then" server
mutate "a failed read does not back off" $ST "self.NextTryAt=self.Clock()+math.min(S.RetryMax,S.RetryBase*2^(self.Failures-1))" "self.NextTryAt=0" server
mutate "claims are not retried" $ST "S.Attempts=4;" "S.Attempts=1;" server
mutate "retries do not wait" $ST "if attempt<S.Attempts then self.Wait((S.Waits[attempt]or 3)*(1+self.Random:NextNumber()*.25))end" "" server
mutate "a live server falls back to memory" $ST " if self.Mode=='Memory'or not self.Studio then return self.Mode end" " if self.Mode=='Memory'then return self.Mode end" server
mutate "Studio uses the live key" $ST "Name=opts.Name or(studio and Rules.StudioStoreName or Rules.StoreName)" "Name=opts.Name or Rules.StoreName" server
mutate "a live store can be edited" $ST " if not self.Studio then return false,'Studio only'end" "" server
mutate "a live server can reset a claim" $SV " if not self.Studio then return false,'voidgift '..sub..' works in Studio only" " if false then return false,'voidgift '..sub..' works in Studio only" server
mutate "the fallback warns more than once" $ST " if self.Mode=='Memory'then return false end
 self.Mode='Memory'" " self.Mode='Memory'" server
mutate "a player who cannot save is served (live)" $SV "if not data.CanSave[player]and not self.Studio then" "if false then" server
mutate "a player far from the pedestal is served" $SV "if not auto and not self:_near(player)then return false,'far'end" "" server
mutate "a flood of presses is not limited" $SV "if not auto and not Gate.Allow(player,'VoidGiveaway152')then return false,'rate'end" "" server
mutate "the pack is not Stage 7" $RU "R.Pack={Stage=7," "R.Pack={Stage=6," server
mutate "the pack is not a Void Pack" $RU "BagVariant='EclipseReliquary',PackSize=1" "BagVariant='Pack06',PackSize=1" server
mutate "the pack is a size 2" $RU "PackSize=1,PackMutation='None',Weather='None'}" "PackSize=2,PackMutation='None',Weather='None'}" server
mutate "the flag moves out of Premium" $SV "function S:_flag(player)return self.Data:GetPremium(player)[Rules.Flag]==true end" "function S:_flag(player)return player:GetAttribute('x')==true end" real
mutate "the real pack is a TestGrant pack" $SV "pcall(function()return data:AddChest(player,pack)end)" "pcall(function()return data:AddChest(player,pack,{TestGrant=true})end)" real
mutate "a track Void pack blocks the claim" $SV " if self:_flag(player)then self:_state(player,'Claimed');return refuse(" " for _,r in ipairs(data:GetChestRecords(player))do if r.BagVariant=='EclipseReliquary'then return refuse('x','owns')end end
 if self:_flag(player)then self:_state(player,'Claimed');return refuse(" real
mutate "the pedestal is walk-through" $AR "slab(holder,'Void footing',f.Size,f.Y0,f.Y1,C.Obsidian,Enum.Material.Slate,true,y)" "slab(holder,'Void footing',f.Size,f.Y0,f.Y1,C.Obsidian,Enum.Material.Slate,false,y)" art
mutate "the pedestal is in the wrong place" $RU "R.Center=Vector3.new(0,0,-392)" "R.Center=Vector3.new(0,0,-340)" art
mutate "the beam reaches behind the pack" $AR "local packBottom=Rules.PackHeight-Rules.PackSize/2-Rules.PackBob-.3" "local packBottom=Rules.PackHeight+Rules.PackSize/2" art
mutate "a disc behind the pack" $AR " local packAnchor=anchor('PackAnchor',Rules.PackHeight)" " local back=drum(m,'Pack disc',Rules.PackSize,-1,1,C.Glow,Enum.Material.Neon,y+Rules.PackHeight)
 local packAnchor=anchor('PackAnchor',Rules.PackHeight)" art
mutate "the lettering is on one face only" $AR "for i,face in ipairs({{0,-1,0},{0,1,math.pi},{1,0,-math.pi/2},{-1,0,math.pi/2}})do" "for i,face in ipairs({{0,-1,0}})do" art
mutate "the prompt text is wrong" $RU "R.PromptAction='Grab ur FREE Void Pack'" "R.PromptAction='Take'" art
mutate "the blizzard drifts are not kept off" $AR " game:GetService('CollectionService'):AddTag(m,'SnowAvoid')" "" art
mutate "the plaques lie in the column's plane (z-fighting)" $AR "Plaque={W=4*K,H=1.6*K,D=.12*K,Y=4.55*K,Out=.03*K}" "Plaque={W=4*K,H=1.6*K,D=.12*K,Y=4.55*K,Out=-.06*K}" zfight
mutate "the capital top shares a face with the capital" $AR "Top={Size=7.2*K,Y0=7.4*K,Y1=7.76*K}" "Top={Size=6.4*K,Y0=7.4*K,Y1=7.4*K}" zfight
mutate "the sign is sized in pixels" $CLI "gui.Size=UDim2.fromScale(Rules.Sign.W,Rules.Sign.H)" "gui.Size=UDim2.fromOffset(300,120)" client
mutate "the sign keeps growing up close" $CLI "gui.DistanceLowerLimit=Rules.SignNear;" "" client
mutate "the sign is hidden from afar" $CLI "gui.MaxDistance=Rules.SignFar" "gui.MaxDistance=60" client
mutate "the number does not pop" $CLI " entry.Pop.Scale=big and 1.3 or 1.18" " entry.Pop.Scale=1" client
mutate "reduced motion still pops" $CLI " if reduced()or not entry.Pop then return end" " if not entry.Pop then return end" client
mutate "CLAIMED is not shown" $CLI " if mine=='Claimed'then note,color=Rules.Mine,RGB(126,240,170)" " if false then note,color=Rules.Mine,RGB(126,240,170)" client
mutate "the prompt stays on after you claimed" $CLI "local want=entry.Model:GetAttribute(A.State)=='Open'and player:GetAttribute(A.Player)=='Open'" "local want=entry.Model:GetAttribute(A.State)=='Open'" client
mutate "ALL CLAIMED is not shown" $CLI "set(entry.Title,'Text',done and Rules.TitleDone or Rules.Title)" "set(entry.Title,'Text',Rules.Title)" client
mutate "the pack does not turn" $CLI "if not rm then entry.Spin=((entry.Spin or 0)+dt*Rules.PackSpin)%(math.pi*2)end" "" client
mutate "reduced motion still moves the pack" $CLI " if rm then -- reduced motion" " if false then -- reduced motion" client
mutate "the effects are left behind (not moved with the pack)" $CLI " if r.Fx then PackFx.Pulse(r,now,rm);PackFx.Step(r,now,frame,tierNow,rm,true,parts,frames)end" " if r.Fx then PackFx.Pulse(r,now,rm)end" client
mutate "the pack is the track's (tagged: a second owner)" $CLI "CS:RemoveTag(bag,'BiomeSeedPackVisual')" "" client
mutate "the pack is built by hand, not the game's art" $CLI " return Visuals.Bag(at,packFolder(),scale,nil,Rules.Pack.Stage,Rules.Pack.BagVariant,1,1,'None')" " error('no art')" client
mutate "a far pedestal keeps its frame loop" $CLI " if not busy and loop then loop:Disconnect();loop=nil end" "" client
mutate "a joining player hears the chime" $CLI " if type(at)~='number'or math.abs(workspace:GetServerTimeNow()-at)>20 then return end" " if type(at)~='number'then return end" client
mutate "the chime is not played" $CLI " if Audio then pcall(Audio.Play,'GemClaim')end" "" client
mutate "no spark burst" $CLI "  if fx and not reduced()then pcall(function()fx.Nebula:Emit(16);fx.Stars:Emit(28)end)end" "" client
mutate "a removed pedestal keeps its pack" $CLI " dropPack(entry);if entry.Gui then entry.Gui:Destroy()end" " if entry.Gui then entry.Gui:Destroy()end" client
mutate "the sign is built before its anchor exists" $CLI " if entry.SignAnchor and not(entry.Gui and entry.Gui.Parent)then buildSign(entry)end" " if not(entry.Gui and entry.Gui.Parent)then buildSign(entry)end" client
mutate "tier 2 steps the pack every frame out of view" $CLI "if tierNow>=3 or entry.Owed>=STEP_LOW-.004 or inView(entry)then" "if true then" client
mutate "tier 2 steps at 30 Hz in view (R153)" $CLI "if tierNow>=3 or entry.Owed>=STEP_LOW-.004 or inView(entry)then" "if tierNow>=3 or entry.Owed>=STEP_LOW-.004 then" client
mutate "the 30 Hz step loses the time it skipped" $CLI "local step=entry.Owed;entry.Owed=0" "local step=dt;entry.Owed=0" client
mutate "the Highlight is on every tier" $CLI "PackFx.Create(r,tierNow,tierNow<3)" "PackFx.Create(r,tierNow)" client
mutate "the main script starts it unguarded" ServerScriptService/ChestChaseServerMain.server.lua "pcall(function()require(modules.VoidGiveaway152).new(" "(function()require(modules.VoidGiveaway152).new(" wiring
mutate "voidgift is a per-player command" ServerScriptService/ChestChaseServer/OwnerCommandTargets82.lua "or s:match('^voidgift')~=nil or" "or" wiring
mutate "a new sound asset" $CLI "local Audio;pcall(" "local SOUND='rbxassetid://1234567';local Audio;pcall(" wiring
mutate "the giveaway uses SetAsync" $ST "function S:Status()" "function S:Wipe()self.Store:SetAsync(self.Key,nil)end
function S:Status()" wiring
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
