--!nocheck
-- R123 treadmill bonus rolls, server side, under the Roblox mock: the real TreadmillBonusService, TreadmillBonusRules,
-- PlayerDataService (+ PremiumProgress etc.), Config, SeedPackRules/PackOdds112 and SecurityGate. DataStores are in
-- memory and every write is deep-copied through a DataStore-safe check. BaseService is a stand-in that only exposes
-- TrainingSessions (the real on-treadmill lock the service reads); ChestService is a SyncTools counter.
-- Run from a folder holding roblox.luau, world.luau, rs_bundle.luau and srv_names.luau (see run.sh).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return math.abs(a-b)<=tol end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;table.sort(out,function(a,b)return a.UserId<b.UserId end);return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local function dsCopy(v,path)
 path=path or'value';local t=type(v)
 if t=='string'or t=='number'or t=='boolean'or t=='nil'then return v end
 if t~='table'or getmetatable(v)~=nil or v.__type then error('not DataStore-safe at '..path..': '..R.typeof(v),0)end
 local o={};for k,x in pairs(v)do o[k]=dsCopy(x,path..'.'..tostring(k))end;return o
end
local stores={}
local DS=W.service('DataStoreService')
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Name=name,Data={},
  UpdateAsync=function(self,key,fn)local v=fn(dsCopy(self.Data[key]),nil);if v~=nil then self.Data[key]=dsCopy(v)end;return dsCopy(self.Data[key])end,
  GetAsync=function(self,key)return dsCopy(self.Data[key])end,SetAsync=function(self,key,v)self.Data[key]=dsCopy(v)end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end;return o end end
-- Real modules ------------------------------------------------------------------------------------------
local Config=server('Config')
local Rules=W.module('TreadmillBonusRules');local PackRules=W.module('SeedPackRules')
local notes={}
local Random=W.env.Random -- the mock's LCG (service claims); distribution checks use math.random (PCG)
local Notes={Show=function(_,p,msg)notes[#notes+1]={P=p,Text=msg}end}
local Map={GetStageAccent=function(_,stage)return R.Color3.new(stage/10,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
local Base={TrainingSessions={}}
local Chests={Synced={}};function Chests:SyncTools(p)self.Synced[p]=(self.Synced[p]or 0)+1 end
local Bonus=server('TreadmillBonusService').new(Config,Data,Base,Chests,Notes)
local remote=remotes:FindFirstChild(Rules.RemoteName)
check(remote and remote:IsA('RemoteFunction'),'TreadmillBonusRoll RemoteFunction created')
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 local bp=R.new('Backpack');bp.Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 local tut=Data:GetPremium(p).Tutorial;if tut then tut.Done=true end;Bonus:Setup(p)
 return p
end
local A=makePlayer(101,'Alice')
-- Heartbeat stand-in: dt-sized steps; on/off decides whether A holds a training session.
local function train(p,seconds,on,dt)
 dt=dt or .5;Base.TrainingSessions[p]=on and{}or nil
 local n=math.floor(seconds/dt+.5);for _=1,n do R.advance(dt);Bonus:Step(dt)end
end
local function attr(p,k)return p:GetAttribute(Rules.Attr[k])end
local function invoke(p,...)return remote.OnServerInvoke(p,...)end
local function packs(p)return #Data:GetChestRecords(p)end

-- 1. Only treadmill time counts --------------------------------------------------------------------------
check(attr(A,'Ready')==0 and attr(A,'Pool')=='1','fresh profile: 0 ready, Forest-only pool ('..tostring(attr(A,'Pool'))..')')
train(A,900,false)
check(Bonus:GetProgress(A)==0 and attr(A,'Ready')==0,'15 min off the treadmill: no progress')
check(Rules.IntervalSeconds==360,'R124: one roll per 6 minutes')
train(A,359,true)
check(attr(A,'Ready')==0 and near(Bonus:GetProgress(A),359,.01),'5:59 on the treadmill: not ready yet')
check(attr(A,'DueAt')~=nil,'DueAt published while training')
train(A,1,true)
check(attr(A,'Ready')==1,'6 min on the treadmill -> 1 roll ready')
check(near(Bonus:GetProgress(A),0,.01),'progress restarts after a roll becomes ready')
check(#notes>0 and notes[#notes].Text:find('bonus roll ready'),'ready notice sent')
-- 2. Progress pauses off the treadmill and is kept (any length of break) ---------------------------------
train(A,180,true);train(A,3600,false)
check(near(Bonus:GetProgress(A),180,.01),'3 min, then an hour off: the 3 min are kept')
check(attr(A,'DueAt')==nil and attr(A,'Left')==180,'off the treadmill: no DueAt, 3:00 left published')
train(A,180,true)
check(attr(A,'Ready')==2,'3 + 3 min -> second roll ready')
-- 3. Cap: 2 ready; time beyond is lost (progress pauses) -------------------------------------------------
train(A,1800,true)
check(attr(A,'Ready')==2 and Bonus:GetProgress(A)==0,'at 2 ready the timer pauses: 30 more min add nothing')
check(attr(A,'DueAt')==nil,'no countdown at the cap')
-- 4. Claim: rate-limited, validated, pack granted once through AddChest + SyncTools ----------------------
A:SetAttribute('ChestLuckMultiplier',50000000)
local before,synced=packs(A),Chests.Synced[A]or 0
R.advance(2)
local res=invoke(A)
check(res and res.Ok==true,'claim succeeds: '..tostring(res and res.Error))
check(packs(A)==before+1,'exactly one pack added')
local rec=Data:GetChestRecords(A)[packs(A)]
check(rec and rec.Kind=='Pack'and rec.Id==res.Id,'granted record is a Pack with the returned id')
check(rec and rec.Stage==1 and res.Stage==1,'Forest treadmill -> Forest pack')
check(rec and rec.BagVariant==res.Variant and rec.OddsVersion==PackRules.OddsVersion and rec.PackMutation=='None','plain world pack, current odds version')
check(rec and rec.PackSize==res.Size and PackRules.SanitizePackSize(res.Size)==res.Size,'R126: the rolled pack size is saved and returned ('..tostring(res.Size)..')')
check(rec and rec.SeedScale==PackRules.NewSeedScale(rec.Stage,rec.BagVariant,rec.PackSize),'R126: seed scale follows the pack size like a world pack')
check(res.Rarity==PackRules.GetPackTier(res.Variant).Name,'result rarity = the pack tier ('..tostring(res.Rarity)..')')
check((Chests.Synced[A]or 0)==synced+1,'Tool synced once')
check(attr(A,'Ready')==1 and res.Ready==1,'one roll spent')
local again=invoke(A)
check(again and again.Error and packs(A)==before+1,'immediate second claim refused (cooldown), nothing granted')
check(invoke(A,'Legendary').Error~=nil and packs(A)==before+1,'client arguments refused')
R.advance(2);check(invoke(A).Ok and packs(A)==before+2 and attr(A,'Ready')==0,'second claim spends the last roll')
R.advance(2);local none=invoke(A)
check(none.Error and packs(A)==before+2,'no roll ready: refused, nothing granted')
-- spam: SecurityGate + cooldown never grant without a ready roll
for _=1,50 do invoke(A)end
check(packs(A)==before+2,'50 spam claims grant nothing')
-- 5. Full bag: refused, roll stays ready ---------------------------------------------------------------
train(A,360,true);check(attr(A,'Ready')==1,'roll ready again')
local cap=Config.MaxSavedChests;Config.MaxSavedChests=packs(A)
R.advance(2);local full=invoke(A)
check(full.Error and full.Error:find('FULL')and attr(A,'Ready')==1 and packs(A)==Config.MaxSavedChests,'full bag: refused, roll kept ('..tostring(full.Error)..')')
Config.MaxSavedChests=cap
R.advance(2);check(invoke(A).Ok,'after making room the kept roll works')
-- 6. Persistence: progress saved, ready rolls are not ---------------------------------------------------
train(A,360,true);train(A,250,true)
check(attr(A,'Ready')==1 and near(Bonus:GetProgress(A),250,.01),'1 ready + 4:10 progress before leaving')
check(Data:Save(A,'test',true)~=false,'saved')
local key='Player_'..A.UserId;local saved
for _,s in pairs(stores)do if s.Data[key]then saved=s.Data[key]end end
check(saved and saved.Premium and near(saved.Premium.TreadmillBonusProgress,250,.01),'progress is in the saved profile')
check(saved and saved.Premium.TreadmillBonusReady==nil,'ready rolls are not saved')
Bonus:Cleanup(A);Data:CleanupPlayer(A);present[A.UserId]=nil;Base.TrainingSessions[A]=nil
local A2=makePlayer(101,'Alice')
check(near(Bonus:GetProgress(A2),250,.01),'rejoin: 4:10 progress restored')
check(attr(A2,'Ready')==0,'rejoin: the unclaimed roll is gone')
train(A2,350,true);check(attr(A2,'Ready')==1,'rejoin: 4:10 + 5:50 -> roll ready')
-- corrupted / hostile saved values are clamped
Data:GetPremium(A2).TreadmillBonusProgress=1e309;check(Bonus:GetProgress(A2)==0,'inf progress reads as 0')
Data:GetPremium(A2).TreadmillBonusProgress=-5;check(Bonus:GetProgress(A2)==0,'negative progress reads as 0')
Data:GetPremium(A2).TreadmillBonusProgress=0
-- 7. Pool by treadmill tier (cumulative) ----------------------------------------------------------------
local mapping={}
for tier=1,#Config.TreadmillTiers do
 Data:GetTreadmillData(A2).Tier=tier;Bonus:Step(0)
 local stages=Rules.DecodePool(attr(A2,'Pool'))
 check(#stages==tier,'tier '..tier..' pool has '..tier..' biomes')
 check(stages[tier]==Config.TreadmillTiers[tier].Stage,'tier '..tier..' adds '..Config.TreadmillTiers[tier].Biome)
 local names={};for _,s in ipairs(stages)do names[#names+1]=PackRules.DesignBiomes[s]end
 mapping[#mapping+1]=string.format('  %d %-14s -> %s',tier,Config.TreadmillTiers[tier].Name,table.concat(names,', '))
end
print('Treadmill tier -> bonus pool');print(table.concat(mapping,'\n'))
local all=Rules.DecodePool(attr(A2,'Pool'));local seen={}
for _,s in ipairs(all)do seen[s]=true end
check(#all==7 and seen[1]and seen[2]and seen[3]and seen[4]and seen[5]and seen[6]and seen[7],'Storm treadmill: all 7 biomes')
-- Storm claims: biome spread + never Mech (R124: a Void Pack, when it comes up, is the Secret tier and always Storm)
local stageCount,variantSeen={},{}
for _=1,60 do
 Bonus.Ready[A2]=1;R.advance(2);local r=invoke(A2)
 if r.Ok then stageCount[r.Stage]=(stageCount[r.Stage]or 0)+1;variantSeen[r.Variant]=true end
 local last=Data:GetChestRecords(A2)[#Data:GetChestRecords(A2)];Data:RemoveChest(A2,last.Id)
end
check(not variantSeen.MechLimited,'never a Mech pack')
local distinct=0;for _ in pairs(stageCount)do distinct+=1 end
check(distinct>=5,'60 Storm claims spread over many biomes ('..distinct..')')
-- 8. Odds (R124 owner spec): Secret/Void 0.1, Mythic 0.5, Legendary 2, rest 43.5/28.6/17.2/8.1; uniform biome, luck-free
local odds=Rules.VariantOdds();local spec={Pack01=43.5,Pack02=28.6,Pack03=17.2,Pack04=8.1,Pack05=2,Pack06=.5,EclipseReliquary=.1}
local sum=0;for k,v in pairs(spec)do sum+=v;check(near(odds[k],v/100,1e-9),k..' chance = '..v..'%')end;check(near(sum,100,1e-9),'odds add up to 100%')
check(Rules.Tier('EclipseReliquary')=='Secret'and Rules.Special.Secret and Rules.Special.Legendary and Rules.Special.Mythic,'Void Pack shows as SECRET and gets the special reveal')
math.randomseed(7);local rng={NextNumber=function()return math.random()end};local n=200000;local vc,sc={},{}
for _=1,n do local p=Rules.RollPack(all,function()return rng:NextNumber()end);vc[p.Variant]=(vc[p.Variant]or 0)+1;sc[p.Stage]=(sc[p.Stage]or 0)+1 end
local rows={}
for _,k in ipairs(Rules.VariantOrder)do
 local got=(vc[k]or 0)/n;local want=odds[k];local tol=4*math.sqrt(want*(1-want)/n)
 check(near(got,want,tol),string.format('%s observed %.3f%% vs %.3f%%',k,got*100,want*100))
 rows[#rows+1]=string.format('  %-9s %-16s spec %6.2f%%  observed %6.3f%%',(Rules.Tier(k)),k,want*100,got*100)
end
print('Bonus roll odds over '..n..' rolls (Storm pool)');print(table.concat(rows,'\n'))
local void=odds.EclipseReliquary
for s=1,7 do local want=(1-void)/7+(s==7 and void or 0);check(near((sc[s]or 0)/n,want,4*math.sqrt(want*(1-want)/n)),'biome '..s..' ~1/7 (Storm + the Void share)')end
-- A Secret result is a real Storm Void Pack, even from a Forest-only pool, and is granted like any other pack.
do
 local p=Rules.RollPack({1},(function()local k=0;return function()k+=1;return k==1 and 0 or .9995 end end)())
 check(p.Variant=='EclipseReliquary'and p.Stage==7,'Secret roll from a Forest pool = Storm Void Pack')
 local saved=Bonus.Random;Bonus.Random={NextNumber=function(_)return .9995 end}
 Bonus.Ready[A2]=1;R.advance(2);local r=invoke(A2);Bonus.Random=saved
 local last=Data:GetChestRecords(A2)[#Data:GetChestRecords(A2)]
 check(r.Ok and r.Variant=='EclipseReliquary'and r.Stage==7 and r.Rarity=='Secret'and r.Biome=='Void Pack','server returns SECRET Void Pack: '..tostring(r.Rarity)..' '..tostring(r.Biome))
 check(last and last.BagVariant=='EclipseReliquary'and last.Stage==7,'Void Pack granted to the bag as a Storm pack')
 check(last and last.PackSize==PackRules.RollPackSize(.9995)and last.PackSize>1 and r.Size==last.PackSize,'R126: the Void Pack rolls a size too (.9995 -> '..tostring(last and last.PackSize)..'x)')
 if last then Data:RemoveChest(A2,last.Id)end
end
-- Luck/boots never change a result: same random stream, boots on vs off -> identical claims
local function seq(luck)
 A2:SetAttribute('ChestLuckMultiplier',luck);Bonus.Random=Random.new(99);local out={}
 for i=1,40 do Bonus.Ready[A2]=1;R.advance(2);local r=invoke(A2);out[i]=r.Stage..r.Variant
  local last=Data:GetChestRecords(A2)[#Data:GetChestRecords(A2)];Data:RemoveChest(A2,last.Id)end
 return table.concat(out,'|')
end
check(seq(1)==seq(25000000)and seq(1)==seq(50000000),'boot luck x25M (Thunder Boots, R155) and x50M (the cap, with the clover) give the identical 40 claims')
-- R126 (owner): every roll also rolls the pack size from the world table (BalanceRules.PackSizes), luck-free.
do
 local want,weights={},{};for _,row in ipairs(PackRules.PackSizes)do want[row.Scale]=row.Weight/100 end
 local saved=Bonus.Random;math.randomseed(126);Bonus.Random={NextNumber=function(_)return math.random()end}
 A2:SetAttribute('ChestLuckMultiplier',50000000)
 local n,count,bad,scaleBad,labelBad=6000,{},0,0,0
 for _=1,n do
  -- R137: bonus packs also go through the hidden size pity; with its counters at 0 the natural table shows.
  Data:LoadPackLuck(A2,{Big=0,Giant=0})
  Bonus.Ready[A2]=1;R.advance(2);local r=invoke(A2)
  local last=Data:GetChestRecords(A2)[#Data:GetChestRecords(A2)]
  if not(r.Ok and last and last.Id==r.Id and want[last.PackSize]and r.Size==last.PackSize)then bad+=1 end
  if last and last.SeedScale~=PackRules.NewSeedScale(last.Stage,last.BagVariant,last.PackSize)then scaleBad+=1 end
  if r.Label~=PackRules.PackLabel(r.Stage,r.Variant,1,'None')then labelBad+=1 end
  if last then count[last.PackSize]=(count[last.PackSize]or 0)+1;Data:RemoveChest(A2,last.Id)end
 end
 Bonus.Random=saved;A2:SetAttribute('ChestLuckMultiplier',1)
 check(bad==0,'R126: every roll grants a size from the world table ('..bad..' bad)')
 check(scaleBad==0,'R126: every rolled pack seed scale = NewSeedScale(size)')
 check(labelBad==0,'R126: result text unchanged (the label never names the size)')
 for _,s in ipairs({.5,1,1.5,2.5})do local p=want[s];local got=(count[s]or 0)/n
  check(near(got,p,4*math.sqrt(p*(1-p)/n)),string.format('R126: size %sx ~%.1f%% (got %.2f%%)',s,p*100,got*100))end
 local big=0;for s,c in pairs(count)do if s>1 then big+=c end end
 check(big>0 and(count[1]or 0)<n,'R126: sizes really vary ('..big..' bigger than 1x)')
end
-- 9. Upgrading the treadmill republishes the pool immediately; leaving drops session state -----------------
Data:GetTreadmillData(A2).Tier=2;Bonus:Step(0);check(attr(A2,'Pool')=='1,6','upgrade/downgrade republishes pool ('..tostring(attr(A2,'Pool'))..')')
-- 10. Public API used by owner test commands
check(Bonus:GrantReady(A2,5)and attr(A2,'Ready')==2,':GrantReady clamps to 2')
check(Bonus:SetProgress(A2,9999)and Bonus:GetProgress(A2)==360 and attr(A2,'Left')==0,':SetProgress clamps to 360')
Bonus:SetProgress(A2,123);check(attr(A2,'Left')==237,':SetProgress republishes time left')
local pool=Bonus:Pool(A2);check(#pool==2 and pool[1]==1 and pool[2]==6,':Pool returns the stages')
Bonus:Cleanup(A2);check(Bonus.Ready[A2]==nil and Bonus.State[A2]==nil,'cleanup drops session state')
-- R123 owner commands (/test bonus ...) through OwnerUpdateCommands82.Execute
do
 local X=server('OwnerUpdateCommands82')
 local O=makePlayer(303,'Owen')
 local ctx={Chase={TreadmillBonus=Bonus},Data=Data,Config=Config,Map={MapRoot=R.new('Folder')}}
 local ok,msg=X.Execute(ctx,O,'bonus',{});check(ok and msg:find('Ready 0/2',1,true)and msg:find('pool: Forest',1,true),'bonus status: '..tostring(msg))
 ok,msg=X.Execute(ctx,O,'bonus',{'ready','2'});check(ok and Bonus:GetReady(O)==2 and attr(O,'Ready')==2,'bonus ready 2: '..tostring(msg))
 ok,msg=X.Execute(ctx,O,'bonus',{'ready','1'});check(ok and Bonus:GetReady(O)==1,'bonus ready sets (not adds): '..tostring(msg))
 ok,msg=X.Execute(ctx,O,'bonus',{'ready','5'});check(not ok and Bonus:GetReady(O)==1,'bonus ready over 2 refused')
 ok,msg=X.Execute(ctx,O,'bonus',{'progress','5:50'});check(ok and Bonus:GetProgress(O)==350 and msg:find('/ 360 s',1,true),'bonus progress 5:50 = 350 s: '..tostring(msg))
 ok,msg=X.Execute(ctx,O,'bonus',{'progress','400'});check(not ok and Bonus:GetProgress(O)==350,'bonus progress over 360 refused')
 local before=packs(O)
 ok,msg=X.Execute(ctx,O,'bonus',{'roll'});check(ok and packs(O)==before+1 and Bonus:GetReady(O)==0,'bonus roll grants one pack: '..tostring(msg))
 R.advance(2);ok,msg=X.Execute(ctx,O,'bonus',{'roll'});check(not ok and packs(O)==before+1,'bonus roll with none ready refused: '..tostring(msg))
 ok,msg=X.Execute(ctx,O,'bonus',{'spin'});check(not ok,'unknown bonus mode refused')
end
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
