--!nocheck
-- R158e tutorial, the server half, on the REAL player data (the R123 world): PlayerDataService (AddChest / OpenSeedPack / PlantSeed / HarvestPlant / SellHarvest, save and load),
-- TutorialProgress, TutorialTargets, PremiumService's Tutorial branch (from source), BeginnerGuide.
--  1  the ten steps walked by a new player: the published step (1 / 4 / 6 / 7 / 9 / 10 / 0) and what the server points at (the nearest pack; carrying: the home line; your dirt; the
--     plant; the market; your treadmill; your base pad as "home");
--  2  only a pack STOLEN on the track (banked) ticks the steal step (the new-player gift pack, a roll, a grant never); after it, opening ANY pack counts (the owner's rule);
--  3  the first fruit in 10 s: the plant planted in the plant step, once per player (saved); its later fruit / regrowth in the normal time; a skipped tutorial: never;
--  4  harvest -> sell -> the treadmill (TreadmillInfo only on step 10) -> done -> the free Forest pack (2x); skip at the start: nothing;
--  5  old saves (R111 - R158d masks) land on the right step; a finished save stays finished; Fast / FastCrop are saved and loaded (optional fields, ProfileVersion 22);
--  6  BeginnerGuide.Resolve over every published step walks the ten looks.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS;local V3,CF=R.Vector3.new,R.CFrame.new
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
local function dsCopy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=dsCopy(x)end;return o end
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(dsCopy(self.Data[key]),nil);if v~=nil then self.Data[key]=dsCopy(v)end;return dsCopy(self.Data[key])end,
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
R.clock=20727*86400+3600*5 -- (os.time on the mock = the clock: a real-looking Unix time)
local Config=server('Config');local Guide=W.module('BeginnerGuide');local B=Guide.Bits;local Rules=W.module('PlantRules');local Packs=W.module('SeedPackRules')
local Targets=server('TutorialTargets')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,{Show=function()end})
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 local m=R.new('Model');m.Name=name;local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,0);root.Parent=m;m.PrimaryPart=root;m.Parent=W.workspace;p.Character=m
 return p
end
local function state(p)return Data:GetPremium(p).Tutorial end
local function step(p)return p:GetAttribute('TutorialStep')end
local function now()return math.floor(R.clock)end
-- A stand-in ChestService for TutorialTargets: the track's packs, the home line, the market, your base (pad, spawn, treadmill, garden dirt).
local function part(name,pos,size)local q=R.new('Part');q.Name=name;q.Size=size or V3(4,1,4);q.CFrame=CF(pos.X,pos.Y,pos.Z);return q end
local baseModel=R.new('Model');baseModel.Name='Base1'
local plots=R.new('Folder');plots.Name='GardenPlots';plots.Parent=baseModel
for i=1,10 do part('DirtPlot_'..i,V3(-20+i,1,10),V3(46,1,22.6)).Parent=plots end
local base={Model=baseModel,Pad=part('Pad',V3(0,0,-20),V3(118,1,180)),Spawn=part('Spawn',V3(0,1,-60)),Treadmill=part('Treadmill',V3(12,1,-6))}
local function worldPack(pos)local body=part('Pack',pos);body.Parent=W.workspace;return {Stage=1,Available=true,Body=body,Prompt={Enabled=true}}end
local packs={worldPack(V3(40,3,90)),worldPack(V3(-60,3,140))}
local chests={Bases={GetPlayerBase=function()return base end},Map={Chests=packs,Refreshing=false,BaseBoundaryLine=part('Line',V3(0,1,50),V3(240,1,2)),SellStation=part('SellStation',V3(0,3,-150))},
 GetPackPickupPosition=function(_,_,pos)return pos end}
local function targets(p)return Targets.State(Data,chests,p)end
local function record(p,id)for _,r in ipairs(Data:GetChestRecords(p))do if r.Id==id then return r end end end
local function crop(p,id)for _,list in pairs(Data.Gardens[p].Plots)do for _,c in ipairs(list)do if c.Id==id then return c end end end end
local function steal(p)return Data:AddChest(p,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{Luck=true,Banked=true})end
local function grantPack(p)return Data:AddChest(p,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})end
local function open(p,id)return Data:OpenSeedPack(p,id,function()return .02 end)end -- (this roll gives a Forest seed with several fruit: "only the first fruit" is checked)
local function finish(p) -- PremiumService's Tutorial request for an action (its branch is checked from source below)
 return function(action)
  if Data:TutorialAction(p,action)then Data:PublishTutorial(p)end
  local gift;if(action=='TreadmillInfo'or action=='Skip')and p:GetAttribute('TutorialDone')==true then gift=Data:GrantStarterPack(p)end
  return gift
 end
end

-- 1-4. A new player walks the ten steps ---------------------------------------------------------------------------------------------------------------------------------
local P=makePlayer(501,'Nova')
check(P:GetAttribute('TutorialDone')==false and step(P)==1,'a brand-new player: step 1 (spawn arrow / TRACK / steal on the client)')
local t=targets(P)
check(t.Success and t.Step==1 and t.Kind=='Pack'and t.Target==V3(40,3,90)and t.TargetPart==packs[1].Body and not t.WaitingForPack,'steps 1 - 3: the server points at the nearest pack')
check(t.HomeCFrame==base.Pad.CFrame and t.HomeSize==base.Pad.Size,'and sends your base pad (home for steps 5 - 10)')
P:SetAttribute('ChestChaseSeedCarrying',true);t=targets(P);check(t.Kind=='Safety'and math.abs(t.Target.Z-38)<.01,'carrying a stolen pack: the home line');P:SetAttribute('ChestChaseSeedCarrying',false)
-- the new-player gift (or a roll / grant) is not a steal
local gift=grantPack(P);check(step(P)==1,'2: a pack that was not stolen (the gift, a roll) does not tick the steal step')
open(P,gift.Id);check(step(P)==1,'2: opening it before the steal changes nothing yet')
steal(P);check(step(P)==4,'3 -> 4: a pack stolen on the track and banked')
t=targets(P);check(t.Step==4 and t.Kind==nil,'4: no world target (the hotbar slot / clicking hand on the client)')
local other=grantPack(P);open(P,other.Id);check(step(P)==6,'4 -> 6: opening ANY pack counts (owner)')
t=targets(P);check(t.Step==6 and t.Kind=='Garden'and t.Target~=nil,'5 / 6: your dirt')
-- the plant step: the first fruit in 10 s
local seed=record(P,other.Id);local def=Config.GardenPlants[seed.SeedId]
print(('INFO the planted seed: %s, %d fruit, %d s to grow, regrows in %s s'):format(seed.SeedId,def.FruitCount or 1,def.Seconds,tostring(def.RegrowSeconds)))
check((def.FruitCount or 1)>1 and def.Mode~='whole'and def.Regrows~=false,'(the walk plants a seed with several fruit, so "only the first fruit" is checked)')
local okPlant,planted=Data:PlantSeed(P,1,seed.Id,{OffsetX=-8,OffsetZ=0},now())
local c=okPlant and crop(P,planted.Id)
check(okPlant and step(P)==7,'6 -> 7: planted')
check(c and c.MatureAt==now()+10 and Rules.FruitReadyAt(c,1)==now()+10,'3: its first fruit is ready in exactly 10 s ('..tostring(c and c.MatureAt-now())..')')
check(state(P).Fast==true and state(P).FastCrop==planted.Id,'3: flagged on the server: once (Fast) and which plant (FastCrop)')
local normal=now()+def.Seconds
local others=true;for i=2,def.FruitCount do if Rules.FruitReadyAt(c,i)<normal-1 then others=false end end
check(others,'3: its other fruit grow in the normal time ('..def.FruitCount..' fruit, '..def.Seconds..' s)')
check(Rules.ValidTraits(c,def.FruitCount),'3: the quick plant is a valid saved crop (the loader keeps it)')
do -- the look (PlantGrowth): fruit 1 ripens with the plant at 10 s; fruit 2+ grow smoothly over their normal time (no jump when the plant is grown up at 10 s)
 local Growth=W.module('PlantGrowth');local t0=c.PlantedAt
 local _,f1=Growth.Progress(c,def,t0+10,1);local _,a=Growth.Progress(c,def,t0+9.9,2);local _,b2=Growth.Progress(c,def,t0+10.1,2);local _,e=Growth.Progress(c,def,t0+def.Seconds-1,2)
 check(f1==1 and math.abs(b2-a)<.01 and a<.2 and e>.95,('3: the look: fruit 1 ripe at 10 s, fruit 2 grows smoothly (%.3f -> %.3f at 10 s, %.2f near its time)'):format(a,b2,e))
end
t=targets(P);check(t.Step==7 and t.Kind=='Crop'and t.ReadyIn==10 and t.Ripe==false and t.Target~=nil,'7: the plant, ready in 10 s, not ripe yet')
R.clock+=10;t=targets(P);check(t.ReadyIn==0 and t.Ripe==true,'7 -> 8: 10 s after planting the fruit is ripe')
local okH,harvest=Data:HarvestPlant(P,1,planted.Id,now(),1)
check(okH and step(P)==9,'8 -> 9: harvested')
check(not Data:HarvestPlant(P,1,planted.Id,now(),2),'3: the second fruit is not quick (normal timing)')
check(Rules.FruitReadyAt(c,1)>=now()+(def.RegrowSeconds or 1)-1,'3: fruit 1 regrows in the normal time ('..(Rules.FruitReadyAt(c,1)-now())..' s)')
t=targets(P);check(t.Step==9 and t.Kind=='Sell'and t.Target==V3(0,3,-150),'9: the market')
check(Data:SellHarvest(P,harvest.Id)and step(P)==10,'9 -> 10: sold')
t=targets(P);check(t.Step==10 and t.Kind=='Treadmill'and t.Target==V3(12,1,-6),'10: your treadmill')
local starter=finish(P)('TreadmillInfo')
check(P:GetAttribute('TutorialDone')==true and step(P)==0,'10 -> done')
check(starter and starter.RateBoost==2 and starter.Stage==1,'the free Forest pack (2x) for finishing')
-- once per player: the tutorial put back on the plant step by hand: the next plant grows normally
do local s=state(P);s.Done=false;s.Mask=bit32.bor(1,B.Pack,B.Seed);Data:PublishTutorial(P)
 local again=grantPack(P);open(P,again.Id)
 local ok2,c2=Data:PlantSeed(P,2,again.Id,{OffsetX=0,OffsetZ=0},now())
 check(ok2 and c2.MatureAt>now()+10 and step(P)==7,'3: only once per player: a second tutorial plant grows in its normal time')
 s.Done=true;Data:PublishTutorial(P)
end
-- a skipped tutorial: no quick fruit, no free pack
do local Q=makePlayer(502,'Skipper');finish(Q)('Skip')
 local pk=steal(Q);open(Q,pk.Id);local ok,cq=Data:PlantSeed(Q,1,pk.Id,{OffsetX=0,OffsetZ=0},now())
 check(ok and cq.MatureAt>now()+10 and not state(Q).Fast,'3: a skipped tutorial: no quick fruit')
 check(Data:GrantStarterPack(Q)==nil,'4: skipping at the start gives no free pack')
end
-- the PremiumService Tutorial branch (from source: PremiumService.new starts product loaders the mock can't settle)
local src=W.B.PremiumService
check(src:find("if(value=='TreadmillInfo'or value=='Skip')and p:GetAttribute('TutorialDone')==true then",1,true)and src:find('return require(script.Parent.TutorialTargets).State(data,chests,p)',1,true),'PremiumService: TreadmillInfo / Skip grant the free pack, every request answers with the targets')

-- 5. Old saves -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local cases={{1,1},{bit32.bor(1,B.Pack),4},{bit32.bor(1,B.Pack,B.Seed),6},{bit32.bor(1,B.Pack,B.Seed,B.Plant),7},{bit32.bor(1,B.Pack,B.Seed,B.Plant,B.Harvest),9},
  {bit32.bor(1,B.Pack,B.Seed,B.Plant,B.Harvest,B.Sell,B.Cash),10}}
 for i,case in ipairs(cases)do
  local V=makePlayer(600+i,'Old'..i);local saved=Data:_buildSaveData(V);saved.Premium.Tutorial={Version=1,Mask=case[1],Done=false}
  Data.Store.Data['Player_'..(700+i)]=saved
  local V2=makePlayer(700+i,'Back'..i)
  check(step(V2)==case[2]and V2:GetAttribute('TutorialDone')==false,('5: an old save with mask %d resumes at step %d (got %s)'):format(case[1],case[2],tostring(step(V2))))
 end
 for i,mask in ipairs({255,31,1})do
  local V=makePlayer(810+i,'Finished'..i);local saved=Data:_buildSaveData(V);saved.Premium.Tutorial={Version=1,Mask=mask,Done=true}
  Data.Store.Data['Player_'..(820+i)]=saved;local V2=makePlayer(820+i,'StillDone'..i)
  check(V2:GetAttribute('TutorialDone')==true and step(V2)==0,'5: a finished save (mask '..mask..') stays finished')
 end
 local L=makePlayer(802,'Saver');local pk=steal(L);open(L,pk.Id);local ok,cl=Data:PlantSeed(L,1,pk.Id,{OffsetX=0,OffsetZ=0},now())
 local saved=Data:_buildSaveData(L);local st=saved.Premium.Tutorial
 check(ok and st.Fast==true and st.FastCrop==cl.Id and st.Version==1,'5: Fast / FastCrop are saved')
 Data.Store.Data['Player_803']=saved;local L2=makePlayer(803,'Loader');local s2=state(L2)
 check(s2.Fast==true and s2.FastCrop==cl.Id and step(L2)==7,'5: ... and loaded back (the grow step, the same plant)')
 check(Config.ProfileVersion==22,'5: ProfileVersion is still 22')
end

-- 6. Resolve walks the ten looks over the published steps ------------------------------------------------------------------------------------------------------------------
do
 local seen={}
 local function look(c)local s,k=Guide.Resolve(c);seen[s]=k;return s,k end
 look({Stage=1,OnTrack=false});look({Stage=1,OnTrack=false,IntroDone=true});look({Stage=1,OnTrack=true})
 look({Stage=4,PackInHand=true});look({Stage=6,Home=false});look({Stage=6,Home=true,SeedInHand=true})
 look({Stage=7,Home=true});look({Stage=7,Home=true,Ripe=true});look({Stage=9});look({Stage=10,Home=true})
 local order={'Spawn','Track','Grab','Open','Base','Plant','Grow','Harvest','Market','Treadmill'}
 for i,k in ipairs(order)do check(seen[i]==k,('6: step %d is %s (%s)'):format(i,k,tostring(seen[i])))end
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
