--!nocheck
-- R137 on the mock with the real modules (SeedPackRules, PackOdds112/137, BalanceRules, PackSizePity, Config,
-- PlayerDataService + PackSizePityData, ChestService.SkinWorldSeeds):
--  1. odds version 137 = the owner-approved proposal (docs/proposals/pity_R136) for every biome and pack;
--  2. packs people already have keep their odds (112, Void, Mech), and saved 112 packs still load as 112;
--  3. the new size table;
--  4. the hidden player pity: soft ramp, never more than 30 packs without a 5x+ or 200 without a 10x+, only for
--     earned biome packs, saved with the profile;
--  5. the hidden track pity: one random spot, never more than 6 refreshes without a 5x+ or 12 without a 10x+.
local W=require('./world');local R=W.R
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
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end;return o end end
local Config=server('Config')
local Rules=W.module('SeedPackRules');local Pity=W.module('PackSizePity');local O137=W.module('PackOdds137')
local expected=require('./expected')
-- R148: the rarity a pack made before the roster change rolls a seed at (Rules.RarityBeforeR149 is empty by the owner's decision: Fire Pepper and
-- Moon Melon follow their new tiers in every pack, so this is today's rarity).
local function tiers(odds)local t={};for id,p in pairs(odds or{})do local r=Rules.RarityBeforeR149[id]or Rules.GetRarity(id);t[r]=(t[r]or 0)+p/100 end;return t end
local function same(a,b)
 for _,k in ipairs({'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'})do
  if math.abs((a[k]or 0)-(b[k]or 0))>1e-12 then return false,k end
 end
 return true
end
-- 1. Odds 137 ---------------------------------------------------------------------------------------------------
-- R148: new packs carry odds version 149 = this model's numbers (PackOdds137) over today's roster; a pack banked at 137 rolls the roster it was made with
-- (no Aloe / Sand Fruit), so the 137 rows below are the approved proposal's. Lava (4) and Crystal (5) are the exception: the roster change promoted
-- Fire Pepper to Mythic and Moon Melon to Legendary (owner: banked packs follow the new tiers too), so the proposal's tier table no longer
-- describes them; test_roster.luau checks their new rows exactly.
check(Rules.OddsVersion==149 and Rules.ValidOddsVersion(137),'new packs carry odds version 149 (PackOdds137\'s numbers over today\'s roster)')
local wrong,rows={},0
for _,e in ipairs(expected.new)do
 if e.Stage~=4 and e.Stage~=5 then
  rows+=1
  local ok,k=same(tiers(Rules.SeedOdds(Config,e.Stage,e.Pack,1,137)),e.Odds)
  if not ok then wrong[#wrong+1]=e.Stage..'/'..e.Pack..' '..k end
 end
end
check(rows==30 and #wrong==0,'all 30 biome x pack odds (not Lava / Crystal) match the approved proposal ('..table.concat(wrong,', ')..')')
local function oneIn(stage,pack,tier)local p=tiers(Rules.SeedOdds(Config,stage,pack,1,137))[tier]or 0;return p>0 and 1/p or 0 end
check(math.abs(oneIn(1,'Pack01','Legendary')-60)<1e-6 and math.abs(oneIn(1,'Pack01','Mythic')-400)<1e-6,'Forest Common pack: Legendary 1/60, Mythic 1/400 (was 1/30, 1/200)')
check(math.abs(oneIn(7,'Pack01','Legendary')-180)<1e-6 and math.abs(oneIn(7,'Pack01','Mythic')-1200)<1e-6,'Storm Peaks Common pack: Legendary 1/180, Mythic 1/1200')
check(math.abs(oneIn(2,'Pack01','Mythic')-600)<1e-6 and math.abs(oneIn(5,'Pack01','Mythic')-1000)<1e-6,'no pass-up: Desert Mythic 1/600 (was 1/6), Crystal 1/1000 (was 1/26)')
check(math.abs(oneIn(2,'Pack04','Mythic')-20)<1e-6 and math.abs(oneIn(2,'Pack06','Mythic')-5)<1e-6,'Desert Epic / Mythic packs: Mythic 1/20 and 1/5 (were always Mythic)')
local seq={1,6,2,3,4,5,7};local rising=true
for i=2,#seq do if O137.BiomeFactor[seq[i]]<=O137.BiomeFactor[seq[i-1]]then rising=false end end
check(rising and O137.BiomeFactor[1]==2,'rarer down the biome list, and Forest already twice as rare')
-- Rolls follow the odds (Desert Epic pack: 1/20 Mythic, otherwise Prickly Pear).
math.randomseed(137);local myth,n=0,60000
for _=1,n do local seed,tier=Rules.Roll(Config,2,math.random,1,'Pack04',137);if tier=='Mythic'then myth+=1 end end
check(math.abs(myth/n-.05)<.006,('Desert Epic pack rolls: %.2f%% Mythic (1/20 = 5%%)'):format(myth/n*100))
local always=true;for _=1,300 do local _,tier=Rules.Roll(Config,2,math.random,1,'Pack04',112);if tier~='Mythic'then always=false end end
check(always,'a version-112 Desert Epic pack still rolls its old odds (always Mythic)')
-- Luck still boosts, capped, and everything adds up.
local lucky=tiers(Rules.SeedOdds(Config,7,'Pack01',50));local sum=0;for _,p in pairs(lucky)do sum+=p end
check(math.abs(sum-1)<1e-9 and lucky.Legendary>1/180 and lucky.Mythic>1/1200,'boots still raise Legendary/Mythic and the odds add up to 100%')
-- 2. Old packs ----------------------------------------------------------------------------------------------------
wrong={};rows=0
for _,e in ipairs(expected.now)do
 if e.Stage~=4 and e.Stage~=5 then -- R148: Lava / Crystal re-split with Fire Pepper / Moon Melon at their new tiers (test_roster.luau)
  rows+=1
  local ok,k=same(tiers(Rules.SeedOdds(Config,e.Stage,e.Pack,1,112)),e.Odds)
  if not ok then wrong[#wrong+1]=e.Stage..'/'..e.Pack..' '..k end
 end
end
check(rows==30 and #wrong==0,'version-112 packs keep exactly their old odds, Lava / Crystal aside ('..table.concat(wrong,', ')..')')
-- R148: the two promoted seeds, in a Common pack of the version everyone has today (137 = 149): Fire Pepper Mythic 1/800, Moon Melon Legendary 1/150
check(math.abs(oneIn(4,'Pack01','Mythic')-800)<1e-6 and math.abs(oneIn(5,'Pack01','Legendary')-150)<1e-6,'Lava Common pack: Mythic 1/800 (Fire Pepper); Crystal Common pack: Legendary 1/150 (Moon Melon)')
local function equal(a,b)for k,v in pairs(a)do if math.abs((b[k]or 0)-v)>1e-12 then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
check(equal(Rules.SeedOdds(Config,7,'EclipseReliquary',1,137),Rules.SeedOdds(Config,7,'EclipseReliquary',1,112)),'Void pack odds unchanged')
check(equal(Rules.SeedOdds(Config,8,'MechLimited',1,81),Rules.SeedOdds(Config,8,'MechLimited',1,81))and next(Rules.SeedOdds(Config,8,'MechLimited',1,81))~=nil,'Mech pack odds unchanged')
check(Rules.ValidOddsVersion(81)and Rules.ValidOddsVersion(112)and Rules.ValidOddsVersion(137)and Rules.ValidOddsVersion(149)and not Rules.ValidOddsVersion(99),'saved odds versions 81, 112, 137 and 149 are kept on load')
-- 3. Sizes ----------------------------------------------------------------------------------------------------------
local total,big,giant,mean=0,0,0,0
for _,row in ipairs(Rules.PackSizes)do total+=row.Weight;if row.Scale>=5 then big+=row.Weight end;if row.Scale>=10 then giant+=row.Weight end;mean+=row.Scale*row.Weight/100 end
check(math.abs(total-100)<1e-9 and math.abs(big-1.409)<1e-9 and math.abs(giant-.129)<1e-9,('size table: 5x+ %.3f%% (1/71), 10x+ %.3f%% (1/775)'):format(big,giant))
check(math.abs(mean-1.318)<.001,('average size %.3f (was 1.188)'):format(mean))
-- 4. Player pity --------------------------------------------------------------------------------------------------
check(Pity.Chance(Pity.Player.Big,18)==0 and Pity.Chance(Pity.Player.Big,19)>0 and Pity.Chance(Pity.Player.Big,30)==1,'5x+ pity: nothing for 18 packs, then a growing chance, sure by the 30th')
check(Pity.Chance(Pity.Player.Giant,150)==0 and Pity.Chance(Pity.Player.Giant,200)==1,'10x+ pity: from the 151st pack, sure by the 200th')
local below=false;for i=1,2000 do if Pity.RollAtLeast(5,i/2001)<5 or Pity.RollAtLeast(10,i/2001)<10 then below=true end end
check(not below and Pity.RollAtLeast(5,.999)>=20,'a pity size is never below its target and can be much bigger')
math.randomseed(7);local state={Big=0,Giant=0};local gapB,gapG,maxB,maxG,sumB,nB,sumG,nG=0,0,0,0,0,0,0,0;local sizes={};local seen={}
for _=1,400000 do
 local s;s,state=Pity.ApplyPlayer(state,Rules.RollPackSize(math.random()),math.random)
 gapB+=1;gapG+=1;seen[s]=true
 if s>=5 then maxB=math.max(maxB,gapB);sumB+=gapB;nB+=1;gapB=0 end
 if s>=10 then maxG=math.max(maxG,gapG);sumG+=gapG;nG+=1;gapG=0 end
end
check(maxB<=30 and maxG<=200,('never more than 30 packs without a 5x+ (worst %d) or 200 without a 10x+ (worst %d)'):format(maxB,maxG))
print(('player: a 5x+ every %.1f packs on average, a 10x+ every %.0f'):format(sumB/nB,sumG/nG))
check(sumB/nB>17 and sumB/nB<26,('a 5x+ about every %.1f packs'):format(sumB/nB))
check(sumG/nG>100 and sumG/nG<160,('a 10x+ about every %.0f packs'):format(sumG/nG))
check(seen[7.5]and seen[15]and seen[25],'pity packs come in every big size')
-- With the real PlayerDataService.
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,{Show=function()end})
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local A=makePlayer(201,'Ava')
check(Data:GetPackLuck(A).Big==0 and Data:GetPackLuck(A).Giant==0,'a new profile starts with empty counters')
Data:LoadPackLuck(A,{Big=29,Giant=12})
local rec=Data:AddChest(A,{Stage=3,BagVariant='Pack02',PackSize=1,PackMutation='None',OddsVersion=137},{Luck=true})
check(rec and rec.PackSize>=5,'30th earned pack in a row without a 5x+: it comes out big ('..tostring(rec and rec.PackSize)..'x)')
check(rec and rec.SeedScale==Rules.NewSeedScale(3,'Pack02',rec.PackSize),'its seed size follows the bigger pack')
check(Data:GetPackLuck(A).Big==0 and Data:GetPackLuck(A).Giant==(rec.PackSize>=10 and 0 or 13),'the 5x counter resets (the 10x one keeps counting)')
Data:LoadPackLuck(A,{Big=29,Giant=0})
local plain=Data:AddChest(A,{Stage=3,BagVariant='Pack02',PackSize=1,PackMutation='None',OddsVersion=137})
check(plain and plain.PackSize==1 and Data:GetPackLuck(A).Big==29,'bought, gifted and test packs (no Luck option) neither change nor count')
local mech=Data:AddChest(A,{Stage=8,BagVariant='MechLimited',PackSize=1,PackMutation='None'},{Luck=true})
check(mech and mech.PackSize==1 and Data:GetPackLuck(A).Big==29,'Mech packs never change or count')
local small=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=137},{Luck=true})
Data:LoadPackLuck(A,{Big=3,Giant=3});local early=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1.5,PackMutation='None',OddsVersion=137},{Luck=true})
check(early.PackSize==1.5 and Data:GetPackLuck(A).Big==4,'early on nothing changes: the pack keeps its size and the counter goes up')
Data:LoadPackLuck(A,{Big=17,Giant=44})
local saved=Data:_buildSaveData(A)
check(type(saved.PackLuck)=='table'and saved.PackLuck.Big==17 and saved.PackLuck.Giant==44,'the counters are saved with the profile')
local B=makePlayer(202,'Ben');Data:LoadPackLuck(B,saved.PackLuck)
check(Data:GetPackLuck(B).Big==17 and Data:GetPackLuck(B).Giant==44,'and load back')
Data:LoadPackLuck(B,{Big='x',Giant=-5});check(Data:GetPackLuck(B).Big==0 and Data:GetPackLuck(B).Giant==0,'bad saved counters load as 0')
local old=Data:_decodeSavedSeedRecord(A,{Id='201_90',Kind='Pack',Stage=2,BagVariant='Pack04',OddsVersion=112,PackSize=1,ChestNumber=90},90)
check(old.OddsVersion==112,'a saved 112 pack still loads as 112 (it would have fallen back to the old 81 odds)')
check(not Data.PublishPackLuck and A:GetAttribute('PackLuck')==nil and A:GetAttribute('PackLuckBig')==nil,'nothing about it is shown to the player')
check(W.B.ChestService:find('AddChest(player, seed, {Luck=true})',1,true)and W.B.TreadmillBonusService:find("},{Luck=true})",1,true)
 and not W.B.PremiumProgress:find('Luck=true',1,true),'stolen/event packs and treadmill bonus packs go through it; bought Mech packs do not')
-- 5. Track pity -----------------------------------------------------------------------------------------------------
check(Pity.Chance(Pity.Track.Big,1)==0 and Pity.Chance(Pity.Track.Big,6)==1 and Pity.Chance(Pity.Track.Giant,12)==1,'track: sure by the 6th refresh (30 min) for 5x+ and the 12th (1 h) for 10x+')
local Chests=server('ChestService')
local fake={Map={Chests={}},PackRandom=W.env.Random.new(42)}
for i=1,35 do fake.Map.Chests[i]={Index=i}end
local placed={};local forcedAt={}
function fake:RefreshWorldPack(seed,variant,testSize,testMutation,odds,rolledSize)
 assert(testSize==nil,'track packs are never test-sized');seed.Available=true;seed.BagVariant=variant;seed.PackSize=rolledSize;placed[#placed+1]=rolledSize
end
local maxDryB,maxDryG,dryB,dryG,bigCount,giantCount,refreshes=0,0,0,0,0,0,6000
for cycle=1,refreshes do
 placed={}
 Chests.SkinWorldSeeds(fake,cycle)
 local biggest=0;for i,s in ipairs(placed)do biggest=math.max(biggest,s);if s>=5 then bigCount+=1 end;if s>=10 then giantCount+=1 end end
 dryB=biggest>=5 and 0 or dryB+1;dryG=biggest>=10 and 0 or dryG+1
 maxDryB=math.max(maxDryB,dryB);maxDryG=math.max(maxDryG,dryG)
 for i,seed in ipairs(fake.Map.Chests)do if seed.PackSize>=10 then forcedAt[i]=(forcedAt[i]or 0)+1 end end
end
print(('track: %.1f packs of 5x+ per hour, a 10x+ every %.0f min'):format(bigCount/refreshes*12,refreshes*5/giantCount))
check(#placed==35,'every spot gets a pack')
check(maxDryB<6 and maxDryG<12,('track: never 6 refreshes in a row without a 5x+ (worst %d) or 12 without a 10x+ (worst %d)'):format(maxDryB,maxDryG))
local spots=0;for _ in pairs(forcedAt)do spots+=1 end
check(spots>=30,'giant packs land on random spots ('..spots..' of 35 spots seen)')
local Track=fake.TrackLuck
check(type(Track)=='table'and type(Track.Big)=='number','the track counters live on the server only')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
