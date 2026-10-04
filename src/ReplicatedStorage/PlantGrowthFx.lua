-- R149 (phase 1 of docs/proposals/R149/growth_style.md, items #7 and #8): the two moments of the plant loop. Client-only and cosmetic: it never changes
-- saved crops, readiness, timing, prices, prompts or collision, and a plant looks right (just plainer) when it is switched off or fails.
--  Ripe     a fruit that has just become ripe bounces once (+10 %, back, settle, 0.8 s) and gives a few glints. Once per ripening, never looped.
--           Limits: at most CueMax cues per CueWindow seconds over the whole garden, a tier's number of fruit bouncing at once, 4 shared particle
--           emitters (short bursts, never left running), only plants near the camera and on screen. Stepped inside GardenVisuals' 20 Hz animation step.
--  Harvest  (owner: "it floats into the player and disappears after, and appears in the player's inventory") the picked fruit lifts off the plant and
--           floats along a short smooth arc to the harvesting player's character (following them if they move), shrinking a little, then vanishes
--           when it reaches them; HarvestArrival tells the inventory (Hotbar), which shows the item and bumps its slot at that moment. It reuses the
--           fruit's OWN parts (no clone, no new part), moved through one batch for all flights, stepped by ONE call per frame (no connection per
--           fruit); at most 8 fly at once, the rest just vanish as before. Other players see the same flight (the harvest replicates as the plant's
--           attributes, so every client's GardenVisuals sees the fruit go) towards the harvester, who is the garden's owner.
-- Both are off with the player's reduced-motion setting, on the lowest quality tier and with the Studio effects switch off (then a harvested fruit
-- vanishes at once, as it did). Lantern Fern and Amethyst Grape, Mech holograms, Verity, the giant Dune Starfruit and the plants with their own
-- motion rigs are not touched. Nothing here runs for a plant that is out of range, and it switches itself off after 3 errors.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Gui=game:GetService('GuiService')
local ClientFx=require(RS:WaitForChild('ClientFxBudget'))
local Batch=require(RS:WaitForChild('PlantAnimationBatch'))
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Growth=require(RS:WaitForChild('PlantGrowth'))
local Hologram=require(RS:WaitForChild('HologramProjection'))
local Arrival=require(RS:WaitForChild('HarvestArrival'))
local V,CF=Vector3.new,CFrame.new
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local GLINT=Color3.fromRGB(255,243,186)
local M={}
M.Tuning={
 RipeSeconds=.8,RipeScale=.15,                -- the bounce: 1 + .15 sin(3 pi u) (1-u)^2 peaks near +10 %, dips a little, settles at 1
 CueGap=.18,CueWindow=2,CueMax=6,             -- ripe cues: this far apart (between plants), at most CueMax in any CueWindow seconds, whole garden
 EmitterCount=4,CuedLimit=256,
 FlightMin=.40,FlightMax=.70,FlightPerStud=.012,    -- seconds: a short hop is quick, a long one (an observer watching from afar) never above FlightMax
 ArcPerStud=.35,ArcMin=.8,ArcMax=2.5,ShrinkTo=.55,  -- the arc's height (studs) and how small the fruit is on arrival
 AimUp=.9,                                    -- studs above the HumanoidRootPart: the upper torso
 FlightMaxParts=48,                           -- a fruit of more parts than this just vanishes
 -- plants whose fruit or parts are moved by their own systems
 Skip={ObsidianMawSeed=true,SilentFrostbellSeed=true,OrbitLotusSeed=true,SupernovaBloomSeed=true,StarfruitSeed=true},
}
-- Per quality tier (ClientFxBudget 1 = low .. 3 = high; graphics level 1-3 forces tier 1, 4-6 caps at tier 2): everything is off on tier 1.
-- Pulses / PulseParts: fruit bouncing at once and the parts they move; Sparks: glints per cue; Flights / FlightParts: fruit flying at once and their parts;
-- Range: studs from the camera inside which an observed plant shows these moments.
M.Budgets={
 {Pulses=0,PulseParts=0,Sparks=0,Flights=0,FlightParts=0,Range=0},
 {Pulses=3,PulseParts=70,Sparks=3,Flights=5,FlightParts=120,Range=38},
 {Pulses=4,PulseParts=120,Sparks=4,Flights=8,FlightParts=200,Range=48},
}
M.Off=M.Budgets[1]
-- reduced = the player's reduced-motion setting, off = the Studio effects switch.
function M.Budget(tier,reduced,off)
 if reduced or off then return M.Off end
 return M.Budgets[math.clamp(math.floor(tonumber(tier)or 3),1,3)]
end
local function graphicsLevel()
 local ok,level=pcall(function()return UserSettings():GetService('UserGameSettings').SavedQualityLevel.Value end)
 return ok and type(level)=='number'and level or 0
end
function M.Tier()
 local tier=ClientFx.Get();local level=graphicsLevel()
 if level>=1 then if level<=3 then tier=1 elseif level<=6 then tier=math.min(tier,2)end end
 return math.clamp(tier,1,3)
end
local function smooth(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
-- Ripe bounce t seconds after the fruit became ripe: the scale multiplier (1 before and after RipeSeconds).
function M.Bounce(t)
 local T=M.Tuning;local u=t/T.RipeSeconds
 if u<=0 or u>=1 then return 1 end
 return 1+T.RipeScale*math.sin(u*math.pi*3)*(1-u)^2
end
-- Harvest flight at u = seconds / duration: how far along the way to the player (eased in and out), the arc (0 .. 1 .. 0) and the fruit's scale.
function M.Flight(u)
 u=math.clamp(u,0,1)
 return smooth(u),math.sin(u*math.pi),1-(1-M.Tuning.ShrinkTo)*smooth(u)
end
function M.FlightSeconds(distance)
 local T=M.Tuning;return math.clamp(T.FlightMin+T.FlightPerStud*(tonumber(distance)or 0),T.FlightMin,T.FlightMax)
end
function M.Eligible(crop)
 local def=crop and Catalog[crop.SeedId]
 return def~=nil and not def.Mech and not def.Verity and not Growth.Frozen[crop.SeedId]and not M.Tuning.Skip[crop.SeedId]and not Hologram.Is(crop.SeedId)
end
local function sequence(a,b,c)
 if c then return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.6,b),NumberSequenceKeypoint.new(1,c)})end
 return NumberSequence.new(a,b)
end
local D={};D.__index=D
function M.new(options)
 options=options or{}
 local parent=options.Parent or workspace
 local old=parent:FindFirstChild('LocalPlantGrowthFx');if old then old:Destroy()end
 local folder=Instance.new('Folder');folder.Name='LocalPlantGrowthFx';folder.Parent=parent
 return setmetatable({Folder=folder,Writer=Batch.new(options.Root or workspace),Pulses={},Flights={},Emitters={},EmitterCursor=0,Cued={},CuedOrder={},CueTimes={},
  NextCue=0,NextBudget=0,Mode='normal',Stats={Cues=0,Skipped=0,Bounces=0,Flights=0,Landed=0,Dropped=0,Failures=0}},D)
end
-- Budget, reduced-motion flag and tier, refreshed a few times a second.
function D:Budget()
 local clock=os.clock()
 if clock>=self.NextBudget or not self.Cache then
  self.NextBudget=clock+.25
  local reduced=Gui.ReducedMotionEnabled==true;local tier=self.Mode=='low'and 1 or M.Tier()
  self.Cache={Budget=M.Budget(tier,reduced,self.Mode=='off'),Reduced=reduced,Tier=tier}
 end
 return self.Cache.Budget,self.Cache.Reduced,self.Cache.Tier
end
function D:SetMode(mode)
 mode=(mode=='off'or mode=='low')and mode or'normal'
 if self.Mode~=mode then self.Mode=mode;self.NextBudget=0 end
end
-- Shared particle emitters (4): a pooled attachment is aimed by repositioning and fires a short burst; it is never left emitting.
function D:Emitter(position)
 self.EmitterCursor=self.EmitterCursor%M.Tuning.EmitterCount+1
 local e=self.Emitters[self.EmitterCursor]
 if not e then
  local holder=workspace:FindFirstChildOfClass('Terrain')or self.Folder
  local a=Instance.new('Attachment');a.Name='GrowthFxEmitter'
  local spark=Instance.new('ParticleEmitter');spark.Name='Growth glint';spark.Texture=SPARK
  spark.Transparency=sequence(.1,.4,1);spark.Lifetime=NumberRange.new(.55,.95);spark.Acceleration=V(0,.9,0);spark.Drag=2
  spark.SpreadAngle=Vector2.new(180,180);spark.Rotation=NumberRange.new(0,360);spark.RotSpeed=NumberRange.new(-120,120)
  spark.LightEmission=.65;spark.LightInfluence=.2;spark.Rate=0;spark.Enabled=false;spark.Color=ColorSequence.new(GLINT);spark.Parent=a
  a.Parent=holder
  e={Attachment=a,Spark=spark};self.Emitters[self.EmitterCursor]=e
 end
 e.Attachment.WorldPosition=position
 return e
end
function D:Burst(position,sparks,radius)
 if sparks<=0 then return end
 radius=math.clamp(radius or .5,.15,6)
 local e=self:Emitter(position)
 e.Spark.Size=sequence(math.clamp(radius*.32,.14,.9),0);e.Spark.Speed=NumberRange.new(.6+radius*.3,1.6+radius*.6);e.Spark:Emit(sparks)
end
-- Centre, radius and the visible parts of a fruit model, from its parts as they are now (world space).
local function measure(model)
 local parts={};local lo,hi
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then
  table.insert(parts,p)
  local c=p.CFrame.Position;local h=p.Size*.5
  local a,b=c-h,c+h
  lo=lo and V(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end end
 if not lo then return parts,nil,0 end
 local size=hi-lo
 return parts,(lo+hi)*.5,math.max(size.X,size.Y,size.Z)*.5
end
local function activeParts(list)local n=0;for _,e in ipairs(list)do n+=#e.Parts end;return n end
-- Who sees it: within the tier's range of the camera, and the plant on screen as far as the garden scheduler knows.
function D:Near(position,r,budget)
 local camera=workspace.CurrentCamera
 if not camera or budget.Range<=0 then return false end
 if(camera.CFrame.Position-position).Magnitude>budget.Range then return false end
 local entry=r and r.Entry
 return entry==nil or entry.OnScreen~=false
end
-- Ripe -----------------------------------------------------------------------------------------------------------------------------------------
-- A fruit (or, with child = nil, a whole plant) has just become ripe: a bounce and glints, once per ripening. `cycle` tells ripenings of one slot apart.
-- Called from GardenVisuals while the plant is at rest (its parts are at their rest frames), so Base can be read from them.
function D:Ripe(r,child,index,crop,cycle)
 if self.Dead or not M.Eligible(crop)then return false end
 local key=tostring(crop.Id)..':'..tostring(index)..':'..tostring(cycle or 0)
 if self.Cued[key]then return false end
 self.Cued[key]=true;table.insert(self.CuedOrder,key);if #self.CuedOrder>M.Tuning.CuedLimit then self.Cued[table.remove(self.CuedOrder,1)]=nil end
 local budget=self:Budget();local clock=os.clock();local T=M.Tuning
 if budget.Range<=0 then return false end
 -- the gap is between plants: the fruits of one plant that ripen together all get their turn (up to CueMax)
 if clock<self.NextCue and self.LastCue~=r then self.Stats.Skipped+=1;return false end
 while #self.CueTimes>0 and clock-self.CueTimes[1]>T.CueWindow do table.remove(self.CueTimes,1)end
 if #self.CueTimes>=T.CueMax then self.Stats.Skipped+=1;return false end
 local parts,center,radius
 if child then parts,center,radius=measure(child)
 else
  local def=Catalog[crop.SeedId];local scale=crop.PlantScale or 1
  center=r.Origin.Position+V(0,def.Height*scale*.5,0);radius=math.clamp(def.Radius*scale*.5,.5,6);parts={}
 end
 if not center or not self:Near(center,r,budget)then self.Stats.Skipped+=1;return false end
 self.NextCue=clock+T.CueGap;self.LastCue=r;table.insert(self.CueTimes,clock);self.Stats.Cues+=1
 self:Burst(center,budget.Sparks,radius)
 if child and #self.Pulses<budget.Pulses and #parts>0 and activeParts(self.Pulses)+#parts<=budget.PulseParts then
  local origin=r.Origin;local pulse={R=r,Child=child,Start=clock,Parts={},Center=origin:ToObjectSpace(CF(center)).Position}
  for _,p in ipairs(parts)do
   local base=origin:ToObjectSpace(p.CFrame)
   table.insert(pulse.Parts,{Part=p,Size=p.Size,Base=base,Rot=base.Rotation,Off=base.Position-pulse.Center})
  end
  table.insert(self.Pulses,pulse);self.Stats.Bounces+=1
 end
 return true
end
local function finishPulse(self,pulse,direct)
 local origin=pulse.R.Origin;local pose=pulse.R.Pose or origin
 for _,e in ipairs(pulse.Parts)do if e.Part.Parent then
  e.Part.Size=e.Size
  if direct then e.Part.CFrame=origin*e.Base else self.Writer:Set(e.Part,pose*e.Base)end
 end end
end
-- Inside GardenVisuals' animation step, BEFORE the rigs of the plants are posed: a bouncing fruit's parts are queued here, so the rig (which only
-- fills the parts not queued yet) leaves them alone. `batch` is the garden's PlantAnimationBatch.
function D:StepBounces(batch)
 local pulses=self.Pulses
 if #pulses==0 then return end
 local clock=os.clock()
 for i=#pulses,1,-1 do
  local pulse=pulses[i];local t=clock-pulse.Start;local r=pulse.R
  local pose=r.Pose or r.Origin
  if not pulse.Child.Parent or t>=M.Tuning.RipeSeconds then
   if pulse.Child.Parent then
    for _,e in ipairs(pulse.Parts)do if e.Part.Parent then e.Part.Size=e.Size;batch:Set(e.Part,pose*e.Base)end end
   end
   table.remove(pulses,i)
  else
   local s=M.Bounce(t)
   for _,e in ipairs(pulse.Parts)do local p=e.Part;if p.Parent then
    p.Size=e.Size*s
    batch:Set(p,pose*(CF(pulse.Center+e.Off*s)*e.Rot))
   end end
  end
 end
end
-- The plant is about to rebuild its rig (or be rebuilt): end its bounces now, parts back at rest, so a rig is only ever captured from the rest pose.
function D:Settle(r)
 for i=#self.Pulses,1,-1 do local pulse=self.Pulses[i]
  if pulse.R==r then finishPulse(self,pulse,true);table.remove(self.Pulses,i)end
 end
end
-- Harvest ----------------------------------------------------------------------------------------------------------------------------------------
-- A ripe fruit model is about to be destroyed because it was picked. Returns true when the fruit flies to the harvester: its parts now belong to this
-- module (the caller must not destroy it); false = the caller destroys it as before (and the inventory is told at once).
function D:Harvest(r,child,index,crop,item)
 local cropId=crop and crop.Id
 local function refuse()Arrival.Land(cropId,index);return false end
 if self.Dead or not M.Eligible(crop)then return refuse()end
 local budget=self:Budget()
 if budget.Flights<=0 or #self.Flights>=budget.Flights then self.Stats.Skipped+=1;return refuse()end
 -- the harvester: the garden's owner (only the owner can pick a fruit)
 local ownerId=item and(item:GetAttribute('GardenOwnerId')or item.Parent and item.Parent:GetAttribute('GardenOwnerId'))
 local owner=ownerId and Players:GetPlayerByUserId(ownerId)
 local character=owner and owner.Character
 local root=character and character:FindFirstChild('HumanoidRootPart');local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 if not root or not humanoid or humanoid.Health<=0 then return refuse()end
 local parts,center=measure(child)
 if not center or #parts==0 or #parts>M.Tuning.FlightMaxParts or activeParts(self.Flights)+#parts>budget.FlightParts then self.Stats.Skipped+=1;return refuse()end
 if owner~=Players.LocalPlayer and not self:Near(center,r,budget)then self.Stats.Skipped+=1;return refuse()end
 local aim=root.Position+V(0,M.Tuning.AimUp,0)
 local distance=(aim-center).Magnitude
 local seconds=M.FlightSeconds(distance)
 child.Parent=self.Folder
 local flight={R=r,Model=child,Start=os.clock(),Seconds=seconds,Center=center,Root=root,Humanoid=humanoid,CropId=cropId,Index=index,Tick=0,
  Arc=math.clamp(M.Tuning.ArcPerStud*distance,M.Tuning.ArcMin,M.Tuning.ArcMax),Parts={}}
 for _,p in ipairs(parts)do
  p.CanQuery=false;p.CanTouch=false;p.CanCollide=false
  local cf=p.CFrame
  table.insert(flight.Parts,{Part=p,Size=p.Size,Off=cf.Position-center,Rot=cf.Rotation})
 end
 table.insert(self.Flights,flight);self.Stats.Flights+=1
 Arrival.Flying(cropId,index,seconds)
 return true
end
local function endFlight(self,flight,landed)
 flight.Model:Destroy()
 if landed then self.Stats.Landed+=1 else self.Stats.Dropped+=1 end
 Arrival.Land(flight.CropId,flight.Index)
end
-- Every frame (one call from GardenVisuals' Heartbeat, no connection per fruit): the flights. Does nothing when none fly.
function D:StepFrame()
 local flights=self.Flights
 if self.Dead or #flights==0 then return end
 local ok,why=pcall(function()
  local clock=os.clock();local writer=self.Writer;local T=M.Tuning
  for i=#flights,1,-1 do
   local f=flights[i];local root=f.Root
   if not f.Model.Parent or not root.Parent or f.Humanoid.Health<=0 then
    -- the plant streamed out, the harvester left or died: the fruit just disappears
    table.remove(flights,i);endFlight(self,f,false)
   else
    local u=(clock-f.Start)/f.Seconds
    if u>=1 then table.remove(flights,i);endFlight(self,f,true)
    else
     local e,arc,scale=M.Flight(u)
     local aim=root.Position+V(0,T.AimUp,0)
     local at=f.Center+(aim-f.Center)*e+V(0,f.Arc*arc,0)
     f.Tick+=1;local sizes=f.Tick%2==1
     for _,part in ipairs(f.Parts)do local p=part.Part;if p.Parent then
      if sizes then p.Size=part.Size*scale end
      writer:Set(p,CF(at+part.Off*scale)*part.Rot)
     end end
    end
   end
  end
  writer:Flush()
 end)
 if not ok then self:Fail(why)end
end
function D:Fail(why)
 -- A cosmetic system must never spam or stall a frame: after three errors it switches itself off.
 self.Stats.Failures+=1;warn('[R149] Plant growth fx: '..tostring(why))
 if self.Stats.Failures>=3 then self:Destroy()end
end
-- A plant's model was rebuilt or removed: drop what points at it. `keep` = it is being rebuilt (the commit in GardenVisuals): flights in the air are
-- independent of the plant and play on; they are dropped only when the plant is gone (streamed out).
function D:Clear(r,keep)
 self:Settle(r)
 if keep then return end
 for i=#self.Flights,1,-1 do local f=self.Flights[i];if f.R==r then table.remove(self.Flights,i);endFlight(self,f,false)end end
end
function D:Active()return #self.Pulses,#self.Flights end
function D:Destroy()
 if self.Dead then return end
 self.Dead=true
 for i=#self.Flights,1,-1 do local f=self.Flights[i];table.remove(self.Flights,i);Arrival.Land(f.CropId,f.Index)end
 for _,pulse in ipairs(self.Pulses)do finishPulse(self,pulse,true)end
 for _,e in ipairs(self.Emitters)do e.Attachment:Destroy()end
 self.Folder:Destroy();table.clear(self.Pulses)
end
return M
