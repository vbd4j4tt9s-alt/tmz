--!nocheck
-- R149 growth style, phase 1 (docs/proposals/R149/growth_style.md, items #1 - #6) on the Roblox mock with the REAL PlantGrowth / PlantVisuals / PlantCatalog /
-- PlantRules of this checkout, proved against the BASE PlantGrowth (the commit before the change, bundled as PlantGrowthBase; run_growth.sh):
--  1. timing and readiness are untouched: Progress / Timer give the base's numbers for every plant;
--  2. the curves: #4 size table (5 / 13 / 35 / 66 / 89 % against today's 1 / 4 / 20 / 56 / 87 %), #6 fruit swell (plump +5 %, exactly 1 at ripe), the ripening
--     colour path (bright middle, exact ends, pale green start), the MeshPart tint path;
--  3. the END STATE does not change: after Visuals.EndGrowth's final pose every part of every plant (and every regrowing fruit) is byte for byte what the
--     base module leaves, plain / Gold / Diamond coats, after the same intermediate steps;
--  4. Lantern Fern and Amethyst Grape (and their regrowing fruit) are drawn identically to the base at every growth step the new module writes, and between
--     writes nothing is written (the picture only lags by less than 1/600);
--  5. #1 write throttling: no write when nothing moved; a rewrite only per 1/600 of growth and only the properties that changed (counts before / after
--     for every plant: the proposal measured ~18,600 property writes a second per growing plant, 99,000 for the Amethyst Grape); no allocation when skipping;
--  6. #3 sprout pop timing, #5 solid leaves that grow out of the stem, #6 fruit colours / material at the ripe moment / Gold and Diamond fruit unchanged,
--     #2 Place (the pose a swaying plant is drawn at) and the registry (no leak after the end of a growth).
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local G,Base,Catalog,Rules=C.Growth,C.Base,C.Catalog,C.Rules;local T=G.Tuning
local function ease(a,b,x)local t=math.clamp((x-a)/math.max(.001,b-a),0,1);return t*t*(3-2*t)end
local ids=C.ids()
local function visible(p)return p.Transparency<1 end
local function label(id)return tostring(Catalog[id].Name or id)end
-- 1. timing and readiness -------------------------------------------------------------------------------------------------------------------------
do
 local n,bad=0,0
 for _,id in ipairs(ids)do
  local d=Catalog[id]
  for _,cy in ipairs({0,2})do
   local crop=C.crop(id,{HarvestCycle=cy})
   if cy>0 then crop.FruitStates={};for i=1,d.FruitCount do crop.FruitStates[tostring(i)]={ReadyAt=d.Seconds*1.4+i*30,Cycle=cy,Duration=d.RegrowSeconds or d.Seconds}end end
   for _,f in ipairs({0,.02,.1,.25,.5,.75,.95,1,1.2,1.5})do
    local now=d.Seconds*f
    for i=1,d.FruitCount do
     local b1,f1=G.Progress(crop,d,now,i);local b2,f2=Base.Progress(crop,d,now,i);n+=1
     if b1~=b2 or f1~=f2 then bad+=1 end
    end
    local t1,p1=G.Timer(crop,d,now);local t2,p2=Base.Timer(crop,d,now);n+=1
    if t1~=t2 or p1~=p2 then bad+=1 end
   end
  end
 end
 check(bad==0 and n>4000,('Progress and Timer: %d samples over %d plants (growing, ripe, regrowing) are the base\'s numbers (%d differ)'):format(n,#ids,bad))
end
-- 2. curves ----------------------------------------------------------------------------------------------------------------------------------------
local function hsv(c)return G.ToHSV(c)end
do
 -- #4: the size table of the proposal, and it never lags today's curve
 local want={[.05]=.05,[.10]=.13,[.25]=.35,[.50]=.66,[.75]=.89}
 for b,w in pairs(want)do check(near(G.Shape(b),w,.006),('Shape(%.2f) = %.3f (proposal %.2f)'):format(b,G.Shape(b),w))end
 check(G.Shape(0)==0 and G.Shape(-1)==0 and G.Shape(1)==1 and G.Shape(2)==1 and G.Shape(.02)==0,'Shape: 0 at the start (and up to 2 %), exactly 1 when grown')
 local last,mono,faster=0,true,true
 for i=0,1000 do
  local b=i/1000;local s=G.Shape(b);if s<last-1e-12 then mono=false end;last=s
  local today=ease(.025,1,b)^.8;if b>.02 and b<=.80 and s<today-1e-9 then faster=false end
 end
 check(mono,'Shape never shrinks as growth goes on');check(faster,'Shape is at least as big as today\'s curve (the .8 power) from 2 % to 80 % of the growth: a fast start, the same finish')
 check(G.Shape(.25)>=.34 and ease(.025,1,.25)^.8<.21,'35 % size at 25 % growth (today about 20 %)')
 -- #6 swell
 check(G.Swell(0)==0 and G.Swell(.05)==0 and near(G.Swell(.1),0,1e-12),'Swell: nothing before 10 % of the fruit\'s growth')
 check(G.Swell(1)==1 and G.Swell(2)==1,'Swell: exactly 1 when ripe (the ripe size is the old one)')
 local peak,at=0,0;for i=0,1000 do local s=G.Swell(i/1000);if s>peak then peak=s;at=i/1000 end end
 check(near(peak,1.05,.003)and at>=.85 and at<=.95,('Swell plumps %.1f %% at %.0f %% and settles'):format((peak-1)*100,at*100))
 local up=true;local prev=0;for i=0,900 do local s=G.Swell(i/1000);if s<prev-1e-12 then up=false end;prev=s end
 check(up,'Swell grows steadily to the plump');local down=true;prev=G.Swell(.9);for i=900,1000 do local s=G.Swell(i/1000);if s>prev+1e-12 then down=false end;prev=s end
 check(down,'... and settles back to 1 without a second bump')
 -- #6 colour path
 local fruit={{200,40,40},{230,120,30},{255,190,40},{90,30,120},{250,250,250},{40,40,40},{120,200,90},{232,172,57}}
 local muddy=0
 for _,k in ipairs(fruit)do
  local c=R.Color3.fromRGB(k[1],k[2],k[3]);local u=G.Unripe(c);local h,s,v=hsv(u)
  check(G.Ripen(c,1)==c and G.Ripen(c,0)==u and G.Ripen(c,2)==c and G.Ripen(c,-1)==u,('Ripen(%d,%d,%d): exact ends'):format(k[1],k[2],k[3]))
  check(near(h,T.UnripeHue,.002)and s>=.27 and s<=.56 and v>=.39 and v<=.83,('Unripe(%d,%d,%d) is a pale green (hue %.0f, s %.2f, v %.2f)'):format(k[1],k[2],k[3],h*360,s,v))
  local _,s1,v1=hsv(c);local _,s0,v0=hsv(u)
  for i=1,19 do
   local m=G.Ripen(c,i/20);local _,sm,vm=hsv(m)
   if vm<math.min(v0,v1)-1e-6 then muddy+=1 end
   if s1>=.08 and sm<math.min(s0,s1)-1e-6 then muddy+=1 end
  end
 end
 check(muddy==0,'Ripen: no step on any path is darker or greyer than both ends')
 -- the red fruit's middle: today green -> red blends through olive / brown
 local red=R.Color3.fromRGB(200,40,40);local green=R.Color3.fromRGB(83,157,64)
 local oldMid=green:Lerp(red,.5);local newMid=G.Ripen(red,.5)
 local _,so,vo=hsv(oldMid);local hn,sn,vn=hsv(newMid)
 check(vn>vo+.1 and sn>so,('red fruit: the middle colour is brighter and richer than today\'s olive-brown (v %.2f against %.2f, s %.2f against %.2f)'):format(vn,vo,sn,so))
 check(hn>.04 and hn<.2,('... and passes through yellow-orange (hue %.0f)'):format(hn*360))
end
-- A model of `id` with the given growth module; returns model, state.
local function mk(Growth,id,crop)return C.grow(Growth,id,crop)end
local function destroy(...)for _,m in ipairs({...})do m:Destroy()end end
-- 3. the end state does not change ------------------------------------------------------------------------------------------------------------------
do
 local plantsChecked,partsChecked,regrow,mismatch=0,0,0,0
 local steps={0,.04,.1,.3,.5,.8,.97}
 for _,id in ipairs(ids)do
  local d=Catalog[id]
  for _,coat in ipairs({'None','Gold','Diamond'})do
   local crop=C.crop(id,{Mutation=coat})
   local mb,sb=mk(Base,id,crop);local mn,sn=mk(G,id,crop)
   local ok,err=pcall(function()
    for _,f in ipairs(steps)do Base.Apply(sb,crop,d.Seconds*f);G.Apply(sn,crop,d.Seconds*f)end
    C.finish(Base,sb,crop,d.Seconds);C.finish(G,sn,crop,d.Seconds)
   end)
   if not ok then check(false,id..' '..coat..': '..tostring(err))
   else
    local a,b=C.snapshot(mb),C.snapshot(mn);local same,why=C.sameParts(a,b);plantsChecked+=1;partsChecked+=#a
    if not same then mismatch+=1;check(false,('%s (%s): ripe look differs from the base: %s'):format(id,coat,tostring(why)))end
   end
   destroy(mb,mn)
   -- a regrowing fruit (the model syncFruit builds for it): the same, for every fruit slot
   if d.Mode~='whole'and coat=='None'then
    for index=1,d.FruitCount do
     local rc=C.crop(id,{HarvestCycle=1});rc.FruitStates={}
     for i=1,d.FruitCount do rc.FruitStates[tostring(i)]={ReadyAt=d.Seconds+(d.RegrowSeconds or d.Seconds)+i*40,Cycle=1,Duration=d.RegrowSeconds or d.Seconds}end
     local ready=rc.FruitStates[tostring(index)].ReadyAt;local dur=rc.FruitStates[tostring(index)].Duration
     local cb,cbs=C.growFruit(Base,id,rc,index);local cn,cns=C.growFruit(G,id,rc,index)
     local ok2,err2=pcall(function()
      for _,f in ipairs({.0,.1,.3,.6,.9,.99})do local now=ready-dur+dur*f;Base.Apply(cbs,rc,now);G.Apply(cns,rc,now)end
      C.finish(Base,cbs,rc,ready);C.finish(G,cns,rc,ready)
     end)
     if not ok2 then check(false,id..' regrow '..index..': '..tostring(err2))
     else
      local same,why=C.sameParts(C.snapshot(cb),C.snapshot(cn));regrow+=1
      if not same then mismatch+=1;check(false,('%s fruit %d: regrown fruit differs from the base: %s'):format(id,index,tostring(why)))end
     end
     destroy(cb,cn)
    end
   end
  end
 end
 check(mismatch==0,('the ripe look is byte for byte the base\'s: %d plants x 3 coats (%d parts) and %d regrown fruit, %d differ'):format(plantsChecked/3,partsChecked,regrow,mismatch))
end
C.done('growth curves')
