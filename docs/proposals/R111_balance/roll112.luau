-- Statistical tests of the staged roll in the REAL PackOdds112 / SeedPackRules (bundled by bundle.py).
local O=RS_MOD('PackOdds112')
local Rules=RS_MOD('SeedPackRules')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
function config.GetSeedById(id) for _,c in ipairs(config.SeedCatalogByStage) do for _,s in ipairs(c) do if s.Id==id then return s end end end end
math.randomseed(20260929)
local rnd=math.random
local function z(hits,n,p)return (hits-n*p)/math.sqrt(n*p*(1-p))end
local worstZ=0
local function report(label,hits,n,p)
 local zz=z(hits,n,p);worstZ=math.max(worstZ,math.abs(zz))
 print(string.format('%-58s %9d hits / %.0e  expected %11.1f  z=%+.2f',label,hits,n,n*p,zz))
end
-- 1. Several gate stages (gate temporarily 0.1): p=3e-5 needs 5 stages.
do local keep=O.Gate;O.Gate=.1
 local hits,n=0,2e7;for _=1,n do if O.Chance(3e-5,rnd)then hits+=1 end end
 report('Chance(3e-5), gate 0.1 (5 stages)',hits,n,3e-5)
 hits=0;for _=1,n do if O.Chance(.37,rnd)then hits+=1 end end
 report('Chance(0.37), gate 0.1 (no stage)',hits,n,.37)
 O.Gate=keep
end
-- 2. Real gate 1e-5 with a tiny probability (one stage): p = 4e-6.
do local hits,n=0,1e8;for _=1,n do if O.Chance(4e-6,rnd)then hits+=1 end end
 report('Chance(4e-6), real gate 1e-5 (1 stage)',hits,n,4e-6)
end
-- 3. RollTier with a tiny top tier through the real code (King 3e-6 is below the gate).
do local odds={King=3e-6,Cosmic=4e-5,Secret=2e-3,Mythic=.05,Rare=1-3e-6-4e-5-2e-3-.05}
 local count,n={},5e7
 for _=1,n do local t=O.RollTier(odds,rnd);count[t]=(count[t]or 0)+1 end
 for _,t in ipairs({'King','Cosmic','Secret','Mythic','Rare'})do report('RollTier synthetic '..t..' '..odds[t],count[t]or 0,n,odds[t])end
end
-- 4. Real tables through Rules.Roll (draw function), seed level, OddsVersion 112.
for _,case in ipairs({{7,'Pack06',5000000},{5,'Pack05',100000},{2,'Pack01',1},{3,'Pack04',2000},{1,'Pack02',50}})do
 local st,pk,L=case[1],case[2],case[3]
 local odds=Rules.SeedOdds(config,st,pk,L,112);local count,n={},2e6
 for _=1,n do local seed=Rules.Roll(config,st,rnd,L,pk,112);count[seed.Id]=(count[seed.Id]or 0)+1 end
 for id,pct in pairs(odds)do if pct>1e-4 then report(string.format('Roll %d %s x%g %s',st,pk,L,id),count[id]or 0,n,pct/100)end end
end
-- 5. Void pack 112 (Mech branch + direct) through Rules.Roll.
do local odds=Rules.SeedOdds(config,7,'EclipseReliquary',1,112);local count,n={},2e6
 for _=1,n do local seed=Rules.Roll(config,7,rnd,1,'EclipseReliquary',112);count[seed.Id]=(count[seed.Id]or 0)+1 end
 for id,pct in pairs(odds)do if pct>1e-3 then report('Void 112 '..id,count[id]or 0,n,pct/100)end end
end
print(string.format('worst |z| = %.2f',worstZ))
