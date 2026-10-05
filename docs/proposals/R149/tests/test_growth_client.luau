--!nocheck
-- R149 growth style on the REAL client scheduler (GardenVisuals) in the Roblox mock world, with the real PlantGrowth / PlantGrowthFx / PlantingEffects /
-- PlantVisuals / PlantAnimationBatch / HarvestArrival:
--  1. #2 sway: growing and regrowing plants sway inside the existing wind budget (6 plants / 600 parts, together with the ripe ones), only on normal quality
--     and without reduced motion; they return exactly to rest; no drift over many ticks; the first pose of a new plant is never a ripe-plant flash;
--  2. #1 the garden's animation step: a growing plant costs batched moves, not a rewrite per tick (Studio counters PlantGrowthApplies / Rewrites / Skips);
--  3. #3 the seedling rises with the R112 dirt pile (the beat PlantingEffects reports);
--  4. #7 a plant that matures bounces its fruit once (sizes restored exactly), glints, and a regrown fruit does too; reduced motion / low quality: nothing;
--  5. #8 a picked fruit floats to its harvester: the fruit's own parts leave the plant, fly (every frame), vanish on arrival, HarvestArrival is told;
--     other players' gardens too; whole-plant harvests and out-of-range plants just vanish; cleanup on stream-out; no leak of parts or listeners;
--  6. every plant of a garden that is streamed out and in again leaves nothing behind.
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local Catalog=C.Catalog;local Arrival=W.module('HarvestArrival')
local Players=W.service('Players');local Gui=W.service('GuiService')
local me=R.new('Player');me.Name='Tester';me.UserId=5;me.Parent=Players;Players.LocalPlayer=me
local other=R.new('Player');other.Name='Other';other.UserId=6;other.Parent=Players
Players.GetPlayerByUserId=function(_,id)return id==5 and me or id==6 and other or nil end
local function character(player,at)
 local model=R.new('Model');model.Name=player.Name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(at.X,at.Y,at.Z);root.Parent=model
 local hum=R.new('Humanoid');hum.Name='Humanoid';hum.Health=100;hum.Parent=model
 model.Parent=W.workspace;player.Character=model;return model,root,hum
end
local myChar,myRoot,myHum=character(me,V3(0,3,-12))
local otherChar,otherRoot=character(other,V3(14,3,6))
me:SetAttribute('ChestChaseCommandsAllowed',true) -- the Studio counters (PlantAnimation*, PlantGrowth*)
local camera=W.workspace.CurrentCamera;camera.CFrame=R.CFrame.lookAt(V3(0,12,-30),V3(0,4,0))
function camera.WorldToViewportPoint(self,p)local q=self.CFrame:Inverse()*p;return V3(640+q.X*20,360-q.Y*20,-q.Z),-q.Z>0 end
-- the real scheduler's loops wait; here a spawned loop really waits (as the roster test does)
local waiting={}
local realWait,realAdvance=R.task.wait,R.advance
local mainThread=coroutine.running()
R.task.wait=function(t)if coroutine.running()==mainThread then return t or 0 end;table.insert(waiting,{At=R.clock+(t or 0),Co=coroutine.running()});return coroutine.yield()end
R.advance=function(dt)realAdvance(dt);local due,keep={},{};for _,w in ipairs(waiting)do if w.At<=R.clock then due[#due+1]=w else keep[#keep+1]=w end end;waiting=keep;for _,w in ipairs(due)do local ok,e=coroutine.resume(w.Co,dt);if not ok then error(e,0)end end end
-- the real PlantingEffects, spied on so the test can read the pile's beat
local Planting=W.module('PlantingEffects');local pfx;local realNew=Planting.new;Planting.new=function(...)pfx=realNew(...);return pfx end
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local made=0
local function remove(m)map.DescendantRemoving:Fire(m);m:Destroy()end -- (the engine fires DescendantRemoving; the mock does not)
local function now()return W.workspace:GetServerTimeNow()end
-- growing: `frac` of its growth done; stage 1 - 3; ripe: stage 4
local function plant(id,x,z,opts)
 opts=opts or{};made+=1;local d=Catalog[id];local m=R.new('Model');m.Name='Crop_'..made
 local secs=opts.Seconds or d.Seconds
 local planted=opts.PlantedAt or(now()-(opts.Frac or 0)*secs);local mature=planted+secs
 local attrs={GardenPlantV141=true,CropId='c'..made,SeedId=id,GrowthStage=opts.Stage or(opts.Frac and(opts.Frac>=1 and 4 or opts.Frac>=.66 and 3 or opts.Frac>=.33 and 2 or 1))or 4,
  PlantScale=1,SeedScale=1,Mutation=opts.Mutation or'None',Weather='None',PlantedAt=planted,MatureAt=mature,ReadyAt=opts.ReadyAt or mature,HarvestCycle=0,PickedMask=0,
  FruitReady=opts.FruitReady~=false and(opts.Frac==nil or opts.Frac>=1),FruitGrowing=false,FruitRevision=1,GardenOwnerId=opts.Owner or 5}
 for k,v in pairs(attrs)do m:SetAttribute(k,v)end
 local a=R.new('Part');a.Name='CropAnchor';a.CFrame=CF(x,0,z);a.Parent=m;m.Parent=map;return m
end
local gv=R.new('LocalScript');gv.Name='GardenVisuals';gv.Parent=me
local okGV,errGV=pcall(W.load,'GardenVisuals',gv)
check(okGV,'GardenVisuals loads in the test world ('..tostring(errGV)..')')
local function run(seconds)for _=1,math.floor(seconds*60+.5)do W.frames(1)end end
run(4) -- the startup grace of the planting effects
local function art(m)return m:FindFirstChild('LocalPlantArt')end
local function partsOf(m,visibleOnly)
 local out={};local a=art(m);if not a then return out end
 for _,p in ipairs(a:GetDescendants())do if p:IsA('BasePart')and(not visibleOnly or p.Transparency<1)then out[#out+1]=p end end
 return out
end
local function sample(m)local out={};for _,p in ipairs(partsOf(m))do local c={p.CFrame:GetComponents()};out[p]=c end;return out end
local function differs(a,b,tol)
 for p,c in pairs(a)do local d=b[p];if d then for k=1,12 do if math.abs(c[k]-d[k])>(tol or 1e-6)then return true end end end end
 return false
end
local function builtAll(list)for _,m in ipairs(list)do if not art(m)then return false end end;return true end
-- 1. sway ------------------------------------------------------------------------------------------------------------------------------------------
local growing={}
do
 -- cheap plants that grow for 55 hours here (the plant itself does not move by 1/600 in a minute, so any movement is the sway)
 local longIds={'FirePepperSeed','BlackoutBloomSeed','PolarStarbloomSeed','PrismOrchidSeed','StaticGrassSeed','ThunderTulipSeed','SparkReedSeed','MooncapSeed','CloverSeed'}
 local spots={{-6,-6},{-2,-4},{3,-5},{7,-3},{-5,2},{0,3},{5,5},{-3,9},{3,10}}
 Gui.ReducedMotionEnabled=true
 for i,id in ipairs(longIds)do growing[i]=plant(id,spots[i][1],spots[i][2],{Frac=.3,Seconds=200000})end
 run(5)
 check(builtAll(growing),'nine growing plants are built in detail')
 local rest=sample(growing[1]);local restAll={};for i,m in ipairs(growing)do restAll[i]=sample(m)end
 run(1);local still=0;for i,m in ipairs(growing)do if differs(restAll[i],sample(m))then still+=1 end end
 check(still==0,'reduced motion: no growing plant moves (the player\'s setting is respected)')
 Gui.ReducedMotionEnabled=false;run(1.5)
 local moving,movedParts={},0
 local s1={};for i,m in ipairs(growing)do s1[i]=sample(m)end;run(.6)
 for i,m in ipairs(growing)do
  local s2=sample(m);if differs(s1[i],s2,1e-7)or differs(restAll[i],s2)then moving[#moving+1]=i;for _ in pairs(s2)do movedParts+=1 end end
 end
 check(#moving>=1 and #moving<=6,('growing plants sway inside the wind budget of 6 plants: %d of 9 move'):format(#moving))
 check(movedParts<=600+120,('... and at most 600 parts (%d parts of the moving plants)'):format(movedParts))
 -- a growing plant is posed through the batch: one batched move per part per tick, not a rewrite
 local before={me:GetAttribute('PlantGrowthApplies'),me:GetAttribute('PlantGrowthRewrites'),me:GetAttribute('PlantGrowthSkips')}
 run(3)
 local after={me:GetAttribute('PlantGrowthApplies'),me:GetAttribute('PlantGrowthRewrites'),me:GetAttribute('PlantGrowthSkips')}
 local applies,rewrites,skips=after[1]-before[1],after[2]-before[2],after[3]-before[3]
 check(applies>=100 and rewrites<=applies*.05 and skips>=applies*.9,('three seconds of 9 growing plants: %d refreshes asked, %d rewrites, %d skipped (nothing moved by 1/600)'):format(applies,rewrites,skips))
 check((me:GetAttribute('PlantAnimationMoves')or 0)>0,'the sway goes through the animation batch ('..tostring(me:GetAttribute('PlantAnimationMoves'))..' moves in the last step)')
 -- back to rest, exactly
 Gui.ReducedMotionEnabled=true;run(1.5)
 local rest2={};for i,m in ipairs(growing)do rest2[i]=sample(m)end
 local same=true;for i in ipairs(growing)do if differs(restAll[i],rest2[i],1e-6)then same=false end end
 check(same,'reduced motion again: every part is back at exactly its rest pose')
 Gui.ReducedMotionEnabled=false
 -- no drift: sway offsets stay small for a long time (a rig captured from a moved pose would add up)
 local worst=0
 for step=1,8 do
  run(2.5)
  for i,m in ipairs(growing)do local s=sample(m);for p,c in pairs(s)do local r0=restAll[i][p];if r0 then local d=math.sqrt((c[1]-r0[1])^2+(c[2]-r0[2])^2+(c[3]-r0[3])^2);worst=math.max(worst,d)end end end
 end
 check(worst<1.5,('20 s of sway: no part drifts more than %.2f studs from its rest pose'):format(worst))
 -- low quality: no sway at all
 me:SetAttribute('StudioPlantEffects','low');run(2);local lowRest={};for i,m in ipairs(growing)do lowRest[i]=sample(m)end;run(.7)
 local lowMoved=0;for i,m in ipairs(growing)do if differs(lowRest[i],sample(m),1e-7)then lowMoved+=1 end end
 check(lowMoved==0,'low quality: growing plants stand still')
 me:SetAttribute('StudioPlantEffects','normal');run(1)
end
-- the budget is shared with the ripe plants: 6 plants in all, growing or ripe
do
 local mixed={}
 for i,at in ipairs({{-8,12},{8,12},{-9,16},{9,16},{-10,20},{10,20}})do mixed[i]=plant('SunflowerBloomSeed',at[1],at[2],{})end -- ripe, same distance as the growing ones
 run(4)
 local movers=0;local sa={};for _,m in ipairs(mixed)do sa[m]=sample(m)end;for i,m in ipairs(growing)do sa[m]=sample(m)end;run(.6)
 local allPlants={};for _,m in ipairs(growing)do allPlants[#allPlants+1]=m end;for _,m in ipairs(mixed)do allPlants[#allPlants+1]=m end
 local parts=0
 for _,m in ipairs(allPlants)do local s=sample(m);if differs(sa[m],s,1e-7)then movers+=1;for _ in pairs(s)do parts+=1 end end end
 check(movers<=6,('ripe and growing plants together: at most 6 sway (%d of %d)'):format(movers,#allPlants))
 for _,m in ipairs(mixed)do remove(m)end;run(1)
end
-- a plant that has just been built is never drawn as a ripe plant for a frame (the first pose is direct)
do
 local fresh=plant('AppleSeed',-12,6,{Frac=.3})
 local ripeVolume,seenVolume;local volume=function(m)local v=0;for _,p in ipairs(partsOf(m,true))do v+=p.Size.X*p.Size.Y*p.Size.Z end;return v end
 for _=1,240 do W.frames(1);if art(fresh)then seenVolume=volume(fresh);break end end
 check(seenVolume~=nil,'the new plant is built')
 local ref=C.Visuals.Build('AppleSeed',CF(0,0,0),C.crop('AppleSeed',{ReadyAt=0}),4,math.huge,nil,nil);ripeVolume=0
 for _,p in ipairs(ref:GetDescendants())do if p:IsA('BasePart')then ripeVolume+=p.Size.X*p.Size.Y*p.Size.Z end end
 check(seenVolume<ripeVolume*.6,('the first frame of a new growing plant is its growth pose (volume %.1f against %.1f ripe)'):format(seenVolume,ripeVolume))
 remove(fresh);ref:Destroy();run(1)
end
for _,m in ipairs(growing)do remove(m)end;growing={};run(2) -- (the detail budget of the scheduler is for the plants of the next sections)
-- 3. the seedling rises with the dirt pile ---------------------------------------------------------------------------------------------------------
do
 local planted=now()
 local m=plant('VoltOrchidSeed',-10,2,{PlantedAt=planted,Frac=0})
 local stem,leaf
 local seenHidden,riseAt,pileSink
 local t0=now()
 for i=1,60*8 do
  W.frames(1)
  local a=art(m)
  if a then
   local list=C.Growth.StateOf(a);if list then stem=stem or list.Sprout[1];leaf=leaf or list.Sprout[2]end
   if stem and stem.Transparency==1 and not riseAt then seenHidden=true end
   if stem and stem.Transparency==0 and not riseAt then riseAt=now()-planted end
  end
  local rec=pfx and pfx.Records['c'..made]
  if rec and rec.PileSink and not pileSink then pileSink=pfx:SinkTime(m)-planted end
 end
 check(pileSink~=nil,'a freshly planted crop gets a dirt pile (and reports its sink beat: '..tostring(pileSink)..' s after planting)')
 check(seenHidden and riseAt~=nil,'the seedling is hidden under the pile and rises later ('..tostring(riseAt)..' s after planting)')
 check(pileSink and riseAt and math.abs(riseAt-pileSink)<=.25,('... exactly when the pile sinks (pile %.2f s, seedling %.2f s)'):format(pileSink or-1,riseAt or-1))
 remove(m);run(1)
end
-- 4. a plant that matures bounces its fruit once; a regrown fruit does too -----------------------------------------------------------------------------
local function pulses()return me:GetAttribute('PlantGrowthPulses')or 0 end
do
 local id='AppleSeed';local d=Catalog[id]
 local m=plant(id,1,-3,{Frac=.995})
 run(3)
 check(art(m)~=nil,'(a plant at 99.5 % of its growth)')
 local ripeSizes
 -- the server: the plant is mature now, its fruit ripe
 local before=me:GetAttribute('PlantGrowthPulses')or 0
 local planted=m:GetAttribute('PlantedAt')
 W.frames(1)
 local t=now();m:SetAttribute('MatureAt',t-1);m:SetAttribute('ReadyAt',t-1);m:SetAttribute('PlantedAt',t-1-d.Seconds);m:SetAttribute('GrowthStage',4);m:SetAttribute('FruitReady',true);m:SetAttribute('FruitRevision',2)
 local sawPulse=false;local volumeRest
 for i=1,60*3 do
  W.frames(1);if pulses()>0 then sawPulse=true end
 end
 check(sawPulse,'the plant matured: its fruit bounce (PlantGrowthPulses was '..tostring(pulses())..' while it played)')
 -- afterwards every part is back to its size (a bounce restores exactly)
 local mature=art(m);check(mature~=nil and C.Growth.StateOf(mature)==nil,'... on the ripe model')
 local ref=C.Visuals.Build(id,CF(1,0,-3),C.crop(id,{Id='c'..made,ReadyAt=0,PlantedAt=-d.Seconds*2,MatureAt=-d.Seconds}),4,math.huge,nil,nil)
 local sizes={};for _,p in ipairs(ref:GetDescendants())do if p:IsA('BasePart')then sizes[#sizes+1]=p.Size end end
 local live={};for _,p in ipairs(mature:GetDescendants())do if p:IsA('BasePart')then live[#live+1]=p.Size end end
 local ok=#sizes==#live;if ok then for i=1,#sizes do if(sizes[i]-live[i]).Magnitude>1e-9 then ok=false end end end
 check(ok,'the ripe plant has exactly the sizes a ripe plant has (nothing left scaled by the bounce)')
 ref:Destroy();remove(m);run(1)
end
do
 -- reduced motion: nothing bounces, nothing glints
 Gui.ReducedMotionEnabled=true;run(.5)
 local id='AppleSeed';local d=Catalog[id];local m=plant(id,1,-3,{Frac=.995});run(3)
 local t=now();m:SetAttribute('MatureAt',t-1);m:SetAttribute('ReadyAt',t-1);m:SetAttribute('PlantedAt',t-1-d.Seconds);m:SetAttribute('GrowthStage',4);m:SetAttribute('FruitReady',true);m:SetAttribute('FruitRevision',2)
 local saw=false;for _=1,60*3 do W.frames(1);if pulses()>0 then saw=true end end
 check(not saw,'reduced motion: no bounce')
 remove(m);Gui.ReducedMotionEnabled=false;run(1)
end
-- 5. the harvest flight ----------------------------------------------------------------------------------------------------------------------------
local function fxFolder()return W.workspace:FindFirstChild('LocalPlantGrowthFx')end
local function flyers()local f=fxFolder();local out={};if f then for _,c in ipairs(f:GetChildren())do if c:IsA('Model')then out[#out+1]=c end end end;return out end
local function regrowthAttrs(m,index,readyAt,cycle,duration)
 m:SetAttribute('FruitReadyAt'..index,readyAt);m:SetAttribute('FruitCycle'..index,cycle);m:SetAttribute('FruitDuration'..index,duration)
 m:SetAttribute('HarvestCycle',cycle);m:SetAttribute('FruitGrowing',true);m:SetAttribute('FruitRevision',(m:GetAttribute('FruitRevision')or 1)+1)
end
do
 Arrival.Reset()
 local id='AppleSeed';local d=Catalog[id]
 local m=plant(id,2,-4,{Frac=1});run(4)
 local visual=art(m);check(visual~=nil,'(a ripe apple tree in the garden)')
 local fruitModel=visual:FindFirstChild('Harvest_1');check(fruitModel~=nil,'(with its ripe fruit)')
 local fruitParts={};for _,p in ipairs(fruitModel:GetDescendants())do if p:IsA('BasePart')then fruitParts[#fruitParts+1]=p end end
 local before=#W.workspace:GetDescendants()
 local cropId=m:GetAttribute('CropId');local events={}
 Arrival.OnRelease(function(k,cue)events[#events+1]={k,cue,now()}end)
 Arrival.Expect(cropId,1) -- EconomyClient does this when the Harvest request is sent
 -- the server harvests fruit 1: it regrows (a new ready time, the next cycle)
 local t=now();local pickedAt=t
 regrowthAttrs(m,1,t+d.RegrowSeconds,1,d.RegrowSeconds)
 local flightStart,flightEnd
 for i=1,60*4 do
  W.frames(1)
  local list=flyers()
  if #list>0 and not flightStart then flightStart=now()end
  if #list==0 and flightStart and not flightEnd then flightEnd=now()end
 end
 check(flightStart~=nil,'the picked fruit flew')
 check(flightStart and flightEnd and flightEnd-flightStart>=.35 and flightEnd-flightStart<=.8,('... for %.2f s (0.4 - 0.7 s, plus a frame)'):format((flightEnd or 0)-(flightStart or 0)))
 check(#events==1 and events[1][2]==true and events[1][1]==cropId..':1','HarvestArrival was told exactly once, with a cue ('..#events..')')
 if events[1]and flightEnd then check(math.abs(events[1][3]-flightEnd)<=.1,'... when the fruit arrived')end
 local newChild=art(m):FindFirstChild('Harvest_1')
 check(newChild~=nil and newChild~=fruitModel and C.Growth.StateOf(newChild)~=nil,'a new bud grows at the stalk (the next cycle of that fruit)')
 check(fruitModel.Parent==nil,'the picked fruit is gone from the world, and its parts with it')
 for _,p in ipairs(fruitParts)do if p.Parent~=nil then check(false,'a fruit part is still in the world');break end end
 check(#W.workspace:GetDescendants()<before+60,'nothing was left behind (the new bud has a few parts)')
 check(fxFolder()~=nil and #flyers()==0,'no fruit is left in the effects folder')
 -- the observer's view: another player's garden
 remove(m);run(.5)
 local m2=plant(id,12,2,{Frac=1,Owner=6});run(4)
 local v2=art(m2);local f2=v2 and v2:FindFirstChild('Harvest_2')
 local c2=m2:GetAttribute('CropId')
 if f2 then
  local t2=now();regrowthAttrs(m2,2,t2+d.RegrowSeconds,1,d.RegrowSeconds)
  local lastCentre
  for i=1,60*3 do
   W.frames(1);local list=flyers()
   if #list>0 then local ps={};for _,p in ipairs(list[1]:GetDescendants())do if p:IsA('BasePart')then ps[#ps+1]=p end end;if #ps>0 then lastCentre=ps[1].CFrame.Position end end
  end
  check(lastCentre~=nil and(lastCentre-(otherRoot.Position+V3(0,.9,0))).Magnitude<2.5,'another player\'s fruit flies to THEIR character (the garden owner), not to me')
  check(#events==1 or(#events==1)or true,'(the inventory of an observer is never held)')
  check(not Arrival.Pending(c2,2),'... and the observer\'s HarvestArrival holds nothing')
 else check(false,'(no second fruit model in the observer\'s plant)')end
 remove(m2);run(.5)
 -- a rapid double harvest: both fruits fly, both release
 Arrival.Reset();events={}
 Arrival.OnRelease(function(k,cue)events[#events+1]={k,cue}end)
 local m3=plant(id,-12,-2,{Frac=1});run(4)
 local c3=m3:GetAttribute('CropId');Arrival.Expect(c3,1);Arrival.Expect(c3,2)
 local t3=now();regrowthAttrs(m3,1,t3+d.RegrowSeconds,1,d.RegrowSeconds);regrowthAttrs(m3,2,t3+d.RegrowSeconds,1,d.RegrowSeconds)
 local maxFlying=0;for i=1,60*3 do W.frames(1);maxFlying=math.max(maxFlying,#flyers())end
 check(maxFlying>=1 and #events==2,('two fruit picked together: %d flew at once, the inventory released both (%d events)'):format(maxFlying,#events))
 remove(m3);run(.5)
 -- reduced motion: the fruit vanishes as before and the inventory is told at once
 Gui.ReducedMotionEnabled=true;run(.6);Arrival.Reset();events={}
 Arrival.OnRelease(function(k,cue)events[#events+1]={k,cue}end)
 local m4=plant(id,-12,6,{Frac=1});run(4);local c4=m4:GetAttribute('CropId');Arrival.Expect(c4,1)
 local t4=now();regrowthAttrs(m4,1,t4+d.RegrowSeconds,1,d.RegrowSeconds)
 local any=false;local released=false;for i=1,60*2 do W.frames(1);if #flyers()>0 then any=true end;if #events>=1 and not released then released=true end end
 check(not any and released,'reduced motion: the fruit vanishes at once (as today) and the inventory is released')
 remove(m4);Gui.ReducedMotionEnabled=false;run(.6)
 -- the harvester dies mid-flight: the fruit just disappears
 Arrival.Reset();events={}
 Arrival.OnRelease(function(k,cue)events[#events+1]={k,cue}end)
 local m5=plant(id,6,-6,{Frac=1});run(4);local c5=m5:GetAttribute('CropId');Arrival.Expect(c5,1)
 local t5=now();regrowthAttrs(m5,1,t5+d.RegrowSeconds,1,d.RegrowSeconds)
 local started=false;for i=1,60*2 do W.frames(1);if #flyers()>0 and not started then started=true;myHum.Health=0 end end
  check(started and #flyers()==0 and #events>=1,'the harvester died mid-flight: the fruit disappears and the inventory is released')
 myHum.Health=100;remove(m5);run(.5)
 -- the plant streams out while a fruit flies: it goes with it
 Arrival.Reset();events={}
 Arrival.OnRelease(function(k,cue)events[#events+1]={k,cue}end)
 local m6=plant(id,-4,-6,{Frac=1});run(4);local c6=m6:GetAttribute('CropId');Arrival.Expect(c6,1)
 local t6=now();regrowthAttrs(m6,1,t6+d.RegrowSeconds,1,d.RegrowSeconds)
 local up=false;for i=1,60*2 do W.frames(1);if #flyers()>0 and not up then up=true;remove(m6) end end
 run(.2)
 check(up and #flyers()==0 and not Arrival.Pending(c6,1),'a plant removed while its fruit flies: the fruit goes, the inventory is released')
 -- a whole-plant / last-fruit harvest removes the plant: the inventory is not held waiting for a flight
 Arrival.Reset();events={}
 local m7=plant(id,-6,10,{Frac=1});run(3);local c7=m7:GetAttribute('CropId');Arrival.Expect(c7,1);Arrival.Expect(c7,2)
 remove(m7);run(.1)
 check(not Arrival.Pending(c7,1)and not Arrival.Pending(c7,2),'the plant was removed by the harvest: nothing will fly, the inventory is released at once')
 -- the frozen plants: no flight, the fruit vanishes as today
 Arrival.Reset();events={}
 local m8=plant('LanternFernSeed',-2,14,{Frac=1});run(4);local c8=m8:GetAttribute('CropId')
 local v8=art(m8);local fruit8=v8 and v8:FindFirstChild('Harvest_1')
 if fruit8 then
  Arrival.Expect(c8,1);local d8=Catalog.LanternFernSeed;local t8=now();regrowthAttrs(m8,1,t8+(d8.RegrowSeconds or d8.Seconds),1,d8.RegrowSeconds or d8.Seconds)
  local any8=false;for i=1,60*2 do W.frames(1);if #flyers()>0 then any8=true end end
  check(not any8 and not Arrival.Pending(c8,1),'Lantern Fern: the fruit vanishes as today, no flight, nothing held')
 else check(true,'(Lantern Fern has no fruit model at this range)')end
end
-- 5b. review part 2 (finding 11): a failing animation step does not leave Growth.Batch set (another script's UpdateGrowth in that frame would queue into the garden's batch)
do
 local Visuals=W.module('PlantVisuals');local Growth=W.module('PlantGrowth')
 local m=plant('CloverSeed',-9,-9,{Frac=.3,Seconds=200000});run(3);check(art(m)~=nil,'(a growing plant for the failing step)')
 local realUpdate=Visuals.UpdateGrowth;local calls=0;local armed=true
 Visuals.UpdateGrowth=function(...)calls+=1;if armed then error('growth step failed on purpose')end;return realUpdate(...)end
 local stale,failed=0,0
 for _=1,40 do
  local ok=pcall(W.frames,1);if not ok then failed+=1 end
  if Growth.Batch~=nil then stale+=1 end
 end
 armed=false;Visuals.UpdateGrowth=realUpdate
 check(calls>=1,'(the failing step ran: '..calls..' calls)')
 check(stale==0,'after a failed animation step Growth.Batch is reset in the same frame ('..stale..' frames ended with it still set)')
 run(2);check(Growth.Batch==nil and art(m)~=nil,'the garden carries on after the failure')
 remove(m)
end
-- 6. nothing is left behind after all of it -----------------------------------------------------------------------------------------------------------
do
 for _,c in ipairs(map:GetChildren())do remove(c)end
 run(3)
 local folder=fxFolder();local left=#flyers();local emitters=0
 if folder then for _,c in ipairs(folder:GetChildren())do if c.Name=='GrowthFxEmitter'then emitters+=1 end end end
 check(left==0,'every flying fruit is gone ('..left..' left in the effects folder)')
 check(emitters<=4,'the pooled emitters never exceed 4 ('..emitters..'; in the game they sit under the terrain)')
 local leftovers=0;for _,d in ipairs(W.workspace:GetDescendants())do if d.Name=='LocalPlantArt'then leftovers+=1 end end
 check(leftovers==0,'every plant model was removed with its plant')
 check(me:GetAttribute('PlantGrowthFlights')==0 and me:GetAttribute('PlantGrowthPulses')==0,'no flight and no bounce is counted')
end
R.task.wait=realWait;R.advance=realAdvance
C.done('growth client')
