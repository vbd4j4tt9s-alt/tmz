--!nocheck
-- R153 (owner: "make it so that players can also roll and open packs whilst on the treadmill"): the REAL server code on the Roblox mock (R151's pack harness, the real
-- PlayerDataService, ChestService:_holdPack / _activatePack / _canOpenPack / _finishOpening, BaseService:_updateTrainingPlayer, TreadmillBonusService, ChaseService:IsPlayerBusy).
--  1. a pack is held, opened with five clicks and revealed while a treadmill session runs; the session, the anchoring and the speed gain are untouched for the whole reveal
--  2. the bonus roll works on the treadmill (also through the remote the client calls); the bonus timer and the speed keep ticking; its own refusals are unchanged
--  3. the other blocks stay (carrying a stolen pack, a chase, queued, ragdolled, flung, PlatformStand, another reveal running, dead), each of them also on the treadmill
-- What blocks them is not the treadmill: nothing in the pack hold / opening or in the roll reads BaseService.TrainingSessions or TreadmillTraining (run_treadmill_open.sh greps it).
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 if class=='Humanoid'then o.Died=R.signal();o.Health=100;o.PlatformStand=false end
 return o end end
R.Inst.UnequipTools=function()end;R.Inst.EquipTool=function()end
local Config=server('Config');local Rules=H.Rules;local Shapes=W.module('PackShapes151')
local ChestService=server('ChestService')
local DEFAULTS={Enabled=true,Force=nil,LoadingSeconds=60,HoldWaitSeconds=2.5,MaxVertices=60000,MaxResidentVertices=400000,HardResidentVertices=600000,GraceSeconds=30,IdleSeconds=900,SweepSeconds=60}
local function fresh()
 Shapes.Reset();Mock.reset();Mock.vertices=200;for k,v in pairs(DEFAULTS)do Shapes.Config[k]=v end;Shapes.Config.Force=nil
end
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Notes={Show=function()end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function character(player)
 local char,hrp,torso=H.character('R15');local hum=R.Instance.new('Humanoid');hum.Parent=char;char.Name=player.Name;player.Character=char
 player.CharacterRemoving=R.signal()
 return char,hrp,torso,hum
end
local function addPack(player,stage,variant)
 local chest={Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion}
 return Data:AddChest(player,chest)
end
local function newSelf()
 -- (a fake ChestService instance with just what the hold reads; _finishOpening is the real one)
 return {PlayerData=Data,Config=Config,Openings={},SyncTools=function()end,_holdPack=ChestService._holdPack,_activatePack=ChestService._activatePack,_canOpenPack=ChestService._canOpenPack,
  _finishOpening=ChestService._finishOpening}
end


-- (header above: the R151 pack harness + the real PlayerDataService, as in R152's test_hold_race.luau)
local Base=server('BaseService');local Bonus=server('TreadmillBonusService');local Chase=server('ChaseService')
local PackRules=W.module('SeedPackRules');local BonusRules=W.module('TreadmillBonusRules')

-- A real treadmill session: BaseService:_updateTrainingPlayer (the real one, as in R140's test) around a stand-in "self"; the busy checker is ChaseService's own.
local P=makePlayer(701,'Runner');local char,hrp,torso,hum=character(P);local backpack=P:FindFirstChildOfClass('Backpack')
hum.Sit=false;hum.Jump=false;hum.WalkSpeed=16
local belt=R.new('Part');belt.Name='Belt';belt.Parent=R.new('Folder');local record={Treadmill=belt}
-- the live wiring (ChestChaseServerMain): BusyChecker = ChaseService:IsPlayerBusy (a run, a start, or a pack reveal playing = ChestService:IsOpening); R153: the treadmill asks
-- TrainingBusyChecker = a run or a start only (ConcurrentKeeperService's Runs / Starting, without the reveal).
local currentSvc
local chaseSelf={Runs={},Starting={},Chests={IsOpening=function(_,p)return currentSvc~=nil and ChestService.IsOpening(currentSvc,p)end}}
local fired={}
local stand=setmetatable({Config=Config,PlayerData=Data,TrainingSessions={},TrainingTime={},TrainingGainRemainder={},TrainingMustLeave={},TrainingCooldown={},
 BusyChecker=function(p)return Chase.IsPlayerBusy(chaseSelf,p)end,TrainingBusyChecker=function(p)return chaseSelf.Runs[p]~=nil or chaseSelf.Starting[p]==true end,GetPlayerBase=function()return record end,
 SpeedGainRemote={FireAllClients=function(_,...)fired[#fired+1]={...}end}},{__index=Base})
local function startTraining()
 hrp.Anchored=true;hum.AutoRotate=false
 local session={Character=char,Humanoid=hum,Root=hrp,Treadmill=belt,Record=record,Target=hrp.CFrame,BeltCFrame=belt.CFrame,Connections={},TutorialTrained=true,AnimationSpeed=Config.TreadmillAnimationSpeed}
 stand.TrainingSessions[P]=session;stand.TrainingTime[P]=0;stand.TrainingGainRemainder[P]=0
 P:SetAttribute('TreadmillTraining',true)
 return session
end
local function speed()return tonumber(Data:GetOrCreateSpeedValue(P).Value)end -- (the saved value is a string)
local dt=Config.TrainingInterval
local function train(n)for _=1,n do R.advance(dt);stand:_updateTrainingPlayer(P,dt)end end
local function bagPacks()local n=0;for _,r in ipairs(Data:GetChestRecords(P))do if r.Kind=='Pack'then n+=1 end end;return n end
local function addPack(stage,variant)
 return Data:AddChest(P,{Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion})
end
local backpackTools=function()local out={};for _,t in ipairs(backpack:GetChildren())do if t:IsA('Tool')then out[#out+1]=t end end;return out end
local function equip(tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=backpack end end;tool.Parent=char end
local function inHand(tool)return tool.Parent==char end
-- a fake ChestService instance with what the hold and the opening read (the methods are the real ones)
local function newSelf()
 local self
 self={PlayerData=Data,Config=Config,Openings={},SyncTools=function()end,PackRandom={NextNumber=function()return .5 end},Notifications={Show=function()end},
  Bases=stand,_holdPack=ChestService._holdPack,_activatePack=ChestService._activatePack,_canOpenPack=ChestService._canOpenPack,_finishOpening=ChestService._finishOpening}
 currentSvc=self;return self
end
fresh()

-- 0. the treadmill itself ------------------------------------------------------------------------------------------------------------------------------------
local session=startTraining()
local s0=speed();train(25)
local perTick=(speed()-s0)/25
check(stand.TrainingSessions[P]==session and perTick>0,'training on the treadmill gains speed every tick ('..string.format('%.2f',perTick)..' per tick over 25 ticks)')
check(hrp.Anchored==true and P:GetAttribute('TreadmillTraining')==true,'(the runner is held on the belt: anchored, TreadmillTraining set)')

-- 1. a pack opens while on the treadmill, and the training goes on ---------------------------------------------------------------------------------------------
do
 local rec=addPack(1,'Pack02');local svc=newSelf();local tool=ChestService._createPackTool(svc,rec,backpack)
 check(tool~=nil and tool.Parent==backpack,'(the pack is a Tool in the Backpack)')
 equip(tool);ChestService._holdPack(svc,P,tool)
 check(inHand(tool) and svc.Openings[P]~=nil and svc.Openings[P].Tool==tool and svc.Openings[P].Bag~=nil,'ON THE TREADMILL: equipping the pack holds it (it stays in the hand, one opening with its bag)')
 local sBefore=speed();train(10)
 check(stand.TrainingSessions[P]==session and speed()>sBefore and hrp.Anchored==true,'holding the pack: the training session is the same one and the speed keeps ticking')
 -- five clicks open it
 local reward;local clickGap=PackRules.ClickInterval+.01
 for i=1,PackRules.OpenClicks do
  R.advance(clickGap);ChestService._activatePack(svc,P,tool)
  check(inHand(tool) or i==PackRules.OpenClicks,'click '..i..': the pack is still in the hand')
 end
 local opening=svc.Openings[P]
 check(opening and opening.Committed==true and opening.RewardId~=nil and tool.Enabled==false,'ON THE TREADMILL: five clicks open it: the opening is committed with its reward')
 check(opening.Bag:GetAttribute('RevealSeedId')~=nil and opening.Bag:GetAttribute('RevealDuration')~=nil and opening.Bag:GetAttribute('RevealAt')~=nil,'... and the bag carries the reveal (the seed, its duration, its start): the client plays the opening over the treadmill')
 local seedRecord;for _,r in ipairs(Data:GetChestRecords(P))do if r.Id==rec.Id then seedRecord=r end end
 check(seedRecord and seedRecord.Kind=='Seed','... the pack in the bag became the seed it rolled')
 check(ChestService.IsOpening(svc,P)==true,'IsOpening says a reveal is playing')
 -- the reveal plays: the training goes on tick by tick, the session and the gain are untouched
 local duration=opening.Bag:GetAttribute('RevealDuration');local sReveal=speed();local ticksIn=0;local tAll=0
 local sessionSame,anchored,flagged=true,true,true
 while svc.Openings[P]==opening and tAll<duration+3 do
  R.advance(dt);tAll+=dt;stand:_updateTrainingPlayer(P,dt);ticksIn+=1
  if stand.TrainingSessions[P]~=session then sessionSame=false end
  if hrp.Anchored~=true then anchored=false end
  if P:GetAttribute('TreadmillTraining')~=true then flagged=false end
 end
 check(svc.Openings[P]==nil,'the reveal finished by itself after ~'..string.format('%.1f',tAll)..' s ('..string.format('%.1f',duration)..' s announced)')
 check(sessionSame and anchored and flagged,'THE WHOLE REVEAL: the training session is the same one, the runner stays on the belt, TreadmillTraining stays set')
 check(math.abs((speed()-sReveal)/ticksIn-perTick)<perTick*.05,'THE WHOLE REVEAL: the speed gain keeps ticking at the same rate ('..string.format('%.2f',(speed()-sReveal)/ticksIn)..' vs '..string.format('%.2f',perTick)..' per tick over '..ticksIn..' ticks)')
 check(tool.Parent==nil or not tool:IsDescendantOf(game),'after the reveal the opened pack\'s Tool is gone')
 -- another pack right after: it opens the same way
 local rec2=addPack(2,'Pack03');local tool2=ChestService._createPackTool(svc,rec2,backpack);equip(tool2);ChestService._holdPack(svc,P,tool2)
 check(inHand(tool2) and svc.Openings[P] and svc.Openings[P].Tool==tool2,'a second pack can be held on the treadmill right after')
 svc.Openings[P]=nil;tool2:Destroy()
end

-- 1b. what used to happen (the owner's problem): with the chase's IsPlayerBusy as the treadmill's checker, the fifth click ended the session on the spot
do
 local saved=stand.TrainingBusyChecker;stand.TrainingBusyChecker=nil -- (BaseService then falls back to BusyChecker, the pre-R153 wiring)
 local rec=addPack(1,'Pack02');local svc=newSelf();local tool=ChestService._createPackTool(svc,rec,backpack)
 equip(tool);ChestService._holdPack(svc,P,tool)
 for _=1,PackRules.OpenClicks do R.advance(PackRules.ClickInterval+.01);ChestService._activatePack(svc,P,tool)end
 check(svc.Openings[P] and svc.Openings[P].Committed==true and ChestService.IsOpening(svc,P)==true,'(before the fix: the pack is committed, a reveal is playing)')
 check(chaseSelf.Runs[P]==nil and chaseSelf.Starting[P]==nil and Chase.IsPlayerBusy(chaseSelf,P)==true,'(ChaseService:IsPlayerBusy says "busy" for a reveal, with no chase at all)')
 train(1)
 check(stand.TrainingSessions[P]==nil and P:GetAttribute('TreadmillTraining')==false,'(before the fix: that stopped the treadmill session at once: this is what the owner could not do)')
 stand.TrainingBusyChecker=saved;svc.Openings[P]=nil
 stand.TrainingMustLeave[P]=nil;stand.TrainingCooldown[P]=nil
 session=startTraining() -- back on the belt for the rest
 check(stand.TrainingSessions[P]==session,'(the runner is back on the belt)')
end

-- 2. the bonus roll works on the treadmill (real TreadmillBonusService, the same treadmill lock) ----------------------------------------------------------------
do
 local synced=0;local chests={SyncTools=function()synced+=1 end}
 local svc=Bonus.new(Config,Data,stand,chests,{Show=function()end})
 Data:GetPremium(P).TreadmillBonusProgress=0
 svc:Setup(P)
 check(stand.TrainingSessions[P]==session,'(still on the treadmill)')
 svc:Step(1);local p0=svc:GetProgress(P)
 check(p0>=.99,'on the treadmill the bonus timer counts ('..p0..' s after 1 s)')
 svc:GrantReady(P,1)
 check(svc:GetReady(P)==1 and P:GetAttribute(BonusRules.Attr.Ready)==1,'a roll is ready (published to the client)')
 local before=bagPacks()
 local res=svc:Roll(P)
 check(res.Ok==true and res.Ready==0 and bagPacks()==before+1 and synced==1,'THE ROLL WORKS ON THE TREADMILL: Ok, a pack arrived in the bag, the roll was spent, the tool sync ran')
 check(res.Stage~=nil and res.Variant~=nil and res.Rarity~=nil and res.Pool~=nil,'... and the reply carries what the client animates (stage, variant, rarity, pool)')
 check(stand.TrainingSessions[P]==session and P:GetAttribute('TreadmillTraining')==true and hrp.Anchored==true,'... the training session is untouched by the roll')
 local sRoll=speed();train(5);svc:Step(1)
 check(speed()>sRoll and svc:GetProgress(P)>p0,'... the speed and the bonus timer keep ticking after it')
 -- the same through the remote (what the client calls), with the real rate limit
 svc:GrantReady(P,1);R.advance(2)
 local ok,res2=pcall(function()return svc.Remote.OnServerInvoke(P)end)
 check(ok and type(res2)=='table' and res2.Ok==true,'the remote the client invokes answers Ok on the treadmill ('..tostring(ok and res2 and(res2.Ok or res2.Error))..')')
 -- unchanged refusals (none of them is about the treadmill)
 R.advance(2);local none=svc:Roll(P);check(none.Error=='No bonus roll ready yet.','no roll ready: still refused on the treadmill ('..tostring(none.Error)..')')
 svc:GrantReady(P,1);local quick=svc:Roll(P);check(quick.Error=='Please wait a moment.','a second roll inside the 1 s cool-down is refused ('..tostring(quick.Error)..')')
 R.advance(2)
 local realRoom=Data.CanReceiveSeed;Data.CanReceiveSeed=function()return false,'SEED BAG FULL'end
 local full=svc:Roll(P);Data.CanReceiveSeed=realRoom
 check(full.Error~=nil and full.Error:find('BAG FULL')and svc:GetReady(P)==1,'a full bag still refuses and keeps the roll ready ('..tostring(full.Error)..')')
 svc:Cleanup(P)
end

-- 3. the other blocks stay: each one still sends the pack back to the Backpack, on the treadmill too ---------------------------------------------------------------
do
 local rec=addPack(1,'Pack01');local svc=newSelf();local tool=ChestService._createPackTool(svc,rec,backpack)
 local function refused(label,set,unset)
  set();equip(tool);ChestService._holdPack(svc,P,tool)
  check(not inHand(tool) and svc.Openings[P]==nil and tool.Parent==backpack,'STILL REFUSED on the treadmill: '..label)
  unset();if svc.Openings[P]then svc.Openings[P]=nil end
 end
 refused('carrying a stolen pack',function()P:SetAttribute('ChestChaseSeedCarrying',true)end,function()P:SetAttribute('ChestChaseSeedCarrying',nil)end)
 refused('a chase is running (ChestChaseRunActive)',function()P:SetAttribute('ChestChaseRunActive',true)end,function()P:SetAttribute('ChestChaseRunActive',nil)end)
 refused('queued for a chase (ChestChaseQueued)',function()P:SetAttribute('ChestChaseQueued',true)end,function()P:SetAttribute('ChestChaseQueued',nil)end)
 refused('ragdolled (GuardianRagdollActive)',function()P:SetAttribute('GuardianRagdollActive',true)end,function()P:SetAttribute('GuardianRagdollActive',nil)end)
 refused('flung (GuardianFlingActive)',function()P:SetAttribute('GuardianFlingActive',true)end,function()P:SetAttribute('GuardianFlingActive',nil)end)
 refused('PlatformStand',function()hum.PlatformStand=true end,function()hum.PlatformStand=false end)
 -- another reveal is already running: the second pack is sent back
 local recB=addPack(2,'Pack03');local toolB=ChestService._createPackTool(svc,recB,backpack)
 equip(tool);ChestService._holdPack(svc,P,tool);local opening=svc.Openings[P];opening.Committed=true
 equip(toolB);ChestService._holdPack(svc,P,toolB)
 check(not inHand(toolB) and svc.Openings[P]==opening,'STILL REFUSED on the treadmill: another reveal is running (the second pack bounces)')
 svc.Openings[P]=nil;if opening.Bag then opening.Bag:Destroy()end
 -- a dead player cannot hold a pack
 hum.Health=0;equip(tool);ChestService._holdPack(svc,P,tool);check(not inHand(tool) and svc.Openings[P]==nil,'STILL REFUSED on the treadmill: a dead player');hum.Health=100
 -- an unloaded profile
 tool:Destroy();toolB:Destroy()
 -- the chase takes the treadmill away: the real busy checker stops the session (and the chase refusals above hold the pack)
 chaseSelf.Runs[P]={}
 stand:_updateTrainingPlayer(P,dt)
 check(stand.TrainingSessions[P]==nil and P:GetAttribute('TreadmillTraining')==false,'STILL STOPS: a chase running stops the training')
 chaseSelf.Runs[P]=nil;stand.TrainingMustLeave[P]=nil;stand.TrainingCooldown[P]=nil;startTraining()
 chaseSelf.Starting[P]=true;stand:_updateTrainingPlayer(P,dt)
 check(stand.TrainingSessions[P]==nil,'STILL STOPS: a chase that is starting stops the training')
 chaseSelf.Starting[P]=nil;stand.TrainingMustLeave[P]=nil;stand.TrainingCooldown[P]=nil
end

-- 4. a pack is held on the treadmill too (nothing in the hold looks at the treadmill) --------------------------------------------------------------------------
do
 hrp.Anchored=true;local s=startTraining();local svc=newSelf();local rec=addPack(3,'Pack04');local tool=ChestService._createPackTool(svc,rec,backpack)
 equip(tool);ChestService._holdPack(svc,P,tool)
 check(inHand(tool) and svc.Openings[P] and stand.TrainingSessions[P]==s,'a pack with a chip-bag shape is held on the treadmill too')
 svc.Openings[P]=nil;if tool:IsDescendantOf(game)then tool:Destroy()end
end

print(('R153 treadmill roll / open checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
