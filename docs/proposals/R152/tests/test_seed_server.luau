--!nocheck
-- R153 seed opening, the SERVER half: the REAL ChestService (_createPackTool, _holdPack, _activatePack, _finishOpening) and PlayerDataService
-- on the Roblox mock (R151's pack harness). The owner: "pack animations should play all the time and shouldn't stop after 2/3 times". The
-- server's part of an opening was never shortened for packs opened back to back, and stays so: every opening gets the FULL RevealDuration of
-- its rarity, the next pack waits for the opening before it to end (_finishOpening), nothing is stuck or lost, and whatever the opener's
-- client shows (the full reveal, a skip, "Skip pack animations") the seed is the server's from the 5th click:
--  1. 18 packs opened back to back, 0.1 s / 1 s / 3 s after the last opening ended (6 each, a guaranteed seed of every tier in turn): each
--     is committed on its 5th click (the seed is in the bag at once and the pull is announced from there), its bag carries the full
--     RevealDuration, the opening ends exactly then and the next pack can be held and opened
--  2. a pack equipped while an opening is committed (its reveal playing) goes back to the Backpack, untouched, and opens once that has ended
--  3. no pack is stuck or lost: every pack became exactly one seed, no opening is left, no pack is left in the bag
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
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
Shapes.Reset();Mock.reset();Mock.vertices=200;for k,v in pairs(DEFAULTS)do Shapes.Config[k]=v end;Shapes.Config.Force=nil
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,{Show=function()end})
-- the announcement hook OpenSeedPack calls (the real one needs the running announcer): recorded
local Announcer=server('PullAnnouncer');local announced={}
Announcer.OnOpened=function(player,pack,reward,wasTest)announced[#announced+1]={Player=player,Pack=pack.Id,Seed=reward.SeedId,At=R.clock}end
local P=R.new('Player');P.Name='Opener';P.DisplayName='Opener';P.UserId=501;P.Parent=Players;present[501]=P
function P.Kick(_,why)error('kicked: '..tostring(why),0)end
R.new('Backpack').Parent=P
Data:PreparePlayer(P);assert(Data:Load(P),'load')
local char,hrp,torso=H.character('R15');local hum=R.Instance.new('Humanoid');hum.Parent=char;char.Name=P.Name;P.Character=char;P.CharacterRemoving=R.signal()
local backpack=P:FindFirstChildOfClass('Backpack')
-- a ChestService with what an opening reads (the methods are the real ones); its tools call them through it
local svc={PlayerData=Data,Config=Config,Openings={},Notifications={Show=function()end},PackRandom={S=153,NextNumber=function(self)self.S=(self.S*16807)%2147483647;return self.S/2147483647 end},SyncTools=function()end,
 _holdPack=ChestService._holdPack,_activatePack=ChestService._activatePack,_canOpenPack=ChestService._canOpenPack,_finishOpening=ChestService._finishOpening}
local function equip(tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=backpack;t.Unequipped:Fire()end end;tool.Parent=char;tool.Equipped:Fire()end
local function record(id)for _,r in ipairs(Data:GetChestRecords(P))do if r.Id==id then return r end end;return nil end
local function packs()local n=0;for _,r in ipairs(Data:GetChestRecords(P))do if r.Kind=='Pack'then n+=1 end end;return n end
-- a pack whose seed is known in advance (the owner's guaranteed reveal, RarePackTests): a seed of every tier in turn
local RareTests=server('RarePackTests')
local byRank={}
for _,spec in ipairs(Rules.SeedDesigns)do local _,r=Rules.GetRarity(spec.id);if r and r.Rank and not byRank[r.Rank]then byRank[r.Rank]=spec.id end end
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local function newPack(rank)
 local rec=Data:AddChest(P,{Stage=2,BagVariant='Pack03',PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion})
 if rank then Data.StudioPackRewards=Data.StudioPackRewards or setmetatable({},{__mode='k'});Data.StudioPackRewards[P]=Data.StudioPackRewards[P]or{};Data.StudioPackRewards[P][rec.Id]=byRank[rank]end
 return rec,ChestService._createPackTool(svc,rec,backpack)
end
local function clicks(tool,n)for _=1,n do tool.Activated:Fire();R.advance(Rules.ClickInterval+.01)end end

-- 1. back to back --------------------------------------------------------------------------------------------------------------------------
local before=packs();local opened=0;local seeds={};local k=0
for _,gap in ipairs({.1,1,3})do
 for i=1,6 do
  k+=1;local rank=((k-1)%8)+1
  local rec,tool=newPack(rank);local tag=string.format('back to back (%.1f s) #%d',gap,i)
  equip(tool)
  local op=svc.Openings[P]
  if check(op and op.Tool==tool and tool.Parent==char,tag..': the pack is held')then
   clicks(tool,Rules.OpenClicks-1)
   check(not op.Committed and record(rec.Id).Kind=='Pack',tag..': four clicks: not opened yet')
   local n0=#announced
   clicks(tool,1)
   local seedRec=record(rec.Id)
   check(op.Committed and seedRec and seedRec.Kind=='Seed',tag..': the 5th click opens it: the seed is in the bag at once ('..tostring(seedRec and seedRec.SeedId)..')')
   check(#announced==n0+1 and announced[#announced].Pack==rec.Id,tag..': and the pull goes to the announcer from there (it times its chat line itself)')
   local rarity=op.Bag:GetAttribute('Rarity');local dur=op.Bag:GetAttribute('RevealDuration');local at=op.Bag:GetAttribute('RevealAt')
   check(dur==Rules.GetRevealDuration(rarity)and dur>0,tag..': its bag carries the FULL RevealDuration of a '..tostring(rarity)..' ('..tostring(dur)..' s), whatever came before')
   seeds[#seeds+1]=seedRec and seedRec.SeedId
   -- a pack equipped while this opening is committed goes back to the Backpack
   local rec2,other=newPack(nil)
   equip(other)
   check(other.Parent==backpack and svc.Openings[P]==op,tag..': another pack equipped while the reveal plays goes back to the Backpack')
   check(record(rec2.Id).Kind=='Pack',tag..': untouched')
   tool.Parent=char
   -- the opening ends exactly at RevealDuration, not before
   local t0=R.clock;local endedAt
   while svc.Openings[P]==op and R.clock-t0<dur+2 do R.advance(1/30);if svc.Openings[P]~=op and not endedAt then endedAt=R.clock end end
   check(endedAt and near(endedAt-at,dur,1/30+1e-6),tag..': the opening ends on its RevealDuration ('..string.format('%.2f',(endedAt or 0)-at)..' s)')
   check(svc.Openings[P]==nil and tool.Parent==nil and op.Bag.Parent==nil,tag..': and is gone: the pack tool and the carried bag are removed')
   opened+=1
   -- the pack that was sent back opens now, `gap` seconds after
   R.advance(gap)
   equip(other)
   local op2=svc.Openings[P]
   check(op2 and op2.Tool==other,tag..': the pack sent back can be held now')
   clicks(other,Rules.OpenClicks)
   check(op2 and op2.Committed and record(rec2.Id).Kind=='Seed',tag..': and opened')
   local dur2=op2 and op2.Bag:GetAttribute('RevealDuration')
   check(dur2==Rules.GetRevealDuration(op2.Bag:GetAttribute('Rarity')),tag..': with its full RevealDuration too')
   local g=0;while svc.Openings[P]==op2 and g<400 do R.advance(1/30);g+=1 end
   check(svc.Openings[P]==nil,tag..': which ends as well')
   opened+=1
   R.advance(gap)
  end
 end
end
-- the guaranteed tiers came out in order (so every tier was opened back to back)
local tiers={}
for k=1,#seeds do local _,r=Rules.GetRarity(seeds[k]or'');tiers[#tiers+1]=r and r.Rank or 0 end
local okTiers=true;for k=1,#tiers do if tiers[k]~=((k-1)%8)+1 then okTiers=false end end
check(okTiers,'every tier opened back to back ('..table.concat(tiers,',')..')')

-- 3. nothing stuck or lost ----------------------------------------------------------------------------------------------------------------
check(opened==36,'36 openings ('..opened..')')
check(packs()==before,'every pack opened became a seed: no pack left in the bag ('..packs()..' packs, '..before..' before)')
check(svc.Openings[P]==nil and char:FindFirstChild('CarriedSeed')==nil,'no opening and no carried bag left')
local seedsIn=0;for _,r in ipairs(Data:GetChestRecords(P))do if r.Kind=='Seed'then seedsIn+=1 end end
check(seedsIn>=36,'36 seeds in the bag ('..seedsIn..')')
check(#announced==36,'36 pulls handed to the announcer, one each ('..#announced..')')
print(('R153 server checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
