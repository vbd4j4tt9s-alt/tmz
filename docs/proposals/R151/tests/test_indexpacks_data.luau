--!nocheck
-- R151 (owner: "add a pack index in the index and state rate of spawn and drop rates"): the data of the Index's PACKS tab (IndexPackData151) against the SERVER's own tables and roll
-- code: the real Config (Config.SeedCatalogByStage, the config every server roll reads), SeedPackRules.SeedOdds / Roll / RollVariant, TreadmillBonusRules.RollPack and
-- MysteryPackRules.Roll, on the Roblox mock.
--  1. what is listed  every pack of the game: 7 biomes x 6 tiers = 42 designs, then the starter, mystery, Void, Mech and Verity packs; nothing else (no legacy sack, no test pack)
--  2. spawn rates     each tier's share of the track = SpawnWeight / sum (the R127 owner weights 42.92 / 28.24 / 16.94 / 7.9 / 3 / 1), equal to what RollVariant picks over its whole range
--  3. drop rates      every pack's seeds and chances = SeedOdds of the SERVER's Config (the client's copy of it agrees seed for seed), adding up to 100; each rarity is the sum of
--                     its seeds; the real Rules.Roll, run thousands of times, agrees; the Void / Verity / Mech packs too
--  4. other sources   bonus roll, mystery pedestal, daily reward, shop, The Darkened, the Verity quest: from the same tables; the bonus roll and mystery roll agree with their text
--  5. format          every chance is 1/N (OddsText85), N whole under a million, "1/16.7B" style above
--  6. hidden          no test pack, no pity, no boots luck, no starter rate boost anywhere in the data or in a string it can produce
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,rel)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(rel or 1e-12)*math.max(1,math.abs(b))end
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
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Rules=W.module('SeedPackRules');local D=W.module('IndexPackData151');local Fmt=W.module('OddsText85')
local Bonus=W.module('TreadmillBonusRules');local Mystery=W.module('MysteryPackRules');local Daily=W.module('DailyRewards');local Mech=W.module('MechCatalog');local Verity=W.module('VerityCatalog')
local Route=W.module('RouteBalance83');local Schedule=W.module('PackSchedule81')
-- the order of the Index's tabs (ChestIndex: Crystal before Lava)
local TAB_STAGES={1,6,2,3,5,4,7}
local data=D.Build{Order=TAB_STAGES}
local byKey={};for _,e in ipairs(data.Entries)do byKey[e.Key]=e end
-- a seeded generator (the checks below are statistics on the REAL roll code: the same numbers every run). Luau's own math.random (PCG): a hand-made LCG loses precision
-- past 2^53 in a double and its draws are not uniform enough for a 5-sigma test.
local function rng(seed)math.randomseed(seed);return function()return math.random()end end
-- 1. what is listed ---------------------------------------------------------------------------------------------------------------------------------------
do
 check(#data.Entries==47,'47 packs are listed ('..#data.Entries..')')
 local keys={};for _,e in ipairs(data.Entries)do keys[e.Key]=(keys[e.Key]or 0)+1 end
 local dup=false;for _,n in pairs(keys)do if n>1 then dup=true end end;check(not dup,'every pack is listed once')
 local designs=0
 for stage=1,7 do for tier=1,6 do
  local key=Rules.DesignKey(stage,string.format('Pack%02d',tier));local e=byKey[key]
  if e and e.Kind=='Track'and e.Stage==stage and e.Variant==string.format('Pack%02d',tier)then designs+=1 end
 end end
 check(designs==42,'all 42 designs are there: the 7 biomes x their 6 pack tiers ('..designs..')')
 local special={};for _,e in ipairs(data.Entries)do if e.Kind~='Track'then special[#special+1]=e.Key end end
 check(table.concat(special,',')=='Starter,Mystery,Void,Mech,Verity','the special packs: starter, mystery, Void (The Darkened), Mech, Verity ('..table.concat(special,',')..')')
 check(#data.Sections==8,'eight groups: the 7 biomes in the Index\'s tab order, then SPECIAL PACKS')
 local titles={};for _,s in ipairs(data.Sections)do titles[#titles+1]=s.Title end
 check(table.concat(titles,',')=='FOREST,JUNGLE,DESERT,SNOW,CRYSTAL,LAVA,STORM,SPECIAL PACKS','... in the tabs\' order: '..table.concat(titles,','))
 for _,s in ipairs(data.Sections)do check(#s.Entries==(s.Key=='Special'and 5 or 6),'group '..s.Title..' lists '..#s.Entries)end
 -- pictures: every pack names the stage and variant of its picture
 local pic=true;for _,e in ipairs(data.Entries)do if type(e.Stage)~='number'or type(e.Variant)~='string'or not Rules.Variants[e.Variant]then pic=false end end;check(pic,'every pack carries the stage and variant its picture is drawn from')
 -- legacy Small / Standard / Grand sacks: nothing in the game makes one, so none is listed
 local legacy=false;for _,e in ipairs(data.Entries)do if e.Variant=='Small'or e.Variant=='Standard'or e.Variant=='Grand'then legacy=true end end
 check(not legacy,'no legacy Small / Standard / Grand sack is listed')
 local seen={};local N=200000
 for i=0,N-1 do seen[Rules.RollVariant((i+.5)/N)]=true end
 local onlyOrder=true;for k in pairs(seen)do if not table.find(Rules.VariantOrder,k)then onlyOrder=false end end
 check(onlyOrder and seen.Pack01 and seen.Pack06,'... because the track only ever rolls Pack01 .. Pack06 (RollVariant over its whole range: '..N..' points)')
 local dailyOk=true;for k in pairs(Daily.SeedPackVariants)do if not table.find(Rules.VariantOrder,k)then dailyOk=false end end
 local bonusOk=true;for _,k in ipairs(Bonus.VariantOrder)do if not(table.find(Rules.VariantOrder,k)or k=='EclipseReliquary')then bonusOk=false end end
 local mysteryOk=true;for _,k in ipairs(Mystery.Order)do if not(table.find(Rules.VariantOrder,k)or k=='EclipseReliquary')then mysteryOk=false end end
 check(dailyOk and bonusOk and mysteryOk,'... the daily reward, the bonus roll and the mystery pedestal likewise (Pack01-06 and the Void pack only)')
 -- no source in the game builds a legacy sack: nothing but the legacy table names them
 -- (the SERVER's modules: the code that makes a pack; the pictures' fallback look for an unknown variant is not a source)
 local srcs=require('./rs_bundle');local hits=0
 for _,name in ipairs(require('./srv_names'))do
  local text=srcs[name]
  for _,key in ipairs({'Small','Standard','Grand'})do
   if text:find("BagVariant *= *['\"]"..key.."['\"]")or text:find("Variant *= *['\"]"..key.."['\"]")then hits+=1;print('   legacy sack named in '..name)end
  end
 end
 check(hits==0,'no server script gives out a legacy sack (BagVariant = Small / Standard / Grand appears nowhere)')
end
-- 2. spawn rates ------------------------------------------------------------------------------------------------------------------------------------------
do
 local expect={42.92,28.24,16.94,7.9,3,1}
 local total=0;for i,k in ipairs(Rules.VariantOrder)do total+=Rules.Variants[k].SpawnWeight;check(near(Rules.Variants[k].SpawnWeight,expect[i]),k..' spawns with weight '..expect[i]..' (the R127 owner weights)')end
 check(near(total,100),'the six weights add up to 100')
 for i,w in ipairs(Route.SpawnWeights)do check(Rules.Variants[Rules.VariantOrder[i]].SpawnWeight==w,'SeedPackRules uses RouteBalance83.SpawnWeights['..i..']')end
 -- the grid: what RollVariant really picks
 local N=400000;local count={}
 for i=0,N-1 do local k=Rules.RollVariant((i+.5)/N);count[k]=(count[k]or 0)+1 end
 local all=true
 for i,k in ipairs(Rules.VariantOrder)do
  local want=Rules.Variants[k].SpawnWeight;local got=100*(count[k]or 0)/N
  local e=byKey[Rules.DesignKey(1,k)]
  if not(e and e.Spawn and math.abs(got-want)<=.001 and near(e.Spawn.Percent,want,1e-9))then all=false;print('   '..k..' spawn: shown '..tostring(e and e.Spawn and e.Spawn.Percent)..' weight '..want..' RollVariant '..got)end
 end
 check(all,'every tier\'s shown spawn rate equals its weight and what RollVariant picks over '..N..' points (within .001%)')
 for _,e in ipairs(data.Entries)do
  if e.Kind=='Track'then check(e.Spawn and e.Spawn.Text==Fmt.Format(Rules.Variants[e.Variant].SpawnWeight),e.Key..' spawn text is OddsText85.Format of its weight ('..tostring(e.Spawn and e.Spawn.Text)..')')
  else check(e.Spawn==nil,e.Key..' has no track spawn rate (it does not spawn on the track)')end
 end
 check(byKey.Forest_05.Spawn.Text=='1/33'and byKey.Forest_06.Spawn.Text=='1/100'and byKey.Storm_01.Spawn.Text=='1/2'and byKey.Lava_04.Spawn.Text=='1/13','Legendary 3% reads 1/33, Mythic 1% reads 1/100, Common 1/2, Epic 1/13')
 -- a spawn rate is the same in every biome (the track weights are global)
 local same=true;for stage=1,7 do for tier=1,6 do local k=string.format('Pack%02d',tier);if byKey[Rules.DesignKey(stage,k)].Spawn.Percent~=byKey[Rules.DesignKey(1,k)].Spawn.Percent then same=false end end end
 check(same,'the same tier spawns at the same rate in every biome')
end
-- 3. drop rates -------------------------------------------------------------------------------------------------------------------------------------------
local function seedsOf(e)local out={};for _,g in ipairs(e.Drops)do for _,s in ipairs(g.Seeds)do out[s.Id]=s.Percent end end;return out end
do
 local version=Rules.OddsVersion
 local clientCfg=D.Config()
 local worst=0;local ok=true;local missing,extra=0,0
 for _,e in ipairs(data.Entries)do
  if e.Kind~='Mystery'then
   local want=Rules.SeedOdds(Config,e.Stage,e.Variant,1,version)
   local got=seedsOf(e)
   local sum=0
   for id,p in pairs(want)do if p>0 then
    if not got[id]then missing+=1;print('   '..e.Key..': '..id..' ('..p..') is not shown')elseif not near(got[id],p,1e-12)then ok=false;print('   '..e.Key..' '..id..': shown '..got[id]..' server '..p)end
   end end
   for id,p in pairs(got)do sum+=p;if not(want[id]and want[id]>0)then extra+=1;print('   '..e.Key..': '..id..' is shown but the server cannot roll it')end end
   worst=math.max(worst,math.abs(sum-100))
   check(math.abs(e.DropTotal-100)<1e-9,e.Key..': the chances add up to 100 ('..e.DropTotal..')')
   local groupSum=0;for _,g in ipairs(e.Drops)do local inner=0;for _,s in ipairs(g.Seeds)do inner+=s.Percent end;groupSum+=g.Percent;if not near(inner,g.Percent,1e-12)then ok=false;print('   '..e.Key..' '..g.Key..': group '..g.Percent..' seeds '..inner)end end
   if not near(groupSum,100,1e-9)then ok=false end
  end
 end
 check(ok and missing==0 and extra==0,'every pack\'s seeds and chances equal SeedOdds of the SERVER\'s Config, none missing, none extra')
 check(worst<1e-9,'every pack\'s chances add up to 100 (worst '..worst..')')
 -- the client's own copy of the config gives the same numbers as the server's (it is built from the same catalog)
 local same=true
 for _,e in ipairs(data.Entries)do if e.Kind=='Track'then
  local a=Rules.SeedOdds(clientCfg,e.Stage,e.Variant,1,version);local b=Rules.SeedOdds(Config,e.Stage,e.Variant,1,version)
  for id,p in pairs(b)do if not near(a[id]or-1,p,1e-12)then same=false end end;for id in pairs(a)do if b[id]==nil then same=false end end
 end end
 check(same,'the client\'s config (SeedPackRules.BuildSeedCatalog) rolls the same odds as the server\'s Config for every track pack')
 -- each rarity is built from the independent tables: PackOdds137.TierOdds over the pool's rarities (ordinary packs)
 local N137=W.module('PackOdds137');local tiersOk=true
 for _,e in ipairs(data.Entries)do if e.Kind=='Track'then
  local pool=Rules.ObtainablePool(Config,e.Stage);local present={}
  for _,s in ipairs(pool)do present[(Rules.GetRarity(s.Id))]=true end
  local tiers=N137.TierOdds(present,Rules.MinimumSeedRarityByStage[e.Stage]or'Common',e.Variant,1,e.Stage)
  for _,g in ipairs(e.Drops)do if not near(g.Percent,100*(tiers[g.Key]or 0),1e-9)then tiersOk=false;print('   '..e.Key..' '..g.Key..': shown '..g.Percent..' PackOdds137 '..100*(tiers[g.Key]or 0))end end
  local shown={};for _,g in ipairs(e.Drops)do shown[g.Key]=true end;for t,p in pairs(tiers)do if p>0 and not shown[t]then tiersOk=false;print('   '..e.Key..': tier '..t..' is not shown')end end
 end end
 check(tiersOk,'every rarity chip equals PackOdds137.TierOdds computed from scratch (the table the server\'s roll uses)')
 -- Monte Carlo on the REAL roll: Rules.Roll with a draw function, the same seeded generator for every pack
 local n=5000;local worstZ=0;local bad=0
 for i,e in ipairs(data.Entries)do
  if e.Kind=='Track'or e.Kind=='Starter'or e.Kind=='Void'or e.Kind=='Mech'or e.Kind=='Verity'then
   local draw=rng(1234+i*7919);local counts={}
   for _=1,n do
    local seed,rarity=Rules.Roll(Config,e.Stage,draw,1,e.Variant,version)
    local id=seed and seed.Id;counts[id or'?']=(counts[id or'?']or 0)+1
   end
   local want=seedsOf(e)
   for id,p in pairs(want)do
    local q=p/100;local got=(counts[id]or 0)/n;local sigma=math.sqrt(q*(1-q)/n)
    if q>=.004 then local z=math.abs(got-q)/math.max(sigma,1e-9);worstZ=math.max(worstZ,z);if z>4.5 then bad+=1;print('   '..e.Key..' '..id..': rolled '..got..' shown '..q..' (z '..z..')')end
    else local allowed=n*q+6*math.sqrt(n*q)+3;if(counts[id]or 0)>allowed then bad+=1;print('   '..e.Key..' '..id..': rolled '..counts[id]..' of '..n..', the table says '..q)end end
   end
   for id,c in pairs(counts)do if not want[id]then bad+=1;print('   '..e.Key..': the roll gave '..id..' ('..c..') which is not listed')end end
  end
 end
 check(bad==0,'Monte Carlo: '..n..' real Rules.Roll draws per pack (the 42 designs, starter, Void, Mech, Verity) agree with the shown chances (worst z '..string.format('%.2f',worstZ)..')')
end
-- 4. other sources ----------------------------------------------------------------------------------------------------------------------------------------
do
 -- bonus roll: the table, then the real RollPack
 local odds=Bonus.VariantOdds();local sum=0;for _,p in pairs(odds)do sum+=p end;check(near(sum,1,1e-12),'the bonus roll table adds up to 1')
 local N=6e5;local counts={};local draw=rng(77)
 for _=1,N do local r=Bonus.RollPack({1,2,3,4,5,6,7},draw);counts[r.Variant]=(counts[r.Variant]or 0)+1 end
 local bonusOk=true
 for _,k in ipairs(Bonus.VariantOrder)do
  local q=odds[k];local got=(counts[k]or 0)/N;local sigma=math.sqrt(q*(1-q)/N)
  if math.abs(got-q)>5*sigma+1/N then bonusOk=false;print('   bonus '..k..': rolled '..got..' table '..q)end
 end
 check(bonusOk,'the bonus roll\'s real RollPack agrees with TreadmillBonusRules.Odds ('..N..' draws)')
 for _,e in ipairs(data.Entries)do
  local want=odds[e.Variant]
  if e.Kind=='Track'then
   local row;for _,a in ipairs(e.Also)do if a.Source=='Bonus roll'then row=a end end
   check(row and near(row.Percent,100*want,1e-9)and row.Text==Fmt.Format(100*want),e.Key..' lists its bonus roll chance '..tostring(row and row.Text))
   local hasDaily=false;for _,a in ipairs(e.Also)do if a.Source=='Daily reward'then hasDaily=true end end
   check(hasDaily==(Daily.SeedPackVariants[e.Variant]==true),e.Key..' lists the daily reward exactly when the daily pool has it')
   local mystery=false;for _,a in ipairs(e.Also)do if a.Source=='Mystery pedestal'then mystery=true end end
   check(mystery==(Mystery.Odds[e.Variant]~=nil),e.Key..' lists the mystery pedestal exactly when the pedestal can give it (never a Common pack)')
  end
 end
 -- mystery pedestal: its own table, rolled by the real Mystery.Roll
 local m=byKey.Mystery;local counts2={};local draw2=rng(99);local M=4e5
 for _=1,M do local r=Mystery.Roll(3,draw2);counts2[r.Variant]=(counts2[r.Variant]or 0)+1 end
 local mOk=true;local total=0;for _,k in ipairs(Mystery.Order)do total+=Mystery.Odds[k]end
 for _,g in ipairs(m.Drops)do
  local q=Mystery.Odds[g.Key]/total;local got=(counts2[g.Key]or 0)/M;local sigma=math.sqrt(q*(1-q)/M)
  if not near(g.Percent,100*q,1e-9)or math.abs(got-q)>5*sigma+1/M then mOk=false;print('   mystery '..g.Key..': shown '..g.Percent..' table '..100*q..' rolled '..got)end
 end
 check(mOk and #m.Drops==#Mystery.Order and math.abs(m.DropTotal-100)<1e-9,'the mystery pack lists the tier it turns out to be (Uncommon .. Mythic, Void) as the real Mystery.Roll draws them')
 local noCommon=true;for _,g in ipairs(m.Drops)do if g.Label=='COMMON'then noCommon=false end;if #g.Seeds~=0 then noCommon=false end end
 check(m.DropTitle=='IT TURNS OUT TO BE'and m.Drops[#m.Drops].Label=='VOID'and noCommon,'(the mystery pack\'s rows are pack tiers, never Common, not seeds)')
 -- how to get the packs that do not spawn on the track
 local function has(e,source,text)for _,a in ipairs(e.How or{})do if a.Source==source and(text==nil or(a.Text and a.Text:find(text,1,true)))then return true end end;return false end
 check(has(byKey.Void,'The Darkened event','every 3rd refresh')and has(byKey.Void,'Bonus roll',Fmt.Format(100*odds.EclipseReliquary))and has(byKey.Void,'Mystery pedestal',Fmt.Format(100*Mystery.Odds.EclipseReliquary/total)),'Void: The Darkened event (every 3rd refresh), Bonus roll '..Fmt.Format(100*odds.EclipseReliquary)..', Mystery pedestal')
 do
  local n=1;while not Schedule.Event(n)do n+=1 end
  check(n==3 and has(byKey.Void,'The Darkened event','about '..(n*Rules.RefreshInterval//60)..' min'),'... the interval is read from PackSchedule81.Event and RefreshInterval ('..n..' refreshes, '..(n*Rules.RefreshInterval//60)..' min)')
 end
 check(has(byKey.Mech,'Shop (Robux)')and has(byKey.Mech,'Daily reward','day 7')and Daily.Login[7].MechPack==1,'Mech: Shop (Robux), Daily reward day 7 (DailyRewards.Login[7].MechPack)')
 check(#Mech.Offers>=1 and Mech.Offers[1].Count==1,'(MechCatalog.Offers: the shop sells 1, 5 and 10)')
 check(has(byKey.Verity,'Verity quest'),'Verity: the Verity quest')
 check(has(byKey.Mystery,'Mystery pedestal in your base')and has(byKey.Mystery,'Free daily',(Mystery.UnlockSeconds//60)..' min'),'Mystery: the pedestal in your base, free daily, '..(Mystery.UnlockSeconds//60)..' min online')
 check(has(byKey.Starter,'Free tutorial gift'),'Starter: the free tutorial gift')
 for _,k in ipairs({'Starter','Mystery','Void','Mech','Verity'})do check(byKey[k].How and #byKey[k].How>=1,k..' says how you get it')end
 -- the limited packs
 check(byKey.Mech.Limited==true and byKey.Verity.Limited==true and not byKey.Void.Limited,'Mech and Verity are marked LIMITED (the Index\'s LIMITED tab holds their seeds)')
 -- Void / Mech / Verity drops by group
 local function group(e,key)for _,g in ipairs(e.Drops)do if g.Key==key then return g end end end
 check(group(byKey.Void,'Mech')and near(group(byKey.Void,'Mech').Percent,.5,1e-9)and group(byKey.Void,'Mech').Text=='1/200','Void: the Mech seeds are one MECH chip, 1/200 (the 0.5% Mech branch)')
 check(group(byKey.Verity,'Verity')and near(group(byKey.Verity,'Verity').Percent,Verity.VerityChance*100,1e-9)and group(byKey.Verity,'Verity').Text=='1/100','Verity: the Verity seed 1/100 (VerityCatalog.VerityChance)')
 local voidKing=group(byKey.Void,'King');check(voidKing and voidKing.Count==5 and not group(byKey.Verity,'King'),'Void has the Kings, the Verity pack none (VerityPackOdds removes them)')
 local mechSeeds=0;for _,g in ipairs(byKey.Mech.Drops)do mechSeeds+=g.Count end;check(mechSeeds==#Mech.Seeds,'the Mech pack lists all '..#Mech.Seeds..' Mech seeds')
 for _,s in ipairs(Mech.Seeds)do check(near(seedsOf(byKey.Mech)[s.Id],s.Chance,1e-12),'Mech seed '..s.Id..' shows MechCatalog\'s own chance '..s.Chance)end
 -- pack sizes
 local sizesOk=true;local shown={}
 for _,z in ipairs(data.Sizes)do shown[z.Scale]=z end
 for _,row in ipairs(Rules.PackSizes)do
  if row.Weight<50 then local z=shown[row.Scale];if not(z and near(z.Percent,row.Weight,1e-12)and z.Text==Fmt.Format(row.Weight))then sizesOk=false end
  elseif shown[row.Scale]then sizesOk=false end
 end
 check(sizesOk and #data.Sizes==10,'pack sizes: every size but the usual 1x, from BalanceRules.PackSizes ('..#data.Sizes..' sizes)')
 local total2=0;for _,row in ipairs(Rules.PackSizes)do total2+=row.Weight end;check(math.abs(total2-100)<.01,'(the size table adds up to 100: '..total2..')')
 local N2=300000;local c3={};for i=0,N2-1 do local s=Rules.RollPackSize((i+.5)/N2);c3[s]=(c3[s]or 0)+1 end
 local sz=true;for _,row in ipairs(Rules.PackSizes)do if math.abs(100*(c3[row.Scale]or 0)/N2-row.Weight)>.01 then sz=false end end
 check(sz,'... and Rules.RollPackSize over its range agrees with the table')
end
-- 5. format -----------------------------------------------------------------------------------------------------------------------------------------------
do
 local function isOdds(t)
  if t=='—'then return false end
  local body=t:match('^1/(.+)$');if not body then return false end
  if body:match('^%d[%d,]*$')then return not body:find(',%d%d%d%d')end -- whole, thousands separators
  if body:match('^%d[%d,]*K$')then return true end
  return body:match('^%d+%.?%d*[MBT]$')~=nil or body:match('^%d+%.?%d*Qa$')~=nil
 end
 local n,bad=0,0
 local function chk(text,where)n+=1;if not isOdds(text)then bad+=1;print('   not a 1/N chance: "'..tostring(text)..'" ('..where..')')end;if text:find('%%')or text:find('%d%.%d+%s*$')and not text:match('[MBT]$')then bad+=1;print('   a percent or a decimal: '..text)end end
 for _,e in ipairs(data.Entries)do
  if e.Spawn then chk(e.Spawn.Text,e.Key..' spawn')end
  for _,a in ipairs(e.Also or{})do if a.Text then chk(a.Text,e.Key..' '..a.Source)end end
  for _,a in ipairs(e.How or{})do if a.Source=='Bonus roll'or a.Source=='Mystery pedestal'then chk(a.Text,e.Key..' '..a.Source)end end
  for _,g in ipairs(e.Drops)do chk(g.Text,e.Key..' '..g.Key);for _,s in ipairs(g.Seeds)do chk(s.Text,e.Key..' '..s.Id)end end
 end
 for _,z in ipairs(data.Sizes)do chk(z.Text,'size '..z.Label)end
 check(bad==0,'all '..n..' chances are 1/N: whole numbers under a million, M / B / T above (OddsText85.Format) ('..bad..' that are not)')
 local fine=true;for _,e in ipairs(data.Entries)do for _,g in ipairs(e.Drops)do if g.Text~=Fmt.Format(g.Percent)then fine=false end;for _,s in ipairs(g.Seeds)do if s.Text~=Fmt.Format(s.Percent)then fine=false end end end end
 check(fine,'every chance text is exactly OddsText85.Format of the number it stands for')
 check(byKey.Desert_05.Drops[#byKey.Desert_05.Drops].Text:find('B$')~=nil or byKey.Desert_05.Drops[#byKey.Desert_05.Drops].Text:find('M$')~=nil,'a King chance reads in B / M ('..byKey.Desert_05.Drops[#byKey.Desert_05.Drops].Text..'), the way the Index writes them')
end
-- 6. hidden mechanics and test packs --------------------------------------------------------------------------------------------------------------------
do
 local forbidden={'pity','testgrant','test pack','test','boost','2x','luck','soft','hidden','rateboost','owner','admin','debug','secret rate','guarantee'}
 local words=0;local leaks={}
 local function scan(text,where)
  local low=string.lower(tostring(text))
  for _,w in ipairs(forbidden)do
   -- 'secret' alone is a seed rarity (SECRET chips are fine); the word list above holds only phrases that would leak a mechanic
   if low:find(w,1,true)then leaks[#leaks+1]=where..': "'..text..'" has "'..w..'"' end
  end
  words+=1
 end
 for _,e in ipairs(data.Entries)do for _,t in ipairs(D.Texts(e))do scan(t,e.Key)end end
 for _,z in ipairs(data.Sizes)do scan(z.Label,'size');scan(z.Text,'size')end
 for _,s in ipairs(data.Sections)do scan(s.Title,'section')end
 check(#leaks==0,'none of the '..words..' strings the tab can show mentions pity, luck, a boost, a test pack or an owner ('..#leaks..' hits)')
 for _,l in ipairs(leaks)do print('   '..l)end
 -- no field of any entry names a hidden thing
 local badKey=false
 local function walk(t,path)
  for k,v in pairs(t)do
   local key=string.lower(tostring(k))
   if key:find('pity')or key:find('testgrant')or key:find('boost')or key:find('luck')then badKey=true;print('   a field named '..path..'.'..tostring(k))end
   if type(v)=='table'then walk(v,path..'.'..tostring(k))end
  end
 end
 for _,e in ipairs(data.Entries)do if not(e.Key=='Starter')or true then walk(e,e.Key)end end
 check(not badKey,'no entry has a field about pity, boots luck, a boost or a test grant')
 -- the starter pack's hidden 2x is not shown: its drops are the ordinary Forest pack's
 local boosted=Rules.SeedOdds(Config,1,'Pack01',1,Rules.OddsVersion,2)
 local plain=Rules.SeedOdds(Config,1,'Pack01',1,Rules.OddsVersion)
 local starter=seedsOf(byKey.Starter);local forest=seedsOf(byKey.Forest_01)
 local same,differs=true,false
 for id,p in pairs(plain)do if p>0 then if not near(starter[id]or-1,p,1e-12)or not near(forest[id]or-1,p,1e-12)then same=false end;if not near(boosted[id]or 0,p,1e-9)then differs=true end end end
 check(same,'the starter pack\'s drops are the ordinary Forest pack\'s (SeedOdds without a rate boost): the free 2x is never shown')
 check(differs,'(and a boosted table really is different, so that comparison means something)')
 check(byKey.Starter.Spawn==nil and byKey.Starter.Tier.Name=='Free','the starter card says Free; nothing about its odds being better')
 -- the data is made without a player: nothing about a player's luck, packs or test grants can get in
 local a=D.Build{Order=TAB_STAGES};local b=D.Build{Order=TAB_STAGES}
 local identical=#a.Entries==#b.Entries
 for i,e in ipairs(a.Entries)do local f=b.Entries[i];if e.Key~=f.Key or e.DropTotal~=f.DropTotal or table.concat(D.Texts(e),'|')~=table.concat(D.Texts(f),'|')then identical=false end end
 check(identical,'building the list twice gives the same list (no state, no randomness)')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
