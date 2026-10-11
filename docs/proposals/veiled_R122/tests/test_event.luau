--!nocheck
-- R122 Veiled One event: real VeiledEvent81 + real ConcurrentKeeperService flow (Begin/_acceptSeed/Finish/
-- drops/_beginBiomeRefresh/_updateBiomeRefresh) on the Roblox mock. ChaseService (Legacy), ChestService,
-- MapService and player data are small fakes; the real SeedPackRules / PackSchedule81 roll and schedule.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Mock gaps used by the server code.
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='ProximityPrompt'then o._props.Triggered=R.signal()end
 if class=='RemoteEvent'then o._props.OnClientEvent=R.signal();o._props.OnServerEvent=R.signal()end
 return o end end
local fired={}
R.Inst.FireAllClients=function(self,...)fired[#fired+1]={Remote=self.Name,Args={...}}end
R.Inst.FireClient=function()end
-- Stubs for the ChestChaseServer siblings and the keeper rig.
local RS=W.RS;local SSS=W.service('ServerScriptService')
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local function serverModule(name,source)local m=R.new('ModuleScript');m.Name=name;m._source=source;m.Parent=folder;return m end
local function serverStub(name,value)W.stub(name,value);local m=R.new('ModuleScript');m.Name=name;m._stubbed=true;m.Parent=folder;return m end
serverStub('RagdollService',{new=function()return {Clear=function()end,CanHit=function()return true end,Apply=function()return {}end}end})
serverStub('KeeperContact',{Touching=function()return false end})
serverStub('BatService',{new=function()return {Start=function()end,CleanupPlayer=function()end}end})
serverStub('SecurityGate',{Allow=function()return true end})
serverStub('MovementGuard',{Check=function()return true end,Reset=function()end})
local keeperBuilds=0
W.stub('VeiledKeeper81',{Build=function(home,parent)keeperBuilds+=1
 local m=R.new('Model');m.Name='TheVeiledOne';local root=R.new('Part');root.Name='VeiledRoot';root.CFrame=home;root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('VeiledKeeper81',true);m:SetAttribute('GuardianBehavior','GUARDING');m.Parent=parent;return m end,Apply=function()end,Frames=function()return nil end})
local K=serverModule('ConcurrentKeeperService','ConcurrentKeeperService');serverModule('VeiledEvent81','VeiledEvent81')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local Rules=W.module('SeedPackRules');local Schedule=W.module('PackSchedule81')
-- Map, chests and players.
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='Runtime';runtime.Parent=mapRoot
local ground=R.new('Part');ground.Name='BiomeGround_7';ground.Size=V3(180,2,600);ground.CFrame=CF(0,0,1000);ground.Parent=mapRoot
local Map={MapRoot=mapRoot,RuntimeFolder=runtime,Chests={},Refreshing=false,GuardiansByStage={}}
function Map:SetBiomeRefreshing(on)self.Refreshing=on==true;mapRoot:SetAttribute('BiomesRefreshing',on==true)end
function Map:IsInsideBiomeTrack(p)return p.Z>500 and p.Z<1400 end
function Map:GetRefreshReturnCFrame()return CF(0,5,0)end
local banked={};local bankRefuse=false
local Chests={PackRandom=W.env.Random.new(7)}
function Chests:_packGround()return ground end
function Chests:GetPackPickupPosition(_,fallback)return fallback end
function Chests:IsOpening()return false end
function Chests:SkinWorldSeeds()end
function Chests:SetWorldPacksClosed()end
function Chests:SetWorldPackAvailable(seed,available)
 seed.Available=available==true;seed.Prompt.Enabled=seed.Available and not Map.Refreshing
 seed.Model:SetAttribute('PackVisible',seed.Available and not Map.Refreshing)
end
function Chests:RefreshWorldPack(seed,variant,size,coat)
 seed.BagVariant=variant or'Pack01'
 seed.PackSize=size and Rules.SanitizePackSize(size)or Rules.RollPackSize(self.PackRandom:NextNumber())
 seed.PackMutation=coat and Rules.MutationKey(coat)or Rules.RollMutation(self.PackRandom:NextNumber())
 seed.Generation=(seed.Generation or 0)+1;seed.Refreshed=(seed.Refreshed or 0)+1
 local old=seed.Model:FindFirstChild('SeedPacket');if old then old:Destroy()end
 local packet=R.new('Model');packet.Name='SeedPacket';packet:SetAttribute('BagVariant',seed.BagVariant);packet.Parent=seed.Model
 self:SetWorldPackAvailable(seed,true)
end
function Chests:Bank(player,chest)if bankRefuse then return nil,'FULL'end;banked[#banked+1]={Player=player,Chest=chest};return {Id=#banked}end
local Players=W.service('Players');local playerList={}
function Players.GetPlayers()return table.clone(playerList)end
local function newPlayer(name,id)
 local p=R.new('Player');p.Name=name;p.UserId=id;p.Parent=Players
 local c=R.new('Model');c.Name=name;local hum=R.new('Humanoid');hum.Health=100;hum.Parent=c
 local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(0,5,950);hrp.Parent=c;c.PrimaryPart=hrp;c.Parent=W.workspace;p.Character=c
 table.insert(playerList,p);return p
end
-- ChaseService stand-in (Legacy): only the hooks ConcurrentKeeperService calls.
local Legacy={}
function Legacy:_clearRunEffects()end;function Legacy:_restorePhysicalSpeed()end;function Legacy:_setGuardianNoticeVisual()end
function Legacy:_getGuardianSettings()return {MinimumSpeed=20}end;function Legacy:_getGuardianHomeCFrame()return CF()end
function Legacy:_crossedBoundary(p)return p.Z<500 end
function Legacy:_applyGuardianFling()end;function Legacy:_updateReturningGuardians()end;function Legacy:_maintainGuardians()end
function Legacy:_publishRunEffects()end
function Legacy:_getGroundedDropPosition(run)return run.HumanoidRootPart.Position end
function Legacy:_createCarriedChest(character)local m=R.new('Model');m.Name='CarriedSeed';m.Parent=character;return m end
function Legacy:_createDroppedChest(position)
 local m=R.new('Model');m.Name='DroppedPack';local b=R.new('Part');b.CFrame=CF(position);b.Parent=m;m.PrimaryPart=b;m.Parent=runtime
 local prompt=R.new('ProximityPrompt');prompt.Parent=b;local label=R.new('TextLabel');label.Parent=b;return m,prompt,label
end
local factory=W.require(K);local Service=factory(Legacy)
local note={}
local self=setmetatable({Runs={},KeeperTargets={},KeeperQueues={},Drops={},Advancing={},Starting={},KnownSeeds={},ReturningGuardians={},
 Map=Map,Chests=Chests,GuardianLeaseSerial=0,DropSerial=0,GuardianMaintenanceAccumulator=0,
 Config={GuardianNoticeDelay=.5,DroppedChestDuration=30,DroppedChestClaimGrace=.35,StageCount=7,FallReturnY=-100},
 PlayerData={IsLoaded=function()return true end,CanReceiveSeed=function()return true end,GetOrCreateSpeedValue=function()return {Value=16}end},
 Bases={GetPlayerBase=function()return {}end},Notifications={Show=function(_,_,text)note[#note+1]=text end},
 RunAlertRemote={FireClient=function()end},PackTaken={FireClient=function()end},
 Ragdoll={Clear=function()end,CanHit=function()return true end,Apply=function()return {}end}},Service)
mapRoot:SetAttribute('BiomeRefreshCycle',0)
self.Event81=W.require(folder.VeiledEvent81).new(self)
local E=self.Event81
-- Drive whole refreshes through the real service: begin at NextRefreshAt, finish after the closed time.
local t=0
self.NextRefreshAt=0;mapRoot:SetAttribute('NextBiomeRefreshAt',R.clock+Rules.RefreshInterval)
-- Refreshes BEGIN every RefreshInterval (server time attribute NextBiomeRefreshAt) and stay closed RefreshClosedSeconds.
local function toNextBegin()
 local dt=(mapRoot:GetAttribute('NextBiomeRefreshAt')or R.clock)-R.clock
 t+=dt;R.advance(dt);self.NextRefreshAt=t
end
local function refresh()
 toNextBegin()
 self:_updateBiomeRefresh(t);check(Map.Refreshing,'refresh closed the track')
 t+=Rules.RefreshClosedSeconds;R.advance(Rules.RefreshClosedSeconds);self:_updateBiomeRefresh(t)
 check(not Map.Refreshing,'refresh reopened the track')
 return mapRoot:GetAttribute('BiomeRefreshCycle')
end
local function slots()return E:LiveSlots()end
local function keeper()return E.Guardian end
local function arrivals()local n=0;for _,f in ipairs(fired)do if f.Remote=='VeiledArrival81'then n+=1 end end;return n end
-- Conservation: every event pack is in exactly one place (slot / carried / dropped / banked).
local total=0
local function conserved(label)
 local inSlot,carried,dropped=0,0,0
 for _,s in ipairs(E.Slots)do if not s.Stolen and s.Available then inSlot+=1 end end
 for _,run in pairs(self.Runs)do if run.Chest.EventKeeper then carried+=1 end end
 for _,d in pairs(self.Drops)do if d.Chest.EventKeeper and not d.Claimed then dropped+=1 end end
 local bank=0;for _,b in ipairs(banked)do if b.Chest.EventKeeper then bank+=1 end end
 return check(inSlot+carried+dropped+bank==total,label..': packs conserved (slot '..inSlot..' carried '..carried..' dropped '..dropped..' banked '..bank..' of '..total..')')
end
local function take(player,slot)
 local hrp=player.Character.HumanoidRootPart;hrp.CFrame=CF(slot.Body.Position.X,5,slot.Body.Position.Z)
 self:Begin(player,slot);return self.Runs[player]
end
local function escape(player)local run=self.Runs[player];player.Character.HumanoidRootPart.CFrame=CF(0,5,100);self:Finish(true,false,run);return run end
-- 1) Spawns at the first scheduled refresh (cycle 3) with TWO packs.
print('-- spawn');for _=1,2 do refresh()end
check(not E:Active()and keeper()==nil,'no event before cycle 3')
check(type(mapRoot:GetAttribute('VeiledNextAt'))=='number','next arrival published while idle')
local predicted=mapRoot:GetAttribute('VeiledNextAt')
local cycle=refresh()
check(cycle==3 and E:Active(),'event active at cycle 3')
check(math.abs((mapRoot:GetAttribute('VeiledArrivalAt')or -1)-predicted)<1e-6,'VeiledNextAt predicted the real arrival time ('..tostring(predicted)..' vs '..tostring(mapRoot:GetAttribute('VeiledArrivalAt'))..')')
check(mapRoot:GetAttribute('VeiledNextAt')==nil,'no next-arrival time while the Veiled One is here')
check(#E.Slots==2 and #slots()==2,'two secret packs spawned');total=2
for i,s in ipairs(E.Slots)do
 check(s.BagVariant=='EclipseReliquary'and s.EventKeeper and s.Available and self.KnownSeeds[s],'slot '..i..' is an available Void Pack')
end
check(E.Slots[1].Body.Position.X~=E.Slots[2].Body.Position.X,'the two packs stand apart')
check(keeperBuilds==1 and keeper()and keeper().Parent,'one keeper built')
check(mapRoot:GetAttribute('VeiledPacksLeft')==2,'packs-left attribute 2')
check(arrivals()==1 and type(fired[#fired].Args[3])=='number','arrival remote fired once with a server timestamp')
conserved('spawn')
-- 2) Survives refreshes; no second event while active; after 3 unstolen refreshes the packs reroll.
print('-- survive + reroll');local k0=keeper();local before={}
for i,s in ipairs(E.Slots)do before[i]={Key=E.VariationKey(s),Gen=s.Generation,Model=s.Model}end
refresh();check(keeper()==k0 and k0.Parent~=nil,'keeper survives refresh 1');check(E.Unstolen==1,'counter 1')
refresh();check(keeper()==k0,'keeper survives refresh 2');check(E.Unstolen==2,'counter 2')
for i,s in ipairs(E.Slots)do check(s.Generation==before[i].Gen and s.Model==before[i].Model and s.Available,'slot '..i..' untouched before the 3rd refresh')end
cycle=refresh() -- cycle 6: also a scheduled event cycle
check(cycle==6 and Schedule.Event(6),'cycle 6 is an event cycle')
check(arrivals()==1 and keeperBuilds==1 and keeper()==k0,'no second Veiled One / event while active')
check(E.Unstolen==0,'counter reset after the reroll')
for i,s in ipairs(E.Slots)do
 check(s.Generation==before[i].Gen+1,'slot '..i..' rerolled once');check(s.BagVariant=='EclipseReliquary','slot '..i..' keeps the Void tier')
 check(E.VariationKey(s)~=before[i].Key,'slot '..i..' changed variation ('..before[i].Key..' -> '..E.VariationKey(s)..')')
 check(s.Available and s.Prompt.Enabled,'slot '..i..' open after reroll')
end
check((mapRoot:GetAttribute('VeiledRerollSerial')or 0)==1,'reroll serial published')
conserved('after reroll')
-- 3) Two thieves: FIFO keeper; first bank = steal, keeper stays for the second pack and re-targets.
print('-- steals');local a,b=newPlayer('A',1),newPlayer('B',2)
local s1,s2=E.Slots[1],E.Slots[2]
local runA=take(a,s1);check(runA and self.KeeperTargets.Veiled==runA,'keeper targets the first thief')
check(not s1.Available and not s1.Prompt.Enabled,'taken pack leaves its slot');conserved('carrying 1')
local runB=take(b,s2);check(runB and self.KeeperTargets.Veiled==runA and #self.KeeperQueues.Veiled==1,'second thief queued for the same keeper')
conserved('carrying 2')
escape(a);check(#banked==1,'first pack banked')
check(E:Active()and keeper()==k0 and keeper().Parent,'keeper stays while one pack remains')
check(self.KeeperTargets.Veiled==runB,'keeper hands off to the next thief')
check(#slots()==1 and mapRoot:GetAttribute('VeiledPacksLeft')==1 and not self.KnownSeeds[s1],'one pack left; stolen slot retired')
-- 4) Caught -> dropped -> expires during the refresh -> back in its slot (hidden while closed).
print('-- drop + refresh');self:Finish(false,true,runB);conserved('dropped')
local dropCount=0;for _ in pairs(self.Drops)do dropCount+=1 end;check(dropCount==1,'pack dropped')
local gen=s2.Generation
-- Counter: the steal happened since the last refresh, so this refresh does not count.
toNextBegin();self:_updateBiomeRefresh(t)
check(Map.Refreshing and s2.Available and not s2.Prompt.Enabled and s2.Model:GetAttribute('PackVisible')==false,'expired drop went home during the closure, hidden until reopening')
t+=Rules.RefreshClosedSeconds;R.advance(Rules.RefreshClosedSeconds);self:_updateBiomeRefresh(t)
check(E.Unstolen==0,'refresh after a steal keeps the counter at 0')
check(s2.Available and s2.Prompt.Enabled and s2.Generation==gen,'dropped pack returned to its slot through the refresh')
conserved('drop returned')
-- 5) Leaving mid-carry returns the pack; a carrier evacuated by a refresh keeps it (counts as a steal).
print('-- leave mid-carry');local c=newPlayer('C',3);take(c,s2);check(not s2.Available,'C carries the last pack')
self:CleanupPlayer(c);check(s2.Available and self.Runs[c]==nil,'leaving returns the pack');conserved('left mid-carry')
refresh();check(E.Unstolen==1,'counter 1 again')
refresh();check(E.Unstolen==2,'counter 2 again')
-- A lost copy (e.g. a drop record vanished) is restored after the refresh; keeper never guards nothing.
take(c,s2);local run=self.Runs[c];self.Runs[c]=nil;self.KeeperTargets.Veiled=nil;run.Finishing=true
check(not s2.Available,'copy lost without being banked')
gen=s2.Generation;local key=E.VariationKey(s2)
refresh() -- 3rd unstolen refresh: restored, then rerolled
check(s2.Available,'lost pack restored after the refresh');check(E.Unstolen==0 and s2.Generation==gen+1 and E.VariationKey(s2)~=key,'remaining pack rerolled after 3 unstolen refreshes')
conserved('restored')
-- Evacuation during a refresh banks the carried pack: that is the last steal -> the keeper leaves.
print('-- last steal');local d=newPlayer('D',4);take(d,s2)
toNextBegin();self:_updateBiomeRefresh(t)
check(#banked==2,'evacuated carrier banked the last pack')
check(not E:Active()and k0.Parent==nil and E.Guardian==nil,'keeper despawned after the last steal')
check(mapRoot:GetAttribute('VeiledEventActive')==false and mapRoot:GetAttribute('VeiledEventClaimed')==true and mapRoot:GetAttribute('VeiledPacksLeft')==0,'event attributes cleared')
check(next(self.KnownSeeds)==nil,'no event slots left registered')
local nextAt=mapRoot:GetAttribute('VeiledNextAt');check(type(nextAt)=='number','next arrival published again (during the refresh)')
t+=Rules.RefreshClosedSeconds;R.advance(Rules.RefreshClosedSeconds);self:_updateBiomeRefresh(t)
cycle=mapRoot:GetAttribute('BiomeRefreshCycle')
check(not E:Active(),'cycle '..cycle..' is not an event cycle, nothing respawns')
conserved('end')
-- The published time is the real next arrival.
while not E:Active()do refresh()end
check(math.abs(mapRoot:GetAttribute('VeiledArrivalAt')-nextAt)<1e-6,'next arrival time was exact ('..nextAt..')')
check(arrivals()==2 and Schedule.Event(mapRoot:GetAttribute('BiomeRefreshCycle')),'a new event only on a scheduled cycle after the last one ended')
-- Bank refused (inventory full) is not a steal: the pack goes home.
print('-- bank refused');total=#banked+2;local e=newPlayer('E',5);local s=E.Slots[1];take(e,s);bankRefuse=true;escape(e);bankRefuse=false
check(s.Available and #slots()==2 and E:Active(),'refused bank returns the pack, no steal');conserved('refused')
-- Forced owner spawn replaces; normal Spawn while active is refused.
check(E:Spawn(9)==false and arrivals()==2,'Spawn while active is refused')
-- Schedule maths.
print('-- schedule');local fake=R.new('Folder')
fake:SetAttribute('BiomeRefreshCycle',3);fake:SetAttribute('NextBiomeRefreshAt',1000)
check(E.NextArrival(fake,false,300,10,Schedule.Event)==1000+10+2*300,'cycle 3 idle -> arrives at the end of refresh 6')
fake:SetAttribute('BiomeRefreshCycle',5);check(E.NextArrival(fake,false,300,10,Schedule.Event)==1010,'cycle 5 -> end of the next refresh')
fake:SetAttribute('BiomeRefreshCycle',5);fake:SetAttribute('BiomeRefreshEndsAt',740);check(E.NextArrival(fake,true,300,10,Schedule.Event)==740,'refreshing into cycle 6 -> end of this refresh')
fake:SetAttribute('BiomeRefreshCycle',6);check(E.NextArrival(fake,true,300,10,Schedule.Event)==1000+10+300,'refreshing into cycle 7 (next begin 1000 -> cycle 8) -> end of refresh 9')
-- R128 (owner): keepers start their swing close, and a swing started close lands at the impact frame, so a keeper next to
-- a thief no longer repeats the animation without hitting. Body contact is stubbed to "never touching" here (the case
-- that used to whiff); running out of range during the windup still dodges.
print('-- strike range')
do
 local Combat=W.module('KeeperCombat')
 local p=newPlayer('Striker',777);local hrp=p.Character.HumanoidRootPart
 local k=R.new('Model');k.Name='StrikeKeeper';local core=R.new('Part');core.CFrame=CF(0,5,900);core.Parent=k;k.PrimaryPart=core;k.Parent=W.workspace
 local run={Player=p,Character=p.Character,HumanoidRootPart=hrp,Chaser=k,KeeperKey='strike-test',GuardianLeaseToken=1,Chest={},CatchEnabledAt=0}
 self.KeeperTargets['strike-test']=run;Map.Refreshing=false
 local finishes={};local saveFinish,saveMove=self.Finish,self._moveKeeperToward
 self.Finish=function(_,escaped,caught)finishes[#finishes+1]=caught==true end;self._moveKeeperToward=function()end
 for stage=1,7 do
  run.Stage=stage;run.Attack=nil;table.clear(finishes);local reach,strike=Combat.Get(stage).Reach,Combat.StrikeReach(stage)
  check(strike<reach and math.abs(strike-reach*Combat.TriggerShare)<1e-9,'stage '..stage..': strike range '..strike..' < old reach '..reach)
  hrp.CFrame=CF(0,5,900+(strike+reach)/2);check(self:_beginKeeperAttack(run)==false and run.Attack==nil,'stage '..stage..': no swing between the strike range and the old reach')
  hrp.CFrame=CF(0,5,900+strike-.3);check(self:_beginKeeperAttack(run)==true and run.Attack~=nil,'stage '..stage..': swing starts in strike range')
  R.advance(Combat.Get(stage).Windup+.01);self:_stepKeeperAttack(run,.05)
  check(#finishes==1 and finishes[1]==true,'stage '..stage..': the swing lands although the bodies never overlap (no whiff loop)')
  run.Attack=nil;table.clear(finishes);run.CatchEnabledAt=0
  hrp.CFrame=CF(0,5,900+strike-.3);self:_beginKeeperAttack(run)
  hrp.CFrame=CF(0,5,900+strike+Combat.HitPadding+2);R.advance(Combat.Get(stage).Windup+.01);self:_stepKeeperAttack(run,.05)
  check(#finishes==0 and run.Attack==nil and run.CatchEnabledAt>R.clock,'stage '..stage..': running out of range during the windup still dodges')
  run.CatchEnabledAt=0
 end
 -- Height still matters: a thief far above the keeper is not hit.
 run.Stage=1;run.Attack=nil;hrp.CFrame=CF(0,5+Combat.Get(1).Height+5,900+1);check(self:_beginKeeperAttack(run)==false,'no swing at a thief far above')
 self.Finish,self._moveKeeperToward=saveFinish,saveMove;self.KeeperTargets['strike-test']=nil;k:Destroy()
end
print(('event checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
