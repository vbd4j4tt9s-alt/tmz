--!nocheck
-- R152 hotbar reliability, the server half: ChestService:_holdPack on the Roblox mock with the REAL server modules (R151's pack-shape harness).
-- A pack the player equipped must stay in the hand:
--  1. a quick unequip + re-equip while its chip-bag shape is still loading starts a SECOND hold of the same pack; the first to finish holds it, the second used to see
--     that opening and throw the pack out of the hand (the R151 known issue). Now it does nothing.
--  2. equipping pack B while pack A is in hand, when B's Equipped is handled before A's Unequipped has finished A's opening: B used to see A's opening and bounce
--     back into the Backpack, so the first click did nothing. A's stale (uncommitted, no longer in the hand) opening is finished and B is held.
--  3. unchanged: a COMMITTED opening (its reveal is playing) still wins and bounces another pack; an opening that is not a table (R139's fake) is left alone;
--     a pack that cannot be held (carrying / running) still bounces; an ordinary equip of one pack still holds it.
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

fresh()
local P=makePlayer(401,'Zed');local char=character(P);local backpack=P:FindFirstChildOfClass('Backpack')
local recA=addPack(P,1,'Pack02');local recB=addPack(P,2,'Pack03')
local realWait=R.task.wait
local function unequip(tool)tool.Parent=backpack end
local function equip(tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=backpack end end;tool.Parent=char end
local function inHand(tool)return tool.Parent==char end

-- 1. a quick unequip / re-equip while the shape loads ---------------------------------------------------------------------------------------------------
do
 fresh();Mock.slow=true
 local svc=newSelf();local tool=ChestService._createPackTool(svc,recA,backpack)
 check(tool:GetAttribute('PackShape')~=nil,'(the pack has a chip-bag shape, so holding it waits for the bake: '..tostring(tool:GetAttribute('PackShape'))..')')
 -- a real yield for task.wait while two holds are in flight
 R.task.wait=function(t)if coroutine.isyieldable()then coroutine.yield()end;R.advance(t or .03);return t or .03 end
 equip(tool)
 local co1=coroutine.create(function()ChestService._holdPack(svc,P,tool)end);coroutine.resume(co1)
 check(coroutine.status(co1)=='suspended'and svc.Openings[P]==nil,'hold 1 is waiting for the bake: no opening yet, the pack is in the hand')
 unequip(tool);equip(tool) -- the player clicked the slot twice
 local co2=coroutine.create(function()ChestService._holdPack(svc,P,tool)end);coroutine.resume(co2)
 check(coroutine.status(co2)=='suspended','hold 2 (the second Equipped) is waiting too')
 Mock.resume()
 for _=1,40 do if coroutine.status(co1)=='suspended'then coroutine.resume(co1)end;if coroutine.status(co2)=='suspended'then coroutine.resume(co2)end;R.advance(.1) end
 check(coroutine.status(co1)=='dead'and coroutine.status(co2)=='dead','both holds finished')
 local op=svc.Openings[P]
 check(inHand(tool),'the pack is STILL IN THE HAND (the second hold did not throw it out)')
 check(op and op.Tool==tool and op.Bag~=nil,'and it is held: one opening, with its bag')
 if op then svc.Openings[P]=nil;if op.Bag then op.Bag:Destroy()end end
 tool:Destroy();R.task.wait=realWait;Mock.slow=false
end

-- 2. pack B equipped while pack A's opening has not been finished yet ---------------------------------------------------------------------------------
do
 fresh()
 local svc=newSelf();local A=ChestService._createPackTool(svc,recA,backpack);local B=ChestService._createPackTool(svc,recB,backpack)
 equip(A);ChestService._holdPack(svc,P,A)
 check(svc.Openings[P]and svc.Openings[P].Tool==A and inHand(A),'(pack A is held)')
 -- the engine puts A back and B in hand; B.Equipped runs BEFORE A.Unequipped
 equip(B);ChestService._holdPack(svc,P,B)
 check(inHand(B),'B stays in the hand (it used to bounce into the Backpack: the first click did nothing)')
 check(svc.Openings[P]and svc.Openings[P].Tool==B,'B is the held pack, A\'s stale opening is gone')
 -- A's Unequipped finally runs: it must not disturb B's opening
 local op=svc.Openings[P]
 ChestService._finishOpening(svc,P,{Tool=A,Connections={},Committed=false,Bag=nil}) -- (a finish for an opening that is no longer current does nothing)
 check(svc.Openings[P]==op and inHand(B),'a late finish for A leaves B held')
 svc.Openings[P]=nil;if op.Bag then op.Bag:Destroy()end
 A:Destroy();B:Destroy()
end

-- 3. what did not change ---------------------------------------------------------------------------------------------------------------------------------
do
 fresh()
 local svc=newSelf();local A=ChestService._createPackTool(svc,recA,backpack);local B=ChestService._createPackTool(svc,recB,backpack)
 -- an ordinary equip holds
 equip(A);ChestService._holdPack(svc,P,A);check(inHand(A)and svc.Openings[P]and svc.Openings[P].Tool==A,'an ordinary equip holds the pack')
 -- the same pack's Equipped again (a duplicate event): still held, still ONE opening
 local op=svc.Openings[P];ChestService._holdPack(svc,P,A);check(inHand(A)and svc.Openings[P]==op,'a repeated Equipped for the held pack changes nothing')
 -- a committed opening (reveal playing) still wins: B bounces
 op.Committed=true;equip(B);ChestService._holdPack(svc,P,B)
 check(not inHand(B)and svc.Openings[P]==op,'while a pack is being revealed (committed) another pack is still sent back to the Backpack')
 svc.Openings[P]=nil;if op.Bag then op.Bag:Destroy()end
 -- R139's fake opening (a bare true) is left alone: the pack bounces as before
 svc.Openings[P]=true;equip(A);ChestService._holdPack(svc,P,A)
 check(not inHand(A)and svc.Openings[P]==true,'an opening that is not a table is left alone (R139 test): the pack bounces as before')
 svc.Openings[P]=nil
 -- carrying a pack: not holdable, bounces (unchanged)
 P:SetAttribute('ChestChaseSeedCarrying',true);equip(A);ChestService._holdPack(svc,P,A)
 check(not inHand(A)and svc.Openings[P]==nil,'while carrying a stolen pack the pack still bounces (unchanged)');P:SetAttribute('ChestChaseSeedCarrying',nil)
 A:Destroy();B:Destroy()
end

print(('R152 hold race checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
