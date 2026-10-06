--!nocheck
-- R149 growth style: #7 (ripe bounce + glints) and #8 (the picked fruit floats into the harvesting player; owner's change to the harvest pop) on the Roblox
-- mock with the REAL PlantGrowthFx, HarvestArrival, PlantAnimationBatch, PlantGrowth and PlantCatalog:
--  1. the numbers: budgets per quality tier (the ripe moment is off on the lowest tier; R151: the harvest flight of the player's own fruit is not; everything is
--     off with reduced motion and with the Studio effects switch off), the bounce curve (+10 %, back, settle at 0.8 s), the flight curve (eased, an arc, shrinks to
--     55 %, a big fruit to about 1.3 studs), the flight time (0.4 - 0.7 s);
--  2. ripe cues: once per ripening, at most 6 per 2 s over the whole garden, a gap between plants, the tier's number of bouncing fruit, at most 4 shared
--     emitters, near-and-on-screen plants only, the excluded plants never; the bounce restores sizes and poses exactly (also when settled early);
--  3. harvest flights: the fruit's OWN parts fly (no clone) to the harvester's character along an arc, follow it when it moves, shrink, vanish on arrival and
--     tell HarvestArrival; other players see the same flight to the garden owner; cap of 8 at once (parts too; R151: the rest fly as balls, up to 16, then
--     vanish), cleanup when the harvester dies / leaves, when the plant streams out, on Destroy: nothing is left in the world; no connection per fruit; Gold /
--     Diamond / giant fruit keep their look. R151: a fruit of up to 200 parts flies as it is, a bigger one as a ball; a plant with motion of its own (Lantern Fern,
--     Amethyst Grape, ...) flies as a detached copy; (the whole-garden test is test_fruit_flight.luau: every seed, every path).
local C=require('./growth_common');local W,R,V3,CF=C.W,C.R,C.V3,C.CF;local check,near=C.check,C.near
local Catalog=C.Catalog
local FxM=W.module('PlantGrowthFx');local Arrival=W.module('HarvestArrival');local Batch=W.module('PlantAnimationBatch')
local Players=W.service('Players');local Gui=W.service('GuiService');local Run=W.service('RunService')
local CFrame=R.CFrame
-- players ---------------------------------------------------------------------------------------------------------------------------------------------
local me=R.new('Player');me.Name='Tester';me.UserId=5;me.Parent=Players;Players.LocalPlayer=me
local other=R.new('Player');other.Name='Other';other.UserId=6;other.Parent=Players
local byId={[5]=me,[6]=other}
Players.GetPlayerByUserId=function(_,id)return byId[id]end
local function character(player,at)
 local model=R.new('Model');model.Name=player.Name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(at.X,at.Y,at.Z);root.Parent=model
 local hum=R.new('Humanoid');hum.Name='Humanoid';hum.Health=100;hum.Parent=model
 model.Parent=W.workspace;player.Character=model;return model,root,hum
end
local myChar,myRoot,myHum=character(me,V3(0,3,0))
local otherChar,otherRoot,otherHum=character(other,V3(30,3,10))
W.workspace.CurrentCamera.CFrame=CF(0,20,-30)
local function frames(n,dt)for _=1,n do R.advance(dt or 1/60)end end
local function newFx()return FxM.new({Parent=W.workspace})end
-- a plant record, a fruit model of `n` parts at `at` (world), the crop and the garden item model
local counter=0
local function plant(seedId,at)
 counter+=1
 local item=R.new('Model');item.Name='Crop_'..counter;item:SetAttribute('GardenOwnerId',5);item.Parent=W.workspace
 local crop=C.crop(seedId,{Id='fx-'..counter})
 local r={Origin=CF(at.X,at.Y,at.Z),Item=item}
 return r,crop,item
end
local function fruit(at,n,mutation)
 local m=R.new('Model');m.Name='Harvest_1'
 for i=1,n do
  local p=R.new('Part');p.Name='fruit part '..i;p.Size=V3(.6+.05*i,.6,.6);p.CFrame=CF(at.X+(i-1)%3*.4-.4,at.Y+math.floor((i-1)/3)*.4,at.Z)
  p.Color=mutation=='Gold'and R.Color3.fromRGB(232,172,57)or R.Color3.fromRGB(200,40+i,40);p.Material=mutation=='Gold'and R.Enum.Material.Metal or R.Enum.Material.Neon;p.CanQuery=true;p.Parent=m
 end
 m.Parent=W.workspace;return m
end
local function count(root)return #root:GetDescendants()end
-- 1. the numbers -----------------------------------------------------------------------------------------------------------------------------------
do
 local B=FxM.Budget
 for tier=1,3 do check(B(tier,true,false)==FxM.Off and B(tier,false,true)==FxM.Off,'tier '..tier..': reduced motion and the Studio effects switch turn everything off')end
 check(B(1,false,false).Pulses==0 and B(1,false,false).Sparks==0 and B(1,false,false).Range==0,'the lowest quality tier: no bounce, no glints, nothing for observers')
 check(B(1,false,false).Flights>=1 and B(1,false,false).Flights<=2 and B(1,false,false).Tokens>=1,'... but your own picked fruit still flies there (R151), in a small budget')
 check(B(2,false,false).Pulses>=1 and B(2,false,false).Flights>=1 and B(2,false,false).Flights<=8,'tier 2 (phones): reduced budgets')
 check(B(3,false,false).Pulses<=4 and B(3,false,false).Flights<=8 and B(3,false,false).Sparks<=4,'tier 3: at most 4 fruit bouncing, 8 flying, a few glints')
 check(B(2,false,false).Pulses<=B(3,false,false).Pulses and B(2,false,false).Flights<=B(3,false,false).Flights,'a phone never gets more than the best tier')
 check(B(nil,false,false)==B(3,false,false)and B(9,false,false)==B(3,false,false)and B(-4,false,false)==B(1,false,false),'a missing or silly tier is clamped')
 -- the bounce: +10 %, back below 1, settle, 0.8 s, once
 check(FxM.Bounce(-1)==1 and FxM.Bounce(0)==1 and FxM.Bounce(.8)==1 and FxM.Bounce(5)==1,'Bounce: 1 before, at the start and from 0.8 s on')
 local peak,peakAt,low=1,0,1;for i=0,800 do local s=FxM.Bounce(i/1000);if s>peak then peak=s;peakAt=i/1000 end;if s<low then low=s end end
 check(peak>1.09 and peak<1.12 and peakAt>.08 and peakAt<.22,('Bounce peaks at +%.1f %% at %.2f s'):format((peak-1)*100,peakAt))
 check(low<1 and low>.94,('... dips to %.3f ("back") and settles'):format(low))
 local crossings,sign=0,0;for i=1,799 do local s=FxM.Bounce(i/1000)-1;local sg=s>1e-4 and 1 or s<-1e-4 and-1 or 0;if sg~=0 and sg~=sign then crossings+=1;sign=sg end end
 check(crossings<=3,'Bounce: one bounce (+, -, +), never a loop ('..crossings..' phases)')
 -- the flight
 local e0,a0,s0=FxM.Flight(0);local e1,a1,s1=FxM.Flight(1);local em,am,sm=FxM.Flight(.5)
 check(near(select(3,FxM.Flight(1,.2)),.2,1e-9)and FxM.Shrink(.5)==FxM.Tuning.ShrinkTo and near(FxM.Shrink(13),FxM.Tuning.EndRadius/13,1e-9)and FxM.Shrink(1e6)>=.04,'Flight(u,shrink): a small fruit ends at '..FxM.Tuning.ShrinkTo..', a big one (Verity\'s 13-stud ball) at about '..FxM.Tuning.EndRadius..' studs')
 check(e0==0 and e1==1 and a0==0 and near(a1,0,1e-9)and near(am,1,1e-9)and s0==1 and near(s1,FxM.Tuning.ShrinkTo,1e-9),'Flight: from 0 to 1, an arc that peaks in the middle, from full size to '..FxM.Tuning.ShrinkTo)
 local mono=true;local pe,ps=0,1;for i=0,100 do local e,_,s=FxM.Flight(i/100);if e<pe-1e-12 or s>ps+1e-12 then mono=false end;pe,ps=e,s end
 check(mono and em>.4 and em<.6,'Flight: the way grows and the size shrinks steadily, eased in and out')
 check(FxM.FlightSeconds(0)==.4 and FxM.FlightSeconds(5)>=.4 and FxM.FlightSeconds(5)<=.7 and FxM.FlightSeconds(500)==.7,'Flight takes 0.4 - 0.7 s (longer for a longer way)')
 check(FxM.Tuning.CueMax==6 and FxM.Tuning.CueWindow==2 and FxM.Tuning.EmitterCount==4,'limits: 6 cues per 2 s, 4 shared emitters')
 for _,id in ipairs({'LanternFernSeed','AmethystSeed','StarfruitSeed','ObsidianMawSeed','SilentFrostbellSeed','OrbitLotusSeed','SupernovaBloomSeed'})do check(not FxM.Eligible(C.crop(id))and not FxM.OwnParts(C.crop(id))and FxM.CanFly(C.crop(id)),id..': its own parts are never moved (no ripe bounce, its picked fruit flies as a copy), but its fruit flies (R151)')end
 local mechId,verityId;for id,d in pairs(Catalog)do if type(d)=='table'then if d.Mech and not mechId then mechId=id end;if d.Verity and not verityId then verityId=id end end end
 check((not mechId or(not FxM.Eligible(C.crop(mechId))and FxM.CanFly(C.crop(mechId))))and(not verityId or(not FxM.Eligible(C.crop(verityId))and FxM.CanFly(C.crop(verityId)))),'Mech holograms and Verity: their own parts are never moved, their picked fruit flies as a copy (R151)')
 local everyone=true;for id,d in pairs(Catalog)do if type(d)=='table'and d.Seconds and not FxM.CanFly(C.crop(id))then everyone=false end end
 check(everyone and not FxM.CanFly(nil)and not FxM.CanFly({SeedId='NoSuchSeed'}),'R151: CanFly is true for every seed of the catalog (and only for them)')
 check(FxM.Eligible(C.crop('AppleSeed'))and FxM.Eligible(C.crop('AshRoseSeed'))and FxM.Eligible(C.crop('SunflowerSeed')),'the Apple, the Ash Tomato and the Watermelon take part')
end
-- 2. ripe cues -------------------------------------------------------------------------------------------------------------------------------------
do
 local fx=newFx()
 local r,crop=plant('AppleSeed',V3(0,0,0));local child=fruit(V3(0,5,0),8)
 check(fx:Ripe(r,child,1,crop,0)==true,'a ripe fruit near the camera cues')
 check(#fx.Pulses==1 and fx.Stats.Cues==1,'... with one bounce')
 check(fx:Ripe(r,child,1,crop,0)==false and fx.Stats.Cues==1,'... once per ripening (the same fruit and cycle again: nothing)')
 check(fx:Ripe(r,child,1,crop,1)==true,'... the next ripening of that slot cues again')
 -- the bounce itself
 local batch=Batch.new(W.workspace)
 local pulse=fx.Pulses[1];local sizes,frames0={},{}
 for i,e in ipairs(pulse.Parts)do sizes[i]=e.Size;frames0[i]=e.Part.CFrame end
 frames(12,.016)
 fx:StepBounces(batch);check(#batch.Parts==#pulse.Parts,'the bounce queues every part of the fruit in the animation batch ('..#batch.Parts..')')
 local s=FxM.Bounce(R.clock-pulse.Start);local ok=true
 for i,e in ipairs(pulse.Parts)do local want=sizes[i]*s;if math.abs(e.Part.Size.X-want.X)>1e-9 then ok=false end end
 check(ok and s~=1,('part sizes follow the curve (x%.3f)'):format(s))
 batch:Flush()
 R.advance(.9);fx:StepBounces(batch);batch:Flush()
 local exact=#fx.Pulses==0
 for i,e in ipairs(pulse.Parts)do if e.Part.Size~=sizes[i]then exact=false end;local a,b={e.Part.CFrame:GetComponents()},{frames0[i]:GetComponents()};for k=1,12 do if math.abs(a[k]-b[k])>1e-9 then exact=false end end end
 check(exact,'after 0.8 s every part is back at exactly its size and place, and the bounce is gone')
 -- settled early (the plant is rebuilt mid-bounce): parts at rest at once
 local r2,crop2=plant('AppleSeed',V3(0,0,0));local c2=fruit(V3(2,5,0),6);R.advance(3)
 check(fx:Ripe(r2,c2,1,crop2,0),'(another plant, 3 s later)')
 local base2={};for i,e in ipairs(fx.Pulses[#fx.Pulses].Parts)do base2[i]=e.Size end
 frames(8,.016);fx:StepBounces(batch);batch:Flush()
 fx:Settle(r2);local settled=#fx.Pulses==0
 local sizesOk=true;for i,p in ipairs(c2:GetChildren())do if p.Size~=base2[i]then sizesOk=false end end
 check(settled and sizesOk,'Settle ends a bounce at once: sizes restored (a rig is only ever captured from the rest pose)')
 -- the limits
 local fx2=newFx();R.advance(10)
 local accepted=0
 for i=1,20 do local rr,cc=plant('AppleSeed',V3(0,0,0));local m=fruit(V3(0,5,0),4);if fx2:Ripe(rr,m,1,cc,0)then accepted+=1 end end
 check(accepted<=1,('a gap between plants: 20 plants at the same instant give %d cue'):format(accepted))
 local rr,cc=plant('AppleSeed',V3(0,0,0));local accepted2=0
 for i=1,12 do local m=fruit(V3(0,5,0),4);if fx2:Ripe(rr,m,i,cc,0)then accepted2+=1 end end
 check(accepted2+accepted<=6,('at most 6 cues in 2 s over the garden (%d given)'):format(accepted+accepted2))
 check(#fx2.Pulses<=4,'at most 4 fruit bouncing at once ('..#fx2.Pulses..')')
 local emitters=0;for _,e in ipairs(fx2.Emitters)do emitters+=1 end
 check(emitters<=4,'at most 4 shared particle emitters ('..emitters..')')
 R.advance(2.1)
 local acc3=0
 for i=1,12 do local p2,c2b=plant('AppleSeed',V3(0,0,0));local m=fruit(V3(0,5,0),4);if fx2:Ripe(p2,m,1,c2b,0)then acc3+=1 end;R.advance(.19)end
 check(acc3>=4 and acc3<=6+1,('the window slides: 12 plants 0.19 s apart over 2.3 s give %d cues (never more than 6 in any 2 s)'):format(acc3))
 -- the glints never keep emitting
 for _,e in ipairs(fx2.Emitters)do check(e.Spark.Rate==0 and e.Spark.Enabled==false,'an emitter only bursts: Rate 0, Enabled false')end
 -- not near / not on screen / excluded plants / modes
 local fx3=newFx();R.advance(5)
 local far,cfar=plant('AppleSeed',V3(0,0,300));check(fx3:Ripe(far,fruit(V3(0,5,300),4),1,cfar,0)==false,'a plant 300 studs away: no cue')
 R.advance(1)
 local off,coff=plant('AppleSeed',V3(0,0,0));off.Entry={OnScreen=false};check(fx3:Ripe(off,fruit(V3(0,5,0),4),1,coff,0)==false,'a plant the scheduler says is off screen: no cue')
 R.advance(1)
 for _,id in ipairs({'LanternFernSeed','AmethystSeed','StarfruitSeed'})do
  local pp,cp=plant(id,V3(0,0,0));check(fx3:Ripe(pp,fruit(V3(0,5,0),4),1,cp,0)==false,id..': no cue');R.advance(1)
 end
 Gui.ReducedMotionEnabled=true;local fx4=newFx();R.advance(1)
 local rm,crm=plant('AppleSeed',V3(0,0,0));check(fx4:Ripe(rm,fruit(V3(0,5,0),4),1,crm,0)==false and #fx4.Pulses==0 and #fx4.Emitters==0,'reduced motion: no cue, no bounce, no emitter')
 Gui.ReducedMotionEnabled=false
 local fx5=newFx();fx5:SetMode('low');R.advance(1)
 local lo,clo=plant('AppleSeed',V3(0,0,0));check(fx5:Ripe(lo,fruit(V3(0,5,0),4),1,clo,0)==false and #fx5.Pulses==0,'low quality: no cue')
 fx5:SetMode('off');R.advance(1);check(fx5:Ripe(lo,fruit(V3(0,5,0),4),2,clo,0)==false,'effects off: no cue')
 fx5:SetMode('normal');R.advance(1);check(fx5:Ripe(lo,fruit(V3(0,5,0),4),3,clo,0)==true,'... and back to normal: cues again')
 -- a whole plant (no fruit model): glints only
 local fx6=newFx();R.advance(5)
 local wr,wc=plant('AppleSeed',V3(0,0,0));check(fx6:Ripe(wr,nil,1,wc,0)==true and #fx6.Pulses==0,'a whole-plant cue: glints, no bounce')
 for _,f in ipairs({fx,fx2,fx3,fx4,fx5,fx6})do f:Destroy()end
 check(W.workspace:FindFirstChild('LocalPlantGrowthFx')==nil,'Destroy removes the folder')
end
-- 3. harvest flights -------------------------------------------------------------------------------------------------------------------------------
do
 Arrival.Reset()
 local fx=newFx();R.advance(5)
 local heartbeats=#Run.Heartbeat._c
 -- one fruit, to the local player
 local r,crop,item=plant('AppleSeed',V3(6,0,4));local m=fruit(V3(6,5,4),9);local descendantsBefore=count(W.workspace)
 local start={};for i,p in ipairs(m:GetChildren())do start[i]=p.CFrame.Position end
 local sizes={};for i,p in ipairs(m:GetChildren())do sizes[i]=p.Size end
 local released={};Arrival.OnRelease(function(k,cue)released[#released+1]={k,cue}end)
 Arrival.Expect(crop.Id,1)
 check(fx:Harvest(r,m,1,crop,item)==true,'a picked ripe fruit flies')
 check(m.Parent==fx.Folder and #fx.Flights==1,'the fruit\'s OWN model flies (reparented, no clone)')
 check(count(W.workspace)==descendantsBefore,'no new part was made ('..count(W.workspace)..' against '..descendantsBefore..')')
 local flight=fx.Flights[1];check(flight.Seconds>=.4 and flight.Seconds<=.7,('it takes %.2f s'):format(flight.Seconds))
 check(Arrival.Pending(crop.Id,1),'HarvestArrival knows it is flying')
 -- half way: between the plant and the player, above the straight line (an arc), smaller
 local centre0=V3(0,0,0);for _,v in ipairs(start)do centre0=centre0+v end;centre0=centre0/#start
 local t0=R.clock
 while R.clock-t0<flight.Seconds*.5 do R.advance(1/60);fx:StepFrame()end
 local ps=m:GetChildren();local c=V3(0,0,0);for _,p in ipairs(ps)do c=c+p.CFrame.Position end;c=c/#ps
 local aim=myRoot.Position+V3(0,FxM.Tuning.AimUp,0)
 local total=(aim-centre0).Magnitude;local done=(c-centre0).Magnitude
 check(done>total*.25 and done<total*.8,('half way through it is half way there (%.0f %%)'):format(done/total*100))
 local straight=centre0+(aim-centre0)*((c-centre0):Dot(aim-centre0)/(total*total))
 check(c.Y>straight.Y+.3,'... and above the straight line (an arc)')
 local ratio=ps[1].Size.X/sizes[1].X;check(ratio<.95 and ratio>.55,('... and smaller (x%.2f)'):format(ratio))
 -- R153 (owner: "fix all jittery type effects"): it shrinks on every frame (the size was written every other frame: a 30 Hz stutter)
 do local same,last=0,ps[1].Size.X;for _=1,6 do R.advance(1/60);fx:StepFrame();if ps[1].Size.X==last then same+=1 end;last=ps[1].Size.X end
  check(same==0,'R153: ... shrinking on every frame ('..same..' of 6 frames kept the last size)')end
 -- the harvester moves: the fruit follows
 myRoot.CFrame=CF(3,3,-6)
 while R.clock-t0<flight.Seconds*.97 do R.advance(1/60);fx:StepFrame()end
 ps=m:GetChildren()
 if #ps>0 then
  c=V3(0,0,0);for _,p in ipairs(ps)do c=c+p.CFrame.Position end;c=c/#ps
  local newAim=myRoot.Position+V3(0,FxM.Tuning.AimUp,0)
  check((c-newAim).Magnitude<1.3,('it follows the player who moved (%.2f studs from them just before the end)'):format((c-newAim).Magnitude))
 end
 while #fx.Flights>0 and R.clock-t0<2 do R.advance(1/60);fx:StepFrame()end
 check(#fx.Flights==0 and m.Parent==nil,'on arrival the fruit vanishes')
 check(count(W.workspace)==descendantsBefore-#start-1,'... and leaves nothing behind ('..count(W.workspace)..' descendants, '..tostring(descendantsBefore-#start-1)..' expected)')
 check(#released==1 and released[1][2]==true and not Arrival.Pending(crop.Id,1),'HarvestArrival is told when it arrives (cue = true)')
 check(R.clock-t0<=.75,('... within 0.7 s of the pick (%.2f s)'):format(R.clock-t0))
 check(#Run.Heartbeat._c==heartbeats,'no connection per fruit (the module has none; GardenVisuals steps it once a frame)')
 myRoot.CFrame=CF(0,3,0)
 -- the cap
 local accepted,refused,real,balls=0,0,0,0;local flyers={}
 for i=1,30 do
  local rr,cc,it=plant('AppleSeed',V3(i,0,4));local mm=fruit(V3(i,5,4),6);Arrival.Expect(cc.Id,1)
  if fx:Harvest(rr,mm,1,cc,it)then accepted+=1;if mm.Parent==fx.Folder then real+=1;flyers[#flyers+1]=mm else balls+=1;check(mm.Parent==nil,'a fruit that flies as a ball is not left on the plant (this module owns its model)')end
  else refused+=1;check(mm.Parent==W.workspace and not Arrival.Pending(cc.Id,1),'a refused fruit is left to the caller and the inventory is told at once');mm:Destroy()end
 end
 check(real==8 and balls==16 and refused==6 and fx.Real==8 and fx.Tokens==16,('at most 8 fruit fly as they are, the next 16 as balls, the rest just vanish and the inventory is told: %d + %d, %d vanish'):format(real,balls,refused))
 -- (R151) a fruit of many parts flies as it is up to FlightMaxParts, a bigger one as a ball; the part budget decides too
 do
  fx:Destroy();fx=newFx();R.advance(5);flyers={}
  local rr,cc,it=plant('AppleSeed',V3(0,0,4));local big=fruit(V3(0,5,4),60);Arrival.Expect(cc.Id,1);check(fx:Harvest(rr,big,1,cc,it)and big.Parent==fx.Folder and not fx.Flights[1].Ball,'a fruit of 60 parts flies as it is (R149 let it vanish)')
  fx:Destroy();fx=newFx();R.advance(5)
  local r2,c2,i2=plant('AppleSeed',V3(0,0,4));local huge=fruit(V3(0,5,4),FxM.Tuning.FlightMaxParts+1);Arrival.Expect(c2.Id,1)
  check(fx:Harvest(r2,huge,1,c2,i2)and huge.Parent==nil and fx.Flights[1].Ball==true and #fx.Flights[1].Parts==1,'a fruit of more than '..FxM.Tuning.FlightMaxParts..' parts flies as ONE ball (its model is gone, nothing vanishes)')
  fx:Destroy();fx=newFx();R.advance(5)
  local sum=0;local flyers2={};local each=FxM.Budget(3,false,false).FlightParts/4
  for i=1,5 do local rr3,cc3,it3=plant('AppleSeed',V3(i,0,4));local m3=fruit(V3(i,5,4),each);Arrival.Expect(cc3.Id,1);fx:Harvest(rr3,m3,1,cc3,it3);flyers2[#flyers2+1]=m3 end
  local flyingAsModels=0;for _,m3 in ipairs(flyers2)do if m3.Parent==fx.Folder then flyingAsModels+=1;sum+=each end end
  check(sum<=FxM.Budget(3,false,false).FlightParts and #fx.Flights==5 and flyingAsModels==4,('the part budget (%d) decides: of five %d-part fruit %d fly as models (%d parts), the fifth as a ball'):format(FxM.Budget(3,false,false).FlightParts,each,flyingAsModels,sum))
  fx:Destroy();fx=newFx();R.advance(5);flyers={}
  for i=1,3 do local r4,c4,i4=plant('AppleSeed',V3(i,0,4));local m4=fruit(V3(i,5,4),6);Arrival.Expect(c4.Id,1);if fx:Harvest(r4,m4,1,c4,i4)then flyers[#flyers+1]=m4 end end
  check(#flyers==3 and #fx.Flights==3,'(three fruit in the air for the next checks)')
 end
 -- cleanup: the harvester dies
 myHum.Health=0;R.advance(1/60);fx:StepFrame()
 check(#fx.Flights==0,'the harvester died: every flight is dropped')
 for _,mm in ipairs(flyers)do check(mm.Parent==nil,'... and its fruit just disappears')end
 myHum.Health=100
 -- Gold / Diamond fruit keep their look while they fly; a giant one too
 local rr,cc,it=plant('AppleSeed',V3(2,0,4));local gold=fruit(V3(2,5,4),8,'Gold');for _,p in ipairs(gold:GetChildren())do p.Size=p.Size*6 end
 local colors,mats,sz={},{},{};for i,p in ipairs(gold:GetChildren())do colors[i]=p.Color;mats[i]=p.Material;sz[i]=p.Size end
 Arrival.Expect(cc.Id,1);check(fx:Harvest(rr,gold,1,cc,it),'a Gold, giant fruit flies')
 local looks=true;local t1=R.clock
 while #fx.Flights>0 and R.clock-t1<1 do R.advance(1/60);fx:StepFrame()
  for i,p in ipairs(gold:GetChildren())do if p.Color~=colors[i]or p.Material~=mats[i]then looks=false end end
 end
 check(looks,'its colours and materials never change on the way (only its size and place)')
 -- an observer: another player's garden; the fruit flies to THEM (the garden's owner), and only when near the camera
 local ro,co,io=plant('AppleSeed',V3(18,0,2));io:SetAttribute('GardenOwnerId',6);local mo=fruit(V3(18,5,2),6);Arrival.Expect(co.Id,1)
 check(fx:Harvest(ro,mo,1,co,io)==true,'another player picks a fruit in view: it flies too')
 local ot=R.clock;local lastC
 while #fx.Flights>0 and R.clock-ot<1 do R.advance(1/60);fx:StepFrame();local ps2=mo:GetChildren();if #ps2>0 then lastC=ps2[1].CFrame.Position end end
 check(lastC and(lastC-(otherRoot.Position+V3(0,FxM.Tuning.AimUp,0))).Magnitude<2.5,'... towards the owner of that garden, not towards me')
 local rf,cf,itf=plant('AppleSeed',V3(0,0,300));itf:SetAttribute('GardenOwnerId',6);local mf=fruit(V3(0,5,300),6);check(not fx:Harvest(rf,mf,1,cf,itf),'a pick far from the camera (not mine): no flight');mf:Destroy()
 local rg,cg,ig=plant('AppleSeed',V3(0,0,0));ig:SetAttribute('GardenOwnerId',99);local mg=fruit(V3(0,5,0),6);check(not fx:Harvest(rg,mg,1,cg,ig),'an owner who is not in the game: no flight');mg:Destroy()
 local rh,ch,ih=plant('AppleSeed',V3(0,0,0));local mh=fruit(V3(0,5,0),6);check(not fx:Harvest(rh,mh,1,ch,nil),'no garden item: no flight');mh:Destroy()
 -- the plant streams out (Clear without keep): its flights vanish; a rebuild (keep) leaves them in the air
 local rs,cs,is=plant('AppleSeed',V3(5,0,5));local ms=fruit(V3(5,5,5),5);Arrival.Expect(cs.Id,1);fx:Harvest(rs,ms,1,cs,is)
 fx:Clear(rs,true);check(#fx.Flights==1 and ms.Parent==fx.Folder,'a rebuild of the plant leaves a fruit in the air')
 fx:Clear(rs);check(#fx.Flights==0 and ms.Parent==nil and not Arrival.Pending(cs.Id,1),'a plant that streams out takes its flights with it, and the inventory is told')
 -- (R151) the plants whose own parts are never moved (Lantern Fern, Amethyst Grape, rigs, holograms, Verity): their picked fruit flies as a COPY built where it hung;
 -- their own model is destroyed at once, as it always was (nothing of the plant's motion systems ever touches the flying parts)
 for _,id in ipairs({'LanternFernSeed','AmethystSeed'})do
  local rf2,cf2,if2=plant(id,V3(0,0,4));local mf2=fruit(V3(0,5,4),5);Arrival.Expect(cf2.Id,1);local before2=#fx.Flights
  check(fx:Harvest(rf2,mf2,1,cf2,if2)==true and #fx.Flights==before2+1 and mf2.Parent==nil and Arrival.Pending(cf2.Id,1),id..': the picked fruit flies (a copy; its own model is destroyed here, not moved)')
  local fl=fx.Flights[#fx.Flights];check(fl.Model.Parent==fx.Folder and fl.Model~=mf2 and #fl.Parts>=2 and not fl.Ball,id..': the flying copy is a fruit model of '..#fl.Parts..' parts in the effects folder')
  check(fx.Stats.Copies>=1,'... counted as a copy')
 end
 Gui.ReducedMotionEnabled=true;R.advance(.3)
 local rr3,cc3,it3=plant('AppleSeed',V3(0,0,4));local m3=fruit(V3(0,5,4),5);Arrival.Expect(cc3.Id,1)
 check(not fx:Harvest(rr3,m3,1,cc3,it3)and not Arrival.Pending(cc3.Id,1),'reduced motion: the fruit vanishes as today and the inventory is told at once');m3:Destroy()
 Gui.ReducedMotionEnabled=false;R.advance(.3)
 fx:Destroy()
 do
  local lowFx=newFx();lowFx:SetMode('low');R.advance(5)
  local rr4,cc4,it4=plant('AppleSeed',V3(0,0,4));local m4=fruit(V3(0,5,4),5);Arrival.Expect(cc4.Id,1)
  check(lowFx:Harvest(rr4,m4,1,cc4,it4)==true and Arrival.Pending(cc4.Id,1)and #lowFx.Flights==1,'low quality: your own fruit still flies (R149 let it vanish)')
  local ro4,co4,io4=plant('AppleSeed',V3(18,0,2));io4:SetAttribute('GardenOwnerId',6);local mo4=fruit(V3(18,5,2),5)
  check(lowFx:Harvest(ro4,mo4,1,co4,io4)==false,'... but another player\'s fruit (observers get no Range on the lowest tier) just goes');mo4:Destroy()
  for i=1,3 do local rx,cx,ix=plant('AppleSeed',V3(i,0,4));local mx=fruit(V3(i,5,4),5);Arrival.Expect(cx.Id,1);lowFx:Harvest(rx,mx,1,cx,ix);if mx.Parent~=nil and mx.Parent~=lowFx.Folder then mx:Destroy()end end
  check(lowFx.Real<=FxM.Budget(1,false,false).Flights and lowFx.Tokens<=FxM.Budget(1,false,false).Tokens,'... inside its own small budget ('..lowFx.Real..' models, '..lowFx.Tokens..' balls)')
  lowFx:Destroy()
 end
 fx=newFx();R.advance(5)
 -- no leak: Destroy with fruit in the air
 local rl,cl,il=plant('AppleSeed',V3(4,0,4));local ml=fruit(V3(4,5,4),5);Arrival.Expect(cl.Id,1);fx:Harvest(rl,ml,1,cl,il)
 fx:Destroy();check(ml.Parent==nil and not Arrival.Pending(cl.Id,1) and W.workspace:FindFirstChild('LocalPlantGrowthFx')==nil,'Destroy with a fruit in the air: gone, inventory told, folder removed')
 check(fx:Harvest(rl,ml,1,cl,il)==false and fx:Ripe(rl,nil,1,cl,0)==false,'a destroyed director refuses everything (no error)')
 -- a failing step is contained: three errors switch it off
 local fx7=newFx();R.advance(5)
 local r7,c7,i7=plant('AppleSeed',V3(0,0,4));local m7=fruit(V3(0,5,4),5);Arrival.Expect(c7.Id,1);fx7:Harvest(r7,m7,1,c7,i7)
 local warns=W.warns or 0
 fx7.Flights[1].Humanoid=setmetatable({},{__index=function()error('boom')end})
 for _=1,5 do R.advance(1/60);fx7:StepFrame()end
 check(fx7.Dead==true and not Arrival.Pending(c7.Id,1) and m7.Parent==nil,'three errors switch the director off, release the inventory and clean up')
end
-- 4. HarvestArrival on its own: a hold always ends -----------------------------------------------------------------------------------------------------
do
 Arrival.Reset();local log={}
 local conn=Arrival.OnRelease(function(k,cue)log[#log+1]=k..(cue and ':cue'or':quiet')end)
 local function tool(cropId,index)
  local t=R.new('Tool');t:SetAttribute('HarvestItemTool',true);t:SetAttribute('SourceCropId',cropId);t:SetAttribute('FruitIndex',index);return t
 end
 check(Arrival.ToolKey(R.new('Tool'))==nil and Arrival.Holds(R.new('Tool'))==false,'a tool that is no harvested item has no key and is never held')
 check(Arrival.Holds(tool('u1',1))==false,'nothing expected: nothing held (the fast path)')
 Arrival.Expect('u1',1);local t1=tool('u1',1)
 check(Arrival.Pending('u1',1) and Arrival.Holds(t1) and not Arrival.Holds(tool('u1',2)) and not Arrival.Holds(tool('u2',1)),'Expect holds exactly that plant and fruit slot')
 check(Arrival.Land('u1',1)==true and #log==1 and log[1]=='u1:1:cue' and not Arrival.Holds(t1),'Land releases it once, with a cue')
 check(Arrival.Land('u1',1)==false and #log==1,'... and a second Land does nothing')
 Arrival.Expect('u3',2);check(Arrival.Cancel('u3',2)==true and log[2]=='u3:2:quiet','Cancel releases it without a cue')
 Arrival.Expect('u4',1);Arrival.Expect('u4',2);Arrival.Expect('u5',1)
 Arrival.LandCrop('u4');check(not Arrival.Pending('u4',1)and not Arrival.Pending('u4',2)and Arrival.Pending('u5',1),'LandCrop releases every slot of that plant and no other')
 Arrival.Land('u5',1)
 -- (R151) a harvest that removes the plant starts its flights first: LandCrop must not cancel a fruit that is in the air; PendingIndexes lists a crop's open holds
 Arrival.Expect('w1',1);Arrival.Expect('w1',2);Arrival.Expect('w1',4);Arrival.Expect('w2',3);Arrival.Flying('w1',2,.5)
 check(table.concat(Arrival.PendingIndexes('w1'),',')=='1,2,4' and table.concat(Arrival.PendingIndexes('w2'),',')=='3' and #Arrival.PendingIndexes('nobody')==0,'PendingIndexes: the open holds of one crop, sorted, and no other crop\'s')
 Arrival.LandCrop('w1');check(not Arrival.Pending('w1',1)and not Arrival.Pending('w1',4)and Arrival.Pending('w1',2)and Arrival.Pending('w2',3),'LandCrop leaves a hold whose fruit is in the air (R151: the plant going away does not cancel its flight)')
 Arrival.Land('w1',2);Arrival.Land('w2',3)
 -- the deadline: a hold nobody releases ends by itself (1.5 s), a flight extends it to its own length + a little
 log={};Arrival.Expect('late',1);R.advance(1.2);check(Arrival.Pending('late',1) and #log==0,'an unreleased hold is still there at 1.2 s')
 R.advance(.5);check(not Arrival.Pending('late',1) and #log==1 and log[1]=='late:1:cue','... and ends at its deadline (1.5 s), with a cue')
 log={};Arrival.Expect('fly',1);R.advance(1);Arrival.Flying('fly',1,.6);R.advance(.7);check(Arrival.Pending('fly',1),'a flight that began extends the hold to its own length (still held at 1.7 s)')
 R.advance(.2);check(not Arrival.Pending('fly',1) and #log==1,'... and the timer releases it just after the flight should have ended')
 Arrival.Flying('nobody',1,.5);check(not Arrival.Pending('nobody',1),'Flying for a fruit nobody expected does nothing (an observer)')
 conn:Disconnect();log={};Arrival.Expect('g',1);Arrival.Land('g',1);check(#log==0,'a disconnected listener hears nothing')
 Arrival.Reset();check(not Arrival.Pending('g',1)and Arrival.Holds(tool('g',1))==false,'Reset clears everything')
 Arrival.Expect('r',1);Arrival.Reset();R.advance(2);check(not Arrival.Pending('r',1),'a timer that outlives a Reset releases nothing (and does not error)')
end
-- 4. review part 2 (finding 11): a picked Emberfruit / Fig fruit keeps its Neon coat while it flies; the plant's other fruit are restored as before ------------
do
 local Effects=W.module('ApprovedFruitEffects');local Enum=R.Enum
 for _,style in ipairs({'EmberLava','FigMagic'})do
  local model=R.new('Model');model.Parent=W.workspace
  local plain=R.Color3.fromRGB(120,60,40)
  local function group(index)
   local g=R.new('Model');g.Name='Harvest_'..index;g:SetAttribute('Mutation','None')
   local core=R.new('Part');core.Name=style=='FigMagic'and'Fig pear body'or'Emberfruit core';core.Size=V3(1,1,1);core.Color=plain;core.Material=Enum.Material.SmoothPlastic;core.Parent=g
   if style=='FigMagic'then local w=R.new('Part');w.Name='Fig rosy window';w.Size=V3(.4,.4,.4);w.Color=plain;w.Material=Enum.Material.SmoothPlastic;w.Parent=g end
   g.Parent=model;return g,style=='FigMagic'and g:FindFirstChild('Fig rosy window')or core
  end
  local g1,coated1=group(1);local g2,coated2=group(2)
  local cleanup=Effects.Start(model,style,nil,false,{Manual=true})
  check(coated1.Material==Enum.Material.Neon and coated2.Material==Enum.Material.Neon,style..': both fruit are coated Neon while the effect runs')
  -- the first fruit is picked and flies: it leaves the plant (PlantGrowthFx parents it to its own folder)
  local flying=R.new('Folder');flying.Parent=W.workspace;g1.Parent=flying
  local flyingColour=coated1.Color
  cleanup()
  check(coated1.Material==Enum.Material.Neon and coated1.Color==flyingColour,style..': the flying fruit keeps its Neon coat and colour when the effect ends (no snap mid-flight)')
  check(coated2.Material==Enum.Material.SmoothPlastic and coated2.Color==plain,style..': a fruit that stays on the plant is restored to its plain look')
  model:Destroy();flying:Destroy()
 end
end
C.done('growth fx')
