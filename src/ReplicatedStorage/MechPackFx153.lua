-- R153 (owner picked the full Mech touch, docs/proposals/R153/mech_pack.md section 4): the Limited Mech Pack's opening, every cue on a beat the R152 reveal
-- already has, so nothing gets longer. The beats are READ (RarePullRules.Pulses / the reveal record's BurstAt, TearTicks and Quick), never set here: a timing
-- change there moves these cues with it.
--  * clicks 1-4 (PackOpeningFeedback, the opener's clicking copy): each backs out one corner bolt (both faces), with UpgradeClick's ratchet tick instead of
--    Bubble04 at Bubble04's volume (InteractionAudio 'MechClick'); click 5 opens as before;
--  * every wobble pulse: a scan line sweeps each face in the R152 hint colour (RarePullRules.Hint: the seam glow's colour walking up the ladder), and the
--    core and the traces flash in it;
--  * every tear group: the hazard stripes go open with their strips, a puff of steam and a soft hiss (R152's Flight whoosh pitched up, about -39 LUFS at
--    its loudest: under the -30 whoosh cap and 8 dB under every hit; ONE extra voice, restarted per group);
--  * the burst: a ring of steam and the turbine spins down. Then the R152 card / story scene, unchanged.
-- SeedPackClient draws the opening pack for everyone near, so onlookers see it too. ReducedMotion / low quality: no bolt or turbine motion and no steam,
-- just the scan colour. One scan part per face, one steam emitter and one Sound, all gone with the reveal (Destroy).
local Ladder=require(script.Parent.RarePullRules)
local Cache do local ok,m=pcall(require,script.Parent.PropCache152);Cache=ok and m or{new=function()return{Set=function(o,k,v)o[k]=v end}end}end
local CF,V=CFrame.new,Vector3.new
local F={}
F.Bolt={Seconds=.12,Turns=1.5,Lift=.07}             -- one click: the bolt turns this many times and rises this far (studs at scale 1) in this long
F.Scan={Seconds=.30,Top=.62,Bottom=-.62,Out=.29,Size=V(1.64,.03,.012)} -- face coordinates (MechPackArt153.FaceFrame): sweeps top to bottom, clear of the blades
F.Glow={Base=.30,Attack=.04,Decay=.35,After=.25}   -- the core / traces: this share of the hint colour through the suspense, a flash on every pulse
F.Turbine={Peak=3,Decay=.45}                         -- spins up to 3x through the suspense, then down (exp, .45 s) after the burst
F.Steam={Puff=6,Ring=16,Grace=.25}                   -- particles per tear group / in the ring; a beat reaching this client later than Grace is skipped
F.Hiss={Volume=.04,Pitch=2.2,Lead=.06,Length=.32,Fade=.15} -- the Flight whoosh: its swell lands Lead after the tick; gone Length after it
local function clamp01(x)return math.clamp(x,0,1)end
local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
local function easeOut(x)x=clamp01(x);return 1-(1-x)^3 end
function F.Is(model)return model~=nil and model:GetAttribute('BagVariant')=='MechLimited'and model:GetAttribute('MechDesignRevision')==153 end
-- ReducedMotion or a low-quality device: no bolt / turbine motion, no steam
function F.Calm(reduced)
 if reduced then return true end
 local ok,low=pcall(function()return require(script.Parent.ClientFxBudget).Low()end)
 return ok and low==true
end
-- a bolt part's frame in the root's frame, backed out by k (0 = in, 1 = out): turned anticlockwise (seen from outside) about its own axis and lifted
function F.BoltLocal(rest,pivot,k,scale)
 return pivot*CF(0,0,F.Bolt.Lift*scale*k)*CFrame.Angles(0,0,F.Bolt.Turns*2*math.pi*k)*pivot:Inverse()*rest
end
-- the turbine's clock (seconds of R103's spin) t seconds into the reveal: the held pack's own spin, faster through the suspense, then spun down after the burst
function F.TurbineClock(t,burstAt)
 local B=math.max(.05,burstAt);local P,tau=F.Turbine.Peak,F.Turbine.Decay
 if t<=0 then return t end
 if t<B then return t+(P-1)*t^3/(3*B*B)end
 return B+(P-1)*B/3+P*tau*(1-math.exp(-(t-B)/tau))
end
-- 0..1: the flash on the core / traces from the pulses (a fast rise, a soft fall)
function F.Flash(t,pulses)
 local f=0
 for _,p in ipairs(pulses)do local a=t-p;if a>=0 then f=math.max(f,a<F.Glow.Attack and a/F.Glow.Attack or math.exp(-(a-F.Glow.Attack)/F.Glow.Decay))end end
 return f
end
-- the scan line at t: progress 0..1 of the sweep under way (nil = none)
function F.ScanAt(t,pulses)
 for i=#pulses,1,-1 do local a=t-pulses[i];if a>=0 then if a<F.Scan.Seconds then return a/F.Scan.Seconds end;return nil end end
 return nil
end
-- how much of the hint colour the core / traces show at t
function F.GlowMix(t,burstAt,pulses)
 if t<0 then return 0 end
 local m=F.Glow.Base+(1-F.Glow.Base)*F.Flash(t,pulses)
 if t>=burstAt then m*=1-clamp01((t-burstAt)/F.Glow.After)end
 return clamp01(m)
end
-- The hiss for a tear group heard a seconds after its tick: {TimePosition at the tick, Volume} (the whoosh entered so its measured swell lands Lead after it)
function F.HissStart()
 local ok,def=pcall(function()return require(script.Parent.RarePullSounds).Get('Flight')end)
 if not ok or not def or not def.Id then return nil end
 return {Id=def.Id,Entry=math.max(def.Region and def.Region[1]or 0,(def.Swell or 1.15)-F.Hiss.Lead*F.Hiss.Pitch),Region=def.Region}
end
function F.HissVolume(a)
 local H=F.Hiss;if a<0 or a>=H.Length then return 0 end
 return H.Volume*clamp01(a/.02)*clamp01((H.Length-a)/H.Fade)
end
-- Clicks 1-4 ------------------------------------------------------------------------------------------------------------------------------------
local clicks=setmetatable({},{__mode='k'})
-- PackOpeningFeedback's clicking copy got click `count`: bolts 1..min(count, 4) start backing out (now = os.clock()). True = a Mech bolt click (play 'MechClick').
function F.Click(copy,count,now)
 if not F.Is(copy)or type(count)~='number'then return false end
 local c=clicks[copy]
 if not c then
  c={Start={},Bolts={}};clicks[copy]=c
  for _,p in ipairs(copy:GetDescendants())do
   local i=p:GetAttribute('MechBolt')
   if i and p:IsA('BasePart')then
    local rest,pivot=p:GetAttribute('PackLocalFrame'),p:GetAttribute('MechBoltPivot')
    if typeof(rest)=='CFrame'and typeof(pivot)=='CFrame'then local list=c.Bolts[i]or{};c.Bolts[i]=list;list[#list+1]={Part=p,Rest=rest,Pivot=pivot}end
   elseif(p:IsA('Light')or p:IsA('ParticleEmitter'))and p:GetAttribute('MechHeldFx')then p.Enabled=false end -- (the real pack under the copy keeps its own hum)
  end
 end
 for i=1,math.min(count,4)do if not c.Start[i]then c.Start[i]=now end end
 return count>=1 and count<=4
end
-- every frame the copy is shaken (after its PivotTo): the bolts that were clicked, at their back-out
function F.StepClicks(copy,now,reduced)
 local c=clicks[copy];if not c or F.Calm(reduced)then return end
 local root=copy.PrimaryPart;if not root then return end
 local s=copy:GetAttribute('VisualScale')or 1;local frame=root.CFrame
 for i,start in pairs(c.Start)do
  local k=easeOut((now-start)/F.Bolt.Seconds)
  for _,b in ipairs(c.Bolts[i]or{})do if b.Part.Parent then b.Part.CFrame=frame*F.BoltLocal(b.Rest,b.Pivot,k,s)end end
 end
end
-- The world opening ------------------------------------------------------------------------------------------------------------------------------
local O={};O.__index=O
-- copy: SeedPackClient's opening copy of a Mech pack; record: its reveal record (RarityRank, Quick, BurstAt, TearTicks, FlapFrames, BagTransparency, Effect, Bag).
-- Takes the bolts, the turbine and the stripes out of record.FlapFrames (it moves them itself). Returns nil for any other pack.
function F.Opening(copy,record)
 if not F.Is(copy)or not copy.PrimaryPart then return nil end
 local Art=require(script.Parent.MechPackArt153)
 local rank=record.RarityRank or 1;local quick=record.Quick==true;local burst=record.BurstAt or Ladder.BurstAt(rank,quick)
 local reduced=false;pcall(function()reduced=game:GetService('GuiService').ReducedMotionEnabled==true end)
 local self=setmetatable({Copy=copy,Rank=rank,Quick=quick,BurstAt=burst,Pulses=Ladder.Pulses(rank,quick),Ticks=record.TearTicks or Ladder.TearTicks(rank,quick),Fired={},
  Scale=copy:GetAttribute('VisualScale')or 1,Calm=F.Calm(reduced),Bolts={},Spin={},Stripes={},Glow={},Blink={},Scans={},Set=Cache.new().Set},O)
 local players=game:GetService('Players');local me=players.LocalPlayer
 self.Mine=me~=nil and record.Bag~=nil and record.Bag.Parent==me.Character
 local frames,base=record.FlapFrames or{},record.BagTransparency or{}
 local strips={};for _,p in ipairs(copy:GetChildren())do if p:IsA('BasePart')and p:GetAttribute('TearIndex')then strips[p:GetAttribute('TearIndex')]=p end end
 local s=self.Scale
 local built={};for _,sp in ipairs(Art.Specs())do built[sp.Name]=sp.Color end -- (the colours as built: the held pack's pulse may have tinted the copy's)
 for _,p in ipairs(copy:GetDescendants())do if p:IsA('BasePart')then
  local rest=p:GetAttribute('PackLocalFrame')
  if typeof(rest)=='CFrame'then
   local bolt,motion,tear=p:GetAttribute('MechBolt'),p:GetAttribute('MechMotion'),p:GetAttribute('MechTear')
   if bolt and typeof(p:GetAttribute('MechBoltPivot'))=='CFrame'then
    self.Bolts[#self.Bolts+1]={Part=p,Rest=rest,Pivot=p:GetAttribute('MechBoltPivot'),Base=base[p]or p.Transparency};frames[p]=nil
   elseif motion=='Spin'and typeof(p:GetAttribute('MechMotionPivot'))=='CFrame'then
    local pivot=p:GetAttribute('MechMotionPivot')
    self.Spin[#self.Spin+1]={Part=p,Pivot=pivot,Offset=pivot:Inverse()*rest,Rate=p:GetAttribute('MechMotionRate')or 0,Base=base[p]or p.Transparency};frames[p]=nil
   elseif tear and strips[tear]then
    local strip=strips[tear];local sf=strip:GetAttribute('PackLocalFrame')or copy.PrimaryPart.CFrame:ToObjectSpace(strip.CFrame)
    self.Stripes[#self.Stripes+1]={Part=p,Strip=strip,Rel=sf:Inverse()*rest};frames[p]=nil
   end
  end
  if p:GetAttribute('MechGlow')then self.Glow[#self.Glow+1]={Part=p,Color=built[p.Name]or p.Color}end
  if p:GetAttribute('MechBlink')then self.Blink[#self.Blink+1]={Part=p,Color=built[p.Name]or p.Color,Period=p:GetAttribute('MechBlink')}end
 end end
 -- the turbine carries on from the held pack's own spin (SeedPackRender's clock: the server time, wrapped at 6 s)
 self.Clock0=self.Calm and 0 or((record.At or 0)%6)
 local parent=record.Effect or copy.Parent
 for _,side in ipairs({-1,1})do
  local p=Instance.new('Part');p.Name='MechScan';p.Size=F.Scan.Size*s;p.Material=Enum.Material.Neon;p.Color=Ladder.Neutral;p.Transparency=1
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
  self.Scans[#self.Scans+1]={Part=p,Face=Art.FaceFrame(side)}
 end
 local root=copy.PrimaryPart
 if not self.Calm then
  local a=Instance.new('Attachment');a.Name='MechSteam';a.CFrame=CF(0,(copy:GetAttribute('TearLipY')or 1.11)*s,Art.Pouch.Center.Z*s);a.Parent=root
  local e=Instance.new('ParticleEmitter');e.Name='MechSteamPuff';e.Texture='rbxasset://textures/particles/smoke_main.dds';e.Rate=0;e.Enabled=true
  e.Color=ColorSequence.new(Color3.fromRGB(236,242,248));e.LightEmission=.15;e.LightInfluence=.6;e.Lifetime=NumberRange.new(.55,.85);e.Drag=3
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12*s),NumberSequenceKeypoint.new(1,.55*s)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,1)});e.Acceleration=V(0,1.2*s,0)
  e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-40,40);e.Parent=a
  self.SteamAttachment,self.Steam,self.SteamRest=a,e,a.CFrame
  self:Puff()
 end
 local hiss=F.HissStart()
 if hiss then
  local snd=Instance.new('Sound');snd.Name='MechHiss';snd.SoundId=hiss.Id;snd.PlaybackSpeed=F.Hiss.Pitch;snd.Volume=0;snd.Looped=false
  snd.RollOffMinDistance=5;snd.RollOffMaxDistance=36;snd.Parent=root
  if hiss.Region then pcall(function()snd.PlaybackRegionsEnabled=true;snd.PlaybackRegion=NumberRange.new(hiss.Region[1],hiss.Region[2])end)end
  pcall(function()require(script.Parent.AudioMixer).Route(snd,'Effects')end)
  self.Hiss,self.HissEntry=snd,hiss.Entry
 end
 return self
end
-- the steam's resting set-up: puffs up out of the seal
function O:Puff()
 local e=self.Steam;local s=self.Scale
 e.EmissionDirection=Enum.NormalId.Top;e.SpreadAngle=Vector2.new(28,28);e.Speed=NumberRange.new(1.2*s,2.2*s)
end
-- a tear group: a puff of steam and the hiss (heard by everyone near: a 3D sound at the pack)
function O:Group(late)
 if self.Steam then self.Steam:Emit(F.Steam.Puff);self.Emitted=(self.Emitted or 0)+F.Steam.Puff end
 if self.Hiss then
  local snd=self.Hiss;pcall(function()snd:Stop()end)
  snd.Volume=F.HissVolume(late);snd.TimePosition=self.HissEntry+late*F.Hiss.Pitch;snd:Play();self.HissAt=self.Now-late;self.Hissed=(self.Hissed or 0)+1
 end
end
-- the burst: a ring of steam (16 puffs sent out flat, each from the attachment turned a 16th) and the turbine winds down (TurbineClock)
function O:Ring()
 local e,a=self.Steam,self.SteamAttachment;if not e then return end
 local s=self.Scale
 e.EmissionDirection=Enum.NormalId.Right;e.SpreadAngle=Vector2.new(4,4);e.Speed=NumberRange.new(2.2*s,2.8*s)
 for k=1,F.Steam.Ring do a.CFrame=self.SteamRest*CFrame.Angles(0,k*2*math.pi/F.Steam.Ring,0);e:Emit(1)end
 a.CFrame=self.SteamRest;self:Puff();self.Emitted=(self.Emitted or 0)+F.Steam.Ring;self.Rung=true
end
local function step(self,t,wrapperRoot)
 local S,s,B=self.Set,self.Scale,self.BurstAt
 self.Now=t
 local fade=clamp01((math.max(0,t-B)-.2)/.6) -- (SeedPackClient's wrapper fade)
 -- the bolts: out (the opener's clicks did it; an onlooker sees them come out in the reveal's first moment), fading with the wrapper
 local k=self.Calm and 0 or(self.Mine and 1 or easeOut(t/F.Bolt.Seconds))
 for _,b in ipairs(self.Bolts)do S(b.Part,'CFrame',wrapperRoot*F.BoltLocal(b.Rest,b.Pivot,k,s));S(b.Part,'Transparency',b.Base+(1-b.Base)*fade)end
 -- the turbine: faster through the suspense, spun down after the burst
 local clock=self.Calm and 0 or self.Clock0+F.TurbineClock(t,B)
 for _,e in ipairs(self.Spin)do S(e.Part,'CFrame',wrapperRoot*e.Pivot*CFrame.Angles(0,0,clock*e.Rate)*e.Offset);S(e.Part,'Transparency',e.Base+(1-e.Base)*fade)end
 -- the stripes go with their strips (SeedPackClient has peeled the strips this frame)
 for _,h in ipairs(self.Stripes)do if h.Strip.Parent then S(h.Part,'CFrame',h.Strip.CFrame*h.Rel);S(h.Part,'Transparency',h.Strip.Transparency)end end
 -- the hint colour (the seam glow's: RarePullRules.Hint) on the core / traces, flashing on every pulse, and the scan line sweeping each face
 local hint=Ladder.Hint(self.Rank,clamp01(t/B))
 local mix=F.GlowMix(t,B,self.Pulses)
 for _,g in ipairs(self.Glow)do S(g.Part,'Color',g.Color:Lerp(hint,mix))end
 for _,l in ipairs(self.Blink)do S(l.Part,'Color',t%l.Period<l.Period*.5 and l.Color or l.Color:Lerp(Color3.new(0,0,0),.7))end
 local u=t<B and F.ScanAt(t,self.Pulses)or nil
 for _,sc in ipairs(self.Scans)do
  if u and not self.Calm then
   local v=F.Scan.Top+(F.Scan.Bottom-F.Scan.Top)*smooth(u)
   S(sc.Part,'CFrame',wrapperRoot*CF(sc.Face.Position*s)*sc.Face.Rotation*CF(0,v*s,F.Scan.Out*s));S(sc.Part,'Color',hint);S(sc.Part,'Transparency',1-.85*math.sin(math.pi*(.1+.9*u)))
  else S(sc.Part,'Transparency',1)end
 end
 -- the tear groups: steam + hiss on each tick (a tick that reaches this client late is skipped), the ring on the burst
 for i,tick in ipairs(self.Ticks)do
  if not self.Fired[i]and t>=tick then self.Fired[i]=true;if t-tick<=F.Steam.Grace then self:Group(t-tick)end end
 end
 if not self.Fired.Burst and t>=B then self.Fired.Burst=true;if t-B<=F.Steam.Grace then self:Ring()end end
 if self.Hiss and self.HissAt then
  local a=t-self.HissAt
  if a>=F.Hiss.Length then pcall(function()self.Hiss:Stop()end);self.HissAt=nil;S(self.Hiss,'Volume',0)else S(self.Hiss,'Volume',F.HissVolume(a))end
 end
end
-- t: seconds after RevealAt; wrapperRoot: the wrapper's frame this frame (SeedPackClient's, wobble included). Runs after SeedPackClient's own part loop.
function O:Update(t,wrapperRoot)
 if self.Destroyed or self.Failed then return end
 local ok,err=pcall(step,self,t,wrapperRoot)
 if not ok then self.Failed=true;warn('[MechPackFx153] '..tostring(err))end -- (one bad frame stops only the Mech touch; the reveal carries on)
end
function O:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true
 if self.Hiss then pcall(function()self.Hiss:Stop()end);self.Hiss:Destroy();self.Hiss=nil end
 for _,sc in ipairs(self.Scans)do sc.Part:Destroy()end;table.clear(self.Scans)
 if self.SteamAttachment then self.SteamAttachment:Destroy();self.SteamAttachment,self.Steam=nil,nil end
end
return F
