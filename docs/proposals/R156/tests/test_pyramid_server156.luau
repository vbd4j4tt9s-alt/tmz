--!nocheck
-- R156 the Desert's secret pyramid, the SERVER, on the Roblox mock with the REAL modules of this checkout: SecretPyramid156 (the map pass and the service),
-- PyramidRules156, PlayerDataService (+ PremiumProgress, InventoryCap155, PackPityData155, PackSizePityData), ChestService.Bank, ChaseService (= the R87
-- ConcurrentKeeperService over the legacy ChaseService: _canTake, _acceptSeed, the keeper queue, Finish, the catch), OwnerUpdateCommands82, OwnerCommandTargets82,
-- the real pack builders (pack_world.luau: the carried pack is SeedPackVisuals.CarryBag with the owner's templates). Faked: the map (a Desert stand-in with the
-- Sunscar Pyramid as the place saves it), the DataStore, notifications, the ragdoll (it records the hit), the base.
--  1. the map pass: the Sunscar Pyramid measured and replaced at its spot, same folder / name, 60 + 1 parts, walk-through, the zone on the anchor
--  2. the prompt: the world packs' "Hold E to steal" (STEAL, E, Config.StealHoldSeconds), RequiresLineOfSight off, MaxActivationDistance = the zone's reach
--  3. joining: a new save, a save from before R156, a broken saved field: all 'Open'
--  4. reach: the four sides and the four corners at ground level and the steps take it; twice the reach, the far side of the track and a hut 2 studs
--     outside the zone do not (the server's check; the prompt's own distance too)
--  5. the take: the normal steal checks run, the carry is a Desert Mythic world pack (every field of a Pack06 world pack's record), the Sand Snake (the stage 2
--     keeper) chases it, 'Out'; a second trigger (spam, carrying) does nothing
--  6. caught by the snake: the hit lands, NOTHING drops on the track, the pack is back in the pyramid ('Open', not claimed), the player can take it again;
--     a bat, lightning, a hole, a fall, leaving the game: the same (each its own notice)
--  7. banked at base: the record in the Bag (Pack06, Stage 2, size from the normal pack-size pity, coat None, today's odds), the claim saved, 'Claimed'; the
--     pack pity counts it like a world pack (opening it moves the Normal count)
--  8. a claimed player's trigger does nothing (no run, no record)
--  9. the 200 cap: a full bag refuses the pickup with the full-bag notice, nothing changes
-- 10. one each: a second player gets their own; nobody gets two
-- 11. save / load: the claim survives a save and a load in another server; an old save loads; the refresh closure refuses a trigger
-- 12. the owner command: /test pyramid status, /test pyramid @name reset (the owner's word order), and the claim back
-- 13. the biome refresh (R157 review fix): the refresh banks every carrier it finds (the evacuation in the track, the stale-runs loop outside it) and its time is public,
--     so a secret carry is ended first as NOT banked: back in the pyramid, not claimed, not saved, not in the Bag, nothing dropped, the keeper released, the 'Refresh'
--     notice; a normal pack is banked as before; Hold E is refused (nothing changed, a notice) while the refresh runs and within Rules.RefreshGuard seconds before it
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
function Players.GetPlayerFromCharacter(_,c)for _,p in pairs(present)do if p.Character==c then return p end end;return nil end
function W.workspace.Raycast()return nil end -- (no physics: a drop would land 2.25 under the body)
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
DS.GetOrderedDataStore=DS.GetDataStore
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
local fired={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(_,p,...)fired[#fired+1]={Remote=o.Name,P=p,Args={...}}end;o.FireAllClients=function()end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 if class=='Humanoid'then o.Died=R.signal();o.Health=100;o.PlatformStand=false;o.WalkSpeed=16 end
 return o end end
R.Inst.UnequipTools=function()end;R.Inst.EquipTool=function()end
local Config=server('Config');local PackRules=W.module('SeedPackRules');local Rules=W.module('PyramidRules156');local Pity=W.module('PackPity155')
local Pyr=server('SecretPyramid156');local ChestService=server('ChestService');local ChaseService=server('ChaseService')
local G=Rules.Geometry()

-- 1. The map pass ---------------------------------------------------------------------------------------------------------------------------------------------
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='ChestChaseRuntime';runtime.Parent=mapRoot
local landmarks=R.new('Folder');landmarks.Name='MythicLandmarks';landmarks.Parent=mapRoot
-- the Sunscar Pyramid as the owner's place holds it after TrackExpansion83 (BiomeVisuals V79 x 1.12, turned -90 degrees; runtime Z 1005)
local old=R.new('Model');old.Name='Biome2_Landmark';old:SetAttribute('LandmarkName','Sunscar Pyramid');old:SetAttribute('Stage',2);old.Parent=landmarks
for i=0,8 do
 local p=R.new('Part');p.Name='PyramidTier';p.Size=V3(44.8-4.48*i,3.92,44.8-4.48*i);p.CFrame=CF(-62.0675,5.96+3.92*i,1005)*R.CFrame.Angles(0,-math.pi/2,0);p.Parent=old
end
local door=R.new('Part');door.Name='RecessedDoor';door.Size=V3(7.84,10.08,.28);door.CFrame=CF(-39.51,9.04,1005)*R.CFrame.Angles(0,-math.pi/2,0);door.Parent=old
local model=Pyr.Apply(mapRoot)
check(model and model.Parent==landmarks and model.Name=='Biome2_Landmark'and model:GetAttribute('PyramidVersion')==156 and model:GetAttribute('LandmarkName')=='Classic Pyramid',
 'the map pass builds the Classic Pyramid in MythicLandmarks under the old name (Biome2_Landmark)')
check(old.Parent==nil and #landmarks:GetChildren()==1,'... and only then removes the Sunscar Pyramid (nothing else in the folder)')
local parts,anchor={},nil
for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then if d.Name==Rules.AnchorName then anchor=d else parts[#parts+1]=d end end end
check(#parts==60 and G.Parts==60 and anchor~=nil,'60 Limestone parts (1 floor, 14 rings of 4 walls, 3 caps) and one invisible part at the pack ('..#parts..')')
local floor=model:FindFirstChild('Slab01')
check(floor and near(floor.Position.X,-62.0675,1e-4)and near(floor.Position.Z,1005,1e-4)and near(floor.Position.Y-floor.Size.Y/2,4,1e-4),'it stands on the Sunscar Pyramid\'s spot: base centre (-62.07, 1005), foot on its ground (4)')
check(near(model:GetAttribute('OldWidth'),44.8,1e-4)and near(G.Width,44.8,.01),('the old footprint was %.2f wide; the new base is %.3f (scale %.4f)'):format(model:GetAttribute('OldWidth')or -1,G.Width,G.Scale))
local walkable=true;for _,p in ipairs(parts)do if p.CanCollide or not p.Anchored or p.CanTouch then walkable=false end end
check(walkable,'every part is anchored and walk-through (no collisions, no touches), like every landmark (WalkthroughProps90, R95)')
check(anchor.Transparency==1 and not anchor.CanCollide and not anchor.CanQuery and W.CS:HasTag(anchor,Rules.Tag),'the pack\'s part is invisible, collides with nothing and carries the client\'s tag')
local zone=Rules.ReadZone(anchor)
check(zone and near(zone.Center.X,-62.0675,1e-4)and near(zone.Center.Y,4,1e-4)and near(zone.Pack.Y,4+G.FloorTop+Rules.Lift,1e-4)and near(zone.Reach,G.Reach),'the zone is written on the anchor (centre, top, pack, reach)')
check(Pyr.Apply(mapRoot)==model,'the pass again: the same model (it is built once)')
-- (no old pyramid: the fallback spot)
do local m2=R.new('Folder');m2.Name='Map2';m2.Parent=W.workspace
 local built=Pyr.Apply(m2);local f=built:FindFirstChild('Slab01')
 check(built.Parent and built.Parent.Name=='MythicLandmarks'and near(f.Position.X,Rules.Fallback.X,1e-4)and near(f.Position.Z,Rules.Fallback.Z,1e-4),'without the old pyramid it stands on the fallback spot (the runtime landmark position)')
 m2:Destroy()
end

-- The services --------------------------------------------------------------------------------------------------------------------------------------------------
local boundary=R.new('Part');boundary.Name='BaseBoundaryLine';boundary.Size=V3(180,1,1);boundary.CFrame=CF(0,4,-100);boundary.Parent=mapRoot
local Map={MapRoot=mapRoot,RuntimeFolder=runtime,Chests={},ChestsByStage={},GuardiansByStage={},Refreshing=false,BaseBoundaryLine=boundary,ObbyStartPad=boundary,
 GetStageAccent=function()return R.Color3.new(.5,.5,.5)end,ResetCourse=function()end,IsInsideBiomeTrack=function(_,p)return p.Z>-100 end,
 SetBiomeRefreshing=function(self,on)self.Refreshing=on==true end,GetRefreshReturnCFrame=function()return CF(0,5,-150)end}
function Map:CreateRuntimePart(props)local p=R.new('Part');for k,v in pairs(props)do if k~='Parent'then p[k]=v end end;p.Parent=props.Parent or runtime;return p end
local KeeperNames=W.module('KeeperRigConfig152')
local function keeper(stage,at)
 local m=R.new('Model');m.Name=KeeperNames.Stages[stage].Name;local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(4,4,4);root.CFrame=at;root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('Stage',stage);m.Parent=mapRoot;return m
end
local snake=keeper(2,CF(70,8,855));Map.GuardiansByStage[2]=snake
local shown={};local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local function lastNote(p)for i=#shown,1,-1 do if shown[i].P==p then return shown[i].Text end end end
local Data=server('PlayerDataService').new(Config,Map,Notes)
local Chests=setmetatable({PlayerData=Data,Map=Map,Config=Config,Openings={}},{__index=ChestService})
function Chests:SyncTools()end;function Chests:IsOpening()return false end
local Bases={GetPlayerBase=function()return {}end,TrainingSessions={}}
local chase=ChaseService.new(Config,Map,Data,Bases,Chests,Notes)
local hits={};chase.Ragdoll={Clear=function()end,CanHit=function()return true end,IsActive=function()return false end,Apply=function(_,p,v,why)hits[#hits+1]={P=p,Why=why};return {}end}
R.clock=1000
local svc=Pyr.new(Config,Data,Chests,chase,Notes,Map,{NoLoop=true,Clock=function()return R.clock end}):Start()
check(Pyr.Current==svc and chase.Pyramid156==svc and Chests.Pyramid156==svc,'the service starts on the built pyramid and hooks into the chase and the bank')

-- 2. The prompt -------------------------------------------------------------------------------------------------------------------------------------------------
local prompt=anchor:FindFirstChild('Steal')
check(prompt and prompt:IsA('ProximityPrompt')and prompt.ActionText=='STEAL'and prompt.ObjectText==''and prompt.KeyboardKeyCode==R.Enum.KeyCode.E and prompt.HoldDuration==Config.StealHoldSeconds and Config.StealHoldSeconds==1,
 'the prompt is the world packs\' "Hold E to steal": STEAL, key E, held '..tostring(prompt and prompt.HoldDuration)..' s (Config.StealHoldSeconds, R125)')
check(prompt.RequiresLineOfSight==false and near(prompt.MaxActivationDistance,zone.Reach)and near(zone.Reach,math.ceil((G.Half*math.sqrt(2)+6)*10)/10),
 ('RequiresLineOfSight off (it works through the walls); reach %.1f = the base\'s half-diagonal %.2f + 6'):format(prompt.MaxActivationDistance,G.Half*math.sqrt(2)))

-- 3. Joining ------------------------------------------------------------------------------------------------------------------------------------------------------
local function character(p,at)
 local char,hrp=H.character('R15',at or CF(-62,7,960));local hum=R.Instance.new('Humanoid');hum.Parent=char;char.Name=p.Name;p.Character=char
 hum.UnequipTools=function()end
 return char,hrp
end
local function makePlayer(id,name,data)
 data=data or Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p);svc:_hook(p);assert(data:Load(p),'load '..name);data.CanSave[p]=true
 R.advance(.1) -- (the deferred setup after DataStatus = Loaded)
 return p
end
local A=makePlayer(701,'Ava')
check(A:GetAttribute(Rules.Attr)=='Open','a new player: the pack is in the pyramid for them (\'Open\')')
-- an old save (an R155 profile: no Secrets156) and a broken field
for key,data in pairs({Player_702={Version=22,Premium={Version=2,Gems=0,Entitlements={},Biomes={},Receipts={}}},Player_703={Version=22,Premium={Version=2,Gems=0,Entitlements={},Biomes={},Receipts={},Secrets156=5}}})do
 for _,s in pairs(stores)do s.Data[key]=data end
end
local Old=makePlayer(702,'Olly');local Odd=makePlayer(703,'Oddie')
check(Old:GetAttribute(Rules.Attr)=='Open'and Data:IsLoaded(Old),'a save from before R156 loads, the pack is there for them')
check(Odd:GetAttribute(Rules.Attr)=='Open'and Data:GetPremium(Odd).Secrets156==nil,'a broken saved field (Secrets156 = 5) loads as not claimed and is dropped')

-- 4. Reach ------------------------------------------------------------------------------------------------------------------------------------------------------
local C0=zone.Center;local half=G.Half
local ground=C0.Y+3 -- (a standing body's root: 3 studs over the floor)
local spots={
 {'north side',V3(C0.X,ground,C0.Z+half+3)},{'south side',V3(C0.X,ground,C0.Z-half-3)},{'east side',V3(C0.X+half+3,ground,C0.Z)},{'west side (by the wall)',V3(C0.X-half-3,ground,C0.Z)},
 {'NE corner',V3(C0.X+half+2,ground,C0.Z+half+2)},{'NW corner',V3(C0.X-half-2,ground,C0.Z+half+2)},{'SE corner',V3(C0.X+half+2,ground,C0.Z-half-2)},{'SW corner',V3(C0.X-half-2,ground,C0.Z-half-2)},
 {'the 4th step',V3(C0.X+half-3*G.SlabHeight,C0.Y+4*G.SlabHeight+3,C0.Z)},{'the top',V3(C0.X,C0.Y+G.Top+3,C0.Z)},{'inside, by the pack',V3(C0.X+3,ground,C0.Z)},
}
local reachOk=true;local worst=0
for _,s in ipairs(spots)do
 local ok=Rules.InZone(zone,s[2],0);local d=(s[2]-zone.Pack).Magnitude;worst=math.max(worst,d)
 if not ok or d>prompt.MaxActivationDistance then reachOk=false;print('  not reached: '..s[1]..(' (%.2f studs)'):format(d))end
end
check(reachOk,('Hold E reaches from the 4 sides and the 4 corners at ground level, from the steps, the top and inside (farthest %.2f of %.1f studs)'):format(worst,prompt.MaxActivationDistance))
local farOk=true
for _,s in ipairs(spots)do if s[1]:find('side')or s[1]:find('corner')then
 local dir=V3(s[2].X-zone.Pack.X,0,s[2].Z-zone.Pack.Z).Unit;local far=V3(zone.Pack.X,ground,zone.Pack.Z)+dir*(2*zone.Reach)
 if Rules.InZone(zone,far,Rules.Slack)or(far-zone.Pack).Magnitude<=prompt.MaxActivationDistance then farOk=false;print('  reached from twice the distance: '..s[1])end
end end
check(farOk,'... and from none of them at twice the reach (neither the prompt nor the server)')
check(not Rules.InZone(zone,V3(C0.X+half+6+2.5,ground,C0.Z),Rules.Slack)and not Rules.InZone(zone,V3(C0.X+60,ground,C0.Z),Rules.Slack),
 'not from a hut 2.5 studs outside the zone, not from across the track (the zone is the base + 6 studs; nothing else stands in it on the map: pyramid_map156)')
check(not Rules.InZone(zone,V3(C0.X,C0.Y+G.Top+6+Rules.Slack+1,C0.Z),Rules.Slack)and not Rules.InZone(zone,V3(C0.X,C0.Y-Rules.Below-Rules.Slack-1,C0.Z),Rules.Slack),'not from high above the top or deep under the ground')

-- 5. The take ------------------------------------------------------------------------------------------------------------------------------------------------------
local function standAt(p,pos)local char=p.Character;if not char then char=character(p)end;char.HumanoidRootPart.CFrame=CF(pos.X,pos.Y,pos.Z)end
local function take(p,pos)standAt(p,pos or V3(C0.X,ground,C0.Z-half-3));R.clock+=Rules.Cooldown+.01;return svc:Trigger(p)end
character(A)
local beforeRecords=#Data:GetChestRecords(A)
local okFar,whyFar=take(A,V3(C0.X,ground,C0.Z-2*zone.Reach))
check(not okFar and tostring(whyFar):find('far')and chase.Runs[A]==nil and A:GetAttribute(Rules.Attr)=='Open','a trigger from twice the reach does nothing ('..tostring(whyFar)..')')
local okTake,whyTake=take(A)
local run=chase.Runs[A]
check(okTake and run~=nil,'a trigger next to the base takes the pack ('..tostring(whyTake)..')')
if not run then error('no run: the rest cannot be checked ('..tostring(whyTake)..')')end
-- the record is a Desert Mythic world pack's: what ChestService:RefreshWorldPack writes on a Pack06 slot (size 1, plain)
local want={Kind='Pack',Stage=2,BagVariant='Pack06',PackSize=1,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion,SeedScale=PackRules.NewSeedScale(2,'Pack06',1),PackShape=0}
local same=true;for k,v in pairs(want)do if run.Chest[k]~=v then same=false;print('  field '..k..': '..tostring(run.Chest[k])..' (want '..tostring(v)..')')end end
check(same and run.Chest.Pyramid156==A.UserId,'the carried record is a Desert Mythic world pack (Stage 2, Pack06 = the Mythic tier, size 1, coat None, OddsVersion '..tostring(PackRules.OddsVersion)..', its seed scale), marked with its owner')
check(PackRules.GetPackTier('Pack06').Name=='Mythic'and PackRules.DesignKey(2,'Pack06')=='Desert_06','(Pack06 is the Mythic tier; its design is Desert_06)')
check(run.Stage==2 and run.KeeperKey==2 and chase.KeeperTargets[2]==run and run.Chaser==snake and snake.Name=='Sand Snake','the Sand Snake (the stage 2 keeper, KeeperRigConfig152.Stages[2]) chases the carrier, as for a stolen Desert pack')
check(snake:GetAttribute('GuardianBehavior')=='ALERTED'and snake:GetAttribute('TargetUserId')==A.UserId,'... it is alerted and its target is the carrier')
local carried=A.Character:FindFirstChild('CarriedSeed')
check(carried and carried:GetAttribute('BagVariant')=='Pack06'and carried:GetAttribute('Stage')==2 and carried:GetAttribute('PackMutation')=='None','the carry is the real carried pack (SeedPackVisuals.CarryBag: Pack06, Desert, plain)')
check(A:GetAttribute(Rules.Attr)=='Out'and A:GetAttribute('ChestChaseSeedCarrying')==true and lastNote(A)==Rules.Text.Taken,'the player is \'Out\' (their pyramid is empty for them), carrying, and told to run')
check(#Data:GetChestRecords(A)==beforeRecords and not Rules.Claimed(Data:GetPremium(A)),'nothing is in the Bag and nothing is claimed yet (only a bank counts)')
local okSpam,whySpam=svc:Trigger(A)
check(not okSpam and whySpam=='spam'and chase.Runs[A]==run,'a second trigger at once does nothing (spam)')
local okAgain,whyAgain=take(A)
check(not okAgain and whyAgain=='out'and chase.Runs[A]==run,'nor one a second later while carrying it ('..tostring(whyAgain)..')')

-- 6. Caught / lost: back in the pyramid -------------------------------------------------------------------------------------------------------------------------
do -- the hooks sit on this chase object only (the ConcurrentKeeperService class is not changed), once, and every other pack goes to the normal code
 local class=getmetatable(chase)
 check(rawget(chase,'_dropChestAfterCatch')~=nil and rawget(chase,'_returnPackToOrigin')~=nil and class._dropChestAfterCatch~=chase._dropChestAfterCatch
  and class._returnPackToOrigin~=chase._returnPackToOrigin and rawget(chase,'_beginBiomeRefresh')~=nil and class._beginBiomeRefresh~=chase._beginBiomeRefresh
  and Pyr.HookChase(chase)==false,'the catch / return / refresh hooks are on the chase object, once; the class is untouched')
 local calls={}
 local fake=setmetatable({},{__index={_dropChestAfterCatch=function(_,r,h)calls[#calls+1]='drop:'..tostring(h and h.Cause)end,
  _returnPackToOrigin=function(_,c)calls[#calls+1]='back:'..tostring(c.OriginSlot);return true end,
  _beginBiomeRefresh=function(_,now)calls[#calls+1]='refresh:'..tostring(now);return 'went' end}})
 local hooked=Pyr.HookChase(fake)
 fake:_dropChestAfterCatch({Chest={Kind='Pack',OriginSlot='s1'}},{Cause='Bat'});local back=fake:_returnPackToOrigin({Kind='Pack',OriginSlot='s2'})
 local went=fake:_beginBiomeRefresh(77) -- (no service on this object: the refresh code goes straight through)
 check(hooked and calls[1]=='drop:Bat'and calls[2]=='back:s2'and back==true and calls[3]=='refresh:77'and went=='went'and #calls==3,'any other pack: the normal catch (drop on the track), return and refresh code ('..table.concat(calls,', ')..')')
 local noRefresh=pcall(Pyr.HookChase,setmetatable({},{__index={_dropChestAfterCatch=function()end,_returnPackToOrigin=function()end}}))
 check(not noRefresh,'a chase object without refresh code is refused (the hook fails loudly, never silently open)')
end
local drops=0;for _ in pairs(chase.Drops)do drops+=1 end
chase:Finish(false,true,run)
local dropsAfter=0;for _ in pairs(chase.Drops)do dropsAfter+=1 end
check(chase.Runs[A]==nil and dropsAfter==drops and runtime:FindFirstChild('DroppedSeed')==nil,'caught by the snake: nothing is dropped on the track')
check(#hits>0 and hits[#hits].P==A and hits[#hits].Why=='Keeper','... the snake\'s hit lands as usual (the fling)')
check(A:GetAttribute(Rules.Attr)=='Open'and A:GetAttribute('ChestChaseSeedCarrying')==false and lastNote(A)==Rules.Text.Caught and not Rules.Claimed(Data:GetPremium(A)),'... the pack is back in the pyramid for them (\'Open\', not claimed): "'..tostring(lastNote(A))..'"')
check(#Data:GetChestRecords(A)==beforeRecords,'... and not in their Bag')
for _,case in ipairs({{'Bat',{Cause='Bat',ImpactApplied=true},Rules.Text.Bat},{'Lightning',{Cause='Lightning',Center=V3(0,0,0)},Rules.Text.Lightning},{'Hole',{Cause='Hole',ImpactApplied=true},Rules.Text.Lost}})do
 local ok=take(A);local r=chase.Runs[A]
 if ok and r then chase:Finish(false,true,r,case[2])end
 check(ok and r and chase.Runs[A]==nil and A:GetAttribute(Rules.Attr)=='Open'and lastNote(A)==case[3],'a '..case[1]..': back in the pyramid, "'..case[3]..'"')
end
do -- lost: a fall (ReturnFallenCharacter), then leaving mid-carry
 local ok=take(A);chase:ReturnFallenCharacter(A.Character)
 check(ok and chase.Runs[A]==nil and A:GetAttribute(Rules.Attr)=='Open'and lastNote(A)==Rules.Text.Lost,'lost in a fall: back in the pyramid ("'..tostring(lastNote(A))..'")')
 local L=makePlayer(704,'Leo');character(L);local okL=take(L)
 check(okL and L:GetAttribute(Rules.Attr)=='Out','(another player takes it)')
 chase:CleanupPlayer(L);present[704]=nil
 check(chase.Runs[L]==nil and svc.Out[L]==nil and not Rules.Claimed(Data:GetPremium(L)),'leaving the game mid-carry: nothing claimed, the pack is back (they can try again next time)')
end

-- 7. Banked at base -------------------------------------------------------------------------------------------------------------------------------------------------
local luckCalls=0;local rollPackLuck=Data.RollPackLuck
Data.RollPackLuck=function(self,p,...)luckCalls+=1;return rollPackLuck(self,p,...)end
local okBank=take(A);run=chase.Runs[A]
standAt(A,V3(0,7,-120)) -- (over the base line)
chase:Finish(true,false,run)
local records=Data:GetChestRecords(A);local rec=records[#records]
check(okBank and #records==beforeRecords+1 and rec.Kind=='Pack'and rec.Stage==2 and rec.BagVariant=='Pack06'and rec.PackMutation=='None'and rec.OddsVersion==PackRules.OddsVersion and rec.PackShape==nil,
 'banked at base: the Desert Mythic pack is in the Bag (Pack06, Stage 2, plain, OddsVersion '..tostring(rec and rec.OddsVersion)..', the default shape)')
check(luckCalls==1,'the bank went through ChestService:Bank with Luck: the hidden pack-size pity counted it like any world pack ('..luckCalls..' roll)')
check(Rules.Claimed(Data:GetPremium(A))and A:GetAttribute(Rules.Attr)=='Claimed'and lastNote(A)==Rules.Text.Claimed,'... the claim is set (Premium.Secrets156.Pyramid) and published: \'Claimed\'')
check(Data.Dirty[A]==true,'... and the profile is marked to save')
-- the pack pity: opening it moves the Normal count, as a world pack's open does
local before=Data:GetPackPity(A).Normal
local opened,whyOpen=Data:OpenSeedPack(A,rec.Id,function()return .5 end) -- (the roll draws from a function)
if not opened then print('  (the open said: '..tostring(whyOpen)..')')end
check(opened and Pity.Group('Pack06')=='Normal'and Data:GetPackPity(A).Normal==Pity.After(before),('opening it counts for the pack pity like a world pack (Normal %d -> %d)'):format(before,Data:GetPackPity(A).Normal))
Data.RollPackLuck=rollPackLuck

-- 8. A claimed player's trigger ------------------------------------------------------------------------------------------------------------------------------------
local n0=#Data:GetChestRecords(A)
local okClaimed,whyClaimed=take(A)
check(not okClaimed and whyClaimed=='claimed'and chase.Runs[A]==nil and #Data:GetChestRecords(A)==n0 and A:GetAttribute(Rules.Attr)=='Claimed','a claimed player\'s trigger does nothing: no carry, no pack')

-- 9. The 200 cap ------------------------------------------------------------------------------------------------------------------------------------------------------
local B=makePlayer(705,'Ben');character(B)
local serial=0
local function seedRow(p)serial+=1;local s=Config.GetSeedById('SunflowerSeed');return {Id=p.UserId..'_s'..serial,ChestNumber=900000+serial,ChestName=s.Name,Kind='Seed',Stage=1,SeedId=s.Id,SeedName=s.Name,SeedEmoji=s.Emoji,AccentColor=s.Color,SeedScale=1,PackMutation='None',BagVariant='Pack01',OddsVersion=PackRules.OddsVersion,PackSize=1}end
local rows=Data:GetChestRecords(B);while Data:HeldItemCount(B)<200 do rows[#rows+1]=seedRow(B)end;Data:_notifySeedInventory(B)
local okFull,whyFull=take(B)
check(not okFull and chase.Runs[B]==nil and B:GetAttribute(Rules.Attr)=='Open'and svc.Out[B]==nil and lastNote(B)=='BAG FULL - MAKE ROOM IN YOUR BAG FIRST','a full bag (200): the pickup stops with the full-bag notice, nothing changes ('..tostring(whyFull)..')')
table.remove(rows);Data:_notifySeedInventory(B)

-- 10. One each ------------------------------------------------------------------------------------------------------------------------------------------------------
local okB=take(B);local runB=chase.Runs[B]
check(okB and runB and runB.Chest.Pyramid156==B.UserId and A:GetAttribute(Rules.Attr)=='Claimed','a second player takes their own pack (the first stays claimed)')
standAt(B,V3(0,7,-120));chase:Finish(true,false,runB)
local pyramidPacks=function(p)local n=0;for _,r in ipairs(Data:GetChestRecords(p))do if r.BagVariant=='Pack06'and r.Stage==2 then n+=1 end end;return n end
check(B:GetAttribute(Rules.Attr)=='Claimed'and pyramidPacks(B)==1 and pyramidPacks(A)==1,'each has one: Ben banked his, Ava has hers')
local okB2=take(B);check(not okB2 and pyramidPacks(B)==1,'nobody gets two')
-- two triggers in the same frame by a fresh player: one carry
local D=makePlayer(706,'Dot');character(D);standAt(D,V3(C0.X+half+3,ground,C0.Z));R.clock+=2
local t1=svc:Trigger(D);local t2=svc:Trigger(D)
check(t1==true and t2==false and chase.Runs[D]~=nil,'two triggers in one frame: one carry')
chase:Finish(false,false,chase.Runs[D])

-- 11. Save / load -----------------------------------------------------------------------------------------------------------------------------------------------------
Data:MarkDirty(A);local saved=Data:Save(A,'test',true)
check(saved==true,'Ava\'s profile saves')
local raw;for _,s in pairs(stores)do if s.Data['Player_701']then raw=s.Data['Player_701']end end
check(raw and raw.Version==Config.ProfileVersion and Config.ProfileVersion==22 and type(raw.Premium)=='table'and type(raw.Premium.Secrets156)=='table'and raw.Premium.Secrets156.Pyramid==true,
 'saved as the optional field Premium.Secrets156 = {Pyramid = true}; ProfileVersion stays 22')
local Data2=server('PlayerDataService').new(Config,Map,Notes)
local svc2=Pyr.new(Config,Data2,Chests,chase,Notes,Map,{NoLoop=true,Clock=function()return R.clock end})
svc2.Anchor=anchor;svc2.Model=model;svc2.Zone=zone
local A2=R.new('Player');A2.Name='Ava';A2.UserId=701;A2.Parent=Players;present[701]=A2;R.new('Backpack').Parent=A2
function A2.Kick(_,why)error('kicked: '..tostring(why),0)end
Data2:PreparePlayer(A2);svc2:_hook(A2);check(Data2:Load(A2),'the profile loads in another server');R.advance(.1)
check(A2:GetAttribute(Rules.Attr)=='Claimed','after the load she is still \'Claimed\'')
character(A2);standAt(A2,V3(C0.X,ground,C0.Z-half-3));R.clock+=2
local okLoaded,whyLoaded=svc2:Trigger(A2)
check(not okLoaded and whyLoaded=='claimed','... and her trigger does nothing (one per player, ever)')
-- the refresh closure
local Rex=makePlayer(707,'Rex');Map.Refreshing=true;local okRef,whyRef=take(Rex);Map.Refreshing=false
check(not okRef and whyRef=='refresh' and chase.Runs[Rex]==nil,'while the biomes refresh (the track is closed) a trigger does nothing ('..tostring(whyRef)..')')

-- 12. The owner command -------------------------------------------------------------------------------------------------------------------------------------------------
local Targets=server('OwnerCommandTargets82');local Owner=server('OwnerUpdateCommands82')
local body,target=Targets.Split('/test pyramid @Ava reset')
check(body=='/test pyramid reset'and target=='Ava','"/test pyramid @Ava reset" (the owner\'s word order) is the command "pyramid reset" for @Ava')
local b2,t2b=Targets.Split('/test pyramid reset @Ava');check(b2=='/test pyramid reset'and t2b=='Ava','... and so is "/test pyramid reset @Ava"')
local b3,t3=Targets.Split('/test pyramid @Ava');check(b3=='/test pyramid'and t3=='Ava','"/test pyramid @Ava" is the status of @Ava')
check(Owner.Actions.pyramid==true,'pyramid is an owner command (OwnerUpdateCommands82)')
local ctx={Config=Config,Data=Data,Chests=Chests,Chase=chase,Map=Map}
local okS,status=Owner.Execute(ctx,A,'pyramid',{})
check(okS and status:find('@Ava has the secret pack',1,true)and status:find('37.7',1,true)and status:find('Pack06',1,true),'/test pyramid: the status ('..tostring(status):gsub('\n',' | ')..')')
local okR,said=Owner.Execute(ctx,A,'pyramid',{'reset'})
check(okR and not Rules.Claimed(Data:GetPremium(A))and A:GetAttribute(Rules.Attr)=='Open'and Data.Dirty[A]==true,'/test pyramid @Ava reset: the claim is cleared (saved) and the pack is back for her: '..tostring(said))
check(pyramidPacks(A)==1,'... the pack she banked stays in her Bag')
local okT=take(A);check(okT and chase.Runs[A]~=nil,'... and she can take it again')
chase:Finish(false,false,chase.Runs[A])
local okBad,whyBad=Owner.Execute(ctx,A,'pyramid',{'explode'});check(not okBad and tostring(whyBad):find('pyramid @username reset',1,true),'a wrong word gets the usage line')

-- 13. The biome refresh (R157 review fix) ------------------------------------------------------------------------------------------------------------------------------
-- The REAL ConcurrentKeeperService refresh code runs here (_updateBiomeRefresh -> _beginBiomeRefresh: the evacuation of the biome track, the stale-runs loop, the queue
-- reset); only the map, the ragdoll and the notifications are faked. The pyramid is inside the track (Z > -100 here); the hub / base side is Z <= -100.
local function fresh(id,name)local p=makePlayer(id,name);character(p);return p end
local function sawNote(p,text,from)for i=from or 1,#shown do if shown[i].P==p and shown[i].Text==text then return true end end;return false end
local function dropsCount()local n=0;for _ in pairs(chase.Drops)do n+=1 end;return n end
local function nextRefresh(seconds)chase.NextRefreshAt=R.clock+seconds end
local function startRefresh()chase.NextRefreshAt=R.clock;chase:_updateBiomeRefresh(R.clock)end -- (the chase's own step: due now -> _beginBiomeRefresh)
local function endRefresh()Map.Refreshing=false;chase.RefreshEndsAt=nil;nextRefresh(300)end
local function inTrack(p)return Map:IsInsideBiomeTrack(p.Character.HumanoidRootPart.Position)end
local function normalCarry(p,pos) -- a normal (not secret) carry of a Desert Mythic world pack, started the way the steal does it
 standAt(p,pos or V3(C0.X,ground,C0.Z-half-3))
 local c,h,r=chase:_canTake(p,p.Character.HumanoidRootPart.Position)
 if not c then return nil end
 chase.Starting[p]=true
 local rec=svc:Pack(p);rec.Pyramid156=nil
 pcall(chase._acceptSeed,chase,p,rec,c,h,r)
 chase.Starting[p]=nil
 return chase.Runs[p]
end
local function snapshot(p)return{Records=#Data:GetChestRecords(p),Hits=#hits,Drops=dropsCount(),Notes=#shown,Dirty=Data.Dirty[p],Returns=svc.Returns,Banks=svc.Banks}end
local function backInPyramid(p,before,label) -- the carry ended as a loss: nothing banked, nothing claimed, nothing saved, nothing dropped, everything cleaned, the notice
 check(chase.Runs[p]==nil and chase.Starting[p]==nil,label..': the carry is over')
 check(not Rules.Claimed(Data:GetPremium(p))and Data:GetPremium(p).Secrets156==nil and Data.Dirty[p]==before.Dirty and svc.Banks==before.Banks,label..': NOT claimed, nothing to save')
 check(#Data:GetChestRecords(p)==before.Records,label..': nothing in the Bag')
 check(p:GetAttribute(Rules.Attr)=='Open'and svc.Out[p]==nil,label..': the pack is back in the pyramid (\'Open\')')
 check(p:GetAttribute('ChestChaseSeedCarrying')==false and p:GetAttribute('ChestChaseQueued')==false and p:GetAttribute('ChestChaseRunActive')~=true and p.Character:FindFirstChild('CarriedSeed')==nil,
  label..': the carrying attributes and the held pack are cleaned (a normal non-banked end)')
 check(dropsCount()==before.Drops and runtime:FindFirstChild('DroppedSeed')==nil and #hits==before.Hits,label..': nothing dropped on the track, no fling')
 check(sawNote(p,Rules.Text.Refresh,before.Notes+1)and not sawNote(p,Rules.Text.Claimed,before.Notes+1)and svc.Returns==before.Returns+1,label..': told "'..Rules.Text.Refresh..'"')
end
nextRefresh(300)
-- (a) a carrier inside the biome track: the evacuation used to bank the pack (Finish(true))
local P1=fresh(710,'Pia');local ok1=take(P1);local run1=chase.Runs[P1]
check(ok1 and run1 and inTrack(P1)and chase.KeeperTargets[2]==run1 and P1:GetAttribute('ChestChaseSeedCarrying')==true,'(Pia carries the secret pack inside the biome track, the snake after her)')
local b1=snapshot(P1);startRefresh()
check(Map.Refreshing==true and chase.RefreshEndsAt~=nil,'(the refresh is running: the track is closed)')
backInPyramid(P1,b1,'refresh, carrier inside the track')
check(chase.KeeperTargets[2]==nil and snake:GetAttribute('TargetUserId')==0 and #(chase.KeeperQueues[2]or{})==0,'... the snake lets go of her (no keeper lease left over)')
check(P1.Character.CFrame and P1.Character.CFrame.Position.Z<-100,'... and she was moved out like every player in the track (the refresh code still ran: PivotTo to the return spot)')
endRefresh()
local againOk=take(P1);check(againOk and chase.Runs[P1]~=nil and P1:GetAttribute(Rules.Attr)=='Out','... after the refresh she can take it again')
chase:Finish(false,false,chase.Runs[P1])
-- (b) a carrier outside the track (already at the hub): the stale-runs loop used to bank the pack (Finish(true) for a run with a valid character)
local P2=fresh(711,'Pete');take(P2);local run2=chase.Runs[P2];standAt(P2,V3(0,7,-120))
check(run2 and not inTrack(P2),'(Pete carries it and stands outside the biome track, in the hub)')
local b2=snapshot(P2);startRefresh()
backInPyramid(P2,b2,'refresh, carrier outside the track');endRefresh()
-- (c) a normal pack: unchanged (kept = banked, inside the track and outside)
local N1=fresh(712,'Nell');local nrun1=normalCarry(N1);local nb1=snapshot(N1)
check(nrun1 and nrun1.Chest.Pyramid156==nil and inTrack(N1),'(Nell carries a normal pack inside the track)')
local N2=fresh(713,'Nick');local nrun2=normalCarry(N2);standAt(N2,V3(0,7,-120));local nb2=snapshot(N2)
check(nrun2 and not inTrack(N2),'(Nick carries a normal pack and stands in the hub)')
startRefresh()
check(chase.Runs[N1]==nil and #Data:GetChestRecords(N1)==nb1.Records+1 and not Rules.Claimed(Data:GetPremium(N1))and N1:GetAttribute(Rules.Attr)=='Open'and not sawNote(N1,Rules.Text.Refresh,nb1.Notes+1),
 'refresh, normal pack inside the track: kept, as before (banked, one more in the Bag, no pyramid claim, no pyramid notice)')
check(chase.Runs[N2]==nil and #Data:GetChestRecords(N2)==nb2.Records+1 and not Rules.Claimed(Data:GetPremium(N2))and not sawNote(N2,Rules.Text.Refresh,nb2.Notes+1),
 'refresh, normal pack outside the track: kept, as before')
check(svc.Returns==nb1.Returns,'... and the pyramid sent nothing back for them');endRefresh()
-- (d) a mix in one keeper queue: a secret carrier first (the snake's target) and a normal carrier behind, then the other way round
local Q1=fresh(714,'Quin');local Q2=fresh(715,'Quill')
take(Q1);local qa=chase.Runs[Q1];local qb=normalCarry(Q2)
check(qa and qb and chase.KeeperTargets[2]==qa and qb.Chest.Pyramid156==nil,'(Quin carries the secret pack and is the snake\'s target; Quill\'s normal pack waits behind)')
local bq1,bq2=snapshot(Q1),snapshot(Q2);startRefresh()
backInPyramid(Q1,bq1,'refresh, secret carrier first in the queue')
check(chase.Runs[Q2]==nil and #Data:GetChestRecords(Q2)==bq2.Records+1 and not sawNote(Q2,Rules.Text.Refresh,bq2.Notes+1),'... the normal carrier behind her is kept, as before')
check(chase.KeeperTargets[2]==nil and #(chase.KeeperQueues[2]or{})==0 and Q1:GetAttribute('ChestChaseQueued')==false and Q2:GetAttribute('ChestChaseQueued')==false,'... the keeper queue is empty and nobody is left queued');endRefresh()
local R1=fresh(716,'Rosa');local R2=fresh(717,'Rob')
normalCarry(R1);local ra=chase.Runs[R1];take(R2);local rb=chase.Runs[R2]
check(ra and rb and chase.KeeperTargets[2]==ra and rb.Chest.Pyramid156==R2.UserId,'(Rosa\'s normal pack is the snake\'s target; Rob\'s secret pack waits behind)')
local br1,br2=snapshot(R1),snapshot(R2);startRefresh()
backInPyramid(R2,br2,'refresh, secret carrier waiting in the queue')
check(chase.Runs[R1]==nil and #Data:GetChestRecords(R1)==br1.Records+1 and chase.KeeperTargets[2]==nil and #(chase.KeeperQueues[2]or{})==0,'... the normal target is kept, as before; the queue is empty');endRefresh()
-- (e) the owner's test commands start the same refresh on the same object
local S1=fresh(718,'Sia');take(S1);local bs=snapshot(S1)
chase:_beginBiomeRefresh(R.clock)
backInPyramid(S1,bs,'a refresh started by a test command (ctx.Chase:_beginBiomeRefresh)');endRefresh()

-- Hold E near the refresh: refused (nothing changed, a notice), outside the window it works
local G=fresh(720,'Gus')
local function attempt(p,untilRefresh)standAt(p,V3(C0.X,ground,C0.Z-half-3));R.clock+=Rules.Cooldown+.01;if untilRefresh~=nil then nextRefresh(untilRefresh)end;return svc:Trigger(p)end
local function untouched(p,b,label)
 check(chase.Runs[p]==nil and svc.Out[p]==nil and p:GetAttribute(Rules.Attr)=='Open'and #Data:GetChestRecords(p)==b.Records and Data.Dirty[p]==b.Dirty and chase.Starting[p]==nil
  and p:GetAttribute('ChestChaseSeedCarrying')~=true and snake:GetAttribute('TargetUserId')==0 and sawNote(p,Rules.Text.RefreshSoon,b.Notes+1),label..': nothing changed, and the notice "'..Rules.Text.RefreshSoon..'"')
end
check(type(Rules.RefreshGuard)=='number'and Rules.RefreshGuard>=10 and Rules.RefreshGuard<=30,'the guard is '..tostring(Rules.RefreshGuard)..' seconds (R157 review fix)')
local taken0=svc.Taken
for _,case in ipairs({{Rules.RefreshGuard-.5,'the refresh is '..(Rules.RefreshGuard-.5)..' s away'},{Rules.RefreshGuard,'exactly '..Rules.RefreshGuard..' s away (inside the window)'},{3,'3 s away'},{0,'due now'},{-5,'5 s overdue'}})do
 local b=snapshot(G);local ok,why=attempt(G,case[1])
 check(not ok and why=='refresh','a trigger when '..case[2]..' is refused ('..tostring(why)..')');untouched(G,b,'... ')
end
do local b=snapshot(G);Map.Refreshing=true;nextRefresh(300);local ok,why=attempt(G)
 check(not ok and why=='refresh','a trigger while the refresh runs (the track is closed) is refused ('..tostring(why)..')');untouched(G,b,'... ');Map.Refreshing=false
 b=snapshot(G);chase.RefreshEndsAt=R.clock+5;local ok2,why2=attempt(G)
 check(not ok2 and why2=='refresh','... also while only the closing time is set ('..tostring(why2)..')');untouched(G,b,'... ');chase.RefreshEndsAt=nil
end
check(svc.Taken==taken0 and(svc.Refused.refresh or 0)>=7,'... none of them took a pack ('..tostring(svc.Refused.refresh)..' refusals counted)')
local okEdge,whyEdge=attempt(G,Rules.RefreshGuard+.5);local runG=chase.Runs[G]
check(okEdge and runG~=nil and G:GetAttribute(Rules.Attr)=='Out','just outside the window ('..(Rules.RefreshGuard+.5)..' s before the refresh) the trigger works ('..tostring(whyEdge)..')')
local bg2=snapshot(G);startRefresh() -- (the refresh arrives while she carries it)
backInPyramid(G,bg2,'a carry that meets the refresh');endRefresh()
local okFar=attempt(G,300);check(okFar and chase.Runs[G]~=nil,'a refresh 300 s away: the trigger works');chase:Finish(false,false,chase.Runs[G])
chase.NextRefreshAt=nil;local okNil=attempt(G);check(okNil and chase.Runs[G]~=nil,'no refresh time known (the chase has not started its clock): the trigger works');chase:Finish(false,false,chase.Runs[G]);nextRefresh(300)
check(Rules.Text.Refresh:find('BIOMES REFRESHING',1,true)and Rules.Text.Refresh:find('PYRAMID',1,true)and Rules.Text.RefreshSoon:find('REFRESH',1,true),'the two refresh notices say what happened (simple words)')

-- the words players read: simple, "you" / "your" in full
local plain=true
for k,text in pairs(Rules.Text)do local l=' '..text:lower()..' ';if l:find('[^%a]ur[^%a]')or l:find('[^%a]u[^%a]')then plain=false;print('  short word in '..k..': '..text)end end
for _,text in ipairs({status,said,whyBad})do local l=' '..tostring(text):lower()..' ';if l:find('[^%a]ur[^%a]')or l:find('[^%a]u[^%a]')then plain=false;print('  short word: '..tostring(text))end end
check(plain,'every message the pyramid adds says "you" / "your" in full')
print(('R156 pyramid server: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
