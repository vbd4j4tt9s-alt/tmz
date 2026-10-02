-- R113: client-only keeper effects (footfall dust, breath / biome particles, wake burst, strike slam,
-- eye light while chasing, ground rings, bounded camera shake). Built-in rbxasset textures only.
-- Budget: distance culled, particle token bucket, at most MaxLights eye lights, off in low graphics
-- (FastMode / ClientFxBudget tier 1) except footfall dust at half count; shake off with ReducedMotion.
local Config=require(script.Parent.KeeperRigConfig)
local Combat=require(script.Parent.KeeperCombat)
local Signature=require(script.Parent.KeeperSignatureStrike)
local Fx={MaxLights=3,DustDistance=120,BreathDistance=90,ShakeDistance=60,Rate=90,LowRate=35}
-- R124: keepers whose move smashes the ground (KeeperSignatureStrike Ground) play this at the visual impact frame.
-- Punches, swipes and pushes keep their sounds. A silent lead-in can be trimmed with SoundTiming Start_<id>.
Fx.GroundSound={Id='rbxassetid://73468358342062',Volume=.5,Lifetime=4}
local groundPreloaded=false
local V,CF=Vector3.new,CFrame.new
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local function rgb(r,g,b)return Color3.fromRGB(r,g,b)end
-- Dust: footfall colour; Size: dust scale; Heavy: footfall shake; Breath: mouth puff; Ambient: body motes.
Fx.Stages={
 [1]={Dust=rgb(112,94,66),Size=1.3,Heavy=.40,Ambient={Color=rgb(170,235,120),Rate=3,Rise=-1.5,Size=.35}},
 [2]={Dust=rgb(222,196,140),Size=.8,Heavy=0,Breath={Color=rgb(230,208,160),Alpha=.55,Size=1.1},Slither=true},
 [3]={Dust=rgb(236,243,250),Size=.9,Heavy=0,Breath={Color=rgb(228,242,255),Alpha=.35,Size=1.3},Ambient={Color=rgb(235,246,255),Rate=2,Rise=-1,Size=.25}},
 [4]={Dust=rgb(72,62,58),Size=1.1,Heavy=.25,Breath={Color=rgb(70,64,62),Alpha=.40,Size=1.6},Ambient={Color=rgb(255,138,40),Rate=5,Rise=4,Size=.30,Glow=true}},
 [5]={Dust=rgb(172,152,204),Size=1.4,Heavy=.45,Ambient={Color=rgb(214,176,255),Rate=3,Rise=.5,Size=.40,Glow=true}},
 [6]={Dust=rgb(98,86,54),Size=1.1,Heavy=.35,Breath={Color=rgb(222,236,216),Alpha=.62,Size=1.2},Ambient={Color=rgb(214,255,120),Rate=2,Rise=.4,Size=.22,Glow=true}},
 [7]={Dust=rgb(122,128,142),Size=1.8,Heavy=.75,Ambient={Color=rgb(170,212,255),Rate=6,Rise=0,Size=.45,Glow=true}},
}
-- Rest-space mouth points (front of the jaw) for breath puffs.
Fx.Mouth={[2]=V(0,1.1,-8.2),[3]=V(0,2.2,-10.9),[4]=V(0,6.2,-13.2),[6]=V(0,7.3,-5.3)}
local contacts={[1]={math.pi*.5,math.pi*1.5},[5]={math.pi*.5,math.pi*1.5},[7]={math.pi*.5,math.pi*1.5},
 [3]={0,math.pi*.5,math.pi,math.pi*1.5},[4]={.125,.125+math.pi},[6]={.125,.125+math.pi}}
local function emitter(parent,texture,color,size,alpha,life,speed,glow)
 local e=Instance.new('ParticleEmitter');e.Name='KeeperFx';e.Texture=texture;e.Color=ColorSequence.new(color)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.45),NumberSequenceKeypoint.new(1,size)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,alpha),NumberSequenceKeypoint.new(1,1)})
 e.Lifetime=NumberRange.new(life*.7,life);e.Speed=NumberRange.new(speed*.5,speed);e.Rate=0;e.Enabled=false
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-40,40);e.LightEmission=glow and 1 or 0;e.LightInfluence=glow and 0 or 1
 e.Drag=3;e.LockedToPart=false;e.Parent=parent;return e
end
-- Shared pools and governors ------------------------------------------------------------------
local tokens,tokenAt=Fx.Rate,0
local lit={};local rings={};local shake={Amount=0,At=0};local folder,connection,camState;local bolt
local function low()
 local ok,budget=pcall(require,script.Parent.ClientFxBudget)
 return ok and budget.Low()or false
end
local function reduced()
 local ok,value=pcall(function()return game:GetService('GuiService').ReducedMotionEnabled end)
 return ok and value==true
end
function Fx.Spend(count,now,isLow)
 -- R123: one clock for the bucket. Callers pass server time (Step/Wake/Slam) or os.clock (Burst); mixing them
 -- drove the bucket far negative after any footfall, silently dropping hit bursts.
 now=os.clock()
 local rate=isLow and Fx.LowRate or Fx.Rate
 tokens=math.min(rate,tokens+(now-tokenAt)*rate);tokenAt=now
 count=math.min(count,math.floor(tokens));if count<=0 then return 0 end
 tokens-=count;return count
end
local function tick()
 local now=os.clock()
 for i=#rings,1,-1 do
  local r=rings[i];local u=(now-r.At)/r.Duration
  if u>=1 or not r.Part.Parent then r.Part.Transparency=1;r.Busy=false;table.remove(rings,i)
  else
   local e=1-(1-u)^3;local d=r.From+(r.To-r.From)*e
   r.Part.Size=V(.18,d,d);r.Part.Transparency=.35+.65*u
  end
 end
 -- R123: lightning accent flash fades over Fx.BoltSeconds.
 if bolt and bolt.Live then
  local u=(now-bolt.At)/Fx.BoltSeconds
  if u>=1 or not bolt.Part.Parent then bolt.Live=false;bolt.Part.Transparency=1;bolt.Light.Enabled=false
  else bolt.Part.Transparency=.1+.9*u;bolt.Light.Brightness=bolt.Peak*(1-u)end
 end
 -- Bounded camera shake (reset/apply around the camera update, like KeeperHitEffects).
 local camera=workspace.CurrentCamera
 local t=now-shake.At;local amount=shake.Amount*math.max(0,1-t/.22)^2
 if camera and amount>.002 and not reduced()then
  local offset=CF(math.sin(t*97)*.10*amount,math.cos(t*83)*.14*amount,0)*CFrame.Angles(math.rad(.35)*amount*math.sin(t*71),0,math.rad(.45)*amount*math.sin(t*89))
  camState={Camera=camera,Offset=offset};camera.CFrame=camera.CFrame*offset;camState.Written=camera.CFrame
 end
end
local function resetCamera()
 local s=camState;camState=nil
 if s and s.Camera==workspace.CurrentCamera and s.Camera.CFrame==s.Written then s.Camera.CFrame=s.Camera.CFrame*s.Offset:Inverse()end
end
local function ensure()
 if connection~=nil then return end
 local Run=game:GetService('RunService');if not Run:IsClient()then connection=false;return end
 folder=Instance.new('Folder');folder.Name='KeeperFxLocal';folder.Parent=workspace
 -- Around the camera update: reset first (Camera-3), apply last (Camera+3). Nests with KeeperHitEffects (-2/+2).
 Run:BindToRenderStep('KeeperFxShakeReset',Enum.RenderPriority.Camera.Value-3,resetCamera)
 Run:BindToRenderStep('KeeperFxShake',Enum.RenderPriority.Camera.Value+3,tick)
 connection=true
end
function Fx.Shake(amount)
 ensure();if reduced()then return end
 local now=os.clock();local left=shake.Amount*math.max(0,1-(now-shake.At)/.22)^2
 shake.Amount=math.min(1,math.max(left,amount));shake.At=now
end
-- Expanding flat ground ring, pooled (max 6 live).
function Fx.Ring(position,color,from,to,duration)
 ensure();if not folder then return end
 local ring
 for _,r in ipairs(rings)do if not r.Busy then ring=r end end
 if not ring then
  if #rings>=6 then ring=table.remove(rings,1)else ring={}end
  if not ring.Part then
   local p=Instance.new('Part');p.Name='KeeperFxRing';p.Shape=Enum.PartType.Cylinder;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
   p.CastShadow=false;p.Material=Enum.Material.Neon;p.Transparency=1;p.Size=V(.18,1,1);p.Parent=folder;ring.Part=p
  end
  table.insert(rings,ring)
 end
 ring.Busy=true;ring.At=os.clock();ring.From=from;ring.To=to;ring.Duration=duration or .45
 ring.Part.Color=color;ring.Part.CFrame=CF(position+V(0,.12,0))*CFrame.Angles(0,0,math.pi/2);ring.Part.Size=V(.18,from,from);ring.Part.Transparency=.35
end
-- One shared ground emitter for one-off bursts (hit dust).
local burstAnchor
function Fx.Burst(position,color,count,size)
 ensure();if not folder then return end
 if not burstAnchor then
  local p=Instance.new('Part');p.Name='KeeperFxBurst';p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Transparency=1;p.Size=V(.2,.2,.2);p.Parent=folder
  local a=Instance.new('Attachment');a.Parent=p;burstAnchor={Part=p,Emitter=emitter(a,SMOKE,color,4,.45,.9,9)}
  burstAnchor.Emitter.EmissionDirection=Enum.NormalId.Top;burstAnchor.Emitter.SpreadAngle=Vector2.new(80,80)
 end
 count=Fx.Spend(count,os.clock(),low());if count<=0 then return 0 end
 local e=burstAnchor.Emitter;burstAnchor.Part.CFrame=CF(position)
 e.Color=ColorSequence.new(color);e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.45),NumberSequenceKeypoint.new(1,size)});e:Emit(count)
 return count
end
-- R123: per-move impact accents at the strike point (KeeperSignatureStrike.Moves[stage].Accent).
-- Spark: glowing shards/embers/sparks (shared emitter); Dust: ground dust; Rings: ground rings (pooled, max 6);
-- Arc: emit along a sweep arc in front; Bolt: one pooled neon bolt + light flash. Every particle goes through
-- Fx.Spend; low graphics keeps only dust (halved) and rings, ReducedMotion drops the light flash.
Fx.BoltSeconds=.14
Fx.Accents={
 Dust={Color=rgb(112,94,66),Dust=10,Size=4.5,Rings=1,Ring={4,20},Ground=true},
 Sand={Color=rgb(226,200,142),Dust=9,Size=2.6,Rings=1,Ring={2,9},Ground=true},
 Frost={Color=rgb(206,236,255),Spark=9,SparkSize=.9,Rings=1,Ring={2,10}},
 Fire={Color=rgb(255,128,34),Spark=4,SparkSize=1.1,Arc=true,Dust=3,Size=2.2,DustColor=rgb(72,62,58)},
 Crystal={Color=rgb(214,176,255),Spark=10,SparkSize=1.0,Rings=1,Ring={2,11}},
 Slam={Color=rgb(98,86,54),Dust=10,Size=3.4,Rings=2,Ring={3,15},Ground=true},
 Lightning={Color=rgb(170,212,255),Spark=8,SparkSize=1.3,Bolt=true,Rings=1,Ring={4,18}},
 Spectral={Color=rgb(204,173,255),Spark=8,SparkSize=1.1,Rings=1,Ring={3,12},Dust=4,Size=2.4,DustColor=rgb(25,21,35)},
}
local sparkAnchor
local function spark(position,color,count,size,isLow)
 ensure();if not folder or isLow then return 0 end
 if not sparkAnchor then
  local p=Instance.new('Part');p.Name='KeeperFxSpark';p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Transparency=1;p.Size=V(.2,.2,.2);p.Parent=folder
  local a=Instance.new('Attachment');a.Parent=p;sparkAnchor={Part=p,Emitter=emitter(a,SPARK,color,1,.05,.45,16,true)}
  sparkAnchor.Emitter.SpreadAngle=Vector2.new(180,180);sparkAnchor.Emitter.Acceleration=V(0,-14,0);sparkAnchor.Emitter.Drag=2
 end
 count=Fx.Spend(count,os.clock(),false);if count<=0 then return 0 end
 local e=sparkAnchor.Emitter;sparkAnchor.Part.CFrame=CF(position)
 e.Color=ColorSequence.new(color);e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size),NumberSequenceKeypoint.new(1,size*.2)});e:Emit(count)
 return count
end
local function flash(position,color)
 ensure();if not folder then return end
 if not bolt then
  local p=Instance.new('Part');p.Name='KeeperFxBolt';p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.Material=Enum.Material.Neon;p.Transparency=1;p.Size=V(.5,24,.5);p.Parent=folder
  local l=Instance.new('PointLight');l.Range=18;l.Shadows=false;l.Enabled=false;l.Parent=p
  bolt={Part=p,Light=l,Live=false,At=0,Peak=0}
 end
 bolt.Part.Color=color;bolt.Light.Color=color
 bolt.Part.CFrame=CF(position+V(0,12,0))*CFrame.Angles(0,math.random()*math.pi,.12)
 bolt.Part.Transparency=.1;bolt.At=os.clock();bolt.Live=true
 bolt.Peak=reduced()and 0 or 3;bolt.Light.Brightness=bolt.Peak;bolt.Light.Enabled=bolt.Peak>0
end
-- kind: accent name; point: world strike point; frame: keeper visual root (facing); isLow: low graphics.
function Fx.Accent(kind,point,frame,isLow)
 local a=Fx.Accents[kind];if not a then return 0 end
 local ground=a.Ground and V(point.X,frame and(frame*V(0,-4,0)).Y or point.Y,point.Z)or point
 local emitted=0
 for i=1,(a.Rings or 0)do Fx.Ring(ground,a.Color:Lerp(Color3.new(1,1,1),.35),a.Ring[1]*i,a.Ring[2]/i^.5,.35+.12*i)end
 if a.Dust then
  local count=isLow and math.ceil(a.Dust/2)or a.Dust
  emitted+=Fx.Burst(ground,a.DustColor or a.Color,count,a.Size)or 0
 end
 if a.Spark then
  if a.Arc and frame then
   -- Three bursts along a sweep from the striker's right to its left, through the strike point.
   for i=-1,1 do emitted+=spark(point+frame:VectorToWorldSpace(V(-i*3.5,.5*math.abs(i),1.2*math.abs(i))),a.Color,a.Spark,a.SparkSize,isLow)end
  else emitted+=spark(point,a.Color,a.Spark,a.SparkSize,isLow)end
 end
 if a.Bolt and not isLow then flash(point,a.Color)end
 return emitted
end
-- Per keeper ------------------------------------------------------------------------------------
local function center(b)return V((b[1][1]+b[2][1])/2,(b[1][2]+b[2][2])/2,(b[1][3]+b[2][3])/2)end
function Fx.new(root,stage)
 local spec=Fx.Stages[stage];local rig=Config[stage];if not spec or not rig then return nil end
 local self={Root=root,Stage=stage,Spec=spec,Feet={},NextBreath=0,NextSlither=0,LastCycle=nil}
 self.GroundSound=(Signature.Moves[stage]and Signature.Moves[stage].Ground)==true
 if self.GroundSound and not groundPreloaded then groundPreloaded=true;require(script.Parent.LocalSfx).Preload({Fx.GroundSound.Id})end
 local s=spec.Size
 self.Foot=Instance.new('Attachment');self.Foot.Name='KeeperFxFoot';self.Foot.Parent=root
 self.Dust=emitter(self.Foot,SMOKE,spec.Dust,3.2*s,.5,.8,5*s)
 self.Dust.EmissionDirection=Enum.NormalId.Top;self.Dust.SpreadAngle=Vector2.new(75,75);self.Dust.Acceleration=V(0,1.5,0)
 for group,b in pairs(rig.Bounds)do
  if group:find('Leg')or(stage==6 and group:find('Arm'))then self.Feet[group]=V((b[1][1]+b[2][1])/2,math.min(b[1][2],b[2][2]),(b[1][3]+b[2][3])/2)end
 end
 self.BodyPoint=rig.Bounds.Body and center(rig.Bounds.Body)or V(0,0,0)
 -- R123: strike tips (rest space) for the impact accent: front of a head, bottom of a limb or blade.
 local move=Signature.Moves[stage];self.Accent=move and move.Accent;self.Tips={}
 for _,group in ipairs(move and move.Tip or {})do
  local b=rig.Bounds[group]
  if b then
   local tip=group=='Head'and V((b[1][1]+b[2][1])/2,(b[1][2]+b[2][2])/2,math.min(b[1][3],b[2][3]))
    or V((b[1][1]+b[2][1])/2,math.min(b[1][2],b[2][2]),(b[1][3]+b[2][3])/2)
   table.insert(self.Tips,{Group=group,Point=tip})
  end
 end
 if spec.Breath and Fx.Mouth[stage]then
  self.Mouth=Instance.new('Attachment');self.Mouth.Name='KeeperFxMouth';self.Mouth.Parent=root
  self.Breath=emitter(self.Mouth,SMOKE,spec.Breath.Color,spec.Breath.Size*2.2,spec.Breath.Alpha,.9,6)
  self.Breath.EmissionDirection=Enum.NormalId.Front;self.Breath.SpreadAngle=Vector2.new(14,14);self.Breath.Acceleration=V(0,.8,0)
 end
 if spec.Ambient then
  local a=spec.Ambient
  self.Body=Instance.new('Attachment');self.Body.Name='KeeperFxBody';self.Body.Parent=root
  self.Ambient=emitter(self.Body,SPARK,a.Color,a.Size*(rig.Scale or 1),.2,2.2,2.5,a.Glow)
  self.Ambient.SpreadAngle=Vector2.new(180,180);self.Ambient.Acceleration=V(0,a.Rise,0);self.Ambient.Drag=1.5
 end
 local eyes,n=V(),0
 for _,p in ipairs(rig.Parts)do if p.EyeGlow then eyes+=V(table.unpack(p.Center));n+=1;self.EyeColor=Color3.new(table.unpack(p.Color))end end
 if n>0 then
  self.EyePoint=eyes/n
  self.Eyes=Instance.new('Attachment');self.Eyes.Name='KeeperFxEyes';self.Eyes.Parent=root
  local l=Instance.new('PointLight');l.Color=self.EyeColor;l.Brightness=0;l.Range=math.min(16,7*math.max(1,(rig.Scale or 1)*.7));l.Shadows=false;l.Enabled=false;l.Parent=self.Eyes
  self.Light=l
 end
 return self
end
local function crossed(from,to,phase)
 local span=(to-from)%(math.pi*2);if span<=0 or span>math.pi then return false end
 return (phase-from)%(math.pi*2)<span
end
local function place(att,root,world)att.WorldCFrame=world end
function Fx.Step(self,c)
 if not self or self.Destroyed then return end
 local now,frames,frame=c.Now,c.Frames,c.Frame
 local isLow=c.Low;local near=c.Distance<Fx.DustDistance
 local spec=self.Spec
 -- Eye light while chasing: nearest few only.
 if self.Light then
  local want=not isLow and c.Distance<120 and c.Chasing and c.Awake>.5
  if want and not lit[self]then local count=0;for _ in pairs(lit)do count+=1 end;if count>=Fx.MaxLights then want=false end end
  if want then
   lit[self]=true;self.Light.Enabled=true;self.Light.Brightness=.6+1.6*math.clamp(c.Urgency or 0,0,1)
   if frames and frames.Head then place(self.Eyes,self.Root,frame*frames.Head*CF(self.EyePoint))end
  elseif lit[self]then lit[self]=nil;self.Light.Enabled=false end
 end
 if self.Ambient then
  local on=not isLow and c.Distance<Fx.BreathDistance and c.Awake>.6
  if on then self.Ambient.Rate=spec.Ambient.Rate*(1+(c.Urgency or 0));if frames and frames.Body then place(self.Body,self.Root,frame*frames.Body*CF(self.BodyPoint))end end
  if self.Ambient.Enabled~=on then self.Ambient.Enabled=on end
 end
 -- Footfalls: detect the gait phase crossing a contact and puff at the lowest foot.
 local cycle=c.Cycle or 0;local last=self.LastCycle;self.LastCycle=cycle
 if not near or not frames or c.Asleep or c.Awake<.5 then return end
 local moving=c.Moving or 0
 if spec.Slither then
  if moving>.3 and now>=self.NextSlither then
   self.NextSlither=now+.18
   local n=frames.Segment5 and Fx.Spend(isLow and 1 or 2,now,isLow)or 0
   if n>0 then place(self.Foot,self.Root,frame*frames.Segment5*CF(2.5,-4,14.9));self.Dust:Emit(n)end
  end
 elseif last and moving>.35 and contacts[self.Stage]then
  for _,phase in ipairs(contacts[self.Stage])do
   if crossed(last,cycle,phase)then
    local best,bestY
    for group,p in pairs(self.Feet)do local f=frames[group];if f then local w=f*p;if not bestY or w.Y<bestY then best,bestY=w,w.Y end end end
    if best then
     local count=math.floor((isLow and 2 or 4)*spec.Size*(.6+.4*moving)+.5)
     local n=Fx.Spend(count,now,isLow)
     if n>0 then place(self.Foot,self.Root,frame*CF(best.X,-4,best.Z));self.Dust:Emit(n)end
     if spec.Heavy>0 and c.LocalDistance and c.LocalDistance<Fx.ShakeDistance then
      Fx.Shake(spec.Heavy*.35*(1-c.LocalDistance/Fx.ShakeDistance)*moving)
     end
    end
   end
  end
 end
 -- Breath puffs: slow while idle/returning, quick while chasing.
 if self.Breath and not isLow and c.Distance<Fx.BreathDistance and frames.Head and now>=self.NextBreath then
  self.NextBreath=now+(c.Chasing and .55 or 1.5)+math.random()*.3
  local n=Fx.Spend(c.Chasing and 3 or 2,now,isLow)
  if n>0 then place(self.Mouth,self.Root,frame*frames.Head*CF(Fx.Mouth[self.Stage]));self.Breath:Emit(n)end
 end
end
-- Wake burst: ground ring and dust at the body, a breath burst, and a short shake nearby.
function Fx.Wake(self,c)
 if not self or self.Destroyed or c.Distance>Fx.DustDistance then return end
 local frame,frames=c.Frame,c.Frames;local spec=self.Spec;local s=spec.Size
 local ground=frame*V(0,-4,0)
 Fx.Ring(ground,spec.Dust:Lerp(Color3.new(1,1,1),.35),4*s,18*s,.55)
 local n=Fx.Spend(c.Low and 6 or 14,c.Now,c.Low)
 if n>0 then place(self.Foot,self.Root,CF(ground));self.Dust:Emit(n)end
 if self.Breath and frames and frames.Head and not c.Low then
  local m=Fx.Spend(8,c.Now,c.Low);if m>0 then place(self.Mouth,self.Root,frame*frames.Head*CF(Fx.Mouth[self.Stage]));self.Breath:Emit(m)end
 end
 if c.LocalDistance and c.LocalDistance<45 then Fx.Shake((.25+spec.Heavy*.5)*(1-c.LocalDistance/45))end
end
-- Strike slam at the client's impact instant (visual only; the server decides the hit).
function Fx.Slam(self,c)
 if not self or self.Destroyed or c.Distance>Fx.DustDistance then return end
 local spec=self.Spec;local reach=Combat.Get(self.Stage).Reach
 local point=c.Frame*V(0,-4,-reach*.55)
 -- R123: the move's own accent at its striking tip (from the client strike frames), small and budgeted.
 local tip,n0=V(),0
 if c.Frames then for _,t in ipairs(self.Tips)do local f=c.Frames[t.Group];if f then tip+=c.Frame*(f*t.Point);n0+=1 end end end
 local strike=n0>0 and tip/n0 or point
 local n=Fx.Spend(c.Low and 2 or 4,c.Now,c.Low)
 if n>0 then place(self.Foot,self.Root,CF(V(strike.X,point.Y,strike.Z)));self.Dust:Emit(n)end
 if self.Accent then Fx.Accent(self.Accent,strike,c.Frame,c.Low)end
 if self.GroundSound then require(script.Parent.LocalSfx).Play(Fx.GroundSound.Id,V(strike.X,point.Y,strike.Z),Fx.GroundSound.Volume,1,Fx.GroundSound.Lifetime)end
 if spec.Heavy>0 and c.LocalDistance and c.LocalDistance<40 then Fx.Shake(spec.Heavy*.6*(1-c.LocalDistance/40))end
end
function Fx.Destroy(self)
 if not self or self.Destroyed then return end
 self.Destroyed=true;lit[self]=nil
 for _,key in ipairs({'Foot','Mouth','Body','Eyes'})do if self[key]then self[key]:Destroy()end end
end
Fx.Low=low
return Fx
