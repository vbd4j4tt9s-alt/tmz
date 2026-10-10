--!nocheck
-- R153, the server half: ChestService on the Roblox mock with the REAL server modules (R151's pack harness, as R152's test_hold_race).
--  1. after a reveal the server hands the reward seed over (_finishOpening: Humanoid:EquipTool from the SERVER). R152 did it whatever the player held: an item
--     they picked during the reveal was thrown back into the Backpack, so their press seemed lost. Now only into an empty hand (an empty hand still gets it).
--  2. a pack sent back to the Backpack says why: HoldRefused = reason@time on the tool (busy: carrying / a chase, opening: another reveal, knocked) and a
--     line in ChestService.HoldLog (what /test hotbar prints); a hold that waited for its chip-bag shape is listed with the wait.
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F
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
local function fresh()Shapes.Reset();Mock.reset();Mock.vertices=200;for k,v in pairs(DEFAULTS)do Shapes.Config[k]=v end;Shapes.Config.Force=nil end
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,{Show=function()end})
local P=R.new('Player');P.Name='Zed';P.DisplayName='Zed';P.UserId=501;P.Parent=Players;present[501]=P
function P.Kick(_,why)error('kicked: '..tostring(why),0)end
R.new('Backpack').Parent=P;Data:PreparePlayer(P);assert(Data:Load(P),'load')
local char=H.character('R15');local hum=R.Instance.new('Humanoid');hum.Parent=char;char.Name=P.Name;P.Character=char;P.CharacterRemoving=R.signal()
local backpack=P:FindFirstChildOfClass('Backpack')
local equips={};R.Inst.EquipTool=function(h,tool)equips[#equips+1]=tool.Name;local c=h.Parent;for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')then t.Parent=backpack end end;tool.Parent=c end -- (the server's Humanoid:EquipTool)
local function addPack(stage,variant)return Data:AddChest(P,{Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion})end
local function newSelf()
 return {PlayerData=Data,Config=Config,Openings={},SyncTools=function()end,_holdPack=ChestService._holdPack,_activatePack=ChestService._activatePack,_canOpenPack=ChestService._canOpenPack,
  _finishOpening=ChestService._finishOpening}
end
local function equip(tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=backpack end end;tool.Parent=char end
local function tool(name,attrs)local t=R.Instance.new('Tool');t.Name=name;for k,v in pairs(attrs)do t:SetAttribute(k,v)end;local h=R.new('Part');h.Name='Handle';h.Parent=t;return t end
local function settleDeferred()for _=1,3 do R.advance(0)end end

-- 1. the reward hand-off after a reveal ----------------------------------------------------------------------------------------------------------------
do
 fresh();local svc=newSelf()
 local rec=addPack(1,'Pack02');local pack=ChestService._createPackTool(svc,rec,backpack)
 local reward=tool('Reward Seed',{GardenSeed=true,SeedInventoryId='reward-1'});reward.Parent=backpack
 -- (a) the player kept the pack in the hand to the end: the hand is empty when it is gone -> the seed is handed over
 equip(pack);local opening={Tool=pack,Character=char,Connections={},Committed=true,RewardId='reward-1'};svc.Openings[P]=opening
 table.clear(equips);ChestService._finishOpening(svc,P,opening);settleDeferred()
 check(reward.Parent==char and #equips==1,'an empty hand after the reveal gets the reward seed ('..table.concat(equips,',')..')')
 -- (b) the player picked a fruit during the reveal: it stays in the hand
 local rec2=addPack(2,'Pack03');local pack2=ChestService._createPackTool(svc,rec2,backpack);reward.Parent=backpack
 local fruit=tool('Blueberry',{HarvestItemTool=true,HarvestInventoryId='fruit-1'});fruit.Parent=backpack
 equip(pack2);local op2={Tool=pack2,Character=char,Connections={},Committed=true,RewardId='reward-1'};svc.Openings[P]=op2
 equip(fruit) -- (the player's press during the reveal: the pack goes to the Backpack, the fruit to the hand)
 table.clear(equips);ChestService._finishOpening(svc,P,op2);settleDeferred()
 check(fruit.Parent==char and reward.Parent==backpack and #equips==0,'an item picked during the reveal stays in the hand (in hand: '..tostring(char:FindFirstChildOfClass('Tool')and char:FindFirstChildOfClass('Tool').Name)..', server equips: '..table.concat(equips,',')..')')
 fruit:Destroy();reward:Destroy()
end

-- 2. why a pack is sent back; how long a hold waited ---------------------------------------------------------------------------------------------------
do
 fresh();local svc=newSelf()
 local recA=addPack(1,'Pack02');local recB=addPack(2,'Pack03')
 local A=ChestService._createPackTool(svc,recA,backpack);local B=ChestService._createPackTool(svc,recB,backpack)
 P:SetAttribute('ChestChaseSeedCarrying',true);equip(A);ChestService._holdPack(svc,P,A)
 local why=A:GetAttribute('HoldRefused')
 check(A.Parent==backpack and type(why)=='string'and why:match('^busy@'),'carrying a stolen pack: the pack goes back with HoldRefused busy@<time> ('..tostring(why)..')')
 P:SetAttribute('ChestChaseSeedCarrying',nil)
 equip(A);ChestService._holdPack(svc,P,A);local op=svc.Openings[P]
 check(op and op.Tool==A and A.Parent==char,'(then A is held)')
 op.Committed=true;equip(B);ChestService._holdPack(svc,P,B)
 why=B:GetAttribute('HoldRefused')
 check(B.Parent==backpack and type(why)=='string'and why:match('^opening@'),'during a reveal: B goes back with HoldRefused opening@<time> ('..tostring(why)..')')
 svc.Openings[P]=nil;if op.Bag then op.Bag:Destroy()end
 P:SetAttribute('GuardianRagdollActive',true);equip(B);ChestService._holdPack(svc,P,B);why=B:GetAttribute('HoldRefused')
 check(B.Parent==backpack and why:match('^knocked@'),'knocked down: knocked@<time> ('..tostring(why)..')');P:SetAttribute('GuardianRagdollActive',nil)
 local log=svc.HoldLog and svc.HoldLog[P]or{}
 local text=table.concat(log,' | ')
 check(#log>=3 and text:find('refused: busy',1,true)and text:find('refused: opening',1,true)and text:find('refused: knocked',1,true),'the server keeps a short list of them for /test hotbar ('..text..')')
 -- a hold that waits for its shape is listed with the wait
 fresh();Mock.slow=true
 R.task.wait=function(t)if coroutine.isyieldable()then coroutine.yield()end;R.advance(t or .03);return t or .03 end
 equip(B);local co=coroutine.create(function()ChestService._holdPack(svc,P,B)end);coroutine.resume(co)
 for _=1,10 do R.advance(.1);if coroutine.status(co)=='suspended'then coroutine.resume(co)end end
 Mock.resume();for _=1,40 do if coroutine.status(co)=='suspended'then coroutine.resume(co)end;R.advance(.05)end
 log=svc.HoldLog[P];text=log[#log]or''
 check(text:find('waited',1,true)~=nil and svc.Openings[P]and svc.Openings[P].Tool==B,'a hold that waited for its shape is listed with the wait ('..text..')')
 Mock.slow=false
end

print(('R153 server hold checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
