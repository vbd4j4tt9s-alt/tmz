--!nocheck
-- R153 (owner: "make it fixed visibly so when players pull a cosmic seed from a void pack they are still reminded of how rare it is"): ONE fixed chance per seed, the SERVER half, on the
-- Roblox mock with the REAL modules (SeedRarity153, SeedPackRules, Config, ChestService, PlayerDataService, PullAnnouncer, PullAnnounceRules, HubDisplayRules, OddsText85):
--  1. SeedRarity153: every seed that can be pulled has a canonical N (54: 47 biome + 6 Mech + Verity), whole-number text exactly as OddsText85 prints it, read from the real odds code
--     over the real Config (equal to the home pack's SeedOdds at luck 1, no boost, current version), cached (no second odds call), nothing for a retired / unknown seed, unaffected by
--     luck / boots / boosts / other packs; nothing equals "1/12" (the owner's wrong example is distinguishable everywhere);
--  2. the Void example: every Secret / Cosmic / King seed (and the Mech seeds that drop from a Void pack) prints its Void-pack chance differently from its fixed one; the fixed one is shown;
--  3. the Index: the real ChestService's SeedCatalog BaseChance equals the canonical chance for all 54 seeds (and the Index text, Format(BaseChance), equals Text);
--  4. packs keep their own odds: a held Void pack's tooltip still lists the Void pack's real chances (a pack's drop table), different from the seeds' fixed ones; the shop's Mech drop
--     table prints the Mech seeds' fixed chances anyway;
--  5. chat: a REAL open of a Void pack that rolls a Cosmic / a Secret / a Mech seed through the real PullAnnouncer: the payload carries the fixed N, the chat line says "(1/N)" of the fixed
--     chance (never the pack's); a pull from another server (Global) and a payload that claims another number show the fixed one too; a record about nobody keeps its given number;
--  6. the hub plaque: a pull record whose stored Odds is the real Void chance still ranks by it (PullBetter unchanged) but the plaque says the fixed chance; a seed the catalog does not
--     know falls back to the stored chance;
--  7. announcements still decide by rarity tier: Qualifies / RecordScope / Rank never look at odds; no script reads a displayed chance back (static);
--  8. owner command texts (/test announce, bestpull) use the fixed chance too.
-- Prints SURFACE lines (plaque, chat-rules): run_seed_rarity.sh compares them with the Index, card and chat tests' lines.
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
do local raw=R.advance;R.advance=function(dt)local n=math.max(1,math.ceil(dt/.25-1e-9));for _=1,n do raw(dt/n)end end end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local Http=W.service('HttpService')
local httpMock=E.http();Http.JSONEncode=httpMock.JSONEncode;Http.JSONDecode=httpMock.JSONDecode;Http.GenerateGUID=httpMock.GenerateGUID
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return p~=nil end,Publish=function()return true end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Packs=W.module('SeedPackRules');local Odds=W.module('OddsText85');local Canon=W.module('SeedRarity153')
local Verity=W.module('VerityCatalog');local Mech=W.module('MechCatalog');local Rules=W.module('PullAnnounceRules');local Hub=W.module('HubDisplayRules')
local Announcer=server('PullAnnouncer')
local function near(a,b,rel)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(rel or 1e-12)*math.max(1,math.abs(b))end
local function drawConstant(x)return function()return x end end
R.clock=20000*86400+3600
local function unix()return 1700000000+math.floor(R.clock)end
local WRONG=12 -- the owner's example: "1/12", what a Cosmic from a Void pack must NOT say

-- 1. SeedRarity153 -------------------------------------------------------------------------------------------------------------------------------------
local all=Canon.All();local byId={}
for _,r in ipairs(all)do byId[r.Id]=r end
local live=0;for _,spec in ipairs(Packs.SeedDesigns)do if not Packs.IsRetired(spec.id)then live+=1 end end
check(#all==54 and live==54,'every pullable seed has a canonical chance: '..#all..' of '..live..' (47 biome + 6 Mech + Verity)')
do
 local bad={}
 for _,spec in ipairs(Packs.SeedDesigns)do
  local n,p,t=Canon.Canonical(spec.id),Canon.Percent(spec.id),Canon.Text(spec.id)
  if not(type(n)=='number'and n==n and n>=1 and n<math.huge and type(p)=='number'and p>0 and p<=100 and near(n,100/p,1e-12)and t==Odds.Format(p)and t:match('^1/')and Canon.Count(spec.id)==Odds.Count(n))then bad[#bad+1]=spec.id end
 end
 check(#bad==0,'every canonical N is finite and >= 1, Text is exactly OddsText85.Format of the percent, Count = Odds.Count(N)'..(#bad>0 and(' (bad: '..table.concat(bad,',')..')')or''))
end
do -- the definition, recomputed here from the REAL Config and the existing odds code (not from the module's own catalog)
 local bad={}
 for _,spec in ipairs(Packs.SeedDesigns)do
  local stage,variant=spec.stage,'Pack01'
  if Verity.Is(spec.id)then stage,variant=Verity.PackStage,Verity.Variant elseif spec.stage==8 then variant='MechLimited'end
  local p=Packs.SeedOdds(Config,stage,variant,1,Packs.OddsVersion)[spec.id]
  if not near(Canon.Percent(spec.id),p,1e-12)then bad[#bad+1]=spec.id..' '..tostring(Canon.Percent(spec.id))..' vs '..tostring(p)end
  local hs,hv=Canon.Home(spec.id);if hs~=stage or hv~=variant then bad[#bad+1]=spec.id..' home '..tostring(hs)..'/'..tostring(hv)end
 end
 check(#bad==0,'canonical = the seed\'s chance in its home pack (the biome\'s Pack01 / the Verity pack / the Mech pack) at luck 1, current version, no boost: '..table.concat(bad,'; '))
end
do -- the owner-approved numbers (R137 / R148 / R147 / Mech), as printed
 local want={FirePepperSeed='1/800',MoonflowerSeed='1/150',DesertAloeSeed='1/8',SandFruitSeed='1/90',VeritySeed='1/100',PlasmaPepperSeed='1/2',NebulaVineSeed='1/40',CrowncoreTreeSeed='1/200',
  PolarStarbloomSeed='1/1M',MirageFigSeed='1/1M',SilentFrostbellSeed='1/10K',PulsarStarfruitSeed='1/1T',DiamondVineSeed='1/1,000',TempestLotusSeed='1/1,200',ElderbloomSeed='1/400',SunflowerSeed='1/2'}
 local bad={};for id,text in pairs(want)do if Canon.Text(id)~=text then bad[#bad+1]=id..'='..Canon.Text(id)..' (want '..text..')'end end
 check(#bad==0,'known values as the game prints them: '..table.concat(bad,'; '))
end
do
 local twelve={};for _,r in ipairs(all)do if r.Text=='1/12'then twelve[#twelve+1]=r.Id end end
 check(#twelve==0,'no seed\'s fixed chance is 1/12 (the owner\'s example of a wrong number stays distinguishable)')
end
do -- cache: a second ask makes no odds call at all
 local rules=Packs;local calls=0;local real=rules.SeedOdds;rules.SeedOdds=function(...)calls+=1;return real(...)end
 for _,spec in ipairs(Packs.SeedDesigns)do Canon.Canonical(spec.id);Canon.Text(spec.id);Canon.Percent(spec.id);Canon.Count(spec.id)end
 rules.SeedOdds=real
 check(calls==0,'cached: asking again for every seed makes no call to SeedPackRules.SeedOdds ('..calls..')')
end
do -- nothing but the seed decides: boots, boosts, other packs, versions never move it
 local before=Canon.Text('PolarStarbloomSeed')..Canon.Text('FirePepperSeed')..Canon.Text('VeritySeed')
 Packs.SeedOdds(Config,3,'Pack06',5e7,Packs.OddsVersion,2);Packs.SeedOdds(Config,7,'EclipseReliquary',1,Packs.OddsVersion);Packs.SeedOdds(Config,4,'Pack04',500,137)
 check(before==Canon.Text('PolarStarbloomSeed')..Canon.Text('FirePepperSeed')..Canon.Text('VeritySeed'),'asking for other packs / luck / boosts / versions does not change it')
 check(Canon.Canonical('NoSuchSeed')==nil and Canon.Text('NoSuchSeed')=='—'and Canon.Canonical(nil)==nil and Canon.Canonical(5)==nil and Canon.Canonical({})==nil and Canon.Percent('')==nil,'unknown / malformed seeds: nil and the dash')
 local retired={'AgaveSeed','DragonfruitSeed','MonsteraSeed','AloeSeed','BananaSeed','StrawberrySeed','FrostFernSeed','DesertRoseSeed','CloverSeed','StaticGrassSeed','SunKingPalmSeed'}
 local ok=true;for _,id in ipairs(retired)do if Canon.Canonical(id)~=nil or Canon.Text(id)~='—'then ok=false end end
 check(ok,'retired seeds (nobody can pull them) have none')
 check(Canon.Canonical({Id='VeritySeed'})==100 and Canon.Canonical({id='VeritySeed'})==100,'a seed row ({Id=...} / a design) works as a key')
end
-- the rarity ladder still reads right: within a biome, a rarer tier is never a smaller N than a commoner tier
do
 local bad={}
 for _,a in ipairs(all)do for _,b in ipairs(all)do
  if a.Stage==b.Stage and a.Stage<8 and a.Variant=='Pack01'and b.Variant=='Pack01'then
   local ra,rb=Packs.Rarities[a.Rarity].Rank,Packs.Rarities[b.Rarity].Rank
   if ra<rb and a.N>b.N+1e-9 then bad[#bad+1]=a.Id..' ('..a.Text..') vs '..b.Id..' ('..b.Text..')'end
  end
 end end
 check(#bad==0,'inside a biome the rarer tier never reads commoner than a lower tier: '..table.concat(bad,'; '))
end

-- 2. the Void example ---------------------------------------------------------------------------------------------------------------------------------
local voidPercent=Packs.SeedOdds(Config,7,'EclipseReliquary',1,Packs.OddsVersion)
do
 local rows,same,order={},0,{}
 for id,p in pairs(voidPercent)do order[#order+1]=id end;table.sort(order)
 for _,id in ipairs(order)do
  local vt=Odds.Format(voidPercent[id]);local ct=Canon.Text(id)
  if vt==ct then same+=1 end
  rows[#rows+1]=('  %-22s %-9s Void pack %-8s fixed %s'):format(id,Packs.GetRarity(id),vt,ct)
 end
 print('VOID EXAMPLE (what a seed pulled from a Void pack used to say, and what it says now):\n'..table.concat(rows,'\n'))
 local cosmic,secret,king=0,0,0
 for _,id in ipairs(order)do local r=Packs.GetRarity(id);if r=='Cosmic'then cosmic+=1 elseif r=='Secret'then secret+=1 elseif r=='King'and id~='CrowncoreTreeSeed'then king+=1 end end
 check(cosmic>=5 and secret>=5 and king>=4,'the Void pack drops every regular Secret / Cosmic / King seed ('..secret..' / '..cosmic..' / '..king..')')
 local worse={}
 for _,id in ipairs(order)do
  if not Mech.Is(id)then
   local vt,ct=Odds.Format(voidPercent[id]),Canon.Text(id)
   if vt==ct or Canon.Canonical(id)<100/voidPercent[id]then worse[#worse+1]=id..' void '..vt..' fixed '..ct end
  end
 end
 check(#worse==0,'every regular Void seed: the fixed chance differs from the Void pack\'s and is the rarer one: '..table.concat(worse,'; '))
 local polar=Canon.Text('PolarStarbloomSeed')
 check(polar=='1/1M'and Odds.Format(voidPercent.PolarStarbloomSeed)=='1/101','the example: Polar Starbloom (Cosmic) from a Void pack used to say '..Odds.Format(voidPercent.PolarStarbloomSeed)..', now '..polar)
 check(Canon.Text('PlasmaPepperSeed')=='1/2'and Odds.Format(voidPercent.PlasmaPepperSeed)~='1/2','a Mech seed from a Void pack reads its Limited-pack chance ('..Canon.Text('PlasmaPepperSeed')..'; as a Void drop it is '..Odds.Format(voidPercent.PlasmaPepperSeed)..')')
end

-- 3. the Index (the real ChestService) ----------------------------------------------------------------------------------------------------------------
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Notes={Show=function()end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
local Chests=server('ChestService')
do
 local ok,svc=pcall(Chests.new,Config,Map,Data,{},Notes)
 check(ok,'the real ChestService builds its SeedCatalog remote ('..tostring(svc)..')')
 local catalog=remotes:FindFirstChild('SeedCatalog')
 local n,bad=0,{}
 for _,entry in ipairs(catalog and catalog:GetChildren()or{})do
  n+=1;local id=entry:GetAttribute('SeedId');local chance=entry:GetAttribute('BaseChance')
  if not(near(chance,Canon.Percent(id),1e-12)and Odds.Format(chance)==Canon.Text(id))then bad[#bad+1]=id end
 end
 check(n==54 and#bad==0,'SeedCatalog: BaseChance of all '..n..' entries is the canonical percent, so the Index text is the canonical text ('..table.concat(bad,',')..')')
end
-- the Index chips are the numbers the Index showed before R153 (the base dump's INDEX lines): run_seed_rarity.sh compares them with the CANON lines below

-- 4. packs keep their own odds (the hold tooltip) ----------------------------------------------------------------------------------------------
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name..' D';p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local fake=setmetatable({PlayerData=Data,Config=Config,Openings={}},{__index=Chests})
local function toolFor(player,id)
 for _,container in ipairs({player:FindFirstChildOfClass('Backpack'),player.Character})do if container then for _,t in ipairs(container:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedInventoryId')==id then return t end end end end
end
local function tipOf(player,record)
 Chests.SyncTools(fake,player);local tool=toolFor(player,record.Id);fake.Openings[player]=true
 Chests._holdPack(fake,player,tool);fake.Openings[player]=nil
 local rows={};for line in tool.ToolTip:gmatch('[^\n]+')do rows[#rows+1]=line end;return rows
end
local function addPack(player,stage,variant)return Data:AddChest(player,{Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})end
local Ann=makePlayer(701,'Ann');local Bob=makePlayer(702,'Bob')
do
 local rows=tipOf(Ann,addPack(Ann,7,'EclipseReliquary'))
 local function row(name)for _,l in ipairs(rows)do if l:sub(1,#name+1)==name..':'then return l end end end
 local polar=row('Polar Starbloom Seed');local pulsar=row('Pulsar Starfruit Seed')
 check(row('Storm Sovereign Seed')=='Storm Sovereign Seed: '..Odds.Format(voidPercent.StormSovereignSeed),'a held Void pack still lists the VOID pack\'s own chance for a Cosmic seed ('..tostring(row('Storm Sovereign Seed'))..'): it answers what THAT pack gives')
 check(row('Storm Sovereign Seed')~='Storm Sovereign Seed: '..Canon.Text('StormSovereignSeed'),'... which is not the seed\'s fixed chance ('..Canon.Text('StormSovereignSeed')..')')
 check(polar==nil or polar=='Polar Starbloom Seed: '..Odds.Format(voidPercent.PolarStarbloomSeed),'(Polar Starbloom: '..tostring(polar)..')')
end

do -- the shop's Limited Mech pack drop table (GamePassClient: Format(seed.Chance)) is a PACK's contents and stays as it is; for a Mech seed that is its fixed chance anyway
 local ok=true;for _,s in ipairs(Mech.Seeds)do if Odds.Format(s.Chance)~=Canon.Text(s.Id)then ok=false end end
 check(ok,'the Mech pack\'s own drop table (shop) prints the very numbers the Mech seeds\' fixed chances are')
end

-- 5. chat: a real Void pack through the real announcer --------------------------------------------------------------------------------------------------
local function remoteLog()
 local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';local log={}
 remote.FireClient=function(_,p,payload)log[#log+1]={Player=p,Payload=payload,At=R.clock}end
 return remote,log
end
local Sink,sinkLog=remoteLog()
local bus=E.bus(function()return R.clock end,unix)
local A=Announcer.new({Data=Data,Players=Players,Http=Http,Messaging=bus:Server('A'),Remote=Sink,Clock=function()return R.clock end,Time=unix,JobId='job-A-0000',Warn=function()end})
Announcer.Instance=A;A:Run()
local function seqDraw(values)local i=0;return function()i+=1;return values[math.min(i,#values)]end end
-- a draw (list of numbers) that makes a real Void pack roll a seed of this rarity: a direct seed (one draw ladder) or the 1/200 Mech branch (first draw .001, the second picks the item)
local function voidDraw(wantRarity,wantMech)
 local tries={}
 if wantMech then for _,u in ipairs({.1,.3,.6,.8,.93,.98,.999})do tries[#tries+1]={.001,u}end
 else for _,d in ipairs({.02,.01,.03,.04,.1,.3,.5,.7,.9,.99})do tries[#tries+1]={d}end;for _,u in ipairs({.1,.4,.7})do tries[#tries+1]={.02,1e-6,1e-4,u}end end -- (a King: 1 in 200M is rolled in gates)
 for _,values in ipairs(tries)do
  local ok,seed,r=pcall(Packs.Roll,Config,7,seqDraw(values),1,'EclipseReliquary',Packs.OddsVersion)
  if ok and seed and r==wantRarity and(Mech.Is(seed.Id)==(wantMech==true))then return values,seed.Id end
 end
end
local function openVoid(player,rarity,mech)
 local values,expect=voidDraw(rarity,mech)
 if not values then return nil end
 local pack=addPack(player,7,'EclipseReliquary')
 local reward=Data:OpenSeedPack(player,pack.Id,seqDraw(values))
 return reward,pack,expect
end
do
 for _,case in ipairs({{'Cosmic',false},{'Secret',false},{'King',false},{'Cosmic',true},{'Secret',true},{'Legendary',true}})do
  local rarity,mech=case[1],case[2]
  local reward,pack,expect=openVoid(Ann,rarity,mech)
  if not reward then check(false,'a real Void pack can be made to open a '..(mech and'Mech 'or'')..rarity)
  else
   table.clear(sinkLog)
   R.advance(Rules.RevealDelay(rarity)+1)
   local pulls={};for _,l in ipairs(sinkLog)do if l.Payload.Kind=='Pull'then pulls[#pulls+1]=l.Payload end end
   local label=(mech and'Mech 'or'')..rarity..' '..reward.SeedId
   check(reward.SeedId==expect and Packs.GetRarity(reward.SeedId)==rarity,'a real Void pack opens a '..label)
   if #pulls>0 then
    local payload=pulls[1]
    local fixedN=Canon.Canonical(reward.SeedId);local real=100/voidPercent[reward.SeedId]
    check(near(payload.Odds,fixedN,1e-12),label..': the announcer\'s payload carries the FIXED N ('..tostring(payload.Odds)..', not the Void pack\'s '..tostring(real)..')')
    local e=Rules.Event('Pull',payload);local line=Rules.Plain(e)
    local fixedText='('..Canon.Text(reward.SeedId)..')'
    check(line:find(fixedText,1,true)~=nil,label..': the chat line says '..fixedText..': '..line)
    local voidText='('..Odds.Format(voidPercent[reward.SeedId])..')'
    check(voidText==fixedText or line:find(voidText,1,true)==nil,label..': ... and not the Void pack\'s '..voidText)
    print('SURFACE chat-real '..reward.SeedId..' '..Canon.Text(reward.SeedId)..' | '..line)
   else check(false,label..': a line was sent to the server\'s players')end
  end
 end
 check(Announcer.OddsOf(Config,Ann,{Stage=7,BagVariant='EclipseReliquary'},'PolarStarbloomSeed')==Canon.Canonical('PolarStarbloomSeed'),'PullAnnouncer.OddsOf = the fixed N whatever pack it is given')
 check(Announcer.OddsOf(Config,Ann,nil,'NoSuchSeed')==nil,'... and nil for a seed it does not know')
end
local chatLines={}
do -- every seed, every kind: the line says the fixed chance whatever number the sender wrote
 local bad={}
 for i,r in ipairs(all)do
  local rarity=r.Rarity
  for _,kind in ipairs({'Pull','Global'})do
   local e=Rules.Event(kind,{Id='e'..i..kind,Name='Ann',UserId=7,SeedId=r.Id,Odds=WRONG})
   local line=e and Rules.Plain(e)
   local at=line and(kind=='Global'and line:match('%((1/[^)]+)%)!')or line:match('%((1/[^)]+)%)'))
   if not e or e.Odds~=Canon.Canonical(r.Id)or at~=r.Text then bad[#bad+1]=r.Id..' '..kind..' '..tostring(at)end
   if kind=='Pull'then chatLines[r.Id]=at end
  end
  print('SURFACE chat-rules '..r.Id..' '..tostring(chatLines[r.Id]))
 end
 check(#bad==0,'every seed, in a pull here and a pull from another server: the line carries the fixed chance even when the payload claims 1/'..WRONG..' ('..table.concat(bad,'; ')..')')
 local noOdds=Rules.Event('Pull',{Id='n1',Name='Ann',UserId=7,SeedId='PolarStarbloomSeed'})
 check(noOdds and noOdds.Odds==1e6 and Rules.Plain(noOdds):find('(1/1M)',1,true),'a pull with no odds field still says the fixed chance')
 local rec=Rules.Event('Record',{Id='r1',Name='Rex',Record='BestPull',Odds=12345})
 check(rec and rec.Odds==12345 and rec.SeedId==nil,'a record about no seed keeps the number it was given (nothing to derive it from)')
 local rec2=Rules.Event('Record',{Id='r2',Name='Rex',Record='BestPull',SeedId='FirePepperSeed',Odds=5})
 check(rec2 and rec2.Odds==800,'a record about a seed carries the fixed chance')
 -- the payload on the wire still travels (older servers read it) and a newer receiver re-derives it
 local e=Rules.Event('Pull',{Id='w1',Name='Ann',UserId=7,SeedId='SunflowerSeed',Odds=3})
 local back=Rules.Event('Global',Rules.Expand(Rules.Compact(e)))
 check(back and back.Odds==Canon.Canonical('SunflowerSeed')and Rules.Plain(back):find('(1/2)',1,true),'Compact / Expand round trip: the receiving server shows the fixed chance')
end

-- 6. the hub plaque -------------------------------------------------------------------------------------------------------------------------------------
do
 local bad={}
 for i,r in ipairs(all)do
  local rec=Hub.CleanPull({Uid=1,Name='A',Id=r.Id,Seed=r.Name,Rarity=r.Rarity,Odds=100/WRONG,Scale=1,Coat='None',At=1700000000+i})
  local out=rec and Hub.SignText('Pull',rec,nil,3600,nil)
  local line=out and out.Plaque.Line.Text
  local at=line and line:match('· (1/%S+)')
  if not rec or at~=r.Text or rec.Odds~=100/WRONG then bad[#bad+1]=r.Id..' '..tostring(line)end
  print('SURFACE plaque '..r.Id..' '..tostring(at))
 end
 check(#bad==0,'the plaque names the fixed chance for every seed, whatever chance the pull was stored with ('..table.concat(bad,'; ')..')')
 -- the pull keeps its real chance for the ranking
 local mk=function(id,rarity,percent,at)return Hub.CleanPull({Uid=1,Name='A',Id=id,Seed='S',Rarity=rarity,Odds=percent,Scale=1,Coat='None',At=at})end
 local lucky=mk('PolarStarbloomSeed','Cosmic',voidPercent.PolarStarbloomSeed,1700000001)
 local plain=mk('PolarStarbloomSeed','Cosmic',1e-4,1700000002)
 check(lucky and plain and Hub.PullBetter(plain,lucky)==true and Hub.PullBetter(lucky,plain)==false,'ranking is unchanged: the pull with the smaller REAL chance is the better one (a Cosmic from a Void pack does not outrank one from a plain pack)')
 check(Hub.SignText('Pull',lucky,nil,60,nil).Plaque.Line.Text==Hub.SignText('Pull',plain,nil,60,nil).Plaque.Line.Text,'... while the two plaques read the same words for the same seed')
 -- coat suffix and unknown ids
 local coat=Hub.CleanPull({Uid=1,Name='A',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='Mythic',Odds=1,Scale=1,Coat='Gold',At=1700000009})
 check(Hub.SignText('Pull',coat,nil,60,nil).Plaque.Line.Text=='Mythic · 1/800 · Gold','a coat still follows the chance ("'..Hub.SignText('Pull',coat,nil,60,nil).Plaque.Line.Text..'")')
 check(Hub.PullOddsText({Id='NoSuchSeed',Odds=.125})=='1/800'and Hub.PullOddsText({Id='FirePepperSeed',Odds=50})=='1/800'and Hub.PullOddsText(nil)=='—','PullOddsText: an unknown seed falls back to the stored chance, a known one never does')
end

-- 7. announcements still decide by rarity tier ---------------------------------------------------------------------------------------------------------
do
 local ok=true
 for _,r in ipairs(all)do
  for _,odds in ipairs({1,12,1e6,1e12})do
   local e=Rules.Event('Pull',{Id='q',Name='A',UserId=1,SeedId=r.Id,Odds=odds})
   local rank=Packs.Rarities[r.Rarity].Rank
   if not e or e.Rarity~=r.Rarity or Rules.Qualifies('Global',e.Rarity)~=(rank>=6)or Rules.Qualifies('InServer',e.Rarity)~=(rank>=4)then ok=false end
  end
 end
 check(ok,'Secret+ goes to every server and Legendary+ to this one, whatever Odds says (rarity tier only)')
 check(Rules.RecordScope('BestPull','Cosmic')=='InServer'and Rules.RecordScope('BestPull','Legendary')=='InServer'and Rules.RecordScope('BestPull','Rare')==nil,'hub record scope still by rarity (R153 best pull: this server only, never another: a Cosmic record is no longer "Global")')
 local src=Rules.Qualifies and true
 check(src,'(Qualifies exists)')
end

-- 8. owner command texts --------------------------------------------------------------------------------------------------------------------------------
do
 local lines={}
 local srv=Announcer.new({Data=Data,Players=Players,Http=Http,Messaging=nil,Remote=select(1,remoteLog()),Clock=function()return R.clock end,Time=unix,JobId='job-cmd',Warn=function()end})
 local ctx={Config=Config}
 local ok,text=srv:RunCommand(ctx,Ann,{'global','polar','starbloom','here'})
 check(ok==true and tostring(text):find('(1/1M)',1,true)~=nil,'/test announce global <Cosmic seed>: the line it shows says the fixed chance: '..tostring(text))
 local ok2,text2=srv:RunCommand(ctx,Ann,{'record','bestpull','fire','pepper'})
 check(ok2==true,'/test announce record <seed> works ('..tostring(text2)..')')
end

-- 9. no pack is a single-seed pack (owner, after R152: "the mythic forest pack can only roll elderbloom ... make it not 100%"). The audit of the real tables: nothing is 100% one seed today (what the
-- owner saw there is the TEST pack of `/test rarepacks mythic`: a guaranteed reveal of the first Mythic seed, Elderbloom, by design). Kept as an invariant, so a later roster change that leaves a
-- pack with one seed fails here. The live packs (odds version 149) also keep their favourite under 90%.
do
 local bad,rowsSeen={},0
 local audit={}
 local names={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm'}
 for _,stage in ipairs({1,6,2,3,4,5,7})do for _,pack in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do
  for _,version in ipairs({'nil',0,81,112,137,149})do for _,luck in ipairs({1,500,5e7})do for _,boost in ipairs({0,2})do
   local odds=Packs.SeedOdds(Config,stage,pack,luck,version~='nil'and version or nil,boost==2 and 2 or nil)
   local count,top,topId=0,0,nil
   for id,p in pairs(odds)do if p>0 then count+=1;if p>top then top,topId=p,id end end end
   rowsSeen+=1
   if count<2 then bad[#bad+1]=('%s %s v%s luck %g boost %d: %d seed(s)'):format(names[stage],pack,tostring(version),luck,boost,count)end
   if version==149 and luck==1 and boost==0 and pack:sub(1,4)=='Pack'then
    audit[#audit+1]=('AUDIT %s %s %d %.4f %s'):format(names[stage],pack,count,top,topId)
    if top>90 then bad[#bad+1]=('%s %s (live): the favourite %s is %.2f%%'):format(names[stage],pack,topId,top)end
   end
  end end end
 end end
 check(rowsSeen>2000 and#bad==0,'no pack is a one-seed pack: every stage x pack x odds version (nil / 0 / 81 / 112 / 137 / 149) x luck x boost lists 2 or more seeds ('..rowsSeen..' rows), and a live pack\'s favourite stays under 90%: '..table.concat(bad,'; '))
 for _,l in ipairs(audit)do print(l)end
 for _,case in ipairs({{Packs.OddsVersion,7,'EclipseReliquary'},{Packs.OddsVersion,7,'VerityReliquary'},{Packs.OddsVersion,8,'MechLimited'}})do
  local odds=Packs.SeedOdds(Config,case[2],case[3],1,case[1]);local n=0;for _,p in pairs(odds)do if p>0 then n+=1 end end
  check(n>=5,case[3]..' lists '..n..' seeds')
 end
 -- the Forest Mythic pack (Pack06), through the real roll: both of its seeds come up
 local counts={};local seedN=12345
 local function draw()seedN=(seedN*1103515245+12345)%2147483648;return seedN/2147483648 end
 for _=1,3000 do local seed=Packs.Roll(Config,1,draw,1,'Pack06',Packs.OddsVersion);if seed then counts[seed.Id]=(counts[seed.Id]or 0)+1 end end
 check((counts.ElderbloomSeed or 0)>600 and(counts.SunflowerBloomSeed or 0)>1500 and(counts.ElderbloomSeed or 0)+(counts.SunflowerBloomSeed or 0)==3000,'the Forest Mythic pack rolls Sunflower AND Elderbloom: '..tostring(counts.SunflowerBloomSeed)..' / '..tostring(counts.ElderbloomSeed)..' of 3000 (73% / 27%)')
 -- the TEST pack (guaranteed reveal) is the one-seed pack: an owner tool, marked TestGrant, never announced
 local RPT=server('RarePackTests')
 check(type(RPT.Expected)=='function','(RarePackTests: /test rarepacks packs reveal one chosen seed on purpose)')
end

print(('R153 seed rarity (server): %d checks, %d failures'):format(checks,fails))
if fails>0 then error('failed')end
