--!nocheck
-- R155 pack pity (owner: "every 10th pack" gets x1.5 luck; "make the pity separate an event pity and a normal pity the event pity only counts for void, verity and mech all
-- other packs have separate pity") on the Roblox mock with the REAL PackPity155 / PackPityData155 / PlayerDataService / SeedPackRules / PackOdds / PackLuck154 / WorldStatusHud /
-- OwnerUpdateCommands82 / ChestService / SeedRarity153 / Config of this checkout (the R153 clover world):
--  1. the rules     - groups for every bag variant the game has, the 10th lucky then 0, sanitising, the words, the lucky scope (on only inside, off after an error)
--  2. the clamps    - PackOdds112 / 137 take x75M only on a lucky roll (x50M otherwise), the pre-R112 mapping gets the x1.5 once, PackLuck154 takes x3 only on a lucky roll,
--                     the HUD luck row shows x1.5 (up to x75M) only for a lucky pack in hand
--  3. lucky odds    - the cap really moves (Desert Common King x1.5 at x75M), the per-tier ceilings and the 80% rule hold in every pack at x75M, packs already at every
--                     ceiling do not change, the Void / Verity / Mech packs take the clover x1.5 (x1.5 / x3), the shown fixed numbers never move
--  4. real opens    - per group (normal vs event, every kind of pack), the 10th lucky then 0, x1.5 applied exactly once (luck and pass luck) with the lucky cap on, the
--                     BEST PULL hook told; TEST opens excluded; refused / failed opens (data loading, replay, unknown, a failed roll, a refused reward, a paid pack not
--                     allowed, spam) neither move nor skip the count
--  5. saved         - the optional PackPity field: save, load, rejoin, old profiles, junk; ProfileVersion 22
--  6. owner / text  - /test pity, /test pity set, /test pity 30 (the old preview), /test odds ... lucky and the rule line; the hold tooltip (lucky odds + the rule)
--  7. held tooltip  - (R155 review) a held pack's tooltip is rebuilt when a pity count or the boots luck changes (one refresh a frame, a never-held pack keeps its short line, a bad record
--                     does not stop the others); the Mech coat line only on a bought pack
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local Config,Data=E.Config,E.Data
local Rules=W.module('SeedPackRules');local Pity=W.module('PackPity155');local Balance=W.module('BalanceValues81')
local O112,O137=W.module('PackOdds112'),W.module('PackOdds137');local L=W.module('PackLuck154')
local Canon=W.module('SeedRarity153');local Verity=W.module('VerityCatalog');local Odds=W.module('OddsText85')
local boots=Config.ShopCatalog.Accessories
local function near(a,b,rel)rel=rel or 1e-9;return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=rel*math.max(1,math.abs(a),math.abs(b))end
local function uniform(seed)math.randomseed(seed);return function()return math.random()end end
local function rarity(id)return(Rules.GetRarity(id))end
local STAGES={1,6,2,3,4,5,7};local PACKS={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'}
local EVENT={EclipseReliquary=true,VerityReliquary=true,MechLimited=true}

-- 1. the rules -----------------------------------------------------------------------------------------------------------------------------------
check(Pity.Every==10 and Pity.Boost==1.5 and Balance.LuckyPackBoost==1.5,'every 10th pack, x1.5 (BalanceValues81.LuckyPackBoost)')
check(Balance.LuckCeiling==5e7 and Balance.LuckyLuckCeiling==7.5e7,'LuckCeiling x50M (R155), the lucky roll\'s x75M = x50M x1.5 (BalanceValues81.LuckyLuckCeiling)')
do
 local keys={};for key in pairs(Rules.Variants)do keys[#keys+1]=key end;table.sort(keys)
 local ok=#keys>=9
 for _,key in ipairs(keys)do local want=EVENT[key]and'Event'or'Normal';if Pity.Group(key)~=want then ok=false;print('FAIL: group of '..key..' = '..tostring(Pity.Group(key)))end end
 check(ok,'every bag variant of the game is in its group: Void / Verity / Mech = EVENT, '..(#keys-3)..' others (Pack01-06 ...) = NORMAL ('..table.concat(keys,', ')..')')
 check(Pity.Group(nil)=='Normal'and Pity.Group('Nope')=='Normal'and Pity.Group(Verity.Variant)=='Event','a missing / unknown variant is NORMAL; the Verity pack is EVENT')
end
do
 local c,lucky=0,{}
 for i=1,30 do if Pity.IsLucky(c)then lucky[#lucky+1]=i end;c=Pity.After(c)end
 check(table.concat(lucky,',')=='10,20,30'and c==0,'opens 1-9 normal, the 10th lucky, back to 0: lucky at '..table.concat(lucky,','))
 local after={};for n=0,9 do after[#after+1]=Pity.After(n)end
 check(table.concat(after,',')=='1,2,3,4,5,6,7,8,9,0','After: 0..8 -> +1, 9 -> 0')
 check(Pity.Count(-1)==0 and Pity.Count(10)==0 and Pity.Count(3.7)==3 and Pity.Count('x')==0 and Pity.Count(0/0)==0 and Pity.Count(math.huge)==0 and Pity.Count('7')==7,'a count is a whole 0..9 (junk = 0)')
 local s=Pity.State({Normal=4,Event=9});local j=Pity.State({Normal=-2,Event='x'});local n=Pity.State(nil)
 check(s.Normal==4 and s.Event==9 and j.Normal==0 and j.Event==0 and n.Normal==0 and n.Event==0,'State: saved counts, junk and no field = 0 / 0')
 check(Pity.Left(0)==10 and Pity.Left(9)==1,'Left: 10 opens from 0, 1 from 9')
 check(Pity.Text('Normal',3)=='3/10 pity'and Pity.Text('Event',3)=='3/10 event pity'and Pity.Text('Normal',9)=='9/10 next one\'s lucky!'and Pity.Text('Event',0)=='0/10 event pity','the bar words: "3/10 pity", "3/10 event pity", "9/10 next one\'s lucky!"')
 check(Pity.Disclosure=='every 10th pack u open is lucky: x1.5 luck (event packs count separately)','the rule line (owner\'s voice)')
end
do
 check(not Pity.Lucky()and Pity.Ceiling(5e7)==5e7,'outside a lucky roll: no lucky ceiling')
 local inside;Pity.Scoped(true,function()inside={Pity.Lucky(),Pity.Ceiling(5e7),Pity.Ceiling(2)}end)
 check(inside[1]==true and inside[2]==7.5e7 and inside[3]==3 and not Pity.Lucky(),'inside Scoped(true): the ceiling is x1.5 (x50M -> x75M, the clover x2 -> x3), off again after')
 local okErr=pcall(Pity.Scoped,true,function()error('boom')end)
 check(not okErr and not Pity.Lucky()and Pity.Ceiling(5e7)==5e7,'an error inside a lucky roll still turns the ceiling back off (and is passed on)')
 local plain;Pity.Scoped(false,function()plain=Pity.Lucky()end);check(plain==false,'Scoped(false) is a plain call')
 local a,b=Pity.Scoped(true,function(x,y)return x+1,y..'!'end,1,'a');check(a==2 and b=='a!','Scoped hands the arguments and every result through')
 check(Pity.Luck(5e7,true)==7.5e7 and Pity.Luck(5e7,false)==5e7 and Pity.Luck(2,true)==3 and Pity.Luck(nil,true)==nil,'Luck: x1.5 only for the lucky one (junk stays junk)')
end

-- 2. the clamps ----------------------------------------------------------------------------------------------------------------------------------
for _,O in ipairs({O112,O137})do
 check(O.Luck(7.5e7)==5e7 and O.Luck(1e9)==5e7 and O.Luck(5e7)==5e7,'PackOdds'..O.Version..'.Luck outside a lucky roll: x50M at most (as before)')
 local a,b,c,d=Pity.Scoped(true,function()return O.Luck(7.5e7),O.Luck(1e9),O.Luck(5e7),O.Luck(0/0)end)
 check(a==7.5e7 and b==7.5e7 and c==5e7 and d==1,'PackOdds'..O.Version..'.Luck on a lucky roll: x75M at most (and junk is 1)')
 local ok=true
 for _,w in ipairs({{1,1},{25,1.15},{249,1.15},{250,1.3},{1e4,1.5},{5e5,1.75},{2.5e7,2},{5e7,2}})do
  if O.LegacyLuck(w[1])~=w[2]then ok=false;print('FAIL: LegacyLuck('..w[1]..')')end
  local v=Pity.Scoped(true,O.LegacyLuck,w[1]*1.5)
  if not near(v,w[2]*1.5)then ok=false;print('FAIL: lucky LegacyLuck('..w[1]..'x1.5) = '..tostring(v)..', want '..w[2]*1.5)end
 end
 check(ok,'PackOdds'..O.Version..'.LegacyLuck: as before outside; a lucky roll\'s luck (x1.5) maps to the same old boot and that gets the x1.5 ONCE (x1 -> x1.5 ... x2 -> x3)')
end
check(L.PassLuck(3)==2 and L.PassLuck(1.5)==1.5 and L.PassLuck(2)==2,'PackLuck154.PassLuck outside a lucky roll: x2 at most (as before)')
check(Pity.Scoped(true,L.PassLuck,3)==3 and Pity.Scoped(true,L.PassLuck,4.5)==3 and Pity.Scoped(true,L.PassLuck,1.5)==1.5,'... on a lucky roll: the clover\'s x2 x1.5 = x3 at most')
do -- the HUD luck row
 local Hud=W.module('WorldStatusHud')
 local p=R.new('Player');p:SetAttribute('TreadmillTier',1);p:SetAttribute('ChestLuckMultiplier',5e7)
 local _,plain=Hud.Boosts(p);local _,lucky=Hud.Boosts(p,true)
 check(plain==5e7 and lucky==7.5e7,'HUD: Thunder Boots + clover read x50M; for a lucky pack x75M (the lucky cap), never more')
 p:SetAttribute('ChestLuckMultiplier',1e9);local _,big=Hud.Boosts(p);local _,bigLucky=Hud.Boosts(p,true)
 check(big==5e7 and bigLucky==7.5e7,'HUD: junk above the cap reads x50M, x75M for a lucky pack')
 p:SetAttribute('ChestLuckMultiplier',1);local _,one=Hud.Boosts(p,true);check(one==1.5,'HUD: no boots: a lucky pack reads x1.5')
 local char=R.new('Model');p.Character=char
 check(Hud.LuckyHeld(p)==false,'LuckyHeld: nothing in hand -> false')
 local tool=R.new('Tool');tool:SetAttribute('SeedPackTool',true);tool:SetAttribute('BagVariant','Pack03');tool.Parent=char
 p:SetAttribute('PackPityNormal',8);check(Hud.LuckyHeld(p)==false,'LuckyHeld: a normal pack at 8/10 -> false')
 p:SetAttribute('PackPityNormal',9);check(Hud.LuckyHeld(p)==true,'LuckyHeld: a normal pack at 9/10 (its open is the lucky 10th) -> true')
 tool:SetAttribute('BagVariant','MechLimited');p:SetAttribute('PackPityEvent',9);check(Hud.LuckyHeld(p)==false,'LuckyHeld: a Mech pack (event, boots never reach it) -> false')
end

-- 3. lucky odds -----------------------------------------------------------------------------------------------------------------------------------
local function oddsAt(stage,variant,luck,pass,lucky,version)return Pity.Scoped(lucky,Rules.SeedOdds,Config,stage,variant,luck,version or 149,nil,pass)end
local function rawAt(stage,variant,luck,pass,lucky,version)return Pity.Scoped(lucky,Rules.RawSeedOdds,Config,stage,variant,luck,version or 149,nil,pass)end
do
 local k50=oddsAt(2,'Pack01',5e7,2,false).SolarStarfruitSeed;local k75=oddsAt(2,'Pack01',7.5e7,2,true).SolarStarfruitSeed
 check(near(k75,1.5*k50),'a lucky roll of a Thunder + clover player (x50M x1.5 = x75M): Desert Common King '..Odds.Format(k50)..' -> '..Odds.Format(k75)..' (x1.5: the cap moved with it)')
 check(near(oddsAt(2,'Pack01',7.5e7,2,false).SolarStarfruitSeed,k50),'the same x75M outside a lucky roll reads as x50M (no other roll can reach it)')
 check(near(oddsAt(2,'Pack01',7.5e7,2,true,112).SolarStarfruitSeed,1.5*oddsAt(2,'Pack01',5e7,2,false,112).SolarStarfruitSeed),'... a banked OddsVersion 112 pack too')
 local legacyPlain=oddsAt(2,'Pack01',1,1,false,81);local legacyLucky=oddsAt(2,'Pack01',1.5,1,true,81)
 local changed=false;for id,p in pairs(legacyPlain)do if not near(p,legacyLucky[id]or 0)then changed=true end end
 check(changed,'a pack banked before R112 (OddsVersion 81): the lucky roll changes its odds too (old luck x1 -> x1.5)')
 -- every world pack x live version: per-tier ceilings and the 80% rule at x75M; packs at every ceiling stay as they are
 local moved,still,okCeil,okRule=0,{},true,true
 for _,stage in ipairs(STAGES)do for _,pack in ipairs(PACKS)do
  local base=rawAt(stage,pack,1,1,false);local raw=rawAt(stage,pack,7.5e7,2,true)
  local tb,tr={},{};for id,p in pairs(base)do local t=rarity(id);tb[t]=(tb[t]or 0)+p end;for id,p in pairs(raw)do local t=rarity(id);tr[t]=(tr[t]or 0)+p end
  for t,cap in pairs(O137.Cap)do if tr[t]and cap<1 and tr[t]/100>math.max(cap,(tb[t]or 0)/100)+1e-9 then okCeil=false;print(('FAIL: %s %s %s %.4f%% over its ceiling'):format(stage,pack,t,tr[t]))end end
  local shaped=oddsAt(stage,pack,7.5e7,2,true);local total=0;for _,p in pairs(shaped)do total+=p end
  for id,p in pairs(shaped)do if p/total>.8+1e-9 then okRule=false;print('FAIL: 80% rule '..stage..' '..pack..' '..id)end end
  local plain=oddsAt(stage,pack,5e7,2,false)
  local diff=false;for id,p in pairs(plain)do if not near(p,shaped[id]or 0,1e-12)then diff=true end end
  if diff then moved+=1 else still[#still+1]=stage..':'..pack end
 end end
 check(okCeil,'at x75M (a lucky Thunder + clover roll) no tier of any of the 42 world packs is over its per-tier ceiling (King 1%, Cosmic 5%, Secret 25%, Mythic 45%, Legendary 50% unless the pack\'s own is higher)')
 check(okRule,'... and no seed of any live pack is over 80% (the 80% rule still holds)')
 check(moved>=30,'a lucky roll at the top luck changes '..moved..' of the 42 world packs; the rest are at every ceiling already ('..table.concat(still,' ')..')')
 print('TABLE lucky-top: '..moved..' of 42 packs move at x75M; unchanged: '..table.concat(still,' '))
 -- the fixed-odds packs: the clover x1.5 (x1.5 without the clover, x3 with it)
 for _,f in ipairs({{'Mech',8,'MechLimited',81},{'Void',7,'EclipseReliquary',149},{'Verity',7,'VerityReliquary',149}})do
  local lucky1=oddsAt(f[2],f[3],1,1.5,true,f[4]);local lucky2=oddsAt(f[2],f[3],1,3,true,f[4])
  local want1=L.FixedOdds(f[1],Config,Rules,1.5);local want2=Pity.Scoped(true,L.FixedOdds,f[1],Config,Rules,3)
  local ok=true;for id,p in pairs(want1)do if not near(p,lucky1[id]or 0,1e-9)then ok=false end end;for id,p in pairs(want2)do if not near(p,lucky2[id]or 0,1e-9)then ok=false end end
  local outside=oddsAt(f[2],f[3],1,3,false,f[4]);local two=oddsAt(f[2],f[3],1,2,false,f[4]);for id,p in pairs(two)do if not near(p,outside[id]or 0,1e-12)then ok=false end end
  check(ok,f[1]..' pack: a lucky roll takes the clover x1.5 (x1.5 without it, x3 with it); outside a lucky roll x3 reads as the clover\'s x2')
 end
 local m15=oddsAt(8,'MechLimited',1,1.5,true,81).CrowncoreTreeSeed;local m3=oddsAt(8,'MechLimited',1,3,true,81).CrowncoreTreeSeed
 check(near(m15,.75)and near(m3,1.5),'Limited Mech pack King (Crowncore Tree): 0.5% -> 0.75% on a lucky pack, 1.5% with the clover too ('..Odds.Format(m15)..', '..Odds.Format(m3)..')')
 local v15=oddsAt(7,'VerityReliquary',1,1.5,true).VeritySeed;local v3=oddsAt(7,'VerityReliquary',1,3,true).VeritySeed
 check(near(v15,1.5)and near(v3,3),'Verity seed: 1% -> 1.5% on a lucky Verity pack, 3% with the clover too')
 print(('TABLE fixed: Mech King lucky %s / lucky+clover %s; Verity seed lucky %s / lucky+clover %s'):format(Odds.Format(m15),Odds.Format(m3),Odds.Format(v15),Odds.Format(v3)))
 -- the shown fixed numbers (Index, reveal card, chat, plaque: SeedRarity153 reads RawSeedOdds at luck 1) never move, also when asked inside a lucky roll
 local outside={};for _,r in ipairs(Canon.All())do outside[r.Id]=Canon.Text(r.Id)end
 local same=true;Pity.Scoped(true,function()for _,r in ipairs(Canon.All())do if Canon.Text(r.Id)~=outside[r.Id]then same=false end end end)
 local raw1=rawAt(2,'Pack01',1,1,false);local raw1L=rawAt(2,'Pack01',1,1,true);for id,p in pairs(raw1)do if not near(p,raw1L[id]or 0,1e-12)then same=false end end
 check(same and #Canon.All()==54,'the shown odds (SeedRarity153 / RawSeedOdds at luck 1: Index, cards, chat) are the same inside a lucky roll (54 seeds)')
 -- the exact staged roll still follows a lucky Mech table
 local n,hits=30000,0;local u=uniform(4242)
 for _=1,n do local seed=Pity.Scoped(true,Rules.Roll,Config,8,u,1,'MechLimited',81,nil,3);if seed and seed.Id=='CrowncoreTreeSeed'then hits+=1 end end
 local e=n*.015;check(math.abs(hits-e)<5*math.sqrt(e),'30,000 lucky Mech rolls with the clover: '..hits..' Crowncore Trees (1.5% = '..e..')')
end

-- 4. real opens --------------------------------------------------------------------------------------------------------------------------------
local seen={};local orig=Rules.Roll
local failRoll=false
Rules.Roll=function(...)local a={...};seen[#seen+1]={Luck=a[4],Variant=a[5],Pass=a[8],Lucky=Pity.Lucky(),Ceil=Pity.Ceiling(5e7)};if failRoll then return nil end;return orig(...)end
local hookInfo={};Data.OnPackOpened=function(_,_,info)hookInfo[#hookInfo+1]=info end
local NORMAL_KINDS={
 {Stage=2,BagVariant='Pack01',OddsVersion=149},{Stage=1,BagVariant='Pack06',OddsVersion=149},{Stage=7,BagVariant='Pack05',OddsVersion=149},
 {Stage=3,BagVariant='Pack02',OddsVersion=137},{Stage=4,BagVariant='Pack03',OddsVersion=112},{Stage=5,BagVariant='Pack04',OddsVersion=81},
 {Stage=6,BagVariant='Pack01',OddsVersion=149,RateBoost=2}, -- the free starter pack (2x rates)
}
local EVENT_KINDS={{Stage=7,BagVariant='EclipseReliquary',OddsVersion=149},{Stage=7,BagVariant='VerityReliquary',OddsVersion=149},{Stage=8,BagVariant='MechLimited'}}
local function pack(kind)local c=table.clone(kind);c.PackSize=1;c.PackMutation='None';return c end
local function counts(p)local s=Data:GetPackPity(p);return s.Normal,s.Event end
local ann=E.makePlayer(6001,'PityAnn');Data:AddBoost(ann,boots[5].Id);ann:SetAttribute('CloverOwned',true);Data:RefreshBoostMultipliers(ann)
local MAXL=ann:GetAttribute('ChestLuckMultiplier')
check(MAXL==5e7,'(a Thunder Boots + clover player: x50M)')
check(ann:GetAttribute('PackPityNormal')==0 and ann:GetAttribute('PackPityEvent')==0 and ann:GetAttribute('PackPityLuckyNormal')==0 and ann:GetAttribute('PackPityLuckyEvent')==0,'after the load the counts are on the player (attributes): 0 / 0, no lucky packs yet')
do
 local luckyAt,groups,okLuck,okPlan={},{},true,true
 table.clear(seen);table.clear(hookInfo)
 for i=1,25 do
  local kind=NORMAL_KINDS[(i-1)%#NORMAL_KINDS+1]
  local rec=Data:AddChest(ann,pack(kind))
  local r,why,plan=Data:OpenSeedPack(ann,rec.Id,uniform(100+i))
  if not r then okPlan=false;print('FAIL: open '..i..' refused: '..tostring(why))end
  if plan and plan.Lucky then luckyAt[#luckyAt+1]=i end
  groups[plan and plan.Group or'nil']=(groups[plan and plan.Group or'nil']or 0)+1
  local s=seen[#seen];local lucky=plan and plan.Lucky
  if lucky then if not(s.Luck==MAXL*1.5 and s.Pass==3 and s.Lucky==true and s.Ceil==7.5e7)then okLuck=false;print('FAIL: lucky open '..i..' luck '..tostring(s.Luck)..' pass '..tostring(s.Pass))end
  elseif not(s.Luck==MAXL and s.Pass==2 and s.Lucky==false and s.Ceil==5e7)then okLuck=false;print('FAIL: open '..i..' luck '..tostring(s.Luck)..' pass '..tostring(s.Pass)..' lucky '..tostring(s.Lucky))end
 end
 check(okPlan and groups.Normal==25,'25 normal packs of every kind (world Pack01-06 in several biomes, banked 137 / 112 / 81, the starter pack) all count as NORMAL')
 check(table.concat(luckyAt,',')=='10,20','... the 10th and the 20th are lucky ('..table.concat(luckyAt,',')..')')
 local n,e=counts(ann);check(n==5 and e==0,'... the normal count is 5 after 25 opens, the event count untouched (0)')
 check(ann:GetAttribute('PackPityNormal')==5 and ann:GetAttribute('PackPityEvent')==0 and ann:GetAttribute('PackPityLuckyNormal')==2 and ann:GetAttribute('PackPityLuckyEvent')==0,'... the player\'s attributes follow (5 / 0, 2 lucky normal packs)')
 check(okLuck,'x1.5 exactly once: the lucky rolls got luck x75M (x50M x1.5) and pass luck x3 (x2 x1.5) with the lucky cap on; every other roll x50M / x2 with the plain cap')
 local hookOk=#hookInfo==25
 for i,info in ipairs(hookInfo)do local want=(i==10 or i==20);if(info.Lucky==true)~=want or info.Luck~=(want and MAXL*1.5 or MAXL)or info.PassLuck~=(want and 3 or 2)then hookOk=false end end
 check(hookOk,'the BEST PULL hook is told the luck each roll took and which were lucky')
end
do -- the event group: Void / Verity / Mech share one count; the normal count is not touched by them
 local luckyAt,okGroup=nil,true;table.clear(seen)
 local n0=counts(ann)
 for i=1,12 do
  local kind=EVENT_KINDS[(i-1)%#EVENT_KINDS+1]
  local rec=Data:AddChest(ann,pack(kind))
  local r,_,plan=Data:OpenSeedPack(ann,rec.Id,uniform(300+i))
  if not r or not plan or plan.Group~='Event'then okGroup=false end
  if plan and plan.Lucky then luckyAt=luckyAt and luckyAt..','..i or tostring(i)end
  local s=seen[#seen];if plan and plan.Lucky then if s.Pass~=3 or s.Luck~=MAXL*1.5 then okGroup=false end elseif s.Pass~=2 then okGroup=false end
 end
 local n,e=counts(ann)
 check(okGroup and luckyAt=='10','Void, Verity and Mech packs share ONE count: the 10th event open is lucky (its pass luck x2 x1.5 = x3) ('..tostring(luckyAt)..')')
 check(n==n0 and e==2 and ann:GetAttribute('PackPityLuckyEvent')==1,'... normal count unchanged ('..n..'), event count 2, one lucky event pack')
end
do -- interleaved: each group keeps its own count
 Data:SetPackPity(ann,8,8);local order={}
 for i,kind in ipairs({NORMAL_KINDS[1],EVENT_KINDS[3],NORMAL_KINDS[2],EVENT_KINDS[1]})do
  local rec=Data:AddChest(ann,pack(kind));local _,_,plan=Data:OpenSeedPack(ann,rec.Id,uniform(500+i));order[#order+1]=plan.Group..(plan.Lucky and'*'or'')
 end
 check(table.concat(order,' ')=='Normal Event Normal* Event*','interleaved normal / event opens: each group counts on its own (8 -> 9, the next of each is lucky) ('..table.concat(order,' ')..')')
end
do -- a player without boots or the clover: the lucky roll still takes x1.5 (x1 -> x1.5, the clover-only packs x1 -> x1.5)
 local bo=E.makePlayer(6002,'PityBo');Data:SetPackPity(bo,9,9);table.clear(seen)
 local r1=Data:AddChest(bo,pack(NORMAL_KINDS[1]));local _,_,p1=Data:OpenSeedPack(bo,r1.Id,uniform(9))
 local r2=Data:AddChest(bo,pack(EVENT_KINDS[3]));local _,_,p2=Data:OpenSeedPack(bo,r2.Id,uniform(10))
 check(p1.Lucky and p2.Lucky and seen[1].Luck==1.5 and seen[1].Pass==1.5 and seen[2].Pass==1.5,'no boots, no clover: the lucky roll is x1.5 (luck 1 -> 1.5, pass luck 1 -> 1.5: it always does something)')
end
do -- TEST opens: never counted, never lucky
 local owner=E.makePlayer(6003,'PityOwner');Data:SetPackPity(owner,9,9);table.clear(seen)
 local rec=Data:AddChest(owner,pack(NORMAL_KINDS[1]),{TestGrant=true});local r,_,plan=Data:OpenSeedPack(owner,rec.Id,uniform(11))
 check(r and plan==nil and seen[1].Lucky==false and seen[1].Luck==1 and select(1,counts(owner))==9,'an owner-made TEST pack (TestGrant): not counted, not lucky even at 9/10')
 local RPT=E.server('RarePackTests')
 local okG=RPT.Grant(Data,owner,'mythic',owner);local test=Data:GetChestRecords(owner)[#Data:GetChestRecords(owner)]
 local r2,_,plan2=Data:OpenSeedPack(owner,test.Id,uniform(12))
 check(okG and r2 and plan2==nil and select(1,counts(owner))==9,'a /test rarepacks reveal: not counted, not lucky')
 local mech=Data:AddChest(owner,pack(EVENT_KINDS[3]),{TestGrant=true});local r3,_,plan3=Data:OpenSeedPack(owner,mech.Id,uniform(13))
 check(r3 and plan3==nil and select(2,counts(owner))==9,'a TEST Mech pack: the event count stays 9/10')
 local tb=E.makePlayer(6004,'PityTestBoots');Data:AddBoost(tb,boots[5].Id,{TestGrant=true});Data:RefreshBoostMultipliers(tb);Data:SetPackPity(tb,9,0);table.clear(seen)
 local r4rec=Data:AddChest(tb,pack(NORMAL_KINDS[1]));local r4,_,plan4=Data:OpenSeedPack(tb,r4rec.Id,uniform(14))
 check(Data:HasTestLuck(tb)and r4 and plan4==nil and seen[1].Lucky==false and select(1,counts(tb))==9,'an open with owner-given boots (a TEST open): not counted, not lucky')
 check(owner:GetAttribute('PackPityLuckyNormal')==0 and owner:GetAttribute('PackPityLuckyEvent')==0,'(no lucky pack was announced to the client for them)')
end
do -- refused / failed opens never move or skip the count
 local cy=E.makePlayer(6005,'PityCy');Data:SetPackPity(cy,9,9)
 local rec=Data:AddChest(cy,pack(NORMAL_KINDS[1]))
 Data.Loaded[cy]=false;local r0,why0=Data:OpenSeedPack(cy,rec.Id,uniform(20));Data.Loaded[cy]=true
 check(r0==nil and tostring(why0):find('LOADING',1,true)and select(1,counts(cy))==9,'data still loading: refused, the count stays 9/10')
 local rX=Data:OpenSeedPack(cy,'nope',uniform(21));check(rX==nil and select(1,counts(cy))==9,'a pack that is not in the bag: refused, unchanged')
 failRoll=true;local rF,whyF=Data:OpenSeedPack(cy,rec.Id,uniform(22));failRoll=false
 check(rF==nil and tostring(whyF):find('REJOIN',1,true)and select(1,counts(cy))==9 and cy:GetAttribute('PackPityLuckyNormal')==0,'a roll that fails (REJOIN TO OPEN): the count stays 9/10 and the lucky pack is not used up')
 local keep=Data.SeedCollectReward;Data.SeedCollectReward=function()return nil,'BAG FULL - MAKE ROOM IN UR BAG FIRST'end
 local rB,whyB=Data:OpenSeedPack(cy,rec.Id,uniform(23));Data.SeedCollectReward=keep
 check(rB==nil and tostring(whyB):find('BAG FULL',1,true)and select(1,counts(cy))==9,'a refused open (the reward refused, e.g. a full bag): unchanged')
 local paid=Data:AddChest(cy,pack(NORMAL_KINDS[1]));paid.PaidRandom=true;local rP=Data:OpenSeedPack(cy,paid.Id,uniform(24))
 check(rP==nil and select(1,counts(cy))==9,'a bought pack this account may not open: refused, unchanged')
 table.clear(seen)
 local ok,again,plans=0,0,{}
 for i=1,20 do local r,_,plan=Data:OpenSeedPack(cy,rec.Id,uniform(30+i));if r then ok+=1;plans[#plans+1]=plan elseif i>1 then again+=1 end end
 check(ok==1 and again==19 and plans[1].Lucky==true and select(1,counts(cy))==0 and cy:GetAttribute('PackPityLuckyNormal')==1,'spam: 20 opens of the same pack = ONE open (the lucky 10th, then 0/10); 19 replays refused')
end
Rules.Roll=orig;Data.OnPackOpened=nil

-- 5. saved --------------------------------------------------------------------------------------------------------------------------------------
do
 local function newPlayerFrom(save,id,name)local d=E.newData();d.Store.Data[d:_getKey({UserId=id,Name=name})]=E.deep(save);return E.makePlayer(id,name,d),d end
 local dee=E.makePlayer(6010,'PityDee');Data:SetPackPity(dee,7,3)
 local save=Data:_buildSaveData(dee)
 check(save.Version==22 and Config.ProfileVersion==22 and type(save.PackPity)=='table'and save.PackPity.Normal==7 and save.PackPity.Event==3,'saved: the optional PackPity = {Normal 7, Event 3}; ProfileVersion still 22')
 local back,d2=newPlayerFrom(save,6011,'PityBack')
 local s=d2:GetPackPity(back)
 check(s.Normal==7 and s.Event==3 and back:GetAttribute('PackPityNormal')==7 and back:GetAttribute('PackPityEvent')==3,'loaded again (a rejoin, another server): 7 / 3, on the player\'s attributes')
 d2:SetPackPity(back,9,3);local rec=d2:AddChest(back,pack(NORMAL_KINDS[1]));local _,_,plan=d2:OpenSeedPack(back,rec.Id,uniform(40))
 check(plan and plan.Lucky and d2:GetPackPity(back).Normal==0,'... and the count goes on from there (9/10 after the rejoin: the next open is the lucky one)')
 local old=E.deep(save);old.PackPity=nil;local o,dOld=newPlayerFrom(old,6012,'PityOld')
 check(dOld:GetPackPity(o).Normal==0 and dOld:GetPackPity(o).Event==0 and o:GetAttribute('PackPityNormal')==0 and o:GetAttribute('PackPityEvent')==0,'a profile saved before R155 (no PackPity): 0 / 0')
 for i,bad in ipairs({{Normal=-3,Event='x'},{Normal=12,Event=9.5},'junk',7})do
  local j=E.deep(save);j.PackPity=bad;local pj,dj=newPlayerFrom(j,6020+i,'PityJunk'..i)
  local sj=dj:GetPackPity(pj);check(pj~=nil and sj.Normal==0 and(sj.Event==0 or sj.Event==9),'junk PackPity ('..E.ser(bad)..') loads as a sane count, never a kick ('..sj.Normal..' / '..sj.Event..')')
 end
 -- the real save path: Save writes the DataStore, a new server reads it
 local ok=pcall(function()Data:Save(dee,'Test',true)end)
 local d3=E.newData();local again=ok and E.makePlayer(6010,'PityDee',d3)
 check(ok and again and d3:GetPackPity(again).Normal==7 and d3:GetPackPity(again).Event==3,'Save -> the DataStore -> a new server\'s Load: 7 / 3 (survives a rejoin)')
end

-- 6. owner commands and the texts -------------------------------------------------------------------------------------------------------------
do
 local X=E.server('OwnerUpdateCommands82')
 local ctx={Config=Config,Data=Data,Map={MapRoot=R.new('Folder')},Chase={IsPlayerBusy=function()return false end},Chests={IsOpening=function()return false end,SyncTools=function()end}}
 local ed=E.makePlayer(6030,'PityEd');Data:SetPackPity(ed,3,0);Data.Dirty[ed]=false
 local ok1,t1=X.Execute(ctx,ed,'pity',{})
 check(ok1 and t1=='PityEd: pity 3/10 (lucky in 7 packs) | event pity 0/10 (lucky in 10 packs)','/test pity: both counts and when each is lucky ('..tostring(t1)..')')
 local ok2,t2=X.Execute(ctx,ed,'pity',{'set','9','9'})
 check(ok2 and Data:GetPackPity(ed).Normal==9 and Data:GetPackPity(ed).Event==9 and t2:find('the NEXT pack is LUCKY',1,true)and t2:find('the NEXT event pack is LUCKY',1,true)and Data.Dirty[ed]==true,'/test pity set 9 9: the next pack of each group is lucky, saved ('..tostring(t2)..')')
 check(ed:GetAttribute('PackPityNormal')==9 and ed:GetAttribute('PackPityEvent')==9,'... and the bars hear it (attributes)')
 local bad=0;for _,args in ipairs({{'set','10','0'},{'set','-1','0'},{'set','1'},{'set','a','b'},{'set','1.5','2'},{'set','1','2','3'}})do if not X.Execute(ctx,ed,'pity',args)then bad+=1 end end
 check(bad==6 and Data:GetPackPity(ed).Normal==9,'/test pity set with a bad number: refused (0-9 only), nothing changed')
 local ok3,t3=X.Execute(ctx,ed,'pity',{'30'});check(ok3 and tostring(t3):find('Reset 30',1,true)~=nil,'/test pity 30: still the track reset preview')
 local ok4,t4=X.Execute(ctx,ed,'odds',{'desert','common','50000000','lucky'})
 local k75=oddsAt(2,'Pack01',7.5e7,1,true).SolarStarfruitSeed
 local lines={};for l in t4:gmatch('[^\n]+')do lines[#lines+1]=l end
 check(ok4 and lines[1]:find('LUCKY 10th',1,true)and lines[1]:find('x50000000 -> x75000000',1,true)and t4:find('Solar Starfruit Seed: '..Odds.Format(k75),1,true),'/test odds desert common 50000000 lucky: the lucky roll\'s odds (x75M: King '..Odds.Format(k75)..') ('..tostring(lines[1])..')')
 check(lines[#lines]=='pity: '..Pity.Disclosure,'... the last line is the pity rule ('..tostring(lines[#lines])..')')
 local ok5,t5=X.Execute(ctx,ed,'odds',{'desert','common','50000000'});local l5={};for l in t5:gmatch('[^\n]+')do l5[#l5+1]=l end
 check(ok5 and not l5[1]:find('LUCKY',1,true)and l5[#l5]=='pity: '..Pity.Disclosure and t5:find('Solar Starfruit Seed: '..Odds.Format(oddsAt(2,'Pack01',5e7,1,false).SolarStarfruitSeed),1,true),'/test odds without "lucky": the plain odds, the rule listed under them')
 local ok6,t6=X.Execute(ctx,ed,'odds',{'event','clover','lucky'});check(ok6 and t6:find('x2 -> x3',1,true),'/test odds event clover lucky: the clover x2 -> x3')
 local ok7,t7=X.Execute(ctx,ed,'odds',{'verity','lucky'});check(ok7 and t7:find('x1 -> x1.5',1,true)and t7:find('Verity Seed: '..Odds.Format(1.5),1,true),'/test odds verity lucky (no clover): x1 -> x1.5, the Verity seed '..Odds.Format(1.5))
 check(not X.Execute(ctx,ed,'odds',{'desert','common','75000000','lucky'}),'/test odds takes a luck up to x50M (the lucky x1.5 is added by the word)')
 -- the hold tooltip
 Data:SetPackPity(ed,9,4)
 local rec=Data:AddChest(ed,pack(NORMAL_KINDS[1]))
 local function raw(luck,pass)return Rules.SeedOdds(Config,rec.Stage,rec.BagVariant,luck,rec.OddsVersion,nil,pass)end
 local odds,before,after=Data:PackPityTooltip(ed,rec,raw)
 check(odds and near(odds.SolarStarfruitSeed,oddsAt(2,'Pack01',1.5,1,true).SolarStarfruitSeed)and before[1]==Pity.LuckyLine and after[1]==Pity.Disclosure,'hold tooltip at 9/10: the lucky roll\'s odds (x1.5), "'..Pity.LuckyLine..'", and the rule')
 local mech=Data:AddChest(ed,pack(EVENT_KINDS[3]))
 local o2,b2,a2=Data:PackPityTooltip(ed,mech,function(l,p)return Rules.SeedOdds(Config,8,'MechLimited',l,nil,nil,p)end)
 check(o2==nil and #b2==0 and a2[1]==Pity.Disclosure,'hold tooltip of a Mech pack at 4/10 event: its plain odds, the rule')
 local tg=Data:AddChest(ed,pack(NORMAL_KINDS[1]),{TestGrant=true});local o3,b3=Data:PackPityTooltip(ed,tg,raw)
 check(o3==nil and #b3==0,'hold tooltip of a TEST pack: never lucky')
 -- the real ChestService:_holdPack writes it on the pack tool
 local okC,Chest=pcall(E.server,'ChestService')
 if okC and Chest and Chest._holdPack then
  local fake=setmetatable({Config=Config,PlayerData=Data,Openings={}},{__index=Chest});fake._canOpenPack=function()return false end
  local tool=R.new('Tool');tool:SetAttribute('SeedInventoryId',rec.Id)
  pcall(Chest._holdPack,fake,ed,tool)
  local tip=tostring(tool.ToolTip)
  check(tip:find(Pity.LuckyLine,1,true)and tip:find(Pity.Disclosure,1,true)and tip:find('Solar Starfruit Seed: '..Odds.Format(oddsAt(2,'Pack01',1.5,1,true).SolarStarfruitSeed),1,true),'ChestService:_holdPack: the pack tool\'s tooltip has the lucky line, the lucky odds and the rule')
 else check(false,'ChestService loads on the mock ('..tostring(Chest)..')')end
end

-- 7. R155 review: a held pack's tooltip follows the pity counts and the boots luck (the real ChestService on the mock) -------------------------------------------
do
 local Chest=E.server('ChestService');local Mech=W.module('MechCatalog')
 local host=setmetatable({Config=Config,PlayerData=Data,Openings={}},{__index=Chest});host._canOpenPack=function()return false end -- (a bare host: _holdPack writes the tooltip, then refuses the hold)
 local tp=E.makePlayer(6040,'PityTip');local bp=tp:FindFirstChildOfClass('Backpack')
 local function expectTip(rec,lucky,coat) -- the tooltip as the rules say it: label, (LUCKY), the odds rows, (the coat line), the rule
  local luck,pass=tp:GetAttribute('ChestLuckMultiplier'),Data:PassLuck(tp)
  local odds=Pity.Scoped(lucky,Rules.SeedOdds,Config,rec.Stage,rec.BagVariant,Pity.Luck(luck,lucky),rec.OddsVersion or 0,nil,Pity.Luck(pass,lucky))
  local rows={Rules.PackLabel(rec.Stage,rec.BagVariant,rec.PackSize,rec.PackMutation)}
  if lucky then rows[#rows+1]=Pity.LuckyLine end
  for _,seed in ipairs(Rules.OddsRows(Config,rec.Stage,rec.BagVariant,odds))do rows[#rows+1]=seed.Name..': '..Odds.Format(odds[seed.Id])end
  if coat then rows[#rows+1]=Mech.CoatLine()end
  rows[#rows+1]=Pity.Disclosure
  return table.concat(rows,'\n')
 end
 local function hold(tool)pcall(Chest._holdPack,host,tp,tool)end
 local function flush()E.advance(0)end
 local SHORT=' • Click / tap / RT 5 times to open'
 local calls=0;local realRefresh=Chest._refreshPackTooltips;Chest._refreshPackTooltips=function(...)calls+=1;return realRefresh(...)end
 Data:SetPackPity(tp,0,9)
 local recA=Data:AddChest(tp,pack(EVENT_KINDS[3]))           -- Mech pack A (a free one: no coat line)
 local recC=Data:AddChest(tp,pack(NORMAL_KINDS[1]))          -- a pack that is never held
 local toolA,toolC=Chest._createPackTool(host,recA,bp),Chest._createPackTool(host,recC,bp)
 local shortC=Rules.PackLabel(recC.Stage,recC.BagVariant,recC.PackSize,recC.PackMutation)..SHORT
 check(toolA.ToolTip==Rules.PackLabel(recA.Stage,recA.BagVariant,recA.PackSize,recA.PackMutation)..SHORT and toolC.ToolTip==shortC and toolA:GetAttribute('OddsTooltip155')==nil,'a new pack tool has the short "Click / tap / RT 5 times to open" tooltip and is not marked yet')
 -- 1. event count 9, A held: the LUCKY line and the x1.5 odds
 hold(toolA)
 check(toolA.ToolTip==expectTip(recA,true,false)and toolA.ToolTip:find(Pity.LuckyLine,1,true)and toolA:GetAttribute('OddsTooltip155')==true,'event count 9, Mech pack A held: its tooltip has the LUCKY line and the x1.5 odds (marked OddsTooltip155)')
 check(expectTip(recA,true,false)~=expectTip(recA,false,false),'(the x1.5 odds really differ from the x1 odds for this pack)')
 toolA.Parent=bp
 -- 2. a lucky open of another event pack: the count goes to 0, A is put away and says so
 local before=calls
 local recB=Data:AddChest(tp,pack(EVENT_KINDS[1]));local r,why,plan=Data:OpenSeedPack(tp,recB.Id,uniform(7001))
 check(r and plan and plan.Lucky and Data:GetPackPity(tp).Event==0,'event pack B takes the lucky roll: the event count is 0 ('..tostring(why)..')')
 check(toolA.ToolTip:find(Pity.LuckyLine,1,true)~=nil and calls==before,'... nothing is rebuilt in the same frame (deferred)')
 flush()
 check(calls==before+1 and toolA.ToolTip==expectTip(recA,false,false)and not toolA.ToolTip:find('LUCKY',1,true),'... after the deferred refresh A\'s tooltip has no LUCKY line and its odds are the x1 odds ('..(calls-before)..' refresh)')
 check(toolC.ToolTip==shortC and toolC:GetAttribute('OddsTooltip155')==nil,'... the never-held pack C keeps its short tooltip (no odds are computed for it)')
 -- 3. the owner sets the count back to 9: A is lucky again
 Data:SetPackPity(tp,0,9);flush()
 check(toolA.ToolTip==expectTip(recA,true,false)and toolA.ToolTip:find(Pity.LuckyLine,1,true),'the owner sets the event count to 9: A\'s tooltip gains the LUCKY line and the x1.5 odds again')
 -- one refresh per frame however many things change
 before=calls;Data:SetPackPity(tp,3,3);tp:SetAttribute('ChestLuckMultiplier',7);tp:SetAttribute('ChestLuckMultiplier',9);Data:SetPackPity(tp,4,4);flush()
 check(calls==before+1,'a pity count, the luck and a count again in one frame: ONE refresh ('..(calls-before)..')')
 before=calls;tp:SetAttribute('ChestLuckMultiplier',9);Data:SetPackPity(tp,4,4);flush()
 check(calls==before,'nothing changed (same values): no refresh')
 tp:SetAttribute('ChestLuckMultiplier',1);flush()
 -- 4. never held, still short after all of that
 check(toolC.ToolTip==shortC and toolC:GetAttribute('OddsTooltip155')==nil,'a never-held pack tool\'s tooltip stays the short one through every change above')
 -- 5. the boots luck: a held world pack's odds follow ChestLuckMultiplier
 local recW=Data:AddChest(tp,pack(NORMAL_KINDS[1]));local toolW=Chest._createPackTool(host,recW,bp);hold(toolW);toolW.Parent=bp
 local plain=toolW.ToolTip
 check(plain==expectTip(recW,false,false),'a held world pack (normal count 4: not lucky) shows its plain odds')
 tp:SetAttribute('ChestLuckMultiplier',1000);flush()
 check(toolW.ToolTip==expectTip(recW,false,false)and toolW.ToolTip~=plain,'ChestLuckMultiplier changes to x1000: the held world pack\'s odds are rebuilt for it')
 -- the Mech coat line: a bought pack only
 local recP=Data:AddChest(tp,pack(EVENT_KINDS[3]));recP.PaidRandom=true;local toolP=Chest._createPackTool(host,recP,bp);hold(toolP);toolP.Parent=bp
 check(toolP.ToolTip==expectTip(recP,false,true)and toolP.ToolTip:find(Mech.CoatLine(),1,true)and not toolA.ToolTip:find(Mech.CoatLine(),1,true),'the coat line is on a BOUGHT Mech pack (PaidRandom) and not on the free one')
 -- a bad record does not stop the others; a record that is gone is skipped
 local realTip=Chest._packTooltip;Chest._packTooltip=function(self,player,record)if record.Id==recA.Id then error('bad record')end;return realTip(self,player,record)end
 local stale=toolA.ToolTip;tp:SetAttribute('ChestLuckMultiplier',3);flush()
 check(toolA.ToolTip==stale and toolW.ToolTip==expectTip(recW,false,false)and toolP.ToolTip==expectTip(recP,false,true),'one record that cannot be built (A) keeps its old text and the other held packs are still rebuilt (x3)')
 Chest._packTooltip=realTip
 local ghost=Chest._createPackTool(host,recC,bp);ghost:SetAttribute('OddsTooltip155',true);ghost:SetAttribute('SeedInventoryId','gone-for-good');ghost.ToolTip='old'
 tp:SetAttribute('ChestLuckMultiplier',4);flush()
 check(ghost.ToolTip=='old'and toolA.ToolTip==expectTip(recA,false,false),'a tool whose record is gone is skipped (its text is left alone); the next refresh rebuilds A again (event count 4: no LUCKY)')
 Chest._refreshPackTooltips=realRefresh
end
E.finish('R155 pack pity')
