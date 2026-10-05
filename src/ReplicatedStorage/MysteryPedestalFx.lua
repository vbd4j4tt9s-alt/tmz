-- R150 (owner: "polish the pack pedestal that players have in base"): the moving parts around a base's mystery pedestal, built on each player's own
-- screen (MysteryPackClient owns when). Client-only and cosmetic: nothing here touches data, prompts or the server's pedestal; a pedestal looks right
-- (just plainer) without it. The still parts (the sculpted pedestal, the glow, the gems) are the server's (MysteryPedestalArt); this adds
--   Runes    eight small tumbling gems orbiting the pack on a tilted ring (a halo): violet, dim and slow while Locked, gold, bright and fast when Ready
--   Wisps    faint violet motes rising off the pad while Locked        Rise   gold sparkles rising while Ready
--   Shaft    a soft column of gold light over the pad, only on the owner's own pedestal while Ready (so you spot it from far away)
--   Padlock  a gold padlock hanging on the column's front while Locked; when the pack unlocks it pops open, hops off and drops away
--   Burst / Pop / the pack's take flight   the moments (unlock, take) - one ring + sparks, and a pop where the pack lands on the player.
--   Sound   only existing assets: the unlock chime (the GemClaim file) and the lift-off whoosh (RarityRevealAudio's) play in the EFFECTS group
--           (AudioMixer: Effects volume 0 mutes them); the pickup pop is the game's pack pickup cue (InteractionAudio Bubble06), played by the client.
--           Each plays in the same call as its picture, from a voice warmed up when the first fx is built (nothing cold is played late).
-- Cost: one Folder "MysteryFx" in the pedestal's model (about 20 parts, 2 emitters of at most ~30 live sparkles) while the pedestal is within range of the
-- camera and its pack is Locked or Ready; nothing at all otherwise (the client destroys it when the pedestal is far, taken, empty or the quality is low).
-- Animation is one function (Step) the client calls once a frame for the pedestals that are near and on screen, and not at all when nothing is.
-- "Still" (the player's reduced-motion setting): the same parts, never moving - no orbit, particles, pulse or padlock animation.
local Tween=game:GetService('TweenService');local Debris=game:GetService('Debris');local SoundService=game:GetService('SoundService')
local Rules=require(script.Parent.MysteryPackRules)
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local VIOLET,GOLD,MINT=RGB(176,118,255),RGB(255,214,90),RGB(120,236,110)
local F={}
F.Colors={Violet=VIOLET,Gold=GOLD,Mint=MINT}
F.Tuning={
 Runes=8,Radius=3.4,Tilt=.3,SlowSpin=.5,FastSpin=1.35,   -- the halo: how many gems, how far from the pack (the pack is at most ~2 wide), how tilted, rad/s
 ShaftHeight=5.8,ShaftWidth=4.6,                         -- the light column over the pad
 LockSeconds=.95,LockHeight=3.4,                         -- the padlock's unlock animation, and its height on the column
 HopSeconds=1.1,HopHeight=.4,                            -- the pack's hop when it unlocks (the sign hangs .9 + .35 above its highest bob)
 LiftSeconds=.2,LiftHeight=.9,ArcHeight=2.2,ShrinkTo=.55,-- the take: the pack lifts, then flies to the player the way a harvested fruit does (PlantGrowthFx)
 FlightMin=.40,FlightMax=.70,FlightPerStud=.012,AimUp=.9,
}
local function smooth(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
-- The pack's hop (studs) t seconds after it unlocked: up and down a couple of times, settling.
function F.Hop(age)
 local T=F.Tuning;if type(age)~='number'or age~=age or age<0 or age>=T.HopSeconds then return 0 end
 local u=age/T.HopSeconds;return T.HopHeight*math.abs(math.sin(u*math.pi*2.5))*(1-u)
end
-- The take flight at u = 0..1 (the same shape as PlantGrowthFx.Flight): how far along (eased), the arc (0 .. 1 .. 0) and the pack's scale.
function F.Flight(u)u=math.clamp(u,0,1);return smooth(u),math.sin(u*math.pi),1-(1-F.Tuning.ShrinkTo)*smooth(u)end
function F.FlightSeconds(distance)local T=F.Tuning;return math.clamp(T.FlightMin+T.FlightPerStud*(tonumber(distance)or 0),T.FlightMin,T.FlightMax)end
-- The padlock at u = 0..1 of its unlock: the shackle pops open (0 .. .28), then the lock hops, tumbles and drops away, fading out.
function F.LockPose(u)
 u=math.clamp(u,0,1);local open=smooth(u/.28);local v=math.clamp((u-.28)/.72,0,1)
 return {Open=open,Up=.6*4*v*(1-v)-2.2*v*v,Tilt=v*2.2,Fade=math.clamp((v-.5)/.5,0,1)}
end
-- Sound ------------------------------------------------------------------------------------------------------------------------------------------------
local voices={}
local function unlockVoice()
 local v=voices.Unlock;if v and v.Parent then return v end
 local id='rbxassetid://82559527540705' -- GemClaim (InteractionAudio.AssetIds): the celebration cue, here in the Effects group
 local ok,Interaction=pcall(require,script.Parent.InteractionAudio)
 if ok and type(Interaction)=='table'and Interaction.Asset then id=Interaction.Asset('GemClaim')or id end
 v=Instance.new('Sound');v.Name='MysteryUnlockChime';v.SoundId=id;v.Volume=.3
 require(script.Parent.AudioMixer).Route(v,'Effects');v.Parent=SoundService;voices.Unlock=v;return v
end
-- Loads the unlock chime (and the whoosh) ahead of time: called when the first fx of a session is built, long before anything unlocks.
function F.WarmAudio()
 if voices.Warm then return end;voices.Warm=true
 task.spawn(function()pcall(function()
  game:GetService('ContentProvider'):PreloadAsync({unlockVoice()})
  local ok,Reveal=pcall(require,script.Parent.RarityRevealAudio);if ok and Reveal.Preload then Reveal.Preload()end
 end)end)
end
-- The unlock chime, now (the caller starts the ring / flash in the same call).
function F.PlayUnlock()return pcall(function()require(script.Parent.SoundTiming).Play(unlockVoice())end)end
-- The whoosh as the pack lifts off (the take flight starts in the same call).
function F.PlayLift()return pcall(function()require(script.Parent.RarityRevealAudio).Play('Whoosh',1.6,nil,.1)end)end
local function glowPart(parent,name,size,color,transparency)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.Neon;p.Transparency=transparency
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=parent;return p
end
local function solidPart(parent,name,size,frame,color)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=parent;return p
end
local function sequence(a,b,c)
 return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.3,b),NumberSequenceKeypoint.new(1,c)})
end
local function emitter(parent,name,color,rate,life,speed,size,transparency)
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Texture=SPARK;e.Color=ColorSequence.new(color);e.LightEmission=.9;e.LightInfluence=0
 e.Rate=rate;e.Lifetime=NumberRange.new(life[1],life[2]);e.Speed=NumberRange.new(speed[1],speed[2]);e.SpreadAngle=Vector2.new(10,10)
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-60,60);e.Size=sequence(size[1],size[2],size[3]);e.Transparency=sequence(1,transparency,1)
 e.Enabled=false;e.Parent=parent;return e
end
-- Builds the fx for one pedestal inside `parent` (its Model). anchorCF: the PackAnchor's CFrame (the pack's centre; the pedestal's turn is in it).
-- still: the reduced-motion version. Everything starts hidden: SetState shows what the state needs.
function F.Build(parent,anchorCF,still)
 local T=F.Tuning
 local folder=Instance.new('Folder');folder.Name='MysteryFx';folder.Parent=parent
 local o=anchorCF*CF(0,-Rules.AnchorHeight,0) -- the pedestal's centre on the pad
 local fx={Folder=folder,Origin=o,Anchor=anchorCF,Still=still==true,Runes={},Spin=T.SlowSpin,Show=false}
 for i=1,T.Runes do local size=i%2==1 and .56 or .4;fx.Runes[i]=glowPart(folder,'Rune'..i,V(size,size,size),VIOLET,1)end
 local shaft=glowPart(folder,'Light shaft',V(T.ShaftHeight,T.ShaftWidth,T.ShaftWidth),GOLD,1)
 shaft.Shape=Enum.PartType.Cylinder;shaft.CFrame=o*CF(0,Rules.PadTop+T.ShaftHeight/2,0)*CFrame.Angles(0,0,math.pi/2);fx.Shaft=shaft
 local root=Instance.new('Part');root.Name='Emitters';root.Size=V(4.6,.2,4.6);root.CFrame=o*CF(0,Rules.PadTop+.25,0);root.Transparency=1
 root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.CastShadow=false;root.Parent=folder;fx.Root=root
 if not fx.Still then
  fx.Wisps=emitter(root,'Wisps',VIOLET,5,{2,3},{.5,1.2},{0,.45,.05},.45)
  fx.Rise=emitter(root,'Rise',GOLD,14,{1.2,1.9},{3,5.5},{0,.55,.08},.1)
 end
 fx.State='Empty'
 F.WarmAudio()
 return fx
end
local function placeRunes(fx,t)
 local T=F.Tuning;local centre=fx.Anchor*CF(0,-.2,0);local sinT,cosT=math.sin(T.Tilt),math.cos(T.Tilt)
 for i,p in ipairs(fx.Runes)do
  local th=t*fx.Spin+(i-1)*2*math.pi/T.Runes;local x,z=math.cos(th)*T.Radius,math.sin(th)*T.Radius
  p.CFrame=centre*CF(x,z*sinT,z*cosT)*CFrame.Angles(t*1.3+i,t*.9+i*.7,0)
 end
end
-- Padlock ------------------------------------------------------------------------------------------------------------------------------------------
-- A chunky gold padlock hanging a little way out from the column's front (the side facing the base's aisle, pad-space -X), built facing out.
function F.BuildLock(fx)
 if fx.Lock then return fx.Lock end
 local base=fx.Origin*CF(-(Rules.ColumnRadius+.075+.275),F.Tuning.LockHeight,0)*CFrame.Angles(0,math.pi/2,0)
 local gold,deep,dark=RGB(255,198,72),RGB(222,160,40),RGB(40,28,22)
 local model=Instance.new('Model');model.Name='Padlock';local parts={}
 local function add(parent,name,size,offset,color,shape)
  local p=solidPart(parent,name,size,base*offset,color);if shape then p.Shape=shape end;parts[#parts+1]=p;return p
 end
 local body=add(model,'Lock body',V(1.5,1.15,.55),CF(0,0,0),gold)
 add(model,'Lock face',V(1.2,.85,.1),CF(0,0,-.3),deep) -- (front at -.35, the body's front at -.275: the plate stands clear of it)
 add(model,'Keyhole',V(.34,.34,.34),CF(0,.12,-.36),dark,Enum.PartType.Ball)
 add(model,'Keyhole slot',V(.14,.42,.12),CF(0,-.12,-.36),dark)
 local shackle=Instance.new('Model');shackle.Name='Shackle'
 for _,sx in ipairs({-.45,.45})do
  local post=add(shackle,'Shackle post',V(.75,.24,.24),CF(sx,.9,0)*CFrame.Angles(0,0,math.pi/2),RGB(235,238,245));post.Shape=Enum.PartType.Cylinder
  add(shackle,'Shackle joint',V(.26,.26,.26),CF(sx,1.275,0),RGB(235,238,245),Enum.PartType.Ball)
 end
 local bar=add(shackle,'Shackle bar',V(.9,.24,.24),CF(0,1.275,0),RGB(235,238,245));bar.Shape=Enum.PartType.Cylinder
 shackle.PrimaryPart=bar;shackle.Parent=model;model.PrimaryPart=body;model.Parent=fx.Folder
 fx.Lock={Model=model,Shackle=shackle,Base=base,Parts=parts}
 return fx.Lock
end
function F.DestroyLock(fx)if fx.Lock then fx.Lock.Model:Destroy();fx.Lock=nil end end
local function poseLock(lock,pose)
 local cf=lock.Base*CF(0,pose.Up,0)*CFrame.Angles(pose.Tilt,0,0)
 lock.Model:PivotTo(cf);lock.Shackle:PivotTo(cf*CF(0,1.275+.4*pose.Open,0))
end
-- The pack unlocked: the padlock pops open and drops away (it is simply taken down when the player has reduced motion on).
function F.OpenLock(fx,now)
 local lock=fx.Lock;if not lock then return false end
 if fx.Still then F.DestroyLock(fx);return false end
 lock.Anim=now;return true
end
-- State ---------------------------------------------------------------------------------------------------------------------------------------------
-- Dresses the fx for the pedestal's state (Empty / Locked / Ready / Claimed); mine = it is the local player's own pedestal.
function F.SetState(fx,state,mine)
 mine=mine==true
 if fx.State==state and fx.Mine==mine and fx.Dressed then return end -- (nothing new: no property is touched)
 local ready=state=='Ready';local locked=state=='Locked';fx.State=state;fx.Show=ready or locked;fx.Mine=mine;fx.Dressed=true
 fx.Spin=ready and F.Tuning.FastSpin or F.Tuning.SlowSpin
 for _,p in ipairs(fx.Runes)do p.Color=ready and GOLD or VIOLET;p.Transparency=fx.Show and(ready and .1 or .5)or 1 end
 if fx.Show then placeRunes(fx,fx.Time or 0)end
 if fx.Wisps then fx.Wisps.Enabled=locked end
 if fx.Rise then fx.Rise.Enabled=ready end
 fx.Shaft.Transparency=(ready and fx.Mine)and .9 or 1
 if locked then F.BuildLock(fx)elseif fx.Lock and not fx.Lock.Anim then F.DestroyLock(fx)end
end
-- Once a frame, for a pedestal that is near the camera and on screen (not at all otherwise): the halo's orbit, the shaft's breathing, the padlock's animation.
function F.Step(fx,now)
 if fx.Still then return end
 fx.Time=now
 if fx.Show then placeRunes(fx,now)end
 if fx.State=='Ready'and fx.Mine then fx.Shaft.Transparency=.9+.03*math.sin(now*3)end
 local lock=fx.Lock
 if lock and lock.Anim then
  local u=(now-lock.Anim)/F.Tuning.LockSeconds
  if u>=1 then F.DestroyLock(fx);if fx.State=='Locked'then F.BuildLock(fx)end -- (a new day's lock, if it came back to Locked meanwhile)
  else
   local pose=F.LockPose(u);poseLock(lock,pose)
   if pose.Fade>0 then for _,p in ipairs(lock.Parts)do p.Transparency=pose.Fade end end
  end
 end
end
function F.Destroy(fx)if fx.Folder then fx.Folder:Destroy()end;fx.Folder=nil;fx.Lock=nil end
-- Moments ---------------------------------------------------------------------------------------------------------------------------------------------
-- A short burst of light and sparks around the pack anchor (yours unlocking: big; taking it: small). The ring spreads over the glowing pad under the pack (not
-- through it); the flash and the sparks are at the pack. reduced: no ring tween and no flash (the sparks still show).
function F.Burst(anchor,color,big,reduced)
 if not anchor or not anchor.Parent then return nil end
 local ring=Instance.new('Part');ring.Name='MysteryBurst';ring.Anchored=true;ring.CanCollide=false;ring.CanQuery=false;ring.CanTouch=false
 ring.Shape=Enum.PartType.Cylinder;ring.Material=Enum.Material.Neon;ring.Color=color;ring.Transparency=.25
 ring.Size=V(.2,2,2);ring.CFrame=anchor.CFrame*CF(0,-(Rules.AnchorHeight-Rules.PadTop-.12),0)*CFrame.Angles(0,0,math.pi/2);ring.Parent=workspace
 local size=big and 16 or 9
 if reduced then ring.Transparency=1 else
  Tween:Create(ring,TweenInfo.new(big and .9 or .5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=V(.2,size,size),Transparency=1}):Play()
  if big then -- a soft flash of light over the swap from the black silhouette to the real pack
   local flash=Instance.new('Part');flash.Name='MysteryFlash';flash.Shape=Enum.PartType.Ball;flash.Anchored=true;flash.CanCollide=false;flash.CanQuery=false;flash.CanTouch=false
   flash.CastShadow=false;flash.Material=Enum.Material.Neon;flash.Color=color;flash.Transparency=.35;flash.Size=V(3,3,3);flash.CFrame=anchor.CFrame;flash.Parent=workspace
   Tween:Create(flash,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=V(9,9,9),Transparency=1}):Play()
   Debris:AddItem(flash,1)
  end
 end
 local spot=Instance.new('Part');spot.Name='MysterySparks';spot.Size=V(.2,.2,.2);spot.Transparency=1;spot.Anchored=true;spot.CanCollide=false;spot.CanQuery=false;spot.CanTouch=false
 spot.CastShadow=false;spot.CFrame=anchor.CFrame;spot.Parent=workspace
 local att=Instance.new('Attachment');att.Parent=spot
 local sparks=Instance.new('ParticleEmitter');sparks.Texture=SPARK;sparks.Color=ColorSequence.new(color)
 sparks.LightEmission=1;sparks.Lifetime=NumberRange.new(.5,1);sparks.Speed=NumberRange.new(8,16);sparks.SpreadAngle=Vector2.new(180,180)
 sparks.Size=NumberSequence.new(.5,0);sparks.Rate=0;sparks.Parent=att;sparks:Emit(big and 40 or 16)
 Debris:AddItem(ring,1.4);Debris:AddItem(spot,1.4)
 return ring
end
-- A small pop of sparks at a point (where the flying pack lands on the player).
function F.Pop(position,color,reduced)
 local p=Instance.new('Part');p.Name='MysteryPop';p.Size=V(.2,.2,.2);p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
 p.CastShadow=false;p.CFrame=CF(position);p.Parent=workspace
 local att=Instance.new('Attachment');att.Parent=p
 local e=Instance.new('ParticleEmitter');e.Texture=SPARK;e.Color=ColorSequence.new(color);e.LightEmission=1;e.Lifetime=NumberRange.new(.4,.8)
 e.Speed=NumberRange.new(5,10);e.SpreadAngle=Vector2.new(180,180);e.Size=NumberSequence.new(.45,0);e.Rate=0;e.Parent=att;e:Emit(reduced and 6 or 14)
 Debris:AddItem(p,1.2);return p
end
-- The take flight: `model` (a copy of the pack) lifts a little, then flies to the player's chest on an arc, shrinking, and spins once.
-- from: where it starts (its pivot); root: the player's HumanoidRootPart. Step it with Flight pose until it returns true (it landed).
function F.NewFlight(model,from,root,now)
 local aim=root.Position+V(0,F.Tuning.AimUp,0)
 return {Model=model,From=from,Root=root,Start=now,Seconds=F.FlightSeconds((aim-from.Position).Magnitude)}
end
function F.StepFlight(fl,now)
 local T=F.Tuning;local age=now-fl.Start;local from=fl.From
 local lifted=from.Position+V(0,T.LiftHeight,0)
 if age<T.LiftSeconds then
  local u=smooth(age/T.LiftSeconds)
  fl.Model:PivotTo(CF(from.Position+V(0,T.LiftHeight*u,0))*from.Rotation)
  fl.Model:ScaleTo(1+.08*u);return false
 end
 local u=(age-T.LiftSeconds)/fl.Seconds
 if u>=1 then return true end
 local e,arc,scale=F.Flight(u)
 local aim=fl.Root.Position+V(0,T.AimUp,0)
 local at=lifted+(aim-lifted)*e+V(0,T.ArcHeight*arc,0)
 fl.Model:PivotTo(CF(at)*from.Rotation*CFrame.Angles(0,u*math.pi*2,0))
 fl.Model:ScaleTo(1.08*scale);return false
end
return F
