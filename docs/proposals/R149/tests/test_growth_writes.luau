--!nocheck
-- R149 growth style: #1 (write only what moved) and the exclusions, on the Roblox mock with the REAL PlantGrowth, proved against the BASE PlantGrowth
-- (PlantGrowthBase, the commit before the change; run_growth.sh):
--  1. Lantern Fern and Amethyst Grape (and their regrowing fruit) are drawn identically to the base at every growth step the new module writes
--     (a hidden part is equal whatever else it holds), and between writes nothing is written: the picture only lags by less than 1/600 of the growth;
--  2. the write counts: property writes a second per growing plant before and after for every plant (the proposal measured ~18,600 on average and ~99,000
--     for the Amethyst Grape), only the properties that changed are written, no write and no allocation when nothing moved;
--  3. a regrowing fruit rewrites only its own parts; a plant that is fully grown but for one fruit costs next to nothing.
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local G,Base,Catalog,Rules=C.Growth,C.Base,C.Catalog,C.Rules
local ids=C.ids()
local function destroy(...)for _,m in ipairs({...})do m:Destroy()end end
-- 1. Lantern Fern and Amethyst Grape: today's picture at every step -------------------------------------------------------------------------------------
do
 local rewrites,skips,compared,regrowCompared=0,0,0,0
 local function ordinals(model)local o={};local i=0;for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then i+=1;o[p]=i end end;return o end
 local function pick(snap,list)local out={};for _,i in ipairs(list)do out[#out+1]=snap[i]end;return out end
 local function walk(label,model,state,crop,baseModel,baseState,times)
  local lastB,lastF
  local ord=ordinals(model)
  for i,now in ipairs(times)do
   local before=G.Stats.Rewrites
   local counts=C.Count(function()G.Apply(state,crop,now)end)
   Base.Apply(baseState,crop,now)
   local b,f=G.Progress(crop,state.Def,now)
   if G.Stats.Rewrites>before then
    rewrites+=1;compared+=1
    -- the whole plant when its growth moved; otherwise the fruit that moved (and the seedling and buds, which follow the clock / their fruit)
    local a,z=C.snapshot(model),C.snapshot(baseModel)
    if state.WBody~=b then
     local list={};for _,r in ipairs(state.Parts)do if r.Fruit and state.Dirty[r.Gi]then list[#list+1]=ord[r.Part]end end
     list[#list+1]=ord[state.Seed];for _,p in ipairs(state.Sprout)do list[#list+1]=ord[p]end
     for index,bud in pairs(state.Buds)do if state.Dirty[index]then list[#list+1]=ord[bud.Part];list[#list+1]=ord[bud.Stem]end end
     a,z=pick(a,list),pick(z,list)
    end
    local same,why=C.sameParts(z,a)
    if not same then check(false,('%s at step %d (t = %.2f): drawn differently from today: %s'):format(label,i,now,tostring(why)));return false end
    lastB,lastF=b,f
   else
    skips+=1
    if(counts.Total or 0)~=0 then check(false,('%s at step %d: nothing moved but %d writes happened'):format(label,i,counts.Total));return false end
    if lastB and(math.abs(b-lastB)*G.Tuning.Steps>=1.0001 and math.abs(f-lastF)*G.Tuning.Steps>=1.0001)then check(false,label..': skipped although growth moved by 1/600');return false end
   end
  end
  return true
 end
 for _,id in ipairs({'LanternFernSeed','AmethystSeed'})do
  local d=Catalog[id]
  for _,coat in ipairs({'None','Gold'})do
   local crop=C.crop(id,{Mutation=coat})
   local mb,sb=C.grow(Base,id,crop);local mn,sn=C.grow(G,id,crop)
   local times={};local n=id=='AmethystSeed'and 500 or 900
   for i=0,n do times[#times+1]=d.Seconds*1.04*i/n end
   check(walk(id..' '..coat..' (growing)',mn,sn,crop,mb,sb,times),id..' '..coat..': every step of the growth is drawn as today')
   destroy(mb,mn)
   if coat=='None'then
    for index=1,d.FruitCount do
     local rc=C.crop(id,{HarvestCycle=1});rc.FruitStates={}
     for i=1,d.FruitCount do rc.FruitStates[tostring(i)]={ReadyAt=d.Seconds+(d.RegrowSeconds or d.Seconds)+i*20,Cycle=1,Duration=d.RegrowSeconds or d.Seconds}end
     local ready=rc.FruitStates[tostring(index)].ReadyAt;local dur=rc.FruitStates[tostring(index)].Duration
     local cb,cbs=C.growFruit(Base,id,rc,index);local cn,cns=C.growFruit(G,id,rc,index)
     local t2={};for i=0,300 do t2[#t2+1]=ready-dur*1.02+dur*1.04*i/300 end
     local before=compared
     check(walk(id..' fruit '..index..' (regrowing)',cn,cns,rc,cb,cbs,t2),id..' regrowing fruit '..index..': every step is drawn as today')
     regrowCompared+=compared-before
     destroy(cb,cn)
    end
   end
  end
 end
 check(compared>600 and skips>600,('Lantern Fern and Amethyst Grape: %d rewrites compared with the base at the same time (all identical, %d of them of regrowing fruit), %d steps between them wrote nothing'):format(compared,regrowCompared,skips))
 print(('FROZEN compared=%d regrow=%d skipped=%d'):format(compared,regrowCompared,skips))
end
-- 2. #1 write counts ---------------------------------------------------------------------------------------------------------------------------------
do
 local sumB,sumN,count,worst,best=0,0,0,math.huge,0
 local rows={}
 for _,id in ipairs(ids)do
  local d=Catalog[id]
  if not d.Mech and not d.Verity then
   local crop=C.crop(id)
   local mb,sb=C.grow(Base,id,crop);local mn,sn=C.grow(G,id,crop)
   local t0=d.Seconds*.5
   Base.Apply(sb,crop,t0);G.Apply(sn,crop,t0) -- the first pose of a plant writes everything once
   local cb=C.Count(function()for i=1,100 do Base.Apply(sb,crop,t0+i/20)end end) -- 5 s of the 20 Hz step
   local cn=C.Count(function()for i=1,100 do G.Apply(sn,crop,t0+i/20)end end)
   local b,n=(cb.Total or 0)/5,(cn.Total or 0)/5;sumB+=b;sumN+=n;count+=1;local ratio=b/math.max(1,n);worst=math.min(worst,ratio);best=math.max(best,ratio)
   rows[id]={Parts=#sn.Parts,Base=b,New=n,Seconds=d.Seconds}
   if d.Seconds>=600 then check(ratio>=20,('%s (%ds): %.0f -> %.0f writes a second (x%.0f)'):format(id,d.Seconds,b,n,ratio))else check(ratio>=5,('%s (%ds): %.0f -> %.0f writes a second (x%.1f)'):format(id,d.Seconds,b,n,ratio))end
   -- only what changed: no colour / material / transparency rewrite per step on a plant that merely grows
   check((cn.Transparency or 0)+(cn.Material or 0)+(cn.CanQuery or 0)+(cn.CanCollide or 0)<=(cn.Size or 0)+2,id..': transparency / material / query are written only for a part that changed ('..(cn.Transparency or 0)..' / '..(cn.Material or 0)..' / '..(cn.CanQuery or 0)..' against '..(cn.Size or 0)..' sizes)')
   mb:Destroy();mn:Destroy()
  end
 end
 check(sumB/count>=15000 and sumB/count<=22000,('base: %.0f property writes a second per growing plant on average (the proposal measured ~18,600)'):format(sumB/count))
 check(sumN/count<=sumB/count/20,('new: %.0f a second on average: x%.0f fewer'):format(sumN/count,sumB/sumN))
 check(rows.AmethystSeed.Base>90000 and rows.AmethystSeed.New<=rows.AmethystSeed.Base/100,('Amethyst Grape: %.0f -> %.0f writes a second (the proposal: ~99,000)'):format(rows.AmethystSeed.Base,rows.AmethystSeed.New))
 print(('WRITES plants=%d average base=%.0f new=%.0f worst x%.1f best x%.0f'):format(count,sumB/count,sumN/count,worst,best))
 for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','AshRoseSeed','LanternFernSeed','AmethystSeed'})do local r=rows[id];print(('WRITES %-18s parts=%3d seconds=%5d base=%6.0f new=%5.0f x%.0f'):format(id,r.Parts,r.Seconds,r.Base,r.New,r.Base/math.max(1,r.New)))end
 -- the same call twice: nothing is written, nothing is allocated
 local id='SunflowerSeed';local crop=C.crop(id);local m,st=C.grow(G,id,crop);local now=Catalog[id].Seconds*.4
 G.Apply(st,crop,now)
 local c0=C.Count(function()for _=1,50 do G.Apply(st,crop,now)end end)
 check((c0.Total or 0)==0,'the same moment asked again: no write at all')
 local c1=C.Count(function()for i=1,50 do G.Apply(st,crop,now+i*1e-6)end end)
 check((c1.Total or 0)==0,'a moment less than 1/600 of the growth later: no write at all')
 collectgarbage();local before=collectgarbage('count')
 for i=1,20000 do G.Apply(st,crop,now+(i%7)*1e-6)end
 local grown=collectgarbage('count')-before
 check(grown<8,('skipping a refresh allocates nothing (%.1f KB over 20000 calls)'):format(grown))
 m:Destroy()
end
-- 3. a regrowing fruit costs only its own parts ----------------------------------------------------------------------------------------------------
do
 local id='AppleSeed';local d=Catalog[id]
 local rc=C.crop(id,{HarvestCycle=1});rc.FruitStates={}
 for i=1,d.FruitCount do rc.FruitStates[tostring(i)]={ReadyAt=d.Seconds+(d.RegrowSeconds or d.Seconds)+i*50,Cycle=1,Duration=d.RegrowSeconds or d.Seconds}end
 local ready=rc.FruitStates['1'].ReadyAt;local dur=rc.FruitStates['1'].Duration
 local cb,cbs=C.growFruit(Base,id,rc,1);local cn,cns=C.growFruit(G,id,rc,1)
 local t0=ready-dur*.5
 local b=C.Count(function()for i=0,99 do Base.Apply(cbs,rc,t0+i/20)end end);local n=C.Count(function()for i=0,99 do G.Apply(cns,rc,t0+i/20)end end)
 check(#cns.Parts<=#cbs.Parts and n.Total<=b.Total/4,('a regrowing apple: %d -> %d writes in 5 s (%d parts)'):format(b.Total,n.Total,#cns.Parts))
 destroy(cb,cn)
end
C.done('growth writes')
