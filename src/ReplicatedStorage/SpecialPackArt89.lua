-- R103: bounded reactor, piston and power-light motion on the original bag.
-- All artwork is thin, inside the outline, and shared by world and shop packs.
-- R153: the Mech design is MechPackArt153 (look B); the rig below also blinks its LED, hums its light and switches its held fx (Live).
local A={TemplateKey='Forest_01'}
local V,CF=Vector3.new,CFrame.new
local Renderer=require(script.Parent.SeedPackRenderer)
local cache
local function bodyBounds()
 if cache then return cache end
 local t=assert(Renderer.GetGeometry(A.TemplateKey),'Approved pack template missing')
 local b={Radius=1,MinY=-1.22,MaxY=1.22,MinZ=0,MaxZ=0}
 for _,p in ipairs(t:GetChildren())do if p:IsA('MeshPart')then
  local f=p:GetAttribute('PackLocalFrame')
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=f*V(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)
   b.Radius=math.max(b.Radius,V(q.X,0,q.Z).Magnitude);b.MinY=math.min(b.MinY,q.Y);b.MaxY=math.max(b.MaxY,q.Y)
   b.MinZ=math.min(b.MinZ,q.Z);b.MaxZ=math.max(b.MaxZ,q.Z)
  end end end
 end end
 cache=b;return b
end
-- R122: the Void (EclipseReliquary) design lives in EclipsePackArt (SeedPackRenderer/SeedPackVisuals
-- call it directly); this module keeps the Mech rig and the shared approved body bounds.
function A.BodyBounds()return bodyBounds()end
-- R153: the Mech pack is look B "Circuit Mech" (MechPackArt153: the flat gunmetal pouch, frame, traces, bolts, hazard seal, antenna). R103's armour panels
-- and pistons (fitted to Forest_01's printed surface) are gone; this module keeps the shared body bounds, the Mech bounds and the rig (CaptureMotion).
function A.Specs(_kind)return require(script.Parent.MechPackArt153).Specs()end
function A.Bounds(kind,scale)
 local b=table.clone(bodyBounds());local depth=kind=='MechLimited'and .075 or .055;b.MinZ-=depth;b.MaxZ+=depth;b.Radius+=kind=='MechLimited'and .085 or .06;b.MinY-=.04;b.MaxY+=.04
 if kind=='MechLimited'then b.MaxY=math.max(b.MaxY,require(script.Parent.MechPackArt153).Antenna.Top+.04)end -- (R153: the antenna's LED)
 for k,v in pairs(b)do b[k]=v*(scale or 1)end;return b
end
function A.Build(bag,_kind)return require(script.Parent.MechPackArt153).Build(bag)end
-- Captured once by each existing renderer. This object owns no connections.
function A.CaptureMotion(bag)
 local state={Bag=bag,Root=bag and bag.PrimaryPart,Entries={},ByPart={},Colors={},Blinks={},Lights={},Fx={}}
 if not state.Root or bag:GetAttribute('BagVariant')~='MechLimited'then
  state.LocalFrame=function()return nil end;state.Step=function()end;state.Pulse=function()end;state.Reset=function()end;state.Live=function()end;return state
 end
 for _,part in ipairs(bag:GetDescendants())do
  -- R153: the held fx (the hum light, the antenna's sparks) and the hum's pulse
  if(part:IsA('Light')or part:IsA('ParticleEmitter'))and part:GetAttribute('MechHeldFx')then state.Fx[#state.Fx+1]=part end
  if part:IsA('Light')and type(part:GetAttribute('MechHum'))=='number'then state.Lights[#state.Lights+1]={Light=part,Brightness=part:GetAttribute('MechHum')}end
 if part:IsA('BasePart')then
  local kind=part:GetAttribute('MechMotion');local rest=part:GetAttribute('PackLocalFrame')
  if kind and typeof(rest)=='CFrame'then
   local entry={Part=part,Rest=rest,Kind=kind,Rate=part:GetAttribute('MechMotionRate')or 0,Amplitude=part:GetAttribute('MechMotionAmplitude')or 0,Phase=part:GetAttribute('MechMotionPhase')or 0,Joint=part:FindFirstChild('MechServo')}
   local pivot=part:GetAttribute('MechMotionPivot');entry.Pivot=typeof(pivot)=='CFrame'and pivot or rest;entry.Offset=entry.Pivot:ToObjectSpace(rest)
   state.Entries[#state.Entries+1]=entry;state.ByPart[part]=entry
  end
  local pulse=part:GetAttribute('MechPulse')
  if type(pulse)=='number'and pulse>0 then state.Colors[#state.Colors+1]={Part=part,Color=part.Color,Amount=math.clamp(pulse,0,.18),Phase=part:GetAttribute('MechMotionPhase')or 0}end
  local blink=part:GetAttribute('MechBlink') -- R153: the antenna's LED (on half of each period, a dim red the other half)
  if type(blink)=='number'and blink>0 then state.Blinks[#state.Blinks+1]={Part=part,Color=part.Color,Period=blink}end
 end end
 local function time(t)return type(t)=='number'and t==t and math.abs(t)<math.huge and t%6 or 0 end
 local function live(part)return bag.Parent~=nil and state.Root.Parent~=nil and part.Parent~=nil and part:IsDescendantOf(bag)end
 function state:LocalFrame(part,t)
  local entry=self.ByPart[part];if not entry or not live(part)then return nil end;t=time(t)
  if entry.Kind=='Spin'then return entry.Pivot*CFrame.Angles(0,0,t*entry.Rate)*entry.Offset end
  if entry.Kind=='Slide'then return entry.Rest*CF(0,math.sin(t*entry.Rate+entry.Phase)*entry.Amplitude,0)end
  return entry.Rest
 end
 function state:Pulse(t)
  t=time(t)
  for _,entry in ipairs(self.Colors)do if live(entry.Part)then
   local amount=(.5+.5*math.sin(t*math.pi*2/3+entry.Phase))*entry.Amount
   entry.Part.Color=entry.Color:Lerp(Color3.new(1,1,1),amount)
  end end
  for _,entry in ipairs(self.Blinks)do if live(entry.Part)then
   local on=t%entry.Period<entry.Period*.5;if entry.On~=on then entry.On=on;entry.Part.Color=on and entry.Color or entry.Color:Lerp(Color3.new(0,0,0),.7)end
  end end
  for _,entry in ipairs(self.Lights)do if entry.Light.Parent then entry.Light.Brightness=entry.Brightness*(.75+.25*math.sin(t*math.pi*2/2.4))end end
 end
 -- R153: the held fx on (a pack SeedPackRender details) or off (hidden, opening, far, off screen); the sparks stay off on low quality. Writes only a change.
 function state:Live(on,low)
  for _,fx in ipairs(self.Fx)do local want=on==true and not(low and fx:IsA('ParticleEmitter'));if fx.Parent and fx.Enabled~=want then fx.Enabled=want end end
 end
 local function apply(entry,pose,rootFrame,move)
  local part=entry.Part
  if part.Anchored then
   if move then move(part,rootFrame*pose)else part.CFrame=rootFrame*pose end
  else
   -- The part may replicate before its servo; retry the lookup until it arrives.
   if not entry.Joint or entry.Joint.Parent~=part then entry.Joint=part:FindFirstChild('MechServo')end
   if entry.Joint and entry.Joint:IsA('Motor6D')and entry.Joint.Part0==state.Root and entry.Joint.Part1==part then
    -- Adjust the local joint only; never move a welded character assembly.
    entry.Joint.C0=pose
   end
  end
 end
 function state:Step(t,rootFrame,move)
  if not bag.Parent or not self.Root.Parent then return end
  rootFrame=rootFrame or self.Root.CFrame
  for _,entry in ipairs(self.Entries)do local pose=self:LocalFrame(entry.Part,t);if pose then apply(entry,pose,rootFrame,move)end end
  self:Pulse(t)
 end
 function state:Reset()
  if not bag.Parent or not self.Root.Parent then return end
  for _,entry in ipairs(self.Entries)do if live(entry.Part)then apply(entry,entry.Rest,self.Root.CFrame)end end
  for _,entry in ipairs(self.Colors)do if live(entry.Part)then entry.Part.Color=entry.Color end end
  for _,entry in ipairs(self.Blinks)do if live(entry.Part)then entry.Part.Color=entry.Color;entry.On=nil end end
  for _,entry in ipairs(self.Lights)do if entry.Light.Parent then entry.Light.Brightness=entry.Brightness end end
  self:Live(false)
 end
 return state
end
return A
