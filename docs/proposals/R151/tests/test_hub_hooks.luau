--!nocheck
-- R151 hub displays: how the displays are wired into the game, on the Roblox mock with the REAL PlayerDataService, Config, RarePackTests, StudioTestCommands,
-- OwnerUpdateCommands82, OwnerCommandTargets82 and HubDisplayService (the art and the avatar are recording stand-ins; their own suites cover them):
--  1. a pack opened: PlayerDataService:OpenSeedPack calls its OnPackOpened hook once, after the commit, with the pack's own stage / variant / odds version / rate boost /
--     luck and a Test flag; a refused open calls nothing; a hook that throws changes nothing; the service ranks it with the odds that pack really had;
--  2. TEST packs (/test rarepacks) are flagged and never count; packs and seeds an owner command gave (/test pack, packset, void, verity, seed, seeds, plant, plants) taint
--     that player for the session: their pulls and harvests do not count; other commands do not; the target (@name) is tainted, not the requester;
--  3. a fruit picked by hand: the harvest record carries what NoteHarvest reads (SeedId, FruitScale, Mutation, Weather); ChestService calls its HarvestHook right after a
--     successful Harvest (and only for a harvest); an owner's `harvestall` (data:HarvestPlant directly) never reaches the hook;
--  4. the owner commands: bestpull / bigfruit / hubdisplays (status, reset, day +/-N): arguments, usage errors, targets, `share`, the server-wide ones refuse @name, strangers are
--     refused; the F4 help and docs/COMMANDS.md list them;
--  (the files themselves - the main script's wiring, the manifest, the docs - are checked by run_hub_displays.sh)
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local owners={}
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return owners[p]==true end,Publish=function(p)return owners[p]==true end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Rules=W.module('SeedPackRules');local HubRules=W.module('HubDisplayRules');local Weight=W.module('ItemWeight')
local PDS=server('PlayerDataService');local RPT=server('RarePackTests');local Cmd=server('StudioTestCommands');local Svc=server('HubDisplayService')
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local told={};local Notes={Show=function(_,p,text)told[#told+1]={P=p,Text=text}end}
local Data=PDS.new(Config,Map,Notes)
R.clock=20727*86400+3600*5
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function drawConstant(x)return function()return x end end
local function addPack(player,stage,variant)
 return Data:AddChest(player,{Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
end
-- the hub service on the real data, recording stand-ins for the art
local function art()
 local A={ItemBuilds={}}
 function A.BuildFrame(parent,kind)local m=R.new('Model');m.Name=kind;m.Parent=parent;local d={Kind=kind,Model=m,FeetAt=R.CFrame.new(0,0,0)};A[kind]=d;return d end
 function A.SetSign(d,t)d.Text=t end;function A.Tint()end
 function A.BuildItem(d,spec)A.ItemBuilds[#A.ItemBuilds+1]=spec;return R.new('Model'),{Parts=1}end
 function A.SetItem()end;function A.SetAvatar()end;function A.Counts()return{Frame=1,Item=1,Avatar=1}end
 return A
end
local avatars={Build=function(_,uid)return R.new('Model'),'avatar'end,Place=function()return true end}
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap'
local hubClock={t=1000}
local hub=Svc.new(Config,Data,Notes,{MapRoot=mapRoot},{Clock=function()return hubClock.t end,Time=function()return math.floor(R.clock)end,Art=art(),Avatars=avatars,NoLoop=true,
 Store=server('HubDisplayStore').new({Disabled=true})})
hub:Start()
Data.OnPackOpened=function(p,r,i)hub:NotePull(p,r,i)end
local ctx={Config=Config,Data=Data,Map={MapRoot=mapRoot},Chase={IsPlayerBusy=function()return false end,HubDisplays=hub},Bases={GetPlayerBase=function()return nil end,StopTraining=function()end},
 Chests=setmetatable({IsOpening=function()return false end,SyncTools=function()end,RenderGarden=function()end},{__index=server('ChestService')})}

-- 1. A pack opened ---------------------------------------------------------------------------------------------------------------------------------------------------------
local A=makePlayer(101,'Ava')
do
 local calls={}
 local plain=Data.OnPackOpened
 Data.OnPackOpened=function(p,r,i)calls[#calls+1]={P=p,R=r,I=i};plain(p,r,i)end
 local pack=addPack(A,4,'Pack03')
 local reward,why=Data:OpenSeedPack(A,pack.Id,drawConstant(.5))
 check(reward and #calls==1,'opening a pack calls the hook once ('..tostring(why)..')')
 local c=calls[1]
 check(c.P==A and c.R==reward and c.R.Kind=='Seed','with the player and the reward OpenSeedPack made')
 check(c.I.Stage==4 and c.I.Variant=='Pack03'and c.I.Version==Rules.OddsVersion and c.I.Test==false and c.I.Luck==A:GetAttribute('ChestLuckMultiplier')and c.I.Boost==nil,'and the PACK\'s own stage, variant, odds version, rate boost and luck, Test false')
 local snap=hub:Snapshot()
 local rec=snap.Pull.Record
 check(rec and rec.Uid==101 and rec.Id==reward.SeedId and rec.Rarity==reward.Rarity and rec.Name=='Ava','the hub took it (it is the first pull of the day)')
 local odds=Rules.SeedOdds(Config,4,'Pack03',c.I.Luck,Rules.OddsVersion)[reward.SeedId]
 check(odds and math.abs(rec.Odds-odds)<1e-12,'with the odds that pack really had for that seed ('..string.format('%.4g',odds)..'%)')
 -- a refused open
 local n=#calls
 check(Data:OpenSeedPack(A,'no-such-pack',drawConstant(.5))==nil and Data:OpenSeedPack(A,pack.Id,drawConstant(.5))==nil and #calls==n,'a refused open (no such pack, a pack already opened) calls nothing')
 -- a rate-boosted starter pack
 local starter=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion,RateBoost=2})
 Data:OpenSeedPack(A,starter.Id,drawConstant(.3))
 check(calls[#calls].I.Boost==2,'the free starter pack\'s rate boost is passed on (its odds are the boosted ones)')
 -- a hook that throws
 Data.OnPackOpened=function()error('hook exploded')end
 local p2=addPack(A,4,'Pack03');local before=#Data:GetChestRecords(A)
 local r2=Data:OpenSeedPack(A,p2.Id,drawConstant(.5))
 check(r2 and r2.Kind=='Seed'and #Data:GetChestRecords(A)==before,'a hook that throws does not stop the open: the reward is returned and the inventory is the same')
 Data.OnPackOpened=nil
 local p3=addPack(A,4,'Pack03');check(Data:OpenSeedPack(A,p3.Id,drawConstant(.5))~=nil,'and no hook at all is fine')
 Data.OnPackOpened=plain
end

-- 2. Test packs and owner grants -----------------------------------------------------------------------------------------------------------------------------------------
local Bo=makePlayer(102,'Bo');local Cy=makePlayer(103,'Cy')
do
 hub:Reset()
 owners[Bo]=true
 Run.IsStudio=function()return true end
 local calls={}
 local plain=Data.OnPackOpened
 Data.OnPackOpened=function(p,r,i)calls[#calls+1]=i;plain(p,r,i)end
 local ok=RPT.Grant(Data,Bo,'king',Bo)
 Run.IsStudio=function()return false end
 local testPack;for _,r in ipairs(Data:GetChestRecords(Bo))do if r.Kind=='Pack'and RPT.Expected(Data,Bo,r.Id)then testPack=r end end
 check(ok and testPack,'rarepacks king gives a TEST pack')
 local opened=Data:OpenSeedPack(Bo,testPack.Id,drawConstant(.5))
 check(opened and opened.Rarity=='King'and calls[#calls].Test==true,'opening it: a King, and the hook is told it is a TEST pack')
 check(hub:Snapshot().Pull.Record==nil,'the board did not take it')
 -- the same player's real pack counts (a test pack only flags itself)
 Bo:SetAttribute('x',1)
 local real=addPack(Bo,4,'Pack03');Data:OpenSeedPack(Bo,real.Id,drawConstant(.5))
 check(hub:Snapshot().Pull.Record and hub:Snapshot().Pull.Record.Name=='Bo','a real pack of the same player counts (only the TEST pack was refused)')
 hub:Reset()
 -- owner commands: the target is tainted, everything they open or pick afterwards is not counted
 local function run(requester,text)return Cmd.Execute(ctx,requester,text)end
 Run.IsStudio=function()return true end
 local before=#Data:GetChestRecords(Cy)
 local okCmd,msg=run(Bo,'/test pack lava 6 @Cy')
 Run.IsStudio=function()return false end
 check(okCmd and #Data:GetChestRecords(Cy)==before+1,'/test pack lava 6 @Cy gave Cy a pack ('..tostring(msg)..')')
 check(hub.Tainted[Cy]==true and hub.Tainted[Bo]~=true,'Cy (the target) is tainted, the owner who typed it is not')
 local give;for _,r in ipairs(Data:GetChestRecords(Cy))do if r.Kind=='Pack'then give=r end end
 Data:OpenSeedPack(Cy,give.Id,drawConstant(.5))
 check(hub:Snapshot().Pull.Record==nil,'what Cy opens from it is not counted')
 local real2=addPack(Cy,4,'Pack03');Data:OpenSeedPack(Cy,real2.Id,drawConstant(.5))
 check(hub:Snapshot().Pull.Record==nil,'nor anything else Cy opens for the rest of the session (even a real pack)')
 -- which commands taint
 local taints={}
 for _,cmd in ipairs({'seed AppleSeed','seeds forest','pack storm 6','plant AppleSeed','plants forest','rarepacks','packset lava','verity 1','void 1','give big diamond apple seed to me'})do
  local who=makePlayer(200+#taints,'T'..#taints);owners[who]=true
  Run.IsStudio=function()return true end;pcall(run,who,'/test '..cmd);Run.IsStudio=function()return false end
  taints[#taints+1]=hub.Tainted[who]==true
  if not taints[#taints]then print('   did not taint: /test '..cmd)end
 end
 local all=true;for _,t in ipairs(taints)do if not t then all=false end end
 check(all,'every command that gives packs, seeds or plants taints its target (seed, seeds, pack, plant, plants, rarepacks, packset, verity, void, give ...)')
 local innocent={}
 for _,cmd in ipairs({'cash add 5','stats','speed 10','heal','catalog forest','odds forest rare 1'})do
  local who=makePlayer(300+#innocent,'N'..#innocent);owners[who]=true
  Run.IsStudio=function()return true end;pcall(run,who,'/test '..cmd);Run.IsStudio=function()return false end
  innocent[#innocent+1]=hub.Tainted[who]==true
 end
 local none=true;for _,t in ipairs(innocent)do if t then none=false end end
 check(none,'cash, stats, speed, heal, catalog and odds do not')
 -- reset forgets
 hub:Reset()
 check(hub.Tainted[Cy]==nil,'hubdisplays reset forgets who was tainted')
end

-- 3. A fruit picked by hand ------------------------------------------------------------------------------------------------------------------------------------------------
local Di=makePlayer(104,'Di')
do
 local fid=hub.Board.FruitId
 -- plant and harvest the day's fruit through the real PlayerDataService
 local pack=Data:AddChest(Di,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 -- give Di the seed of today's fruit directly (a real seed record like OpenSeedPack makes)
 local seedRec=Data:GetChestRecords(Di)
 local idx;for i,r in ipairs(seedRec)do if r.Id==pack.Id then idx=i end end
 local seed=Config.GetSeedById(fid)
 seedRec[idx]={Id=pack.Id,ChestNumber=pack.ChestNumber,ChestName=seed.Name,Kind='Seed',Stage=1,SeedId=fid,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity='Common',SeedScale=1,PackMutation='None',BagVariant='Pack01',OddsVersion=Rules.OddsVersion,PackSize=1}
 local nowT=os.time()
 local planted,crop=Data:PlantSeed(Di,1,pack.Id,{OffsetX=0,OffsetZ=0},nowT)
 check(planted and crop.SeedId==fid,'the day\'s fruit ('..fid..') is planted')
 local okH,harvest=Data:HarvestPlant(Di,1,crop.Id,nowT+crop.ReadyAt-nowT,nil)
 check(okH and harvest.SeedId==fid and type(harvest.FruitScale)=='number'and harvest.FruitScale>0 and harvest.Mutation~=nil and harvest.Weather~=nil,'a harvest carries SeedId, FruitScale, Mutation and Weather (what NoteHarvest reads)')
 check(hub:Snapshot().Fruit.Record==nil,'HarvestPlant itself does not report (a test harvest, /test harvestall, goes through it too)')
 check(hub:NoteHarvest(Di,harvest),'the garden Harvest handler reports it through NoteHarvest')
 local rec=hub:Snapshot().Fruit.Record
 check(rec and rec.Uid==104 and math.abs(rec.Kg-harvest.FruitScale*Weight.FruitBase(fid))<1e-9 and rec.Coat==harvest.Mutation,'the board holds it: weight = the plant\'s base kg x the fruit\'s size, with its coat')
 -- ChestService wires the hook right after a successful Harvest (the whole handler needs bases and soil: checked in its source)
 local src=W.B.ChestService
 local a=src:find('self.PlayerData:HarvestPlant(player, slot, crop.Id, os.time(), payload.FruitIndex)',1,true)
 local b=src:find('if action == "Harvest" and self.HarvestHook then pcall(self.HarvestHook, player, result) end',1,true)
 local c=src:find('self.PlayerData:QueueGardenSave(player)\n\tlocal refreshed',1,true)
 local d=src:find('if not success then return reject(result) end',a or 1,true)
 check(a and b and c and d and a<d and d<b and b<c,'ChestService.InteractGarden: HarvestPlant, then the failure return, then the HarvestHook (only for a Harvest), then the save')
 check(select(2,src:gsub('HarvestHook','HarvestHook'))==2,'and the hook is mentioned nowhere else in ChestService')
 -- an owner's harvestall: picks through PlayerDataService:HarvestPlant directly (never the garden handler), so the hook never hears of it
 hub:Reset()
 local Ed=makePlayer(105,'Ed');owners[Ed]=true
 local sd=Data:AddChest(Ed,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 local recs=Data:GetChestRecords(Ed)
 for i,r in ipairs(recs)do if r.Id==sd.Id then recs[i]={Id=sd.Id,ChestNumber=sd.ChestNumber,ChestName=seed.Name,Kind='Seed',Stage=1,SeedId=fid,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity='Common',SeedScale=25,PackMutation='None',BagVariant='Pack01',OddsVersion=Rules.OddsVersion,PackSize=1}end end
 local plantedEd=Data:PlantSeed(Ed,1,sd.Id,{OffsetX=0,OffsetZ=0},os.time())
 Run.IsStudio=function()return true end
 Cmd.Execute(ctx,Ed,'/test growall')
 local okAll,msgAll=Cmd.Execute(ctx,Ed,'/test harvestall')
 Run.IsStudio=function()return false end
 check(plantedEd and okAll and #Data.Gardens[Ed].Harvests>0,'/test harvestall picked '..#Data.Gardens[Ed].Harvests..' fruit ('..tostring(msgAll)..')')
 check(hub:Snapshot().Fruit.Record==nil and hub.Tainted[Ed]~=true,'none of them reached the board (harvestall goes around the hook), and it did not taint the owner')
end

-- 4. Owner commands ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 hub:Reset()
 local Fay=makePlayer(106,'Fay');local Gus=makePlayer(107,'Gus');owners[Fay]=true
 local function run(text,who)Run.IsStudio=function()return true end;local ok,msg=Cmd.Execute(ctx,who or Fay,text);Run.IsStudio=function()return false end;return ok,msg end
 local ok,msg=run('/test bestpull fire pepper')
 check(ok and msg:find('Mythic Fire Pepper',1,true)and hub:Snapshot().Pull.Record.Name=='Fay'and hub:Snapshot().Pull.Source=='Test','bestpull fire pepper: a test pull for the caller ('..tostring(msg)..')')
 hub:Reset()
 ok,msg=run('/test bestpull FirePepperSeed @Gus')
 check(ok and hub:Snapshot().Pull.Record.Name=='Gus','bestpull FirePepperSeed @Gus: for the named player')
 hub:Reset()
 ok,msg=run('/test bestpull solar starfruit share')
 check(ok and msg:find('(shared)',1,true),'bestpull ... share')
 hub:Reset()
 ok,msg=run('/test bestpull');check(not ok and msg:find('Use bestpull',1,true),'bestpull needs a seed ('..tostring(msg)..')')
 ok,msg=run('/test bestpull nonsense');check(not ok and msg:find('Unknown seed',1,true),'an unknown seed is refused')
 ok,msg=run('/test bigfruit 12.4')
 check(ok and hub:Snapshot().Fruit.Record.Name=='Fay','bigfruit 12.4 ('..tostring(msg)..')')
 hub:Reset()
 ok,msg=run('/test bigfruit 30 gold @Gus');check(ok and hub:Snapshot().Fruit.Record.Coat=='Gold'and hub:Snapshot().Fruit.Record.Name=='Gus','bigfruit 30 gold @Gus')
 ok,msg=run('/test bigfruit');check(not ok and msg:find('Use bigfruit',1,true),'bigfruit needs a weight')
 ok,msg=run('/test bigfruit x');check(not ok,'a non-number weight is refused')
 ok,msg=run('/test bigfruit 1 2');check(not ok and msg:find('Use bigfruit',1,true),'two numbers are refused')
 ok,msg=run('/test hubdisplays')
 check(ok and msg:find('Day ',1,true)and msg:find('BEST PULL',1,true)and msg:find('BIGGEST FRUIT',1,true),'hubdisplays prints the state ('..tostring(msg):gsub('\n',' | ')..')')
 ok,msg=run('/test hubdisplays status');check(ok,'hubdisplays status works too')
 ok,msg=run('/test hubdisplays reset')
 check(ok and hub:Snapshot().Pull.Record==nil and hub:Snapshot().Fruit.Record==nil,'hubdisplays reset empties both boards')
 local day=hub:Snapshot().Day
 ok,msg=run('/test hubdisplays day +1')
 check(ok and hub:Snapshot().Day==day+1 and hub:Snapshot().DayOffset==1,'hubdisplays day +1 previews tomorrow')
 ok,msg=run('/test hubdisplays day 0');check(ok and hub:Snapshot().Day==day,'hubdisplays day 0 comes back')
 ok,msg=run('/test hubdisplays day +3');check(not ok and msg:find('Use hubdisplays day',1,true),'an odd day is refused with the usage line')
 ok,msg=run('/test hubdisplays nonsense');check(not ok and msg:find('Use hubdisplays',1,true),'an unknown subcommand is refused')
 ok,msg=run('/test hubdisplays @Gus');check(not ok and msg:find('once',1,true),'hubdisplays takes no @name (it affects the server once): "'..tostring(msg)..'"')
 ok,msg=run('/test hubdisplays reset @all');check(not ok,'neither does reset')
 ok,msg=run('/test bestpull fire pepper',Gus);check(not ok and msg:find('owner',1,true),'a player who is not an owner or admin is refused ('..tostring(msg)..')')
 local noHub=setmetatable({Chase={IsPlayerBusy=function()return false end}},{__index=ctx})
 Run.IsStudio=function()return true end;owners[Fay]=true
 local okN,msgN=Cmd.Execute(noHub,Fay,'/test hubdisplays');Run.IsStudio=function()return false end
 check(not okN and msgN:find('not running',1,true),'with no service running the commands say so')
 -- help and docs
 local Help=W.module('StudioTestHelp');local has={}
 for _,e in ipairs(Help)do for _,k in ipairs({'bestpull','bigfruit','hubdisplays'})do if e[1]:find('/test '..k,1,true)then has[k]=e end end end
 check(has.bestpull and has.bigfruit and has.hubdisplays and has.hubdisplays[2]:find('day +1',1,true)and has.bestpull[2]:find('share',1,true),'the F4 help lists bestpull, bigfruit and hubdisplays (day +1, share)')
end

print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
