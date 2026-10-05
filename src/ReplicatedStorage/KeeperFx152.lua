-- R152: the approved sheets' effects on the new keeper models (docs/proposals/R151/keepers/keepers.md section 2), client only and on the
-- R152 variant only (today's keepers keep KeeperFx alone). Every emitter, beam and trail sits on an Attachment inside the keeper's own mesh
-- part of the right rig group (area effects: on the part itself), so it moves with that pose group; built-in textures only.
--  * Where the sheets draw stand-ins (KeeperRigConfig152 Fx): the Lava Dragon's back-spike and tail-tip flames and the smoke it snorts in
--    its sleep; the Storm Colossus's lightning under its cloud crown and on its shoulder rocks and fists (Beams that flash); The
--    Darkened's void wisps at its cloak hem, hands and feet.
--  * From the effects notes: the golem's falling leaves and drifting spores, the Jungle King's falling leaves, the Sand Snake's sand swirl
--    at the tail and a dust trail while it chases, Ice Fang's frost aura and the glint on its tail crystals, the Crystal Knight's slash
--    trail while it strikes, the colossus's rain under the cloud. (Dust, breath, embers, sparkles, the strike accents, the colossus's chest
--    arcs and the glow pulse stay in KeeperFx / KeeperSurge / BeastAnimation.)
--  * Budget: ClientFxBudget tier 1 (low graphics / FastMode) = none, tier 2 (mobile) = half the rates, tier 3 = full; an emitter never above
--    MaxRate, a keeper never above MaxKeeperRate in all (both times the tier's share); nothing beyond Range studs from the camera.
--  * Asleep: flames burn low (35 %), wisps / spores / frost / rain / glint dim, the sand swirl and the dust trail stop, the bolts flash half
--    as often, the dragon snorts its smoke (only asleep, as in the sheets); the golem's leaves keep falling (it sleeps as a tree).
local M={Range=200,MaxRate=14,MaxKeeperRate=40,TierScale={[1]=0,[2]=.5,[3]=1}}
local V,CF=Vector3.new,CFrame.new
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local FIRE='rbxasset://textures/particles/fire_main.dds'
local function rgb(r,g,b)return Color3.fromRGB(r,g,b)end
-- Rate: particles / s at tier 3 awake; Asleep / Awake: rate factor in that state; Chase: only while hunting; Area: from the part's volume.
M.Looks={
 Flame={Texture=FIRE,Colors={rgb(255,226,120),rgb(255,120,28),rgb(150,36,10)},Size={.85,.3},Alpha={.1,1},Life={.35,.6},Speed={2.6,4},Rate=5,Asleep=.35,Glow=1,Spread=12},
 Smoke={Texture=SMOKE,Colors={rgb(96,90,88),rgb(54,50,50)},Size={.5,1.5},Alpha={.45,1},Life={1,1.6},Speed={1.4,2.4},Rate=1.4,Asleep=1,Awake=0,Glow=0,Spread=14},
 Wisp={Texture=SMOKE,Colors={rgb(176,96,255),rgb(64,18,128)},Size={.55,.15},Alpha={.25,1},Life={.8,1.3},Speed={1,2},Rate=2,Asleep=.5,Glow=.8,Spread=18},
 Leaves={Texture=SPARK,Colors={rgb(104,170,70),rgb(70,128,48)},Size={.45,.35},Alpha={.05,1},Life={3,4.5},Speed={.3,.8},Rate=2.5,Asleep=1,Glow=0,Area=true,Fall=2.2,Spin=true},
 Spores={Texture=SPARK,Colors={rgb(236,250,170),rgb(170,235,120)},Size={.18,.08},Alpha={.2,1},Life={2,3},Speed={.2,.6},Rate=1.2,Asleep=.5,Glow=.6,Area=true,Rise=.6},
 JungleLeaves={Texture=SPARK,Colors={rgb(86,150,58),rgb(130,176,70)},Size={.4,.3},Alpha={.05,1},Life={2.2,3.2},Speed={1.5,2.5},Rate=1,Asleep=.5,Glow=0,Fall=2.5,Spread=55,Spin=true},
 Swirl={Texture=SMOKE,Colors={rgb(226,200,142),rgb(214,186,132)},Size={.45,1.3},Alpha={.45,1},Life={.7,1.1},Speed={1,2},Rate=2,Asleep=0,Glow=0,Spread=60,Spin=true},
 DustTrail={Texture=SMOKE,Colors={rgb(222,196,140),rgb(200,176,124)},Size={.9,2.4},Alpha={.5,1},Life={.8,1.2},Speed={.5,1.2},Rate=4,Asleep=0,Chase=true,Glow=0,Spread=70},
 Frost={Texture=SMOKE,Colors={rgb(214,240,255),rgb(176,222,255)},Size={1.2,2.2},Alpha={.78,1},Life={1.4,2},Speed={.2,.5},Rate=1.5,Asleep=.6,Glow=.2,Area=true,Rise=.4},
 Glint={Texture=SPARK,Colors={rgb(240,252,255),rgb(150,220,255)},Size={.5,.1},Alpha={0,1},Life={.35,.6},Speed={0,.2},Rate=1.2,Asleep=.5,Glow=1,Spread=180},
 Rain={Texture=SPARK,Colors={rgb(190,214,240),rgb(160,190,226)},Size={.14,.14},Alpha={.3,.6},Life={.6,.9},Speed={20,26},Rate=12,Asleep=.6,Glow=.15,Area=true,Rain=true},
}
-- Effects from the notes, on a mesh part by name; At = the part's centre + its size * At (rest space).
M.Extra={
 [1]={{Look='Leaves',Part='Head_Canopy'},{Look='Spores',Part='Body'}},
 [6]={{Look='JungleLeaves',Part='Head',At={0,.5,0},Dir={0,1,0}}},
 [2]={{Look='Swirl',Part='Segment9',At={0,0,.5},Dir={0,1,.3}},{Look='DustTrail',Part='Segment4',At={0,-.5,0},Dir={0,1,0}}},
 [3]={{Look='Frost',Part='Body'},{Look='Glint',Part='Tail',At={.22,.2,.42},Dir={0,1,0}}},
 [5]={{Trail='Slash',Part='Sword',From={0,.05,0},To={0,-.42,0}}},
 [7]={{Look='Rain',Part='Head_Cloud'}},
}
M.Bolt={Color=rgb(196,236,255),Width=.11,Every={.9,2.6},For=.12,Kinks=2}
M.Slash={Colors={rgb(240,220,255),rgb(176,128,255)},Life=.2}

local function seq(a,b)return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(1,b)})end
local function colours(list)
 local k={};for i,c in ipairs(list)do k[i]=ColorSequenceKeypoint.new((i-1)/math.max(1,#list-1),c)end
 return ColorSequence.new(k)
end
local function emitter(look,parent,kind)
 local e=Instance.new('ParticleEmitter');e.Name='KeeperFx152';e:SetAttribute('KeeperFxKind',kind);e.Texture=look.Texture;e.Color=colours(look.Colors)
 e.Size=seq(look.Size[1],look.Size[2]);e.Transparency=seq(look.Alpha[1],look.Alpha[2])
 e.Lifetime=NumberRange.new(look.Life[1],look.Life[2]);e.Speed=NumberRange.new(look.Speed[1],look.Speed[2])
 e.LightEmission=look.Glow or 0;e.LightInfluence=look.Glow and look.Glow>.5 and 0 or 1;e.Rate=0;e.Enabled=false;e.LockedToPart=false
 e.SpreadAngle=Vector2.new(look.Spread or 25,look.Spread or 25);e.EmissionDirection=Enum.NormalId.Top
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=look.Spin and NumberRange.new(-90,90)or NumberRange.new(-20,20)
 if look.Fall then e.Acceleration=V(0,-look.Fall,0);e.Drag=.6 end
 if look.Rise then e.Acceleration=V(0,look.Rise,0);e.Drag=1 end
 if look.Rain then
  e.EmissionDirection=Enum.NormalId.Bottom;e.SpreadAngle=Vector2.new(4,4);e.Acceleration=V(0,-20,0)
  e.Orientation=Enum.ParticleOrientation.VelocityParallel;e.Squash=NumberSequence.new(-.85);e.Rotation=NumberRange.new(0);e.RotSpeed=NumberRange.new(0)
 elseif look.Area then e.EmissionDirection=look.Fall and Enum.NormalId.Bottom or Enum.NormalId.Top;e.SpreadAngle=Vector2.new(60,60)end
 e.Parent=parent;return e
end
-- An attachment at rig-space point `at` (rest), its +Y along `dir`, inside `part` (whose rest frame is RestCFrame / VeiledFrame).
local function attach(part,at,dir,name)
 local rest=part:GetAttribute('RestCFrame')or part:GetAttribute('VeiledFrame')or CF()
 local local_=rest:PointToObjectSpace(at)
 local up=dir and rest:VectorToObjectSpace(dir).Unit or V(0,1,0)
 local side=math.abs(up.X)<.9 and V(1,0,0)or V(0,0,1)
 local right=side:Cross(up).Unit;local back=right:Cross(up).Unit
 local a=Instance.new('Attachment');a.Name=name or'KeeperFx152';a.CFrame=CFrame.fromMatrix(local_,right,up,back);a.Parent=part
 return a
end
local function vec(t)return V(t[1],t[2],t[3])end
local function partSpec(cfg,name)for _,s in ipairs(cfg.Parts)do if s.Name==name then return s end end end
local function relative(cfg,name,rel)
 local s=partSpec(cfg,name);if not s then return nil end
 return V(s.Center[1]+s.Size[1]*rel[1],s.Center[2]+s.Size[2]*rel[2],s.Center[3]+s.Size[3]*rel[3])
end

-- container: the keeper's BeastBody (biome keepers) or The Darkened's model; stage 0 = The Darkened. Returns nil when the stage has none,
-- and for today's keepers (only a container marked KeeperMeshVariant 'R152' gets these effects).
function M.new(container,stage)
 if not container or container:GetAttribute('KeeperMeshVariant')~='R152'then return nil end
 local Config=require(script.Parent.KeeperRigConfig152)
 local cfg=stage==0 and Config.Stages[0]or Config.Get(stage)
 if not cfg then return nil end
 local self={Stage=stage,Made={},Emitters={},Bolts={},Trails={},Random=Random.new(stage*7919+152)}
 local function keep(inst)table.insert(self.Made,inst);return inst end
 local function find(name)local p=container:FindFirstChild(name);return p and p:IsA('BasePart')and p or nil end
 for _,s in ipairs(cfg.Fx or{})do
  local part=find(s.Part)
  if part and s.Kind=='Bolt'then
   local a,b=vec(s.At),vec(s.To);local points={}
   for i=0,M.Bolt.Kinks+1 do points[i]=keep(attach(part,a:Lerp(b,i/(M.Bolt.Kinks+1)),nil,'KeeperBolt152'))end
   local beams={}
   for i=1,M.Bolt.Kinks+1 do
    local beam=Instance.new('Beam');beam.Name='KeeperBolt152';beam:SetAttribute('KeeperFxKind','Bolt');beam.Attachment0=points[i-1];beam.Attachment1=points[i]
    beam.Color=ColorSequence.new(M.Bolt.Color);beam.LightEmission=1;beam.LightInfluence=0;beam.FaceCamera=true;beam.Segments=1
    beam.Width0=M.Bolt.Width*(1+s.Size*.15);beam.Width1=beam.Width0*.7;beam.Transparency=NumberSequence.new(.05);beam.Enabled=false;beam.Parent=part
    beams[i]=keep(beam)
   end
   table.insert(self.Bolts,{Part=part,Points=points,Beams=beams,A=a,B=b,Rest=part:GetAttribute('RestCFrame')or part:GetAttribute('VeiledFrame')or CF(),NextAt=0,Until=-1})
  elseif part then
   local look=M.Looks[s.Kind]
   local e=emitter(look,keep(attach(part,vec(s.At),vec(s.Dir))),s.Kind)
   e.Size=seq(look.Size[1]*math.max(.6,s.Size*.55),look.Size[2]*math.max(.6,s.Size*.55))
   table.insert(self.Emitters,{Emitter=e,Look=look,Kind=s.Kind,Part=part.Name})
  end
 end
 for _,x in ipairs(M.Extra[stage]or{})do
  local part=find(x.Part)
  if part and x.Trail then
   local a0=keep(attach(part,relative(cfg,x.Part,x.From),nil,'KeeperSlash152'));local a1=keep(attach(part,relative(cfg,x.Part,x.To),nil,'KeeperSlash152'))
   local t=Instance.new('Trail');t.Name='KeeperSlash152';t:SetAttribute('KeeperFxKind',x.Trail);t.Attachment0=a0;t.Attachment1=a1;t.Color=colours(M.Slash.Colors);t.Transparency=seq(.25,1)
   t.Lifetime=M.Slash.Life;t.LightEmission=.7;t.FaceCamera=false;t.Enabled=false;t.Parent=part
   table.insert(self.Trails,{Trail=keep(t),Part=part.Name})
  elseif part then
   local look=M.Looks[x.Look]
   local host=look.Area and part or keep(attach(part,relative(cfg,x.Part,x.At),vec(x.Dir)))
   local e=emitter(look,host,x.Look);if look.Area then keep(e)end
   table.insert(self.Emitters,{Emitter=e,Look=look,Kind=x.Look,Part=part.Name})
  end
 end
 if #self.Emitters==0 and #self.Bolts==0 and #self.Trails==0 then return nil end
 return self
end
-- c: Now, Asleep, Chasing (hunting), Striking, Distance (camera), Tier (ClientFxBudget). Writes only what changed.
function M.Step(self,c)
 if not self or self.Destroyed then return end
 local tier=M.TierScale[c.Tier]or 0;local on=tier>0 and(c.Distance or 0)<=M.Range
 local total=0
 for _,it in ipairs(self.Emitters)do
  local look=it.Look;local k=c.Asleep and(look.Asleep or 1)or(look.Awake or 1)
  if look.Chase and not c.Chasing then k=0 end
  it.Want=on and math.min(M.MaxRate*tier,look.Rate*k*tier)or 0;total+=it.Want
 end
 local cap=M.MaxKeeperRate*tier;local scale=total>cap and cap/total or 1
 for _,it in ipairs(self.Emitters)do
  local r=math.floor(it.Want*scale*100)/100;local e=it.Emitter
  if e.Rate~=r then e.Rate=r end
  if e.Enabled~=(r>0)then e.Enabled=r>0 end
 end
 local now=c.Now or os.clock();local rnd=self.Random
 for _,b in ipairs(self.Bolts)do
  local show=false
  if on then
   if now>=b.NextAt then
    -- a new flash: a fresh zigzag between the two ends
    b.Until=now+M.Bolt.For;b.NextAt=now+rnd:NextNumber(M.Bolt.Every[1],M.Bolt.Every[2])*(c.Asleep and 2 or 1)/math.max(.5,tier)
    local len=(b.B-b.A).Magnitude
    for i=1,#b.Points-1 do
     local p=b.A:Lerp(b.B,i/#b.Points)+V(rnd:NextNumber(-1,1),rnd:NextNumber(-.5,.5),rnd:NextNumber(-1,1))*len*.18
     b.Points[i].Position=b.Rest:PointToObjectSpace(p)
    end
   end
   show=now<b.Until
  end
  if b.Shown~=show then b.Shown=show;for _,beam in ipairs(b.Beams)do beam.Enabled=show end end
 end
 for _,t in ipairs(self.Trails)do local want=on and c.Striking==true;if t.Trail.Enabled~=want then t.Trail.Enabled=want end end
end
-- Current rates (tests, /test views): {total, count}.
function M.Rates(self)
 local total,n=0,0;if not self then return 0,0 end
 for _,it in ipairs(self.Emitters)do total+=it.Emitter.Rate;if it.Emitter.Enabled then n+=1 end end
 return total,n
end
function M.Destroy(self)
 if not self or self.Destroyed then return end
 self.Destroyed=true
 for i=#self.Made,1,-1 do local inst=self.Made[i];if inst.Parent then inst:Destroy()end end
 table.clear(self.Made)
end
return M
