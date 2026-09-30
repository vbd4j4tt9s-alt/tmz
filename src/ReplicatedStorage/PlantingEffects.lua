-- R112: planting feedback. Client-only and cosmetic: never changes crops, prompts, raycasts or saved data.
-- A freshly planted crop gets a ring of voxel dirt chunks that pops out of the soil with a bounce, a dirt burst,
-- a few chunks tossed onto the rim and a layered thud / crunch / pop. After a few seconds the chunks sink back into
-- the soil and a small dug-soil mark stays at the growth point until the crop is harvested away or removed.
-- Fresh = the crop model replicated after this client started AND its saved PlantedAt is only seconds old, so joins,
-- garden loads, streaming and growth-stage rebuilds (same CropId) never replay the pile.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local RS=game:GetService('ReplicatedStorage')
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Rules=require(RS:WaitForChild('PlantRules'))
local Fx=require(RS:WaitForChild('ClientFxBudget'))
local Timing=require(RS:WaitForChild('SoundTiming'))
local Mixer=require(RS:WaitForChild('AudioMixer'))
local V,CF=Vector3.new,CFrame.new
local M={}

-- Owner settings ---------------------------------------------------------------------------------------------------
-- Sound layers, all positional at the planted spot. Swap an id here, or set a '<Key>SoundId' attribute on this
-- ModuleScript (a number or 'rbxassetid://...'). An empty id or Volume 0 turns a layer off.
-- R114: the owner's three planting sounds, each synced to a moment of the dirt pile (Beat) plus Delay seconds:
--  Dig    (118769294546013) Beat 'Start':   the pile pops out of the soil with the dirt burst.
--  Land   (137853494539894) Beat 'Settled': the last tossed chunk lands on the rim.
--  Settle (97631814076710)  Beat 'Sink':    the pile sinks back into the soil.
-- Start = seconds of silence to skip at the front of a file (also settable per id on SoundTiming as Start_<id>).
--  Sparkle: off until a short soft chime is added; plays for the planter only.
M.Sounds={
 {Key='Dig',Id='rbxassetid://118769294546013',Volume=.5,Pitch={.96,1.04},Beat='Start',Delay=0},
 {Key='Land',Id='rbxassetid://137853494539894',Volume=.45,Pitch={.96,1.04},Beat='Settled',Delay=0},
 {Key='Settle',Id='rbxassetid://97631814076710',Volume=.4,Pitch={.96,1.04},Beat='Sink',Delay=0},
 {Key='Sparkle',Id='',Volume=.06,Pitch={1.2,1.35},Beat='Start',Delay=.16,OwnOnly=true},
}
M.Tuning={
 FreshSeconds=6,       -- PlantedAt (server clock) younger than this counts as a new planting
 StartupGrace=3,       -- nothing is fresh during the first seconds of this client (join/stream-in burst)
 RiseSeconds=.34,HoldSeconds=2.4,SinkSeconds=.5,MarkFadeSeconds=.45,
 NearRange=95,         -- full pile inside this camera distance; half pile up to FarRange; mark/sound only beyond
 FarRange=170,SoundRange=130,MarkRange=220,
 OthersVolume=.75,     -- other players' plantings are a little quieter than your own
 MarkAllCrops=true,    -- false: only crops planted during this session get a mark
}
-- Per quality tier (ClientFxBudget 1 = low .. 3 = high); graphics level 1-3 forces tier 1, 4-6 caps at tier 2.
M.Budgets={
 {Piles=2,Chunks=50,PerPile=22,Flyers=0,Particles=.4,Marks=60,Shadows=false},
 {Piles=4,Chunks=130,PerPile=44,Flyers=3,Particles=.7,Marks=110,Shadows=false},
 {Piles=6,Chunks=260,PerPile=96,Flyers=6,Particles=1,Marks=160,Shadows=true},
}
local SOIL=Color3.fromRGB(112,75,45)
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'

-- Pure geometry (also used by the offline renders) --------------------------------------------------------------------
-- Pile scale from the plant footprint (catalog Radius x PlantScale), square-root scaled and clamped: a 2-stud herb
-- gets a ~1.1-stud mound of ~18 cubes, a 10-stud apple tree ~1.9 / ~25, a 37-stud king tree ~3.1 / ~36, giant
-- rolls cap at 4.5 / ~48. Cubes grow with the mound (0.4 to 1 stud) so big piles stay chunky and low-poly.
function M.Size(base)
 base=tonumber(base)or 0;if base~=base then base=0 end;base=math.clamp(base,0,1e4)
 local radius=math.clamp(.55+.42*math.sqrt(base),1,4.5);local hollow=math.max(.26,radius*.27)
 local count=math.floor(8+9*radius+.5)
 return {Base=base,Radius=radius,Height=radius*.4,Hollow=hollow,Count=count,Chunk=math.sqrt(math.pi*(radius^2-hollow^2)/count)*.86,Mark=math.clamp(radius*.42,.45,1.35)}
end
function M.BaseRadius(seedId,plantScale)
 local def=Catalog[seedId];if not def then return 2 end
 return def.Radius*Rules.Scale(plantScale)
end
function M.Hash(text)
 local h=5381;text=tostring(text)
 for i=1,#text do h=(h*33+string.byte(text,i))%2147483647 end
 return h
end
local GOLDEN=math.pi*(3-math.sqrt(5))
local function build(size,count,seed,flyers)
 local rng=Random.new(seed)
 local R,H,ri=size.Radius,size.Height,size.Hollow
 local s=math.clamp(math.sqrt(math.pi*(R*R-ri*ri)/count)*.86,.28,1.3)
 local peak=ri+(R-ri)*.3
 local function height(r)
  if r<=peak then return H*(.72+.28*math.clamp((r-ri)/math.max(.01,peak-ri),0,1))end
  local u=math.clamp((r-peak)/math.max(.01,R-peak),0,1);return H*(1-u*u)
 end
 local chunks={}
 local function add(x,y,z,edge,tone,delay,sink)
  local c={Position=V(x,y,z),Size=edge,Tone=tone,Delay=delay,Sink=sink,HiddenY=-edge*.5-.06,
   Rotation=CFrame.Angles(0,rng:NextNumber(0,math.pi/2),0)*CFrame.Angles(rng:NextNumber(-.22,.22),0,rng:NextNumber(-.22,.22)),
   WobbleX=rng:NextNumber(-.5,.5),WobbleZ=rng:NextNumber(-.5,.5)}
  table.insert(chunks,c);return c
 end
 -- Sunflower spiral over the ring around the seed hole, biased toward the rim; outer cubes are smaller clods.
 local turn=rng:NextNumber(0,2*math.pi)
 for i=1,count do
  local f=((i-.5)/count)^1.25
  local rr=math.clamp(math.sqrt(ri*ri+(R*R-ri*ri)*f)+rng:NextNumber(-.12,.12)*s,ri+s*.4,R-s*.2)
  local a=turn+i*GOLDEN+rng:NextNumber(-.12,.12)
  local wave=math.clamp((rr-ri)/math.max(.01,R-ri),0,1)
  local top=height(rr)*rng:NextNumber(.88,1.12)
  -- Tall rim cubes are a little bigger, so a mound needs at most one support cube under each.
  local edge=math.max(s*(1.12-.34*wave)*rng:NextNumber(.86,1.14),top/1.75);top=math.max(edge*.42,top)
  local x,z=math.cos(a)*rr,math.sin(a)*rr
  local delay=.02+wave*.16+rng:NextNumber(0,.05);local sink=(1-wave)*.28+rng:NextNumber(0,.08)
  local tone=math.clamp(math.floor(1+top/math.max(.01,H)*2.2+rng:NextNumber(0,1.6)),1,4)
  local y=top-edge*.5
  add(x,y,z,edge,tone,delay,sink)
  -- Support cubes under tall ones, so nothing floats; each overlaps the one above a little.
  for _=1,2 do
   local bottom=y-edge*.5
   if bottom<=edge*.2 then break end
   local below=edge*rng:NextNumber(1,1.15)
   y=bottom-below*.3;edge=below
   add(x+rng:NextNumber(-.08,.08)*below,y,z+rng:NextNumber(-.08,.08)*below,edge,math.max(1,tone-1),delay-.015,sink+.02)
  end
 end
 -- A few chunks are tossed out of the hole and land on top of the rim.
 for _=1,flyers do
  local a=rng:NextNumber(0,2*math.pi);local rr=math.clamp(peak+rng:NextNumber(-.2,.25)*s,ri+s*.3,R)
  local edge=s*rng:NextNumber(.6,.8)
  local c=add(math.cos(a)*rr,height(rr)+edge*.4,math.sin(a)*rr,edge,rng:NextInteger(3,4),rng:NextNumber(.03,.12),rng:NextNumber(0,.08))
  c.Flyer=true;c.Flight=rng:NextNumber(.42,.56);c.Apex=(.7+.3*R)*rng:NextNumber(.85,1.15)
  c.Spin=V(rng:NextNumber(-7,7),rng:NextNumber(-5,5),rng:NextNumber(-7,7))
 end
 return {Size=size,Chunk=s,Chunks=chunks,Count=count,Flyers=flyers}
end
-- Deterministic chunk layout in the soil frame (Y up, 0 = soil top); the same crop id gives the same pile on every
-- client. Over the cap, fewer but bigger cubes keep the mound's shape.
function M.Layout(base,seed,cap,flyers)
 local size=M.Size(base)
 cap=math.max(6,math.floor(tonumber(cap)or 54));flyers=math.clamp(math.floor(tonumber(flyers)or 0),0,2+math.floor(size.Radius))
 local count=size.Count;local out=build(size,count,seed,flyers)
 for _=1,10 do
  if #out.Chunks<=cap then break end
  count=math.max(4,math.floor(math.min(count*.88,count*cap/#out.Chunks)));out=build(size,count,seed,flyers)
 end
 while #out.Chunks>cap do table.remove(out.Chunks)end
 return out
end
-- Four tones around the soil colour: shade, soil, lit, crumb.
function M.Palette(soil)
 soil=soil or SOIL
 local function k(f)return Color3.new(math.clamp(soil.R*f,0,1),math.clamp(soil.G*f,0,1),math.clamp(soil.B*f,0,1))end
 return {k(.74),k(.92),k(1.1),k(1.26)}
end
M.Ease={
 BackOut=function(u)local c=1.9;u-=1;return 1+(c+1)*u*u*u+c*u*u end,
 BackIn=function(u)local c=1.4;return (c+1)*u*u*u-c*u*u end,
 OutQuad=function(u)return 1-(1-u)*(1-u)end,
 OutCubic=function(u)return 1-(1-u)^3 end,
}
local ease=M.Ease
-- Local pose of one chunk t seconds after the pile started (nil = at rest).
function M.Pose(c,t,sinkAfter,reduced)
 local sinkT=t-(sinkAfter+c.Sink)
 if sinkT>=0 then
  local u=math.clamp(sinkT/M.Tuning.SinkSeconds,0,1)
  local e=reduced and u or ease.BackIn(u)
  return CF(c.Position.X,c.Position.Y+(c.HiddenY-c.Position.Y)*e,c.Position.Z)*c.Rotation,u>=1
 end
 local lt=t-c.Delay
 if lt<0 then return CF(c.Flyer and 0 or c.Position.X,c.HiddenY,c.Flyer and 0 or c.Position.Z)*c.Rotation end
 if c.Flyer then
  local u=lt/c.Flight
  if u<1 then
   local p=V(0,c.HiddenY,0):Lerp(c.Position,u)+V(0,c.Apex*4*u*(1-u),0);local w=1-u
   return CF(p.X,p.Y,p.Z)*CFrame.Angles(c.Spin.X*w,c.Spin.Y*w,c.Spin.Z*w)*c.Rotation
  end
  local v=(lt-c.Flight)/.18
  if v<1 then return CF(c.Position.X,c.Position.Y+c.Size*.22*math.sin(math.pi*v)*(1-v),c.Position.Z)*c.Rotation end
  return nil
 end
 local u=lt/M.Tuning.RiseSeconds
 if u>=1 then return nil end
 local e=reduced and ease.OutQuad(u)or ease.BackOut(u);local w=reduced and 0 or 1-ease.OutCubic(u)
 return CF(c.Position.X,c.HiddenY+(c.Position.Y-c.HiddenY)*e,c.Position.Z)*CFrame.Angles(c.WobbleX*w,0,c.WobbleZ*w)*c.Rotation
end
-- Seconds from pile start until every chunk has landed (flyers include their landing hop).
function M.Settled(layout)
 local t=0
 for _,c in ipairs(layout.Chunks)do t=math.max(t,c.Delay+(c.Flyer and c.Flight+.18 or M.Tuning.RiseSeconds))end
 return t
end

-- Runtime ------------------------------------------------------------------------------------------------------------
local player=Players.LocalPlayer
local function graphicsLevel()
 local ok,level=pcall(function()return UserSettings():GetService('UserGameSettings').SavedQualityLevel.Value end)
 return ok and type(level)=='number'and level or 0
end
function M.Tier()
 local tier=Fx.Get();local level=graphicsLevel()
 if level>=1 then if level<=3 then tier=1 elseif level<=6 then tier=math.min(tier,2)end end
 return math.clamp(tier,1,3)
end
local function mode()
 local value=player and player:GetAttribute('StudioPlantEffects')
 return value=='off'and'off'or'normal'
end
local function soundId(layer)
 local value=script:GetAttribute(layer.Key..'SoundId');if value==nil then value=layer.Id end
 if type(value)=='number'then value=value>0 and value%1==0 and 'rbxassetid://'..string.format('%.0f',value)or''end
 if type(value)~='string'then return nil end
 if value:match('^rbxassetid://[1-9]%d*$')or value:match('^rbxasset://sounds/[%w_%-%./ ]+$')then return value end
 local digits=value:match('^[1-9]%d*$');return digits and 'rbxassetid://'..digits or nil
end
local function cosmetic(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Transparency=1;p.Parent=parent
 return p
end
local function sequence(a,b,c)
 if c then return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.6,b),NumberSequenceKeypoint.new(1,c)})end
 return NumberSequence.new(a,b)
end
local E={};E.__index=E
function M.new(options)
 options=options or{}
 local parent=options.Parent or workspace
 local old=parent:FindFirstChild('LocalPlantingEffects');if old then old:Destroy()end
 local folder=Instance.new('Folder');folder.Name='LocalPlantingEffects';folder.Parent=parent
 local self=setmetatable({Folder=folder,Records={},ByModel={},Waiting={},Piles={},FreeChunks={},LiveChunks=0,FreeMarks={},Marks=0,
  Emitters={},EmitterCursor=0,Queue={},Stopping={},Fading={},Leaving={},Fired={},FiredOrder={},Started=os.clock(),NextSound=0,NextCull=0,
  Random=Random.new(),Stats={Piles=0,Skipped=0,Sounds=0}},E)
 -- Warm the three emitters now so the first planting's sounds are already loaded.
 for _=1,3 do self:Emitter(Vector3.zero)end
 -- A cosmetic system must never spam or stall a frame: after three errors it switches itself off.
 self.Connection=RunService.Heartbeat:Connect(function()
  local ok,why=pcall(self.Step,self)
  if not ok then self.Failures=(self.Failures or 0)+1;warn('[R112] Planting effects: '..tostring(why));if self.Failures>=3 then self:Destroy()end end
 end)
 return self
end
function E:Budget()
 local b=M.Budgets[M.Tier()]
 return b,Gui.ReducedMotionEnabled==true
end
-- Crop models --------------------------------------------------------------------------------------------------------
function E:Add(model,initial)
 if self.Dead or self.ByModel[model]then return end
 local key=model:GetAttribute('CropId');if key==nil then return end;key=tostring(key)
 local r=self.Records[key]
 if r then r.Models[model]=true;r.Model=model;r.Gone=nil;self.ByModel[model]=r;return end
 r={Key=key,Models={[model]=true},Model=model,Initial=initial==true or os.clock()<self.Started+M.Tuning.StartupGrace,Deadline=os.clock()+1.5,HoldMark=true}
 self.Records[key]=r;self.ByModel[model]=r;table.insert(self.Waiting,r)
end
function E:Remove(model)
 local r=self.ByModel[model];if not r then return end
 self.ByModel[model]=nil;r.Models[model]=nil
 if r.Model==model then r.Model=next(r.Models)end
 -- Growth-stage rebuilds add the replacement first; give reordered replication a moment before cleaning up.
 if not r.Model then r.Gone=os.clock()+.5;table.insert(self.Leaving,r)end
end
function E:Resolve(r)
 local model=r.Model;if not model then return false end
 local anchor=model:FindFirstChild('CropAnchor')
 if not anchor or not anchor:IsA('BasePart')then return false end
 r.Origin=anchor.CFrame*CF(0,-.025,0)
 r.Base=M.BaseRadius(model:GetAttribute('SeedId'),model:GetAttribute('PlantScale'))
 local plot=model.Parent
 r.Palette=M.Palette(plot and plot:IsA('BasePart')and plot:GetAttribute('GardenSoil')and plot.Color or SOIL)
 return true
end
function E:Owned(r)
 local model=r.Model;local plot=model and model.Parent
 local owner=model and model:GetAttribute('GardenOwnerId')or plot and plot:GetAttribute('GardenOwnerId')
 return player~=nil and owner==player.UserId
end
function E:Release(r)
 if r.Pile then self:EndPile(r.Pile)end
 if r.Mark then self:HideMark(r)end
 for model in pairs(r.Models)do self.ByModel[model]=nil end
 self.Records[r.Key]=nil;r.Released=true
end
function E:Remember(key)
 if self.Fired[key]then return end
 self.Fired[key]=true;table.insert(self.FiredOrder,key)
 if #self.FiredOrder>512 then self.Fired[table.remove(self.FiredOrder,1)]=nil end
end
-- Decide once per crop, when its anchor and PlantedAt are readable (or give up after the deadline).
function E:Settle(r,now)
 local model=r.Model;if not model then return true end
 local planted=model:GetAttribute('PlantedAt')
 local ready=self:Resolve(r)
 if(not ready or type(planted)~='number')and now<r.Deadline then return false end
 local age=type(planted)=='number'and workspace:GetServerTimeNow()-planted or math.huge
 local fresh=ready and not r.Initial and not self.Fired[r.Key]and age>=-2 and age<=M.Tuning.FreshSeconds
 -- Anything young enough to count is remembered, so a stream-out/in within the window cannot replay it.
 if age<=M.Tuning.FreshSeconds+2 then self:Remember(r.Key)end
 if fresh then r.Planted=true;r.FadeIn=true;if not self:StartPile(r)then r.HoldMark=false end else r.HoldMark=false end
 self.NextCull=math.min(self.NextCull,now+.1)
 return true
end
-- Pile ---------------------------------------------------------------------------------------------------------------
function E:Chunk(budget)
 local p=table.remove(self.FreeChunks)or cosmetic(self.Folder,'Dirt chunk')
 p.CastShadow=budget.Shadows;self.LiveChunks+=1
 return p
end
function E:FreeChunk(p)
 self.LiveChunks-=1;p.Transparency=1
 if #self.FreeChunks<M.Budgets[3].Chunks then table.insert(self.FreeChunks,p)else p:Destroy()end
end
function E:StartPile(r)
 local budget,reduced=self:Budget()
 local camera=workspace.CurrentCamera;local position=r.Origin.Position
 local distance=camera and(camera.CFrame.Position-position).Magnitude or 0
 local e=self:Emitter(position+V(0,.15,0))
 local sounding=distance<=M.Tuning.SoundRange
 local skip=mode()=='off'or distance>M.Tuning.FarRange
 if not skip and camera and distance>30 then local _,visible=camera:WorldToViewportPoint(position+V(0,.5,0));skip=not visible end
 local room=budget.Chunks-self.LiveChunks
 if skip or #self.Piles>=budget.Piles or room<8 then
  -- No pile drawn (far away, off screen or over budget): the sounds keep the timing of a typical pile.
  if sounding then self:PlaySounds(e,self:Owned(r),M.Size(r.Base).Radius,M.Beats())end
  self.Stats.Skipped+=1;return false
 end
 local near=distance<=M.Tuning.NearRange
 local layout=M.Layout(r.Base,M.Hash(r.Key),math.min(near and budget.PerPile or math.floor(budget.PerPile*.5),room),(near and not reduced)and budget.Flyers or 0)
 local settled=M.Settled(layout)
 local pile={Record=r,Origin=r.Origin,Start=os.clock(),Layout=layout,Chunks=layout.Chunks,Parts={},Rest={},Reduced=reduced,
  SinkAfter=settled+(reduced and M.Tuning.HoldSeconds*.75 or M.Tuning.HoldSeconds)}
 local sinkEnd=0;for _,c in ipairs(layout.Chunks)do sinkEnd=math.max(sinkEnd,c.Sink)end
 pile.EndAfter=pile.SinkAfter+sinkEnd+M.Tuning.SinkSeconds
 if sounding then self:PlaySounds(e,self:Owned(r),M.Size(r.Base).Radius,{Start=0,Settled=settled,Sink=pile.SinkAfter})end
 for i,c in ipairs(layout.Chunks)do
  local p=self:Chunk(budget);p.Size=V(c.Size,c.Size,c.Size);p.Color=r.Palette[c.Tone]
  p.CFrame=pile.Origin*(M.Pose(c,0,pile.SinkAfter,reduced)or CF(c.Position)*c.Rotation);p.Transparency=0;pile.Parts[i]=p
 end
 r.Pile=pile;table.insert(self.Piles,pile);self.Stats.Piles+=1
 self:Burst(e,layout,budget,reduced,near,r.Palette)
 return true
end
function E:EndPile(pile)
 for _,p in ipairs(pile.Parts)do self:FreeChunk(p)end
 table.clear(pile.Parts);pile.Done=true
 local index=table.find(self.Piles,pile);if index then table.remove(self.Piles,index)end
 if pile.Record.Pile==pile then pile.Record.Pile=nil end
end
-- Emitters: three pooled attachments at the planted spot, each with the dirt burst and the sound layers.
function E:Emitter(position)
 self.EmitterCursor=self.EmitterCursor%3+1
 local e=self.Emitters[self.EmitterCursor]
 if not e then
  local holder=workspace:FindFirstChildOfClass('Terrain')or self.Folder
  local a=Instance.new('Attachment');a.Name='PlantingEmitter'
  local puff=Instance.new('ParticleEmitter');puff.Name='Dirt puff';puff.Texture=SMOKE
  puff.Transparency=sequence(.42,.7,1);puff.Lifetime=NumberRange.new(.45,.8);puff.Drag=4;puff.Acceleration=V(0,-3,0)
  puff.SpreadAngle=Vector2.new(70,70);puff.Rotation=NumberRange.new(0,360);puff.RotSpeed=NumberRange.new(-60,60)
  puff.LightEmission=0;puff.LightInfluence=1;puff.EmissionDirection=Enum.NormalId.Top;puff.Rate=0;puff.Enabled=false;puff.Parent=a
  local clods=Instance.new('ParticleEmitter');clods.Name='Dirt clods';clods.Texture=SPARK
  clods.Transparency=sequence(0,.1,1);clods.Lifetime=NumberRange.new(.45,.75);clods.Acceleration=V(0,-45,0);clods.Drag=.5
  clods.SpreadAngle=Vector2.new(48,48);clods.Rotation=NumberRange.new(0,360);clods.RotSpeed=NumberRange.new(-220,220)
  clods.LightEmission=0;clods.LightInfluence=1;clods.EmissionDirection=Enum.NormalId.Top;clods.Rate=0;clods.Enabled=false;clods.Parent=a
  local sounds={};local preload={}
  for _,layer in ipairs(M.Sounds)do
   local id=soundId(layer)
   if id then
    local s=Instance.new('Sound');s.Name='Planting '..layer.Key;s.SoundId=id;s.Volume=layer.Volume;s.Looped=false
    s.RollOffMode=Enum.RollOffMode.InverseTapered;s.RollOffMinDistance=12;s.RollOffMaxDistance=M.Tuning.SoundRange
    Mixer.Route(s,'Effects');s.Parent=a;sounds[layer.Key]=s;table.insert(preload,s)
   end
  end
  a.Parent=holder
  e={Attachment=a,Puff=puff,Clods=clods,Sounds=sounds};self.Emitters[self.EmitterCursor]=e
  if #preload>0 then task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync(preload)end)end)end
 end
 e.Attachment.WorldPosition=position
 return e
end
function E:Burst(e,layout,budget,reduced,near,palette)
 local R=layout.Size.Radius;local k=budget.Particles*(near and 1 or .5)*(reduced and .5 or 1)
 local puffs=math.floor((3+2*R)*k+.5)
 if puffs>0 then
  e.Puff.Color=ColorSequence.new(palette[4]);e.Puff.Size=sequence(.45+.2*R,1.2+.45*R)
  e.Puff.Speed=NumberRange.new(2+.5*R,4+R);e.Puff:Emit(puffs)
 end
 local clods=reduced and 0 or math.floor((7+4*R)*k+.5)
 if clods>0 then
  e.Clods.Color=ColorSequence.new(palette[1],palette[2]);e.Clods.Size=sequence(.16+.05*R,.1+.03*R)
  e.Clods.Speed=NumberRange.new(6+1.2*R,10+2*R);e.Clods:Emit(clods)
 end
end
-- Beat times (seconds after planting) of a typical pile, used when no pile is drawn.
function M.Beats()
 local settled=M.Tuning.RiseSeconds+.2
 return {Start=0,Settled=settled,Sink=settled+M.Tuning.HoldSeconds}
end
-- Bigger mounds sound a little heavier: lower pitch and a touch more volume with the pile radius.
function E:PlaySounds(e,own,radius,beats)
 local now=os.clock();if now<self.NextSound then return end;self.NextSound=now+.09
 local heavy=math.clamp(((radius or 1)-1)/3.5,0,1);beats=beats or M.Beats()
 for _,layer in ipairs(M.Sounds)do
  local sound=e.Sounds[layer.Key]
  if sound and layer.Volume>0 and(own or not layer.OwnOnly)then
   table.insert(self.Queue,{At=now+(beats[layer.Beat or'Start']or 0)+(layer.Delay or 0),Sound=sound,Volume=math.min(1,layer.Volume*(own and 1 or M.Tuning.OthersVolume)*(1+.3*heavy)),
    Speed=self.Random:NextNumber(layer.Pitch[1],layer.Pitch[2])*(1-.12*heavy),Start=layer.Start,Length=layer.Length})
  end
 end
end
-- Marks: two flat discs (dug soil + darker seed hole) at the growth point, pooled and distance-culled.
function E:ShowMark(r,fade)
 local m=table.remove(self.FreeMarks)
 if not m then
  local outer=cosmetic(self.Folder,'Planting mark');outer.Shape=Enum.PartType.Cylinder;outer.Material=Enum.Material.Ground
  local inner=cosmetic(self.Folder,'Planting mark hole');inner.Shape=Enum.PartType.Cylinder
  m={Outer=outer,Inner=inner}
 end
 local size=M.Size(r.Base);local flat=CFrame.Angles(0,0,math.pi/2)
 m.Outer.Size=V(.08,size.Mark*2,size.Mark*2);m.Outer.CFrame=r.Origin*flat;m.Outer.Color=r.Palette[1]:Lerp(Color3.new(0,0,0),.12)
 m.Inner.Size=V(.08,size.Mark*.9,size.Mark*.9);m.Inner.CFrame=r.Origin*CF(0,.02,0)*flat;m.Inner.Color=r.Palette[1]:Lerp(Color3.new(0,0,0),.42)
 local alpha=fade and 1 or 0;m.Outer.Transparency=alpha;m.Inner.Transparency=alpha
 if fade then table.insert(self.Fading,{Mark=m,Start=os.clock()})end
 r.Mark=m;self.Marks+=1
end
function E:HideMark(r)
 local m=r.Mark;if not m then return end
 r.Mark=nil;self.Marks-=1;m.Outer.Transparency=1;m.Inner.Transparency=1
 for i=#self.Fading,1,-1 do if self.Fading[i].Mark==m then table.remove(self.Fading,i)end end
 if #self.FreeMarks<M.Budgets[3].Marks then table.insert(self.FreeMarks,m)else m.Outer:Destroy();m.Inner:Destroy()end
end
function E:Cull()
 local budget=self:Budget();local camera=workspace.CurrentCamera;local eye=camera and camera.CFrame.Position
 local off=mode()=='off';local want={}
 for _,r in pairs(self.Records)do
  if not r.Origin and r.Model then self:Resolve(r)end
  local d=r.Origin and eye and(r.Origin.Position-eye).Magnitude or 0
  -- A crop in its short removal grace (r.Gone) keeps its mark until Release, so a stage rebuild never blinks it.
  if r.Origin and not r.HoldMark and not off and(M.Tuning.MarkAllCrops or r.Planted)and d<=M.Tuning.MarkRange then
   r.Distance=d;table.insert(want,r)
  elseif r.Mark then self:HideMark(r)end
 end
 if #want>budget.Marks then table.sort(want,function(a,b)return a.Distance<b.Distance end)end
 for i,r in ipairs(want)do
  if i<=budget.Marks then if not r.Mark then self:ShowMark(r,r.FadeIn==true)end;r.FadeIn=nil elseif r.Mark then self:HideMark(r)end
 end
 if player and(RunService:IsStudio()or player:GetAttribute('ChestChaseCommandsAllowed'))then
  player:SetAttribute('PlantingPiles',#self.Piles);player:SetAttribute('PlantingChunks',self.LiveChunks);player:SetAttribute('PlantingMarks',self.Marks)
 end
end
function E:Step()
 if self.Dead then return end
 local now=os.clock()
 for i=#self.Waiting,1,-1 do
  local r=self.Waiting[i]
  if r.Released or self:Settle(r,now)then table.remove(self.Waiting,i)end
 end
 for i=#self.Leaving,1,-1 do
  local r=self.Leaving[i]
  if not r.Gone or r.Released then table.remove(self.Leaving,i)elseif now>=r.Gone then table.remove(self.Leaving,i);self:Release(r)end
 end
 -- Sound layers are queued so they land on the pile's beats.
 for i=#self.Queue,1,-1 do
  local q=self.Queue[i]
  if now>=q.At then
   -- A voice still loading may wait up to .25 s; later than that it would be out of step with the pile, so it is skipped.
   local waiting=not q.Sound.IsLoaded and q.Sound.Parent~=nil and now<q.At+.25
   if not waiting then table.remove(self.Queue,i)end
   if not waiting and q.Sound.IsLoaded and q.Sound.Parent then
    for j=#self.Stopping,1,-1 do if self.Stopping[j].Sound==q.Sound then table.remove(self.Stopping,j)end end
    q.Sound:Stop();q.Sound.Volume=q.Volume;q.Sound.PlaybackSpeed=q.Speed;Timing.Play(q.Sound,q.Start);self.Stats.Sounds+=1
    if q.Length then table.insert(self.Stopping,{Sound=q.Sound,At=now,Length=q.Length,Volume=q.Volume})end
   end
  end
 end
 for i=#self.Stopping,1,-1 do
  local s=self.Stopping[i];local left=s.At+s.Length-now
  if left<=0 then s.Sound:Stop();table.remove(self.Stopping,i)else s.Sound.Volume=s.Volume*math.min(1,left/.08)end
 end
 if #self.Piles>0 then
  local parts,frames={},{}
  for i=#self.Piles,1,-1 do
   local pile=self.Piles[i];local t=now-pile.Start
   if t>=pile.SinkAfter and pile.Record.HoldMark then pile.Record.HoldMark=false;self.NextCull=0 end
   if t>=pile.EndAfter then self:EndPile(pile)
   else
    for j,c in ipairs(pile.Chunks)do
     local pose,hidden=M.Pose(c,t,pile.SinkAfter,pile.Reduced)
     if pose then
      pile.Rest[j]=nil
      if hidden then pile.Parts[j].Transparency=1 end
      table.insert(parts,pile.Parts[j]);table.insert(frames,pile.Origin*pose)
     elseif not pile.Rest[j]then
      pile.Rest[j]=true;table.insert(parts,pile.Parts[j]);table.insert(frames,pile.Origin*CF(c.Position)*c.Rotation)
     end
    end
   end
  end
  if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
 end
 for i=#self.Fading,1,-1 do
  local f=self.Fading[i];local u=math.clamp((now-f.Start)/M.Tuning.MarkFadeSeconds,0,1)
  f.Mark.Outer.Transparency=1-u;f.Mark.Inner.Transparency=1-u
  if u>=1 then table.remove(self.Fading,i)end
 end
 if now>=self.NextCull then self.NextCull=now+.5;self:Cull()end
end
function E:Destroy()
 if self.Dead then return end
 self.Dead=true;self.Connection:Disconnect()
 for _,e in ipairs(self.Emitters)do e.Attachment:Destroy()end
 self.Folder:Destroy();table.clear(self.Records);table.clear(self.ByModel);table.clear(self.Piles);table.clear(self.Queue)
end
return M
