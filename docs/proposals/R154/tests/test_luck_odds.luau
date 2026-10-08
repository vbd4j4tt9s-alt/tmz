--!nocheck
-- R154 on the Roblox mock with the REAL SeedPackRules / PackLuck154 / PackOdds / PlayerDataService / RarePackTests / SeedRarity153 / Config of this checkout (the R153 clover world):
--  1. the cap      - LuckCeiling = MaxLuck x the clover; a clover owner's luck is never capped below the clover's x2 (Thunder Boots x50M -> x100M, owner test boots too), without the
--                    pass it is as before; PackOdds112 / 137 take x100M; the King of a pack doubles from x50M to x100M; an open hands the roll x100M and the clover's x2 (passLuck)
--  2. fixed packs  - the Void / Verity / Mech packs: without the clover (or with boots only) byte-for-byte their old tables; with it, each tier above the pack's lowest x2^Power (King x2,
--                    Cosmic x2^.40, Secret x2^.28, Mythic x2^.16), the branches keep their size; junk / bigger pass luck; real rolls follow the tables (and the exact roll at the extremes);
--                    a real open of each by a clover owner and by a player without it
--  3. the 80% rule - every world pack x live odds version x luck (1, 10, 1e3, 1e6, 5e7, 1e8 and a dense sweep) x starter boost, the fixed packs x clover: no seed over 80%, the others at
--                    least 19% (+ the 1% upgrade), the upgrade is the next tier's seed, the table equals an INDEPENDENT re-implementation of the rule; banked versions untouched;
--                    rolls follow the shaped table, the exact roll still reaches a 1 in a trillion seed
--  4. rarepacks    - /test rarepacks <rarity>: a random real seed of that rarity from any biome (every one of them comes up), in its biome's pack, still a guaranteed TEST reveal
--  5. the display  - SeedRarity153 keeps the R153 number of every seed (the base-luck table before the rule), also where the rule changed the Common pack
-- Prints TABLE lines (before -> after) for docs/proposals/R154/luck_and_odds.md.
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local RS=E.RS;local Config=E.Config;local Data=E.Data
local Rules=W.module('SeedPackRules');local L=W.module('PackLuck154');local Balance=W.module('BalanceValues81')
local O137=W.module('PackOdds137');local O112=W.module('PackOdds112');local Mech=W.module('MechCatalog');local Verity=W.module('VerityCatalog')
local Odds=W.module('OddsText85');local Canon=W.module('SeedRarity153')
local boots=Config.ShopCatalog.Accessories
local function near(a,b,rel)rel=rel or 1e-9;return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=rel*math.max(1,math.abs(a),math.abs(b))end
local function sum(t)local s=0;for _,p in pairs(t)do s+=p end;return s end
local function rarity(id)return(Rules.GetRarity(id))end
local function rank(id)return O137.Rank[rarity(id)]or 0 end
local function name(id)local s=Config.GetSeedById(id);return s and(s.Name:gsub(' Seed$',''))or id end
local function same(a,b,rel)
 for id,p in pairs(a)do if not near(p,b[id]or 0,rel or 1e-12)then return false,id end end
 for id,p in pairs(b)do if not near(p,a[id]or 0,rel or 1e-12)then return false,id end end
 return true
end
local function top(t)local id,v=nil,-1;for k,p in pairs(t)do if p>v or(p==v and k<id)then id,v=k,p end end;return id,v end
local function tierSum(t)local out={};for id,p in pairs(t)do local r=rarity(id);out[r]=(out[r]or 0)+p end;return out end
local function show(t)
 local rows={};for id,p in pairs(t)do if p>0 then rows[#rows+1]={id,p}end end
 table.sort(rows,function(a,b)if a[2]~=b[2]then return a[2]>b[2]end;return a[1]<b[1]end)
 local out={};for _,r in ipairs(rows)do out[#out+1]=('%s %s (%s)'):format(name(r[1]),('%.4g%%'):format(r[2]),Odds.Format(r[2]))end
 return table.concat(out,' | ')
end
local function lcg(seed)local s=seed;return function()s=(s*1103515245+12345)%2147483648;return s/2147483648 end end
-- a good uniform for big samples (Luau's math.random, a PCG, seeded): the mock's LCG is too regular for the staged roll's tiny gates
local function uniform(seed)math.randomseed(seed);return function()return math.random()end end
local STAGES={1,6,2,3,4,5,7};local PACKS={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'}
local BIOME={[1]='Forest',[6]='Jungle',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[7]='Storm'}

-- 1. the cap ---------------------------------------------------------------------------------------------------------------------------------
local MAX=Balance.MaxLuck
check(MAX==5e7 and Balance.PassLuckCeiling==2 and Balance.LuckCeiling==1e8,'LuckCeiling = MaxLuck (50M, the boots\' cap) x the passes (2) = 100M ('..tostring(Balance.LuckCeiling)..')')
for _,O in ipairs({O137,O112})do
 check(O.Luck(1e8)==1e8 and O.Luck(2e8)==1e8 and O.Luck(5e7)==5e7 and O.Luck(0)==1 and O.Luck(0/0)==1 and O.Luck('x')==1,'PackOdds'..O.Version..'.Luck takes up to x100M (and clamps above / junk as before)')
end
do
 local ann=E.makePlayer(5401,'Ann');Data:AddBoost(ann,boots[5].Id)
 check(ann:GetAttribute('ChestLuckMultiplier')==MAX,'Thunder Boots without the clover: x50M, as before')
 ann:SetAttribute('CloverOwned',true);Data:RefreshBoostMultipliers(ann)
 check(ann:GetAttribute('ChestLuckMultiplier')==2*MAX,'Thunder Boots + the 4 Leaf Clover: x100M, the clover\'s x2 on top ('..tostring(ann:GetAttribute('ChestLuckMultiplier'))..')')
 check(Data:PassLuck(ann)==2,'PassLuck = 2 (the clover alone)')
 local bob=E.makePlayer(5402,'Bob');Data:AddBoost(bob,boots[5].Id,{TestGrant=true});bob:SetAttribute('CloverOwned',true);Data:RefreshBoostMultipliers(bob)
 check(bob:GetAttribute('ChestLuckMultiplier')==2*MAX and Data:HasTestLuck(bob),'owner test Thunder Boots + the clover: x100M, still test luck')
 for i=1,4 do local p=E.makePlayer(5410+i,'B'..i);Data:AddBoost(p,boots[i].Id);local was=p:GetAttribute('ChestLuckMultiplier');p:SetAttribute('CloverOwned',true);Data:RefreshBoostMultipliers(p)
  check(was==boots[i].LuckMultiplier and p:GetAttribute('ChestLuckMultiplier')==2*was,'boots '..i..': x'..was..' -> x'..(2*was)..' with the clover')end
 -- the King of a pack follows: Desert Common pack (King power 1)
 local function king(l)return Rules.SeedOdds(Config,2,'Pack01',l,149).SolarStarfruitSeed end
 check(near(king(1e8),2*king(5e7)),'Desert Common pack: Solar Starfruit (King) doubles from x50M to x100M ('..Odds.Format(king(5e7))..' -> '..Odds.Format(king(1e8))..')')
 check(near(Rules.SeedOdds(Config,2,'Pack01',1e8,112).SolarStarfruitSeed,2*Rules.SeedOdds(Config,2,'Pack01',5e7,112).SolarStarfruitSeed),'... a banked OddsVersion 112 pack too (the clover is luck, not a rule change)')
 -- an open hands the roll both lucks
 local seen={};local orig=Rules.Roll
 Rules.Roll=function(...)local a={...};seen[#seen+1]={Luck=a[4],Variant=a[5],Pass=a[8]};return orig(...)end
 local info;Data.OnPackOpened=function(_,_,i)info=i end
 local pack=Data:AddChest(ann,{Stage=2,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 local reward=Data:OpenSeedPack(ann,pack.Id,uniform(7))
 check(reward and reward.Kind=='Seed'and #seen==1 and seen[1].Luck==2*MAX and seen[1].Pass==2,'a clover owner\'s open: the roll gets luck x100M and passLuck 2 ('..tostring(seen[1]and seen[1].Luck)..', '..tostring(seen[1]and seen[1].Pass)..')')
 check(info and info.Luck==2*MAX and info.PassLuck==2,'... and the BEST PULL hook sees both (its odds include the clover)')
 local cy=E.makePlayer(5403,'Cy');local p2=Data:AddChest(cy,{Stage=8,BagVariant='MechLimited',PackSize=1,PackMutation='None'});Data:OpenSeedPack(cy,p2.Id,uniform(8))
 check(#seen==2 and seen[2].Pass==1 and seen[2].Variant=='MechLimited','no clover: passLuck 1 (a Mech pack opens exactly as before)')
 Rules.Roll=orig;Data.OnPackOpened=nil
end

-- 2. the fixed-odds packs --------------------------------------------------------------------------------------------------------------------
local FIXED={{Kind='Void',Stage=7,Variant='EclipseReliquary',Version=149},{Kind='Verity',Stage=7,Variant='VerityReliquary',Version=149},{Kind='Mech',Stage=8,Variant='MechLimited',Version=81}}
local P2={Legendary=2^.08,Mythic=2^.16,Secret=2^.28,Cosmic=2^.40,King=2}
for _,f in ipairs(FIXED)do
 local base=Rules.RawSeedOdds(Config,f.Stage,f.Variant,1,f.Version)
 local plain=Rules.SeedOdds(Config,f.Stage,f.Variant,1,f.Version)
 check(same(base,plain,0),f.Kind..' pack without the clover: exactly its old table')
 for _,l in ipairs({50,1e6,5e7,1e8})do check(same(base,Rules.SeedOdds(Config,f.Stage,f.Variant,l,f.Version),0),f.Kind..' pack: boots luck x'..l..' changes nothing (only the clover does)')end
 for _,junk in ipairs({1,0,-2,.5,0/0,math.huge,'2',true})do check(same(base,Rules.SeedOdds(Config,f.Stage,f.Variant,1,f.Version,nil,junk),0),f.Kind..' pack: pass luck '..tostring(junk)..' = none')end
 check(same(base,L.FixedOdds(f.Kind,Config,Rules,1),1e-12),f.Kind..': PackLuck154.FixedOdds at x1 rebuilds the pack\'s own table')
 local clover=Rules.SeedOdds(Config,f.Stage,f.Variant,1,f.Version,nil,2)
 check(near(sum(clover),100,1e-12),f.Kind..' with the clover: adds up to 100% ('..sum(clover)..')')
 check(same(clover,Rules.SeedOdds(Config,f.Stage,f.Variant,1,f.Version,nil,5),0),f.Kind..': pass luck above the ceiling = x2')
 local ids=0;for id,p in pairs(base)do ids+=1;check(clover[id]and clover[id]>0,f.Kind..': '..name(id)..' still drops')end
 check(E.count(clover)==ids,f.Kind..': the same seeds')
 print('TABLE '..f.Kind..' before: '..show(base))
 print('TABLE '..f.Kind..' clover: '..show(clover))
 -- the banked old Void (OddsVersion 81 / none) and other stages are not touched
end
do -- the exact numbers, tier by tier
 local m0=Rules.SeedOdds(Config,8,'MechLimited',1,81);local m=Rules.SeedOdds(Config,8,'MechLimited',1,81,nil,2)
 local t0,t=tierSum(m0),tierSum(m)
 check(near(t.King,2*t0.King)and near(t.Cosmic,t0.Cosmic*P2.Cosmic)and near(t.Secret,t0.Secret*P2.Secret)and near(t.Mythic,t0.Mythic*P2.Mythic),'Mech: King x2 (0.5% -> 1%), Cosmic x2^.40, Secret x2^.28, Mythic x2^.16 ('..('%.4g/%.4g/%.4g/%.4g'):format(t.King,t.Cosmic,t.Secret,t.Mythic)..')')
 check(near(t.Legendary,100-t.King-t.Cosmic-t.Secret-t.Mythic)and t.Legendary<t0.Legendary and t.Legendary>=.4*t0.Legendary,'Mech: Plasma Pepper (the lowest tier) gives the rest up: '..t0.Legendary..'% -> '..('%.4g'):format(t.Legendary)..'%')
 check(near(m.HoloMelonSeed/m.PrismLotusSeed,26/16),'Mech: Holo Melon : Prism Lotus stays 26 : 16')
 local v0=Rules.SeedOdds(Config,7,'EclipseReliquary',1,149);local v=Rules.SeedOdds(Config,7,'EclipseReliquary',1,149,nil,2)
 local mech0,mech=0,0;for _,s in ipairs(Mech.Seeds)do mech0+=v0[s.Id]or 0;mech+=v[s.Id]or 0 end
 check(near(mech0,.5)and near(mech,.5),'Void: the Mech roll stays 1/200 ('..mech..'%)')
 check(near(v.CrowncoreTreeSeed,2*v0.CrowncoreTreeSeed)and near(v.CrowncoreTreeSeed/.5,m.CrowncoreTreeSeed/100),'Void: its Mech roll is a Mech pack roll with the clover (Crowncore Tree 1/40K -> 1/20K)')
 local kings0,kings,cos0,cos=0,0,0,0
 for id,p in pairs(v0)do if not Mech.Is(id)then if rarity(id)=='King'then kings0+=p elseif rarity(id)=='Cosmic'then cos0+=p end end end
 for id,p in pairs(v)do if not Mech.Is(id)then if rarity(id)=='King'then kings+=p elseif rarity(id)=='Cosmic'then cos+=p end end end
 check(near(kings,2*kings0)and near(cos,cos0*P2.Cosmic),'Void: the Kings x2 (1/200M -> 1/100M a King), the Cosmics x2^.40 (5% -> '..('%.4g'):format(cos/.995)..'% of the direct roll)')
 check(near(v.PolarStarbloomSeed,v.OrbitLotusSeed)and near(v.StarfruitSeed,v.HollowGeodeSeed),'Void: seeds of a tier still split it evenly')
 local y0=Rules.SeedOdds(Config,7,'VerityReliquary',1,149);local y=Rules.SeedOdds(Config,7,'VerityReliquary',1,149,nil,2)
 check(near(y0[Verity.Id],1)and near(y[Verity.Id],2),'Verity: the Verity seed (its King) 1/100 -> 1/50')
 local ymech=0;for _,s in ipairs(Mech.Seeds)do ymech+=y[s.Id]or 0 end
 check(near(ymech,.98*.5)and y.CrowncoreTreeSeed==nil,'Verity: the Mech roll stays 1/200 of the rest, still without the Crowncore Tree')
 local ycos=0;for id,p in pairs(y)do if not Mech.Is(id)and rarity(id)=='Cosmic'then ycos+=p end end
 check(near(ycos,98*.995*.05*P2.Cosmic),'Verity: the Cosmics x2^.40 of the direct roll')
 -- real rolls follow the tables
 local function freq(stage,variant,version,pass,n,seed)
  local draw=uniform(seed);local c={}
  for _=1,n do local s=Rules.Roll(Config,stage,draw,1,variant,version,nil,pass);if s then c[s.Id]=(c[s.Id]or 0)+1 end end
  return c
 end
 local n=60000;local c=freq(8,'MechLimited',81,2,n,11)
 local ok=true;local worst=''
 for id,p in pairs(m)do local e=n*p/100;local sd=math.sqrt(e*(1-p/100));if math.abs((c[id]or 0)-e)>5*sd+2 then ok=false;worst=worst..name(id)..' '..(c[id]or 0)..' vs '..e..'; 'end end
 check(ok,'Mech with the clover: '..n..' real rolls follow the table (each seed within 5 sd) '..worst)
 local c0=freq(8,'MechLimited',81,1,n,11);check((c.CrowncoreTreeSeed or 0)>1.5*(c0.CrowncoreTreeSeed or 0),'... Crowncore Tree '..(c0.CrowncoreTreeSeed or 0)..' -> '..(c.CrowncoreTreeSeed or 0)..' of '..n)
 local function const(x)return function()return x end end
 check(Rules.Roll(Config,8,const(0),1,'MechLimited',81,nil,2).Id=='CrowncoreTreeSeed'and Rules.Roll(Config,8,const(.999999),1,'MechLimited',81,nil,2).Id=='PlasmaPepperSeed','Mech exact roll: draws of 0 give the rarest seed, draws near 1 the commonest')
 local vk=Rules.Roll(Config,7,const(0),1,'EclipseReliquary',149,nil,2);check(vk and rarity(vk.Id)=='King'and not Mech.Is(vk.Id),'Void exact roll reaches a 1-in-500M King with draws of 0 ('..tostring(vk and vk.Id)..')')
 local vy=Rules.Roll(Config,7,const(0),1,'VerityReliquary',149,nil,2);check(vy and vy.Id~=nil and rarity(vy.Id)=='King','Verity exact roll: the rarest is a King (the Verity seed)')
 local cv=freq(7,'VerityReliquary',149,2,n,12);local e=n*.02;check(math.abs((cv[Verity.Id]or 0)-e)<5*math.sqrt(e),'Verity with the clover: the Verity seed '..(cv[Verity.Id]or 0)..' of '..n..' (2%)')
 -- an open of each by a clover owner goes through the clover's table
 local dee=E.makePlayer(5404,'Dee');dee:SetAttribute('CloverOwned',true);Data:RefreshBoostMultipliers(dee)
 local got={}
 for _,f in ipairs(FIXED)do
  local rec=Data:AddChest(dee,{Stage=f.Stage,BagVariant=f.Variant,PackSize=1,PackMutation='None',OddsVersion=f.Kind~='Mech'and Rules.OddsVersion or nil})
  local r=Data:OpenSeedPack(dee,rec.Id,const(0))
  got[f.Kind]=r and r.SeedId
 end
 check(got.Mech=='CrowncoreTreeSeed'and rarity(got.Void or'')=='King'and got.Verity==Verity.Id,'a clover owner opens a Mech / Void / Verity pack through the clover\'s roll ('..tostring(got.Mech)..', '..tostring(got.Void)..', '..tostring(got.Verity)..')')
end

-- 3. the 80% rule ----------------------------------------------------------------------------------------------------------------------------
-- An independent re-implementation of the rule (from the R154 spec, not PackLuck154): returns the expected table, and the top / upgrade ids when it acts.
local function expected(raw)
 local total,n=0,0;for _,p in pairs(raw)do if p>0 then total+=p;n+=1 end end
 local t,tp=top(raw)
 if n<2 or tp/total<=.8+1e-9 then return raw end
 local tr=rank(t);local nextR,rarest=nil,-1
 for id,p in pairs(raw)do if p>0 then local r=rank(id);if r>tr and(not nextR or r<nextR)then nextR=r end;if r>rarest then rarest=r end end end
 local want=nextR or rarest;local ups={};for id,p in pairs(raw)do if p>0 and rank(id)==want then ups[#ups+1]=id end end
 local out={};for id,p in pairs(raw)do out[id]=p end
 local share=tp/total
 if #ups==1 and ups[1]==t then
  out[t]=.8*total;for id,p in pairs(raw)do if id~=t and p>0 then out[id]=p+(tp-.8*total)*p/(total-tp)end end
  return out,t,ups
 end
 local newTop=math.min(.8,share-.01)*total;local extra=math.max(0,share-.81)*total
 out[t]=newTop
 for id,p in pairs(raw)do if id~=t and p>0 then out[id]=p+extra*p/(total-tp)end end
 for _,id in ipairs(ups)do out[id]+=.01*total/#ups end
 return out,t,ups
end
local LUCKS={1,10,1e3,1e6,5e7,1e8};for k=1,32 do LUCKS[#LUCKS+1]=10^(k/4)end
local cases,acted,bad,badMsg=0,0,0,''
local function audit(label,raw,new)
 cases+=1
 local total=sum(new);local t,tp=top(new);local n=0;for _,p in pairs(new)do if p>0 then n+=1 end end
 local ok=near(total,100,1e-9)and n>=2 and tp/total<=.8+1e-12 and(total-tp)/total>=.2-1e-12
 local want,wt,ups=expected(raw)
 local eq=same(want,new,1e-11)
 if wt then
  acted+=1
  local rarer=true;for _,u in ipairs(ups)do if u~=wt and rank(u)<=rank(wt)then rarer=false end end
  local gain=0;for _,u in ipairs(ups)do gain+=new[u]-raw[u]end
  if not(#ups==1 and ups[1]==wt)then ok=ok and rarer and gain>=1-1e-9 end
 else ok=ok and same(raw,new,0)end
 if not(ok and eq)then bad+=1;if #badMsg<600 then badMsg=badMsg..label..(eq and''or' (differs from the independent rule)')..'; 'end end
end
for _,stage in ipairs(STAGES)do for _,v in ipairs(PACKS)do for _,ver in ipairs({149,'nil'})do for _,l in ipairs(LUCKS)do for _,b in ipairs({0,2})do
 local version=ver~='nil'and ver or nil;local boost=b==2 and 2 or nil
 audit(BIOME[stage]..' '..v..' v'..tostring(ver)..' L'..l..' B'..b,Rules.RawSeedOdds(Config,stage,v,l,version,boost),Rules.SeedOdds(Config,stage,v,l,version,boost))
end end end end end
for _,f in ipairs(FIXED)do for _,pass in ipairs({1,2})do
 local raw=pass==2 and L.FixedOdds(f.Kind,Config,Rules,2)or Rules.RawSeedOdds(Config,f.Stage,f.Variant,1,f.Version)
 audit(f.Kind..' clover '..pass,raw,Rules.SeedOdds(Config,f.Stage,f.Variant,1,f.Version,nil,pass))
end end
check(bad==0,'the 80% rule on '..cases..' live tables (7 biomes x 6 packs x OddsVersion 149 / none x '..#LUCKS..' lucks x starter boost, + Void / Verity / Mech x clover): no seed over 80%, the others >= 19% + the 1% upgrade (rarer than the top), equal to an independent re-implementation ('..acted..' tables changed) '..badMsg)
check(acted>0,'(the rule acted somewhere: '..acted..' tables)')
-- the R154 sweep the owner asked for, by name: every pack x live version x luck 1, 10, 1e3, 1e6, 5e7, 1e8: top <= 80
do
 local worst,at=0,''
 for _,stage in ipairs(STAGES)do for _,v in ipairs(PACKS)do for _,l in ipairs({1,10,1e3,1e6,5e7,1e8})do
  local t=Rules.SeedOdds(Config,stage,v,l,149);local _,p=top(t);if p>worst then worst,at=p,BIOME[stage]..' '..v..' L'..l end
 end end end
 check(worst<=80+1e-9,'every biome pack at luck 1 / 10 / 1e3 / 1e6 / 5e7 / 1e8: the biggest share of one seed is '..('%.4g'):format(worst)..'% ('..at..')')
end
-- banked packs: untouched (the R148 "no windfall")
do
 local diff=0
 for _,stage in ipairs(STAGES)do for _,v in ipairs(PACKS)do for _,ver in ipairs({0,81,112,137})do for _,l in ipairs({1,1e6,5e7})do
  if not same(Rules.RawSeedOdds(Config,stage,v,l,ver),Rules.SeedOdds(Config,stage,v,l,ver),0)then diff+=1 end
 end end end end
 check(diff==0,'banked world packs (OddsVersion 0 / 81 / 112 / 137): exactly their old tables at every luck ('..diff..' differ)')
 check(same(Rules.RawSeedOdds(Config,7,'EclipseReliquary',1,81),Rules.SeedOdds(Config,7,'EclipseReliquary',1,81,nil,2),0),'a Void pack banked before R112 keeps its old table, clover or not')
 local before=Rules.RawSeedOdds(Config,2,'Pack01',1,137);local _,tp=top(before)
 check(tp>90,'(a banked Desert Common pack is still '..('%.3g'):format(tp)..'% Prickly Pear: the rule does not reach it)')
end
-- rolls follow the shaped table
do
 local n=60000
 for _,case in ipairs({{2,'Pack01',1},{7,'Pack06',1},{3,'Pack04',1}})do
  local stage,v,l=case[1],case[2],case[3];local odds=Rules.SeedOdds(Config,stage,v,l,149);local draw=uniform(stage*100+l);local c={}
  for _=1,n do local s=Rules.Roll(Config,stage,draw,l,v,149);if s then c[s.Id]=(c[s.Id]or 0)+1 end end
  local ok,worst=true,''
  for id,p in pairs(odds)do local e=n*p/100;local sd=math.sqrt(e*(1-p/100));if math.abs((c[id]or 0)-e)>5*sd+2 then ok=false;worst=worst..name(id)..' '..(c[id]or 0)..' vs '..('%.1f'):format(e)..'; 'end end
  local t=top(odds)
  check(ok,BIOME[stage]..' '..v..' L'..l..': '..n..' real rolls follow the 80% table ('..name(t)..' '..(c[t]or 0)..', '..('%.1f'):format(100*(c[t]or 0)/n)..'%) '..worst)
 end
 local function const(x)return function()return x end end
 local k=Rules.Roll(Config,2,const(0),1,'Pack01',149);check(k and k.Id=='SolarStarfruitSeed','the shaped roll is exact: draws of 0 still reach the 1-in-726B King (Solar Starfruit)')
 local c=Rules.Roll(Config,2,const(.9999999),1,'Pack01',149);check(c and c.Id=='CactusSeed','... and draws near 1 the 80% seed (Prickly Pear)')
 check(Rules.Roll(Config,2,.5,1,'Pack01',149)==nil,'(a live pack still needs a draw function, as in R137)')
end
-- the before -> after tables for the note
for _,case in ipairs({{1,'Pack06'},{2,'Pack01'},{3,'Pack01'},{3,'Pack04'},{3,'Pack06'},{4,'Pack06'},{5,'Pack06'},{7,'Pack06'}})do
 for _,l in ipairs({1,1e6,5e7,1e8})do
  local raw,new=Rules.RawSeedOdds(Config,case[1],case[2],l,149),Rules.SeedOdds(Config,case[1],case[2],l,149)
  print(('TABLE %s %s L%g before: %s'):format(BIOME[case[1]],case[2],l,show(raw)))
  print(('TABLE %s %s L%g after: %s'):format(BIOME[case[1]],case[2],l,show(new)))
 end
end
-- the Forest Mythic pack the owner looked at: two seeds at every luck, never over 80%
for _,l in ipairs(LUCKS)do
 local t=Rules.SeedOdds(Config,1,'Pack06',l,149);local _,p=top(t)
 if p>80 or E.count(t)<2 then check(false,'Forest Mythic pack at x'..l..': '..show(t))end
end
check(true,'the Forest Mythic pack lists Sunflower and Elderbloom at every luck, the bigger at most 73.3%')

-- 4. /test rarepacks <rarity> ---------------------------------------------------------------------------------------------------------------
do
 local RPT=E.server('RarePackTests')
 local u=uniform(99);RPT.Random={NextInteger=function(_,a,b)return a+math.floor(u()*(b-a+1))end}
 local want={Legendary=0,Mythic=0,Secret=0,Cosmic=0,King=0}
 for _,stage in ipairs(STAGES)do for _,seed in ipairs(Rules.ObtainablePool(Config,stage))do local r=rarity(seed.Id);if want[r]then want[r]+=1 end end end
 for r,n in pairs(want)do
  local list=RPT.Candidates(Config,r)
  local okList=#list==n and n>0
  for _,c in ipairs(list)do if rarity(c.Spec.id)~=r or Rules.IsRetired(c.Spec.id)or Mech.Is(c.Spec.id)or Verity.Is(c.Spec.id)or c.Stage<1 or c.Stage>7 or Rules.ObtainableStage(c.Spec.id)~=c.Stage then okList=false end end
  check(okList,r..': '..#list..' candidates = every live biome seed of that rarity ('..n..'), none retired / Mech / Verity, each with its biome')
 end
 local owner=E.makePlayer(5405,'Owner')
 local function grant(sel)
  local records=Data:GetChestRecords(owner);table.clear(records)
  local ok,msg=RPT.Grant(Data,owner,sel,owner);return ok,msg,Data:GetChestRecords(owner)
 end
 for _,r in ipairs({'Mythic','Legendary','Secret'})do
  local seen,count,okAll={},0,true
  for _=1,120 do
   local ok,_,records=grant(r:lower())
   local rec=records[1]
   if not ok or #records~=1 or rarity(rec.SeedId)~=r or rec.Rarity~=r or rec.BagVariant~='Pack06'or rec.TestGrant~=true or rec.Stage~=Rules.ObtainableStage(rec.SeedId)or RPT.Expected(Data,owner,rec.Id)~=rec.SeedId then okAll=false end
   if rec then if not seen[rec.SeedId]then count+=1 end;seen[rec.SeedId]=(seen[rec.SeedId]or 0)+1 end
  end
  check(okAll,'rarepacks '..r:lower()..': one TEST Pack06 in the seed\'s own biome, a guaranteed reveal of a '..r..' seed')
  check(count==want[r],'rarepacks '..r:lower()..' x120: every one of the '..want[r]..' '..r..' seeds comes up ('..count..')')
  if r=='Mythic'then check((seen.ElderbloomSeed or 0)<60,'... Elderbloom is not always the one ('..(seen.ElderbloomSeed or 0)..' of 120)')end
 end
 local ok,_,records=grant('all')
 local rs={};for _,rec in ipairs(records)do rs[#rs+1]=rec.Rarity end
 check(ok and table.concat(rs,',')=='Legendary,Mythic,Secret,Cosmic,King','rarepacks (all): five TEST packs, Legendary to King ('..table.concat(rs,',')..')')
 local opened=Data:OpenSeedPack(owner,records[2].Id,uniform(5))
 check(opened and opened.SeedId==records[2].SeedId and opened.TestGrant==true,'opening one reveals exactly its seed (a TEST seed)')
 local okM,_,mech=grant('mech');check(okM and #mech==6 and mech[1].SeedId=='PlasmaPepperSeed'and mech[1].BagVariant=='MechLimited','rarepacks mech: the six Mech packs, as before')
 local okV,_,ver=grant('verity');check(okV and #ver==1 and ver[1].SeedId==Verity.Id and ver[1].Stage==7,'rarepacks verity: the Verity pack, as before')
 local okR,_,ros=grant('roster');check(okR and #ros==4 and ros[1].SeedId=='FirePepperSeed','rarepacks roster: the four roster seeds, as before')
 table.clear(Data:GetChestRecords(owner))
end

-- 5. the display -----------------------------------------------------------------------------------------------------------------------------
do
 local fixedText={CactusSeed='1/1',DesertAloeSeed='1/8',SandFruitSeed='1/90',DatePalmSeed='1/600',StarfruitSeed='1/10K',MirageFigSeed='1/1M',SolarStarfruitSeed='1/1T',
  SnowdropSeed='1/1',IceberrySeed='1/8',WinterPineSeed='1/105',SilentFrostbellSeed='1/10K',PolarStarbloomSeed='1/1M',WinterCrownwoodSeed='1/1T',
  ElderbloomSeed='1/400',SunflowerBloomSeed='1/60',VoltOrchidSeed='1/180',PulsarStarfruitSeed='1/1T',[Verity.Id]='1/100',CrowncoreTreeSeed='1/200',PlasmaPepperSeed='1/2'}
 for id,text in pairs(fixedText)do check(Canon.Text(id)==text,'the display keeps '..name(id)..' at '..text..' ('..Canon.Text(id)..')')end
 local all=Canon.All();local okAll=#all==54
 for _,r in ipairs(all)do
  local raw=Rules.RawSeedOdds(Config,r.Stage,r.Variant,1,Rules.OddsVersion)[r.Id]
  if not near(r.Percent,raw,1e-12)then okAll=false end
 end
 check(okAll,'all 54 seeds: the display = the home pack\'s base-luck table before the 80% rule (no clover)')
 local shaped=Rules.SeedOdds(Config,2,'Pack01',1,149)
 check(Odds.Format(shaped.DesertAloeSeed)=='1/5'and Canon.Text('DesertAloeSeed')=='1/8','(where the rule acts the pack differs: the Desert Common pack gives Aloe 1/5 now, the Index keeps its 1/8)')
end
E.finish('R154 luck and odds')
