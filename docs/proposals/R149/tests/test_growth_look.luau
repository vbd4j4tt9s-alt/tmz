--!nocheck
-- R149 growth style: the look of phase 1 (#2 Place, #3 sprout pop, #5 solid leaves, #6 fruit colours / swell / material) on the Roblox mock with the REAL
-- PlantGrowth, PlantVisuals, PlantCatalog and PlantRules of this checkout, against the BASE PlantGrowth (PlantGrowthBase; run_growth.sh):
--  1. #3 sprout: nothing but the seed under the dirt pile; the seedling rises at the pile's sink beat (PlantedAt + 2.9 s, or the beat PlantingEffects
--     reports), opens its two leaves, hands over to the plant at 7 - 17 % of the growth; a late joiner sees it settled; writes stop when it is up;
--  2. #5 leaves: foliage keeps its real opacity at every growth step (today: a ghost fade), grows out of its joint, lower leaves first;
--  3. #6 fruit: hidden until it swells, pale green of its own colour pattern, the bright ripening path, plump +5 % and settle, the real material only at the
--     ripe moment (today: at 82 %), Gold and Diamond fruit unchanged, MeshPart fruit (vertex colours + Part.Color tint) with the same exact ends;
--  4. #2 Place: a drawn plant moves to a pose through the batch and back; later writes keep that pose; the last write is at rest; the first pose is direct;
--  5. the registry (G.StateOf) has no leak; the scenes of every plant at 25 / 50 / 75 % go to check_floating.py (R134) in run_growth.sh;
--  6. (review part 2, finding 2) the server's silhouettes and the distant gardens run no leaf attachment pass (Plain: the leaves only appear in turn, the end state
--     is the same), the near-detail build yields through its job's budget once per 32 contact tests.
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local G,Base,Catalog,Rules=C.Growth,C.Base,C.Catalog,C.Rules;local T=G.Tuning
local Batch=W.module('PlantAnimationBatch');local Enum,CFrame=R.Enum,R.CFrame
local ids=C.ids()
local function plain(id)local d=Catalog[id];return not d.Mech and not d.Verity end
local function ease(a,b,x)local t=math.clamp((x-a)/math.max(.001,b-a),0,1);return t*t*(3-2*t)end
local function parts(model)local out={};for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then out[#out+1]=p end end;return out end
local function cfNear(a,b,tol)local p,q={a:GetComponents()},{b:GetComponents()};for i=1,12 do if math.abs(p[i]-q[i])>(tol or 1e-9)then return false end end;return true end
-- 1. #3 sprout pop ------------------------------------------------------------------------------------------------------------------------------------
do
 local id='VoltOrchidSeed';local d=Catalog[id];check(d.Seconds>=3000,'(a long plant: '..d.Seconds..' s)')
 local crop=C.crop(id);local model,st=C.grow(G,id,crop)
 local seed,stem,leafA,leafB=st.Seed,st.Sprout[1],st.Sprout[2],st.Sprout[3]
 local function at(now)G.Apply(st,crop,now)end
 at(.2)
 check(seed.Transparency==0 and stem.Transparency==1 and leafA.Transparency==1 and leafB.Transparency==1,'0.2 s after planting: only the seed (the R112 dirt pile stands over it)')
 local squash0=seed.Size.Y;at(.25);check(seed.Size.Y<seed.Size.X,'the seed squashes as it is planted')
 at(1.5);check(stem.Transparency==1 and leafA.Transparency==1,'1.5 s: no seedling yet')
 at(2.85);check(stem.Transparency==1,'2.85 s: the pile has not started to sink: no seedling')
 at(3.0);check(stem.Transparency==0,'3.0 s: the seedling is up as the pile sinks')
 local last,rising=0,true;for i=0,10 do at(2.95+i*.05);local h=stem.Size.Y;if stem.Transparency==0 then if h<last-1e-9 and i<5 then rising=false end;last=h end end
 check(rising,'the stem rises while the pile sinks')
 at(3.2);local early=leafA.Transparency;at(3.6);check(early==1 and leafA.Transparency==0 and leafB.Transparency==0,'the two seed leaves open after the stem is up (3.2 s: closed, 3.6 s: open)')
 local a1=leafA.Size;at(4.6);local a2=leafA.Size;at(5.5);local a3=leafA.Size
 check(a2.X>=a1.X and a2==a3,'... and they are settled by 4.6 s')
 check(math.abs(leafA.Size.Z-leafB.Size.Z)<1e-9,'both leaves open alike')
 -- writes: the sprout writes by the clock, then nothing until the plant itself moves
 local busy=C.Count(function()for i=0,19 do at(3.0+i*.05)end end)
 check((busy.Total or 0)<=20*20,'the sprout costs a few parts a step ('..tostring(busy.Total)..' writes in 20 steps)')
 at(10) -- (the first refresh after the sprout puts the seedling at rest once)
 local calm=C.Count(function()for i=1,20 do at(10+i*.05)end end)
 check((calm.Total or 0)==0,'once it is up, a 20 Hz stream of refreshes writes nothing (the plant has not moved by 1/600)')
 -- the hand-over to the real plant
 local g1=C.grow(G,id,crop)
 local _,s2=C.grow(G,id,crop)
 G.Apply(s2,crop,d.Seconds*.04);check(s2.Sprout[1].Transparency==0,'4 % of the growth: the seedling is still the plant')
 G.Apply(s2,crop,d.Seconds*.25)
 check(s2.Sprout[1].Transparency==1 and s2.Sprout[2].Transparency==1 and s2.Seed.Transparency==1,'25 % of the growth: the seedling has handed over to the plant')
 local big=0;for _,r in ipairs(s2.Parts)do if r.Part.Transparency<1 then big+=1 end end;check(big>10,'... and the plant is drawn ('..big..' parts)')
 -- a late joiner (or a stream-in): the settled seedling at once
 local _,s3=C.grow(G,id,crop);G.Apply(s3,crop,100)
 check(s3.Sprout[1].Transparency==0 and s3.Sprout[2].Transparency==0 and s3.Sprout[2].Size.Z>.2,'a late joiner (100 s after planting) sees the settled seedling, no pop')
 -- the pile decides: a sink beat later than the default moves the rise with it
 local c2=C.crop(id);c2.SproutAt=9;local _,s4=C.grow(G,id,c2)
 G.Apply(s4,c2,5);check(s4.Sprout[1].Transparency==1,'a crop whose pile sinks at 9 s has no seedling at 5 s')
 G.Apply(s4,c2,9.3);check(s4.Sprout[1].Transparency==0,'... and the seedling rises at 9.3 s')
 -- no PlantedAt (a preview): no seedling logic, no error
 local c3=C.crop(id);c3.PlantedAt=nil;local _,s5=C.grow(G,id,c3);check(pcall(function()G.Apply(s5,c3,50)end),'a crop without PlantedAt is drawn without error')
 -- the Dune Starfruit has no seedling, as before
 local sid='StarfruitSeed';local sc=C.crop(sid);local _,ss=C.grow(G,sid,sc);G.Apply(ss,sc,3.5)
 check(ss.Sprout[1].Transparency==1 and ss.Sprout[2].Transparency==1,'the giant Dune Starfruit has no seedling')
 -- the frozen plants: today's seedling (no pop): the same as the base at the same moment
 for _,fid in ipairs({'LanternFernSeed','AmethystSeed'})do
  local fc=C.crop(fid);local mb,sb=C.grow(Base,fid,fc);local mn,sn=C.grow(G,fid,fc)
  for _,t in ipairs({.2,3,6,9,12,40})do
   local before=G.Stats.Rewrites;Base.Apply(sb,fc,t);G.Apply(sn,fc,t)
   check(G.Stats.Rewrites>before and C.sameAs(C.snapshot(mb),C.snapshot(mn)),fid..' at '..t..' s: the seedling is drawn as today (no pop, no squash)')
  end
  mb:Destroy();mn:Destroy()
 end
end
-- 2. #5 solid leaves ------------------------------------------------------------------------------------------------------------------------------------
do
 local ghostsNew,ghostsBase,foliage,plants=0,0,0,0
 local semiNew,semiBase=0,0
 for _,id in ipairs(ids)do
  local d=Catalog[id]
  if plain(id)and not G.Frozen[id]then
   local crop=C.crop(id);local mb,sb=C.grow(Base,id,crop);local mn,sn=C.grow(G,id,crop);plants+=1
   for _,f in ipairs({.1,.25,.5,.75,.95})do
    Base.Apply(sb,crop,d.Seconds*f);G.Apply(sn,crop,d.Seconds*f)
    for _,r in ipairs(sn.Parts)do if r.Foliage and not r.Fruit then
     foliage+=1;local t=r.Part.Transparency
     if not(t==1 or t==r.Alpha)then ghostsNew+=1;check(false,id..' '..f..': a leaf at transparency '..t..' (its own is '..r.Alpha..')')end
    end end
    for _,r in ipairs(sb.Parts)do if r.Foliage and not r.Fruit then local t=r.Part.Transparency;if t>r.Alpha+.001 and t<.999 then ghostsBase+=1 end end end
    if f==.5 then
     for _,r in ipairs(sn.Parts)do local t=r.Part.Transparency;if t>0 and t<1 then semiNew+=1 end end
     for _,r in ipairs(sb.Parts)do local t=r.Part.Transparency;if t>0 and t<1 then semiBase+=1 end end
    end
   end
   -- at the end the leaves are exactly the old ones
   G.Apply(sn,crop,d.Seconds);for _,r in ipairs(sn.Parts)do if r.Foliage and not r.Fruit then
    check(r.Part.Size==V3(math.max(.01,r.Size.X),math.max(.01,r.Size.Y),math.max(.01,r.Size.Z))and r.Part.Transparency==r.Alpha,id..': a grown leaf is exactly its ripe size and opacity')
   end end
   mb:Destroy();mn:Destroy()
  end
 end
 check(ghostsNew==0 and ghostsBase>200,('leaves keep their opacity: 0 ghost leaves in %d (plant x step) leaf draws of %d plants; today %d draws are semi-transparent ghosts'):format(foliage,plants,ghostsBase))
 print(('SEMI-TRANSPARENT parts at 50 %% growth over %d plants: today %d, now %d'):format(plants,semiBase,semiNew))
 check(semiNew<semiBase,'fewer semi-transparent parts to draw (cheaper on phones) at 50 % growth ('..semiNew..' against '..semiBase..')')
-- the attach tree: parents first, lower leaves first, and every leaf stays attached to its parent at every step of the growth
 do
  local total,free,plantsWith,worst,sumTests=0,0,0,0,0
  local function gap(g,point) -- distance from a point to the grown box of the parent part
   local r=g.R;local centre,factor=g.Centre,g.Factor
   local f=r.Frame;local d=point-centre;local h=r.Size*.5*factor
   local x=math.max(math.abs(d:Dot(f.RightVector.Unit))-h.X,0);local y=math.max(math.abs(d:Dot(f.UpVector.Unit))-h.Y,0);local z=math.max(math.abs(d:Dot(f.LookVector.Unit))-h.Z,0)
   return math.sqrt(x*x+y*y+z*z)
  end
  local worstGap=0;local bad=0;local drawBad,drawn,notYet,placed=0,0,0,0
  for _,id in ipairs(ids)do
   local d=Catalog[id]
   if plain(id)and not G.Frozen[id]then
    local crop=C.crop(id);local before=G.Stats.LinkTests;local m,st=C.grow(G,id,crop);local tests=G.Stats.LinkTests-before
    worst=math.max(worst,tests);sumTests+=tests
    if st.Leaves then
     plantsWith+=1
     local seen={};local order=true
     for _,r in ipairs(st.Leaves)do if r.Par and(not seen[r.Par]or r.LeafStart<r.Par.LeafStart)then order=false end;seen[r]=true end
     check(order,id..': parents are drawn before their children and a child never starts before its parent')
     for _,f in ipairs({.08,.15,.25,.4,.6,.85})do
      G.Apply(st,crop,d.Seconds*f);local scale=G.Shape(f)
      for _,r in ipairs(st.Leaves)do
       if r.Part.Transparency<1 and not r.Free and r.PR then
        local parent=r.PR;local g
        if parent.Foliage then g={R=parent,Centre=parent.LAt,Factor=parent.LS}else g={R=parent,Centre=parent.Pos*scale,Factor=scale}end
        local e=gap(g,r.LM);worstGap=math.max(worstGap,e);if e>.06 then bad+=1 end
       end
      end
      -- what is DRAWN is what the attach tree worked out: a leaf is hidden until its start, then its own shape grown out of its joint
      for _,r in ipairs(st.Leaves)do
       local want=r.LAmount;drawn+=1
       if want>.0001 then
        local s0=r.Size
        if not(r.Part.Transparency<1 and r.Part.Size==V3(math.max(.01,s0.X*want),math.max(.01,s0.Y*want),math.max(.01,s0.Z*want)))then drawBad+=1 end
        placed+=1;if(r.Part.Position-(st.Origin*CF(r.LAt)).Position).Magnitude>1e-4 then drawBad+=1 end
       elseif r.Part.Transparency~=1 then drawBad+=1 end
       if f<=r.LeafStart and r.Part.Transparency~=1 then notYet+=1 end
      end
     end
     for _,r in ipairs(st.Leaves)do total+=1;if r.Free then free+=1 end end
    end
    m:Destroy()
   end
  end
  check(drawBad==0 and notYet==0 and placed>800,('the drawn leaves are the attach tree\'s: %d leaf draws, %d placed at their joint-grown positions, %d wrong, %d visible before their start'):format(drawn,placed,drawBad,notYet))
  check(bad==0,('every leaf of every plant stays on its parent while it grows (worst gap %.3f studs; the contact tolerance is .04, art rotations carry rounding)'):format(worstGap))
  check(total>800 and free<=total*.25,('%d leaves of %d plants: %d attach to the nearest part because they touch nothing in the mature plant'):format(total,plantsWith,free))
  print(('LEAF TREE plants=%d leaves=%d free=%d contact tests per plant: average %.0f, worst %d'):format(plantsWith,total,free,sumTests/math.max(1,plantsWith),worst))
  check(worst<=60000,'attaching the leaves costs at most 60,000 point-in-box tests once per plant ('..worst..')')
  for _,id in ipairs({'AppleSeed','BluebellSeed','BananaSeed'})do
   local crop=C.crop(id);local m,st=C.grow(G,id,crop)
   local list={};for _,r in ipairs(st.Leaves)do list[#list+1]=r end
   table.sort(list,function(a,b)return a.Att.Y<b.Att.Y end)
   local third=math.floor(#list/3);local low,high=0,0
   for i=1,third do low+=list[i].LeafStart;high+=list[#list-i+1].LeafStart end
   check(third>=2 and high/third>low/third+.02,('%s: the leaves at the foot of the plant start earlier (mean start %.3f low, %.3f high)'):format(id,low/third,high/third))
   m:Destroy()
  end
  -- the opt-out list: those plants' leaves grow with the plant (no attach tree), solid, appearing in turn
  G.PlainLeaves.BananaSeed=true
  local crop=C.crop('BananaSeed');local m,st=C.grow(G,'BananaSeed',crop)
  check(st.Leaves==nil,'G.PlainLeaves: no attach tree');G.Apply(st,crop,Catalog.BananaSeed.Seconds*.3)
  local solid=true;for _,r in ipairs(st.Parts)do if r.Foliage and not r.Fruit then local t=r.Part.Transparency;if not(t==1 or t==r.Alpha)then solid=false end end end
  check(solid,'... and the leaves are still solid');G.PlainLeaves.BananaSeed=nil;m:Destroy()
 end
end
-- review part 2 (finding 2): what nobody sees up close skips the leaf attachment pass (the server's silhouettes, the distant gardens); the near-detail build
-- yields through its job's budget while it runs
do
 local Distant=W.module('DistantPlantView');local Visuals=C.Visuals
 local noTests,noTree,starts,silhouettes,distant=true,true,true,0,0
 for _,id in ipairs(ids)do if plain(id)and not G.Frozen[id]then
  local d=Catalog[id];local crop=C.crop(id);local now=d.Seconds*.5
  local before=G.Stats.LinkTests
  local silhouette=R.new('Model');Visuals.GrowingSupports(id,C.origin,crop,2,silhouette,now) -- (the server: GrowingSupports -> BeginGrowth)
  local st=G.StateOf(silhouette);if G.Stats.LinkTests~=before then noTests=false end
  if st then
   silhouettes+=1;if st.Leaves then noTree=false end
   for _,r in ipairs(st.Parts)do if r.Foliage and not r.Fruit and type(r.LeafStart)~='number'then starts=false end end
  end
  Visuals.EndGrowth(silhouette);silhouette:Destroy()
  before=G.Stats.LinkTests
  local far,growing=Distant.Build(crop,C.origin,now) -- (a distant garden)
  local fs=G.StateOf(far);if G.Stats.LinkTests~=before then noTests=false end
  if fs then distant+=1;if fs.Leaves then noTree=false end end
  far:Destroy()
 end end
 check(silhouettes>40 and distant>40,('(%d server silhouettes and %d distant plants were drawn)'):format(silhouettes,distant))
 check(noTests,'a server silhouette and a distant plant run no contact test at all')
 check(noTree and starts,'... their leaves have no attach tree, only a start (they appear in turn, solid)')
 -- the end state does not depend on the pass
 for _,id in ipairs({'AppleSeed','FrostFernSeed','SunflowerSeed','TempestLotusSeed'})do
  local crop=C.crop(id)
  local ma,sa=C.grow(G,id,crop,{Plain=true});C.finish(G,sa,crop);local a=C.snapshot(ma)
  local mb,sb=C.grow(G,id,crop);C.finish(G,sb,crop);local b=C.snapshot(mb)
  check(sa.Leaves==nil and sb.Leaves~=nil and C.sameAs(a,b),id..': a plain capture ends exactly where the full one does')
  ma:Destroy();mb:Destroy()
 end
 do local crop=C.crop('FrostFernSeed');local m,st=C.grow(G,'FrostFernSeed',crop,{Plain=true});G.Apply(st,crop,Catalog.FrostFernSeed.Seconds*.1)
  local solid,hidden,shown=true,0,0
  for _,r in ipairs(st.Parts)do if r.Foliage and not r.Fruit then local t=r.Part.Transparency;if t==1 then hidden+=1 elseif t==r.Alpha then shown+=1 else solid=false end end end
  check(solid and hidden>0 and shown>0,('a plain plant at 10 %%: the leaves that started are solid (%d), the others are still hidden (%d)'):format(shown,hidden));m:Destroy() end
 -- the near-detail build: one BeforePart(1) per 32 contact tests, on top of what the parts cost
 local function calls(f)local n=0;f({Model=function()end,BeforePart=function()n+=1 end});return n end
 for _,id in ipairs({'FrostFernSeed','MonsteraSeed','AloeSeed','SunflowerSeed'})do
  local d=Catalog[id];local crop=C.crop(id);local now=d.Seconds*.5;local ripe=table.clone(crop);ripe.ReadyAt=0
  local build=calls(function(work)Visuals.Build(id,C.origin,ripe,4,math.huge,nil,work):Destroy()end)
  local before=G.Stats.LinkTests
  local grow=calls(function(work)local m=Visuals.BuildGrowing(id,C.origin,crop,now,2,work);Visuals.EndGrowth(m);m:Destroy()end)
  local tests=G.Stats.LinkTests-before
  check(tests>400 and grow-build==tests//32,('%s: the near-detail build yields once per 32 contact tests (%d tests, %d extra yields)'):format(id,tests,grow-build))
 end
end
-- 3. #6 fruit ------------------------------------------------------------------------------------------------------------------------------------------
do
 local function regrow(id,index,coat)
  local d=Catalog[id];local rc=C.crop(id,{HarvestCycle=1,Mutation=coat or'None'});rc.FruitStates={}
  for i=1,d.FruitCount do local dur=d.RegrowSeconds or d.Seconds;rc.FruitStates[tostring(i)]={ReadyAt=d.Seconds+dur+i*40,Cycle=1,Duration=dur}end -- (the plant is mature while the fruit regrows)
  local ready=rc.FruitStates[tostring(index)].ReadyAt;local dur=rc.FruitStates[tostring(index)].Duration
  local m,st=C.growFruit(G,id,rc,index);return m,st,rc,ready-dur,dur
 end
 local pale,fruitParts,meshPlants,meshParts,neon,neonPlants=0,0,0,0,0,0
 local tested=0
 for _,id in ipairs(ids)do
  local d=Catalog[id]
  if plain(id)and not G.Frozen[id]and id~='StarfruitSeed'and d.Mode~='whole'then
   local m,st,rc,t0,dur=regrow(id,1)
   local fp={};for _,r in ipairs(st.Parts)do if r.Fruit then fp[#fp+1]=r end end
   if #fp>0 then
    tested+=1
    G.Apply(st,rc,t0+dur*.05)
    local hidden=0;for _,r in ipairs(fp)do if r.Part.Transparency==1 then hidden+=1 end end
    check(hidden==#fp,id..': a bud only (the fruit is hidden) at 5 % of its growth')
    local hasMesh=false;local hasNeon=false
    for _,r in ipairs(fp)do if r.Mesh then hasMesh=true end;if r.Material~=Enum.Material.SmoothPlastic and r.Material~=Enum.Material.Plastic then hasNeon=true end end
    if hasMesh then meshPlants+=1 end;if hasNeon then neonPlants+=1 end
    for _,k in ipairs({.2,.4,.55,.7,.85,.9,.95,.99})do
     G.Apply(st,rc,t0+dur*k)
     local ck=ease(T.ColourFrom,T.ColourTo,k)
     for _,r in ipairs(fp)do if r.Part.Transparency<1 then
      fruitParts+=1
      local want=r.Mesh and(ck<=0 and r.Unripe or r.Unripe:Lerp(r.Color,ck))or G.Ripen(r.Color,ck)
      if ck>=1 then want=r.Ripe end
      local got=r.Part.Color
      if math.abs(got.R-want.R)>1e-9 or math.abs(got.G-want.G)>1e-9 or math.abs(got.B-want.B)>1e-9 then check(false,('%s %s at %.2f: colour is not the ripening path'):format(id,r.Part.Name,k))end
      if r.Mesh then meshParts+=1
       -- a MeshPart's Part.Color only tints its vertex colours: it stays between the pale tint and the part's own colour on every channel
       local u=r.Unripe;local c=r.Color
       for _,ch in ipairs({'R','G','B'})do local lo,hi=math.min(u[ch],c[ch]),math.max(u[ch],c[ch]);if got[ch]<lo-1e-9 or got[ch]>hi+1e-9 then check(false,id..' '..r.Part.Name..': mesh tint left the pale..own range')end end
      end
      if r.Material~=Enum.Material.SmoothPlastic and r.Part.Material~=Enum.Material.SmoothPlastic then check(false,id..': the real material is on before the ripe moment (at '..k..')')end
     end end
    end
    -- the swell: plump +5 % at 90 %, exactly the ripe size at ripe
    G.Apply(st,rc,t0+dur*.9)
    for _,r in ipairs(fp)do if r.Part.Transparency<1 and r.Fruit then
     local ratio=r.Part.Size.X/math.max(.01,r.Size.X);if r.Size.X>.05 and math.abs(ratio-1.05)>.011 then check(false,('%s %s: plump %.3f at 90 %%'):format(id,r.Part.Name,ratio))end
    end end
    G.Apply(st,rc,t0+dur)
    local grown=true;for _,r in ipairs(fp)do local p=r.Part
     if p.Size~=V3(math.max(.01,r.Size.X),math.max(.01,r.Size.Y),math.max(.01,r.Size.Z))or p.Material~=r.Material or p.Transparency~=r.Alpha then grown=false end end
    check(grown,id..': ripe = the old size, material and opacity exactly')
   end
   m:Destroy()
  end
 end
 check(tested>=40,('%d plants tested at 5 / 20 / 40 / 55 / 70 / 85 / 90 / 95 / 99 / 100 %% of a fruit\'s growth (%d fruit-part draws)'):format(tested,fruitParts))
 check(meshPlants>=1 and meshParts>0,('MeshPart fruit (the stub of the baked meshes): %d plants, %d part draws follow the tint path and end exactly on their colour'):format(meshPlants,meshParts))
 check(neonPlants>=10,neonPlants..' plants have Neon / Wood / Sand fruit parts: all switch on at the ripe moment, none before')
 -- a young fruit is a pale green of its own colour: a melon keeps its stripes (different parts, different pale greens)
 local id='SunflowerSeed';local m,st,rc,t0,dur=regrow(id,1);G.Apply(st,rc,t0+dur*.5)
 local hues,shades={},{}
 for _,r in ipairs(st.Parts)do if r.Fruit and r.Part.Transparency<1 and not r.Mesh then
  local h,s,v=G.ToHSV(r.Part.Color);local _,s1,_=G.ToHSV(r.Color);if s1>.08 then hues[#hues+1]=h end;shades[string.format('%.2f',v)]=true
 end end
 local nShades=0;for _ in pairs(shades)do nShades+=1 end
 local avg=0;for _,h in ipairs(hues)do avg+=h end;avg/=math.max(1,#hues)
 check(#hues>3 and nShades>=2,'the watermelon: its parts keep different shades while young ('..nShades..' shades over '..#hues..' parts)')
 m:Destroy()
 -- Gold / Diamond fruit keep their colour: no blend
 for _,coat in ipairs({'Gold','Diamond'})do
  local gm,gs,grc,g0,gd=regrow('AppleSeed',1,coat)
  for _,k in ipairs({.3,.7,.95})do G.Apply(gs,grc,g0+gd*k)
   for _,r in ipairs(gs.Parts)do if r.Fruit and r.Part.Transparency<1 and r.Part.Color~=r.Color then check(false,coat..' fruit changed colour while growing')end end
  end
  gm:Destroy()
 end
 check(true,'Gold and Diamond fruit keep their colour while they grow (no blend)')
 -- a whole plant growing: fruit hidden until it swells, then the same path (the plant model carries its fruit)
 local pid='AppleSeed';local pd=Catalog[pid];local pc=C.crop(pid);local pm,ps=C.grow(G,pid,pc)
 G.Apply(ps,pc,pd.Seconds*.3);local hiddenFruit=true;for _,r in ipairs(ps.Parts)do if r.Fruit and r.Part.Transparency<1 then hiddenFruit=false end end
 check(hiddenFruit,'a young apple tree at 30 %: no fruit yet, only buds')
 G.Apply(ps,pc,pd.Seconds*.85);local seen=0;for _,r in ipairs(ps.Parts)do if r.Fruit and r.Part.Transparency<1 then seen+=1 end end
 check(seen>0,'... and fruit at 85 % ('..seen..' parts)')
 pm:Destroy()
 -- ripe flag: a fruit whose time has passed but that is picked is not "ripe" (Query stays off): as before
 local qm,qs,qrc,q0,qd=regrow('AppleSeed',1)
 G.Apply(qs,qrc,q0+qd*.99);local anyQuery=false;for _,r in ipairs(qs.Parts)do if r.Part.CanQuery then anyQuery=true end end
 check(not anyQuery,'an unripe fruit cannot be queried (the harvest prompt rules are untouched)')
 G.Apply(qs,qrc,q0+qd);local queryOn=false;for _,r in ipairs(qs.Parts)do if r.Part.CanQuery and r.Query then queryOn=true end end
 check(queryOn,'... and the ripe one can (as its ripe self)')
 qm:Destroy()
end
-- 4. #2 Place -------------------------------------------------------------------------------------------------------------------------------------------
do
 local id='AppleSeed';local d=Catalog[id];local crop=C.crop(id)
 local m,st=C.grow(G,id,crop);local batch=Batch.new(W.workspace)
 local pose=CF(0,0,0)*CFrame.Angles(.01,0,.02)
 -- the first pose is direct even while a batch is installed (a plant must never show its ripe pose for a frame)
 G.Batch=batch;G.Apply(st,crop,d.Seconds*.5)
 check(batch.Requested==0,'the first pose of a plant is written directly (nothing waits in the batch)')
 -- moving by 1/600: the CFrames go through the batch
 G.Apply(st,crop,d.Seconds*.52)
 check(batch.Requested>0,'a later rewrite queues its CFrames in the batch ('..batch.Requested..')')
 local queued=batch.Requested;local count,asked=batch:Flush();check(count>0 and count==queued,'one flush moves them all ('..count..')')
 G.Batch=nil
 local visibleParts=0;for _,r in ipairs(st.Parts)do if r.Part.Transparency<1 then visibleParts+=1 end end
 local rest=C.snapshot(m)
 local n=G.Place(st,pose,batch);batch:Flush()
 check(n>=visibleParts,('Place moves every visible part (%d for %d visible, plus the seedling and buds)'):format(n,visibleParts))
 local ok=true
 for _,r in ipairs(st.Parts)do if r.Part.Transparency<1 then
  local want=pose*(CF(r.At)*r.Rot);if not cfNear(r.Part.CFrame,want)then ok=false end
 end end
 check(ok,'every part sits at pose x its grown pose')
 -- a rewrite while posed writes at the pose
 G.Apply(st,crop,d.Seconds*.6);local ok2=true
 for _,r in ipairs(st.Parts)do if r.Part.Transparency<1 then if not cfNear(r.Part.CFrame,pose*(CF(r.At)*r.Rot))then ok2=false end end end
 check(ok2,'a later rewrite keeps the plant at the pose')
 -- back to rest: exactly what a plain rewrite at the same time draws
 G.Place(st,nil,batch);batch:Flush()
 local m2,st2=C.grow(G,id,crop);G.Apply(st2,crop,d.Seconds*.6)
 local same=true;for i,r in ipairs(st.Parts)do if r.Part.Transparency<1 then if not cfNear(r.Part.CFrame,st2.Parts[i].Part.CFrame)then same=false end end end
 check(same,'Place(nil) puts every part back exactly where a rewrite at rest puts it')
 -- the end of the growth is written at rest, whatever pose was left
 G.Place(st,pose,batch);batch:Flush();G.Apply(st,crop,d.Seconds)
 check(st.Pose==nil,'the last write clears the pose')
 local m3,st3=C.grow(G,id,crop);G.Apply(st3,crop,d.Seconds);local fin=true
 for i,r in ipairs(st.Parts)do if not cfNear(r.Part.CFrame,st3.Parts[i].Part.CFrame)then fin=false end end
 check(fin,'... and every part is at its resting final pose')
 -- hidden parts are not moved (they cost nothing)
 local m4,st4=C.grow(G,id,crop);G.Apply(st4,crop,d.Seconds*.05)
 local hiddenParts=0;for _,r in ipairs(st4.Parts)do if r.Part.Transparency==1 then hiddenParts+=1 end end
 local moved=G.Place(st4,pose,batch);batch:Flush()
 check(moved<#st4.Parts and hiddenParts>0,('a young plant: %d of %d parts are hidden and not moved (%d moves)'):format(hiddenParts,#st4.Parts,moved))
 for _,x in ipairs({m,m2,m3,m4})do x:Destroy()end
 -- the budget table of GardenVisuals: a state that was never drawn is not moved
 local m5,st5=C.grow(G,id,crop);check(G.Place(st5,pose,batch)==0,'a plant that was never drawn is not moved');m5:Destroy()
 -- G.Parts: the set the rig must leave out
 local m6,st6=C.grow(G,id,crop);G.Apply(st6,crop,d.Seconds*.5);local set=G.Parts(st6)
 local allIn=true;for _,r in ipairs(st6.Parts)do if not set[r.Part]then allIn=false end end
 check(allIn and set[st6.Seed]and set[st6.Sprout[1]],'G.Parts covers every part the state moves, the seedling and the buds');m6:Destroy()
 check(G.Sways('AppleSeed',Catalog.AppleSeed)and not G.Sways('StarfruitSeed',Catalog.StarfruitSeed)and not G.Sways('LanternFernSeed',Catalog.LanternFernSeed)and not G.Sways('AmethystSeed',Catalog.AmethystSeed),
  'G.Sways: no sway for the giant Dune Starfruit, Lantern Fern and Amethyst Grape (growing)')
end
-- 5. the registry ---------------------------------------------------------------------------------------------------------------------------------
do
 local id='AppleSeed';local crop=C.crop(id);local m,st=C.grow(G,id,crop)
 check(G.StateOf(m)==st,'G.StateOf finds the state of a model being grown')
 C.finish(G,st,crop,Catalog[id].Seconds)
 check(G.StateOf(m)==nil,'... and nothing once the growth is over (the temporary parts are gone)')
 local m2,st2=C.grow(G,id,crop);check(G.StateOf(m2)==st2,'(again)');m2:Destroy();check(G.StateOf(m2)==nil,'... and nothing once the model is destroyed')
 m:Destroy()
 -- Mech and Verity plants keep their own growth code (the registry never holds them)
 local mid;for _,i in ipairs(ids)do if Catalog[i].Mech then mid=i;break end end
 if mid then local mc=C.crop(mid);local ok,mm,ms=pcall(C.grow,G,mid,mc);check(ok,'a Mech plant still captures through PlantGrowth');if ok then check(G.StateOf(mm)==nil,'... and is not in the registry');mm:Destroy()end end
end
-- 6. the scenes for the floating check (R134): every plant at 25 / 50 / 75 % of its growth, the base's and this module's -----------------------------------
do
 local function addScene(list,labels,label,model)
  labels[#labels+1]=label;local seed=#labels
  for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and c.Name~='VisualPivot'and(c.Transparency or 0)<1 then
   local cf=c.CFrame;local r=cf.R;local p=cf.Position;local sz=c.Size
   local shape=(c.Shape and(type(c.Shape)=='table'and c.Shape.Name or tostring(c.Shape):match('(%w+)$')))or'Block'
   local function n4(v)return string.format('%.4f',v)end
   list[#list+1]=('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"t":%s}'):format(seed,c.Name,shape,
    n4(sz.X),n4(sz.Y),n4(sz.Z),n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),n4(c.Transparency or 0))
  end end
 end
 local new,old,labels={},{},{}
 for _,id in ipairs(ids)do
  local d=Catalog[id]
  if plain(id)and not G.Frozen[id]then
   for _,f in ipairs({.25,.5,.75})do
    local crop=C.crop(id);local mb,sb=C.grow(Base,id,crop);local mn,sn=C.grow(G,id,crop)
    Base.Apply(sb,crop,d.Seconds*f);G.Apply(sn,crop,d.Seconds*f)
    -- the seedling is a temporary part of its own; the plant is what the check is about
    for _,st in ipairs({sb,sn})do st.Seed.Transparency=1;for _,p in ipairs(st.Sprout)do p.Transparency=1 end;for _,b in pairs(st.Buds)do b.Part.Transparency=1;b.Stem.Transparency=1 end end
    local label=id..' @'..math.floor(f*100)
    local n0=#labels;addScene(old,labels,label,mb);local lab=#labels;labels[#labels]=nil;addScene(new,labels,label,mn)
    mb:Destroy();mn:Destroy()
   end
  end
 end
 -- the same labels for both lists (the base scene reuses each label's index)
 local function label()local o={};for i,l in ipairs(labels)do o[i]=('{"text":"%s"}'):format(l)end;return table.concat(o,',')end
 print('SCENE_GROWTH_BASE {"parts":['..table.concat(old,',')..'],"labels":['..label()..']}')
 print('SCENE_GROWTH_NEW {"parts":['..table.concat(new,',')..'],"labels":['..label()..']}')
end
C.done('growth look')
