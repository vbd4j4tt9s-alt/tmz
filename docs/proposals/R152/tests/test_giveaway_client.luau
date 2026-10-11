--!nocheck
-- R152 Void Pack giveaway, the local player's screen: VoidGiveawayClient152 on the Roblox mock with the REAL pedestal (VoidGiveawayArt152 through the service), the real
-- SeedPackVisuals / EclipsePackArt / VoidPackFx / SeedPackRenderer (stand-in pack meshes), the R150 harness's real tweens and recorded sounds. Covers:
--  1. the sign: built once over the pedestal, in studs, stops growing close up (DistanceLowerLimit), shows far; "487 / 500 LEFT" ticks live with a pop on every change; the small
--     title; "CLAIMED ✓" for you; "CLAIMING…"; "ALL CLAIMED" at 0; loading; low-stock colour; its apparent size at 30 / 60 / 100 studs;
--  2. the pack: a real Void Pack (EclipseReliquary, built by SeedPackVisuals.Bag, not the track's tag), the size, over the cradle, hovering and turning slowly; its glow and
--     particles (VoidPackFx) ride on the pack itself (the core follows it every frame), nothing behind it; quality tiers, the plant-effects setting, reduced motion;
--  3. the prompt: on while Open and not yet claimed, off for you once Claimed, the server's flip back on is undone;
--  4. the claim moment: the chime (InteractionAudio GemClaim, no new sound), the pack hops, a spark burst, the sign pops; a stale stamp (joining) does nothing;
--  5. cost: nothing per frame while the pedestal is far, connected only while near, fx cleared when leaving; streaming (parts that arrive late, a pedestal that goes away and comes back);
--     the pack art failing falls back to a plain pouch; teardown.
--  6. R158c (a claim needs a finished tutorial; sections 4b and 6): until your TutorialDone is true the line under the number reads "finish the tutorial to claim" and the prompt is off for you; it
--     updates the moment TutorialDone changes; a player who claimed sees "CLAIMED ✓" whatever the tutorial says (one pack per player); no state yet = the hint as before; the text is a constant and none of it
--     is in the frame function; the real server and the real client together (play time opens nothing).
local G=require('./giveaway_harness');local H,W,R=G.H,G.W,G.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=G.Rules;local A=Rules.Attr
local warns={};W.env.warn=function(...)local t={};for _,v in ipairs({...})do t[#t+1]=tostring(v)end;warns[#warns+1]=table.concat(t,' ')end
R.clock=20000*86400+3600
local me=H.player(77,'Tester',true);H.character(me,V3(0,5,-370));me:SetAttribute('TutorialDone',true) -- (R158c: a player who has finished the tutorial, unless a section says otherwise)
local CENTER=V3(0,18,-392)
local function setup(o)
 o=o or{}
 local b=G.backend();local s=G.server(b,nil,{FreshMap=o.Fresh~=false,Name='A'});s.Svc:Start()
 if o.Count then s.Svc:_force(o.Count)end
 return s
end
local function folder()return W.workspace:FindFirstChild('VoidGiveawayPacks152')end
local function bag()local f=folder();return f and f:FindFirstChild('VoidGiveawayPack')end
local function sign(s)return s.Svc.Model:FindFirstChild('VoidGiveawaySign')end
local function text(s,n)return sign(s):FindFirstChild(n).Text end
local function fxFolder()for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='_VoidPackFx122'then return c end end end
local function nOf(root,class)local n=0;for _,d in ipairs(root:GetDescendants())do if d:IsA(class)then n+=1 end end;return n end
local function yaw(p)local l=p.CFrame.LookVector;return math.atan2(l.X,l.Z)end
local function fxCount()local n=0;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='_VoidPackFx122'then n+=1 end end;return n end

-- 1. The sign -----------------------------------------------------------------------------------------------------------------------------------------------------
local s=setup();G.look(V3(0,10,-360),CENTER);G.loadClient();G.run(1)
local m=s.Svc.Model;local ped=s.Svc.Pedestal
local gui=sign(s)
check(gui~=nil and gui:IsA('BillboardGui'),'a BillboardGui hangs on the pedestal')
check(gui.Adornee==ped.SignAnchor,'adorned to the sign anchor (over the pack)')
check(gui.Size.X.Scale==Rules.Sign.W and gui.Size.Y.Scale==Rules.Sign.H and gui.Size.X.Offset==0 and gui.Size.Y.Offset==0,'sized in STUDS (scale), not pixels: it shrinks with distance and can never fill the screen from afar')
check(gui.DistanceLowerLimit==Rules.SignNear and Rules.SignNear>=24 and Rules.SignNear<=40,'it stops growing closer than '..Rules.SignNear..' studs (DistanceLowerLimit): never silly-large up close')
check(gui.MaxDistance==Rules.SignFar and Rules.SignFar>=200,'and shows from across the plaza and well past it (up to '..Rules.SignFar..' studs)')
check(gui.LightInfluence==0 and gui.AlwaysOnTop==false,'unlit, not through walls')
check(text(s,'Title')=='FREE VOID PACK','the small title: FREE VOID PACK')
check(text(s,'Count')=='500 / 500 LEFT','the number: "500 / 500 LEFT"')
check(text(s,'Note')==Rules.Hint,'a quiet line: LIMITED! 1 PER PLAYER')
-- apparent size (Roblox: a studs-sized billboard is H / (2 d tan(fov / 2)) of the screen height)
local function share(h,d,fov)return h/(2*d*math.tan(math.rad(fov or 70)/2))end
check(share(Rules.Sign.H,Rules.SignNear)<=.2,'at the closest it grows to '..string.format('%.0f%%',share(Rules.Sign.H,Rules.SignNear)*100)..' of the screen height (<= 20%)')
check(share(Rules.Sign.H*.44,100)>=.02,'the number row is still '..string.format('%.1f%%',share(Rules.Sign.H*.44,100)*100)..' of the screen height at 100 studs (>= 2%): readable across the plaza')
check(share(Rules.Sign.H,60)>=.08,'the whole sign is '..string.format('%.0f%%',share(Rules.Sign.H,60)*100)..' of the screen at 60 studs')
-- live ticking: the server's Left attribute is all the client reads
local count=gui:FindFirstChild('Count');local pop=count:FindFirstChild('Pop')
check(pop and pop.Scale==1,'the number carries a UIScale for its pop')
m:SetAttribute('Count',13);m:SetAttribute('Left',487)
check(text(s,'Count')=='487 / 500 LEFT','a claim somewhere: the number reads "487 / 500 LEFT" at once')
check(pop.Scale>1.1,'and pops (a short overshoot: UIScale '..string.format('%.2f',pop.Scale)..')')
G.run(.5);check(math.abs(pop.Scale-1)<1e-6,'back to normal size')
local pops=0;local last=pop.Scale
for left=486,480,-1 do m:SetAttribute('Left',left);if pop.Scale>1.1 then pops+=1 end;G.run(.4)end
check(pops==7 and text(s,'Count')=='480 / 500 LEFT','seven more ticks: seven pops, "480 / 500 LEFT"')
m:SetAttribute('Left',480);G.run(.5);check(math.abs(pop.Scale-1)<1e-6,'an unchanged number does not pop')
-- low stock
m:SetAttribute('Left',20);G.run(.1);local c1=count.TextColor3;m:SetAttribute('Left',300);G.run(.1)
check(c1.R>count.TextColor3.R and c1.G>.7 and c1.B<.55,'at 25 or fewer the number turns amber')
-- your own state
me:SetAttribute(A.Player,'Claimed');G.run(.1)
check(text(s,'Note')=='CLAIMED ✓','after you claim: "CLAIMED ✓"')
me:SetAttribute(A.Player,'Busy');G.run(.1);check(text(s,'Note')=='CLAIMING…','while the server works on your claim: "CLAIMING…"')
me:SetAttribute(A.Player,'Open');G.run(.1);check(text(s,'Note')==Rules.Hint,'back to the hint')
-- at zero
m:SetAttribute('Count',500);m:SetAttribute('Left',0);m:SetAttribute('State','Empty');G.run(.2)
check(text(s,'Title')=='ALL CLAIMED'and text(s,'Count')=='0 / 500 LEFT'and text(s,'Note')=='','at 0: "ALL CLAIMED" and "0 / 500 LEFT"')
local greyC=count.TextColor3;check(greyC.R<.7 and math.abs(greyC.R-greyC.B)<.3,'dimmed (grey-violet)')
me:SetAttribute(A.Player,'Claimed');G.run(.1);check(text(s,'Note')=='CLAIMED ✓','and a player who claimed still sees CLAIMED ✓')
me:SetAttribute(A.Player,'Open');m:SetAttribute('Count',13);m:SetAttribute('Left',487);m:SetAttribute('State','Open');G.run(.2)
-- loading
local s2=setup({Fresh=false});s2.Svc.Model:SetAttribute('Left',nil);s2.Svc.Model:SetAttribute('State','Loading');G.run(.6)
check(sign(s2)~=nil,'(a second pedestal in the world gets its own sign)')
for _,c in ipairs(W.workspace:GetChildren())do end
s2.Svc.Model:Destroy();G.run(.3)

-- 2. The pack ------------------------------------------------------------------------------------------------------------------------------------------------------
local pack=bag()
check(pack~=nil and pack:GetAttribute('BagVariant')=='EclipseReliquary'and pack:GetAttribute('Stage')==7,'a real Void Pack was built (SeedPackVisuals.Bag: EclipseReliquary, stage 7)')
check(pack:GetAttribute('SpecialPackDesign89')==true and pack:GetAttribute('EclipsePack')==true and pack:GetAttribute('VoidDesignRevision')~=nil,'with the Void art (EclipsePackArt: the galaxy, the event horizon, the eye)')
check(not W.CS:HasTag(pack,'BiomeSeedPackVisual'),'not tagged as a track pack (the track\'s Void-pack renderer leaves it alone)')
check(pack.Parent==folder() and folder().Parent==W.workspace and not pack:IsDescendantOf(m),'it lives in its own local folder, not in the pedestal model')
-- (R153 perf, lag audit D3: a piece may instead be welded to an anchored part of the pack - its root or a ring's spin hub - which holds it)
local heldBy={};for _,w in ipairs(pack:GetDescendants())do if w._class=='Weld'and w.Part1 and w.Part0 and w.Part0.Anchored and w.Part0:IsDescendantOf(pack)then heldBy[w.Part1]=true end end
local function held(d)return heldBy[d]==true end
local anyUnanchored,collides,welded=0,0,0;for _,d in ipairs(pack:GetDescendants())do if d:IsA('BasePart')then if not d.Anchored then if held(d)then welded+=1 else anyUnanchored+=1 end end;if d.CanCollide or d.CanQuery or d.CanTouch then collides+=1 end end end
check(anyUnanchored==0 and collides==0,'every part anchored or welded to an anchored part of the pack ('..welded..' welded), no collision, not queryable')
check(nOf(pack,'BaseScript')==0 and nOf(pack,'Sound')==0,'no scripts, no sounds')
local root=pack.PrimaryPart
local at=ped.PackAnchor.Position
check((root.Position-at).Magnitude<1.2,'over the cradle ('..string.format('%.2f',(root.Position-at).Magnitude)..' studs from the pack anchor)')
local _,box=pack:GetBoundingBox()
check(math.abs(box.Y-Rules.PackSize)<.6 or math.abs(box.Y-Rules.PackSize)<1.2,'about '..Rules.PackSize..' studs tall (halo included): '..string.format('%.1f',box.Y))
-- hovering and turning, slowly
local ys,yaws={},{};for i=1,150 do G.run(1/30);ys[#ys+1]=root.Position.Y;yaws[#yaws+1]=yaw(root)end
local lo,hi=math.huge,-math.huge;for _,y in ipairs(ys)do lo=math.min(lo,y);hi=math.max(hi,y)end
check(hi-lo>.35 and hi-lo<1.4,'it hovers: '..string.format('%.2f',hi-lo)..' studs of bob over 5 s')
local turned=0;for i=2,#yaws do local d=yaws[i]-yaws[i-1];if d>math.pi then d-=2*math.pi elseif d<-math.pi then d+=2*math.pi end;turned+=d end
check(math.abs(turned)>1.4 and math.abs(turned)<3.2,'it turns slowly: '..string.format('%.2f',turned)..' radians in 5 s (about '..Rules.PackSpin..' rad/s)')
local still=true;for i=2,#yaws do local d=math.abs(yaws[i]-yaws[i-1]);if d>.15 and d<math.pi then still=false end end
check(still,'smoothly (no frame turns more than .15 rad)')
-- its glow and particles ride on the pack
local fx=fxFolder()
check(fx~=nil and fxCount()==1,'the Void pack\'s effects exist (VoidPackFx): one set')
local emitters=nOf(fx,'ParticleEmitter');check(emitters==3,'haze, nebula swirl and starfall: '..emitters..' emitters')
check(fx:FindFirstChild('VoidFxCore')~=nil and fx:FindFirstChildWhichIsA('Highlight',true)~=nil and nOf(fx,'PointLight')==1,'a core part, a violet highlight on the pack, one pulsing light')
local core=fx:FindFirstChild('VoidFxCore')
local maxGap=0;for i=1,90 do G.run(1/30);maxGap=math.max(maxGap,(core.Position-root.Position).Magnitude)end
check(maxGap<.6,'the emitters\' core part follows the pack every frame (never more than '..string.format('%.2f',maxGap)..' studs from it): attached to the pack, not left behind')
check(fx.Parent==W.workspace and not fx:IsDescendantOf(m),'(and not part of the pedestal: no disc behind the pack)')
local debris=0;for _,d in ipairs(fx:GetChildren())do if d.Name=='VoidDebris'then debris+=1 end end
check(debris>=2,'orbiting debris ('..debris..') on a ring around the pack')
local maxDebris=0;for _,d in ipairs(fx:GetChildren())do if d.Name=='VoidDebris'then maxDebris=math.max(maxDebris,(d.Position-root.Position).Magnitude)end end
check(maxDebris<Rules.PackSize,'which stays within a pack\'s width of it ('..string.format('%.1f',maxDebris)..')')
-- the inner galaxy spins (the art's own spinners are posed too)
local spinners=0;for _,d in ipairs(pack:GetDescendants())do if d:IsA('BasePart')and d:GetAttribute('VoidSpin')then spinners+=1 end end
check(spinners>=20,'the galaxy arms and the event-horizon halo (VoidSpin parts: '..spinners..') are moved by VoidPackFx.Pose')

-- quality tiers and the plant-effects setting
H.tier=1;G.run(1.2);fx=fxFolder()
check(fx~=nil and fx:FindFirstChild('VoidHaze',true)~=nil,'(the lowest tier keeps a small set)')
local haze=fx:FindFirstChild('VoidHaze',true);check(haze.Enabled==false and fx:FindFirstChild('VoidStarfall',true).Enabled==false and fx:FindFirstChild('VoidNebulaSwirl',true).Enabled==false,'at the lowest tier the haze, swirl and stars are off')
H.tier=3;G.run(1.2);fx=fxFolder();check(fx:FindFirstChild('VoidHaze',true).Enabled==true and fx:FindFirstChild('VoidStarfall',true).Enabled==true,'at the top tier they are on')
me:SetAttribute('StudioPlantEffects','off');G.run(1.2);check(fxCount()==0 and bag()~=nil,'"effects off" removes the effects, the pack stays')
me:SetAttribute('StudioPlantEffects',nil);G.run(1.2);check(fxCount()==1,'and they come back')
me:SetAttribute('StudioPlantEffects','low');G.run(1.2);fx=fxFolder();check(fx and fx:FindFirstChild('VoidHaze',true).Enabled==false,'"effects low" is the lowest tier')
me:SetAttribute('StudioPlantEffects',nil);G.run(1.2)
-- review fix B5: what the pack costs every frame, by tier. Tier 3 is unchanged (every frame, with its Highlight); tier 2 and below have no Highlight (an outline written every frame) and
-- step the pack (pose, debris, comets, pulse: one BulkMoveTo) at 30 Hz, with the time it skipped, so the turn keeps its speed
do
 local PackFx=W.module('VoidPackFx')
 local moves,pulses,rawMove,rawPulse=0,0,W.workspace.BulkMoveTo,PackFx.Pulse
 W.workspace.BulkMoveTo=function(self,parts,frames,mode)moves+=1;return rawMove(self,parts,frames,mode)end
 PackFx.Pulse=function(...)pulses+=1;return rawPulse(...)end
 local seen={}
 for _,tier in ipairs({3,2,1})do
  H.tier=tier;G.run(1.2,1/60);fx=fxFolder()
  local hl=fx and fx:FindFirstChildWhichIsA('Highlight',true)
  check((hl~=nil)==(tier==3),'B5: tier '..tier..(tier==3 and': the pack keeps its violet Highlight'or': no Highlight on the pack'))
  moves,pulses=0,0;local y0=yaw(root);local outlines={};local last=hl and hl.OutlineTransparency
  for _=1,180 do G.run(1/60,1/60);if hl and hl.OutlineTransparency~=last then outlines[#outlines+1]=true;last=hl.OutlineTransparency end end
  local turned=yaw(root)-y0;if turned<-math.pi then turned+=2*math.pi end
  seen[tier]={Moves=moves/3,Pulses=pulses/3,Turn=turned/3,Outline=#outlines/3}
 end
 check(seen[3].Moves>=57 and seen[3].Pulses>=57 and seen[3].Outline>=50,string.format('B5: tier 3: the pack is stepped every frame at 60 fps (%.0f moves, %.0f pulses, the Highlight written %.0f times a second)',seen[3].Moves,seen[3].Pulses,seen[3].Outline))
 -- R153 (owner: "fix all jittery type effects"): in view, tier 2 and below step every frame too (30 Hz turned in steps on a 60 Hz screen)
 for _,tier in ipairs({2,1})do
  check(seen[tier].Moves>=57 and seen[tier].Pulses>=57,string.format('R153: tier %d, in view: every frame at 60 fps (%.0f moves, %.0f pulses a second)',tier,seen[tier].Moves,seen[tier].Pulses))
  check(math.abs(seen[tier].Turn-seen[3].Turn)<.12 and seen[tier].Turn>.3,string.format('B5: tier %d: it turns at the same speed (%.3f vs %.3f rad/s; the slow sway adds up to +-.05, half the speed would read .22)',tier,seen[tier].Turn,seen[3].Turn))
 end
 -- R153: and at 30 / 144 fps, in view, tier 2 steps once per drawn frame
 H.tier=2;G.run(.5,1/60)
 for _,fps in ipairs({30,144})do moves,pulses=0,0;G.run(1,1/fps);check(math.abs(moves-fps)<=2 and math.abs(pulses-fps)<=2,string.format('R153: tier 2 at %d fps, in view: %d moves, %d pulses in 1 s (one per drawn frame)',fps,moves,pulses))end
 -- R153: out of view (ViewCull152) tier 2 keeps B5's saving: 30 Hz, with the time it skipped (back in view the turn is where it should be)
 do
  local cam=W.workspace.CurrentCamera;local hadRay=cam._props.ViewportPointToRay
  cam.ViewportPointToRay=function(self,x,y)
   local vs=self.ViewportSize;local tv=math.tan(math.rad(self.FieldOfView or 70)/2);local th=tv*vs.X/vs.Y
   local dx,dy=(2*x/vs.X-1)*th,(1-2*y/vs.Y)*tv;local cf=self.CFrame
   return {Origin=cf.Position,Direction=(cf.RightVector*dx+cf.UpVector*dy+cf.LookVector).Unit}
  end
  local turns={}
  for _,tier in ipairs({3,2})do
   H.tier=tier;G.look(V3(0,10,-360),CENTER);G.run(1.2,1/60)
   local y0=yaw(root);G.look(V3(0,10,-360),V3(0,10,-200));G.run(.5,1/60) -- (facing away: the pack is behind the camera)
   moves=0;for _=1,180 do G.run(1/60,1/60)end;local away=moves/3
   G.look(V3(0,10,-360),CENTER);G.run(1/60,1/60)
   local turned=(yaw(root)-y0)%(2*math.pi);turns[tier]=turned
   if tier==2 then check(away>=27 and away<=33,string.format('R153: tier 2, out of view: 30 Hz as before (%.0f moves a second)',away))
   else check(away>=57,string.format('R153: tier 3, out of view: every frame as before (%.0f moves a second)',away))end
  end
  check(math.abs(turns[2]-turns[3])<.35 and turns[2]>.75*turns[3],string.format('R153: tier 2 comes back into view turned as far as tier 3 (%.3f vs %.3f rad; the slow sway alone moves +-.13, losing the skipped time would read half)',turns[2],turns[3]))
  cam.ViewportPointToRay=hadRay;G.look(V3(0,10,-360),CENTER)
 end
 W.workspace.BulkMoveTo=rawMove;PackFx.Pulse=rawPulse
 H.tier=3;G.run(1.2)
 check(fxFolder()~=nil and fxFolder():FindFirstChildWhichIsA('Highlight',true)~=nil,'B5: back on tier 3 the Highlight is back')
end
-- at 0 left the pack sleeps: it still turns, its glow and sparks are off; reopened (a Studio reset) they are back
m:SetAttribute('Count',500);m:SetAttribute('Left',0);m:SetAttribute('State','Empty');G.run(1.2)
local yawA=yaw(root);G.run(1)
check(fxCount()==0 and bag()~=nil,'at 0 left: the pack\'s effects are off')
check(math.abs(yaw(root)-yawA)>.2,'... and it still turns')
m:SetAttribute('Count',13);m:SetAttribute('Left',487);m:SetAttribute('State','Open');G.run(1.2)
check(fxCount()==1,'reopened: the effects are back')
-- reduced motion: the same parts, still
W.Gui.ReducedMotionEnabled=true;G.run(.3)
local y0,r0=root.Position.Y,yaw(root);G.run(3)
check(math.abs(root.Position.Y-y0)<.02 and math.abs(yaw(root)-r0)<.01,'reduced motion: the pack does not bob, sway or turn at all (within .02 studs / .01 rad over 3 s)')
local pos0=root.Position;m:SetAttribute('Left',433);G.run(.1);check(math.abs(pop.Scale-1)<1e-6,'reduced motion: no pop')
W.Gui.ReducedMotionEnabled=false;G.run(.3)

-- 3. The prompt ----------------------------------------------------------------------------------------------------------------------------------------------------
local prompt=ped.Prompt
m:SetAttribute('Left',487);me:SetAttribute(A.Player,'Open');ped.Prompt.Enabled=true;G.run(.6)
check(prompt.Enabled==true,'Open and not claimed: the prompt is on')
me:SetAttribute(A.Player,'Claimed');G.run(.1);check(prompt.Enabled==false,'once you have claimed it is off for you')
prompt.Enabled=true;G.run(.1);check(prompt.Enabled==false,'the server turning it back on (a state change) is undone for you')
G.run(.6);check(prompt.Enabled==false,'and stays off')
me:SetAttribute(A.Player,'Busy');G.run(.1);check(prompt.Enabled==false,'off while your claim is in flight (no double press)')
me:SetAttribute(A.Player,'Open');G.run(.1);check(prompt.Enabled==true,'on again for a player who has not claimed')
m:SetAttribute('State','Empty');G.run(.1);check(prompt.Enabled==false,'off for everyone at 0')
m:SetAttribute('State','Open');G.run(.1);check(prompt.Enabled==true,'(and on again when it is Open)')
me:SetAttribute(A.Player,nil);G.run(.1);check(prompt.Enabled==false,'a player whose state is not known yet sees no prompt')
me:SetAttribute(A.Player,'Open');G.run(.1)

-- 4. The claim moment ----------------------------------------------------------------------------------------------------------------------------------------------
do
 H.sounds={}
 local before=W.workspace:GetServerTimeNow()
 me:SetAttribute(A.Player,'Claimed');me:SetAttribute(A.At,W.workspace:GetServerTimeNow())
 G.run(.05)
 check(H.soundCount('GemClaim')==1,'the reward chime plays once (InteractionAudio GemClaim: an existing sound)')
 check(#H.sounds==1,'and nothing else is played')
 local peak=-math.huge;local base=ped.PackAnchor.Position.Y
 for i=1,25 do G.run(1/30);peak=math.max(peak,root.Position.Y-base)end
 check(peak>.46+.5,'the pack hops (up to '..string.format('%.2f',peak)..' studs over its rest height in the first .8 s; the idle bob never passes .46)')
 check(pop.Scale>=1 and G.R.clock>0,'(the sign popped)')
 local fx=fxFolder();local emitted=0;for _,d in ipairs(fx:GetDescendants())do if d:IsA('ParticleEmitter')then emitted+=(d._emitted or 0)end end
 check(emitted>=30,'a burst of sparks came out of the pack\'s own emitters ('..emitted..')')
 -- a stamp from long ago (what a player sees when they join having claimed before) does nothing
 H.sounds={};R.clock+=60;me:SetAttribute(A.At,before-100);G.run(.05)
 check(H.soundCount('GemClaim')==0,'an old stamp (joining after a claim made earlier) plays nothing')
 me:SetAttribute(A.At,nil);G.run(.05);check(#H.sounds==0,'clearing it plays nothing')
 me:SetAttribute(A.Player,'Open')
 -- reduced motion: the chime still plays, no hop
 W.Gui.ReducedMotionEnabled=true;H.sounds={};me:SetAttribute(A.At,W.workspace:GetServerTimeNow()+.001);G.run(.05)
 local p2=-math.huge;for i=1,25 do G.run(1/30);p2=math.max(p2,root.Position.Y-base)end
 check(H.soundCount('GemClaim')==1 and p2<.3,'reduced motion: the chime plays, the pack does not hop')
 W.Gui.ReducedMotionEnabled=false;G.run(.3)
end

-- 4b. R158c (owner: "for the void pack there isn't a 20 minute lock anymore and requirement is just finishing the tutorial"): the line under the number, and the prompt, until your tutorial is finished ------------
do
 local function note()return text(s,'Note')end
 local function noteLabel()return sign(s):FindFirstChild('Note')end
 local function words(t)local padded=' '..t:lower()..' ';return padded:find('%f[%a]ur%f[%A]')==nil and padded:find('%f[%a]u%f[%A]')==nil end
 local LINE='finish the tutorial to claim'
 m:SetAttribute('Count',13);m:SetAttribute('Left',487);m:SetAttribute('State','Open');me:SetAttribute(A.Player,'Open');ped.Prompt.Enabled=true;me:SetAttribute('TutorialDone',true);G.run(.6)
 -- finished: the hint and the prompt, as ever
 check(Rules.TutorialAttr=='TutorialDone'and note()==Rules.Hint and prompt.Enabled==true,'R158c: tutorial finished (TutorialDone true): the hint and the prompt are as before')
 local hint=noteLabel().TextColor3
 -- not finished
 me:SetAttribute('TutorialDone',false);G.run(.1)
 check(note()==LINE,'R158c: tutorial not finished: the line under the number reads "finish the tutorial to claim"')
 check(prompt.Enabled==false,'R158c: ... and the prompt is off for you')
 local c=noteLabel().TextColor3;check(c.R>.9 and c.G>.7 and c.G<.9 and c.B<.55,'R158c: ... in a warm yellow, so it reads as "wait" (not the quiet violet of the hint)')
 check(text(s,'Count')=='487 / 500 LEFT'and text(s,'Title')=='FREE VOID PACK','R158c: ... the title and the number above it are as before')
 check(noteLabel().Size.Y.Scale<=.2 and noteLabel().Size.X.Scale<=.9 and noteLabel().TextScaled==true and #note()<=30,'R158c: ... a small line (the same label: .88 x .17 of the sign, scaled to fit; '..#note()..' letters)')
 check(words(note())and not note():lower():find('cla[u]de')and not note():lower():find('op[u]s')and not note():lower():find('sonn[e]t')and not note():lower():find('haik[u]'),'R158c: ... simple words, no "u" / "ur"')
 prompt.Enabled=true;G.run(.1);check(prompt.Enabled==false,'R158c: the server turning the prompt on (a state change) is undone for you')
 G.run(.6);check(prompt.Enabled==false and note()==LINE,'R158c: ... and it stays that way')
 -- it updates the moment TutorialDone changes (finished / skipped = true), and back
 me:SetAttribute('TutorialDone',true);G.run(.05)
 check(note()==Rules.Hint and prompt.Enabled==true,'R158c: the tutorial gets finished (or skipped): at once the line is gone (the hint is back) and the prompt works')
 local back=noteLabel().TextColor3;check(back.R==hint.R and back.G==hint.G and back.B==hint.B,'R158c: ... in its old colour')
 me:SetAttribute('TutorialDone',false);G.run(.05);check(note()==LINE and prompt.Enabled==false,'R158c: and back to the line if it reads false again')
 -- not published yet / junk: only exactly true counts as finished (the server\'s test)
 me:SetAttribute('TutorialDone',nil);G.run(.1);check(note()==LINE and prompt.Enabled==false,'R158c: no TutorialDone attribute (not published yet): "not finished", as the server counts it')
 for _,bad in ipairs({'yes',1,0,'true'})do
  me:SetAttribute('TutorialDone',bad);G.run(.05)
  check(note()==LINE and prompt.Enabled==false,'R158c: a junk value ('..tostring(bad)..') is not "finished"')
 end
 -- players who already claimed see what they see today, whatever the tutorial says (one pack per player)
 for _,done in ipairs({true,false})do
  me:SetAttribute('TutorialDone',done);me:SetAttribute(A.Player,'Claimed');G.run(.1)
  check(note()=='CLAIMED ✓'and prompt.Enabled==false,'R158c: a player who claimed (tutorial '..tostring(done)..') sees "CLAIMED ✓" and no prompt, as today (never "finish the tutorial")')
 end
 me:SetAttribute('TutorialDone',false);me:SetAttribute(A.Player,'Busy');G.run(.1);check(note()=='CLAIMING…'and prompt.Enabled==false,'R158c: while the claim is in flight: "CLAIMING…" as today')
 me:SetAttribute(A.Player,'Open');G.run(.1);check(note()==LINE,'R158c: and back to the line if the claim did not go through and the tutorial is not finished')
 -- your state is not known yet (no VoidGift152): the hint, no prompt, as before
 me:SetAttribute(A.Player,nil);G.run(.1);check(note()==Rules.Hint and prompt.Enabled==false,'R158c: your state is not known yet: the hint and no prompt (as before; the line is for players the server has set up)')
 me:SetAttribute(A.Player,'Open');G.run(.1)
 -- at 0 left the sign says nothing under the number, as today
 m:SetAttribute('Count',500);m:SetAttribute('Left',0);m:SetAttribute('State','Empty');G.run(.2)
 check(note()==''and prompt.Enabled==false and text(s,'Title')=='ALL CLAIMED','R158c: at 0 left there is no tutorial line (ALL CLAIMED, nothing under the number), as today')
 m:SetAttribute('Count',13);m:SetAttribute('Left',487);m:SetAttribute('State','Open');G.run(.2)
 check(note()==LINE,'R158c: reopened: the line is back')
 -- cost: the text is a constant; nothing is built per refresh, no Instance is made; the frame function has none of it
 local made=0;local inew=R.Instance.new;R.Instance.new=function(...)made+=1;return inew(...)end
 G.run(3,1/60)
 R.Instance.new=inew
 check(made==0 and note()==LINE,'R158c: 180 frames and 6 half-second refreshes later: no Instance made ('..made..')')
 local src=require('./rs_bundle').VoidGiveawayClient152;local a,z=src:find('local function frame(dt)',1,true),src:find('local function wake()',1,true)
 check(a and z and z>a and not src:sub(a,z):find('utorial',1,true)and not src:sub(a,z):find('Play',1,true),'R158c: the per-frame function (frame) does not touch any of it')
 check(not src:find('Heartbeat:Connect',1,true)or select(2,src:gsub('Heartbeat:Connect','',100))==1,'R158c: and there is still just the one half-second Heartbeat tick (no new loop)')
 check(not src:find('PlayLeft',1,true)and not src:find('VoidPlayLeft157',1,true)and not src:find('PlayHintText',1,true),'R158c: the client has no trace of the 20 minute countdown')
 me:SetAttribute('TutorialDone',true);me:SetAttribute(A.Player,'Open');G.run(.1)
end

-- 5. Cost, streaming, failure, teardown --------------------------------------------------------------------------------------------------------------------------
do
 check(H.renderConnections()==1,'one per-frame function while the pedestal is near')
 local conn0=0;for _,c in ipairs(W.Run.Heartbeat._c)do if c.Connected then conn0+=1 end end
 -- walk away: the frame loop disconnects, the effects go, the pack stays
 G.look(V3(0,10,-392+260),CENTER);G.run(1.2)
 check(H.renderConnections()==0,'260 studs away: no per-frame work at all')
 check(fxCount()==0,'the effects are cleared when far')
 check(bag()~=nil and sign(s)~=nil,'(the pack and the sign are still there)')
 G.look(V3(0,10,-392+120),CENTER);G.run(1.2)
 check(H.renderConnections()==1 and fxCount()==1,'back within range: the loop and the effects come back')
 G.look(V3(0,10,-392+210),CENTER);G.run(1.2);check(H.renderConnections()==1,'hysteresis: still active at 210 studs (leaves at 230)')
 G.look(V3(0,10,-360),CENTER);G.run(.5)
 -- streaming: a pedestal that goes away and comes back
 s.Svc.Model:Destroy();G.run(.6)
 check(bag()==nil or not bag().Parent,'the pedestal went away: its pack is removed')
 check(fxCount()==0 and H.renderConnections()==0,'... its effects and its frame loop too')
 local s3=setup({Fresh=false});G.run(1)
 check(bag()~=nil and sign(s3)~=nil and fxCount()==1,'a new pedestal (streamed back in) starts clean: one pack, one sign, one set of effects')
 check(#folder():GetChildren()==1,'(no leftovers)')
 -- parts that arrive after the model (streaming): found on the next half second
 local late=R.new('Model');late.Name='VoidGiveaway152';late.Parent=W.workspace;W.CS:AddTag(late,'VoidGiveaway152');G.run(.6)
 check(late:FindFirstChild('VoidGiveawaySign')==nil,'a model with no parts yet: nothing is built, nothing throws')
 local anchorSign=R.new('Part');anchorSign.Name='SignAnchor';anchorSign.Size=V3(.5,.5,.5);anchorSign.CFrame=R.CFrame.new(40,30,-392);anchorSign.Anchored=true;anchorSign.Parent=late
 local anchorPack=R.new('Part');anchorPack.Name='PackAnchor';anchorPack.Size=V3(.5,.5,.5);anchorPack.CFrame=R.CFrame.new(40,20,-392);anchorPack.Anchored=true;anchorPack.Parent=late
 late:SetAttribute('Left',250);late:SetAttribute('State','Open');G.run(.6)
 check(late:FindFirstChild('VoidGiveawaySign')~=nil and late:FindFirstChild('VoidGiveawaySign'):FindFirstChild('Count').Text=='250 / 500 LEFT','when its parts arrive the sign is built and shows the number')
 late:Destroy();G.run(.3)
 s3.Svc.Model:Destroy();G.run(.3)
 -- the pack art fails: a plain pouch, one warn, still hovering, no effects
 local Visuals=W.module('SeedPackVisuals');local realBag=Visuals.Bag;Visuals.Bag=function()error('the pack meshes are missing')end
 local w0=#warns;local s4=setup({Fresh=false});G.run(1)
 local pouch=bag();check(pouch~=nil and pouch:FindFirstChild('VisualRoot')~=nil and pouch:FindFirstChild('Seam')~=nil,'if the pack art cannot be built a plain pouch is shown')
 check(#warns==w0+1 and warns[#warns]:find('R152',1,true),'with one warn line')
 local py={};for i=1,60 do G.run(1/30);py[#py+1]=pouch.PrimaryPart.Position.Y end
 local plo,phi=math.huge,-math.huge;for _,y in ipairs(py)do plo=math.min(plo,y);phi=math.max(phi,y)end
 check(phi-plo>.2 and fxCount()==0,'the pouch hovers and has no effects')
 check(sign(s4)~=nil and sign(s4).Count.Text=='500 / 500 LEFT','the sign works regardless')
 s4.Svc.Model:Destroy();G.run(.3);Visuals.Bag=realBag
 -- teardown
 local s5=setup({Fresh=false});G.run(1);local f=folder()
 G.client:Destroy();G.run(.2)
 check(folder()==nil and fxCount()==0,'the script destroyed: its folder and effects are gone')
 local live=0;for _,c in ipairs(W.Run.RenderStepped._c)do if c.Connected then live+=1 end end
 check(live==0,'no per-frame connection left')
 local sc=s5.Svc.Model:FindFirstChild('VoidGiveawaySign');check(sc==nil,'the sign is gone too')
end

-- 6. R158c end to end: the real server checks the tutorial, the real client shows it ------------------------------------------------------------------------------------------------------
do
 local s6=setup();G.look(V3(0,10,-360),CENTER);G.loadClient();G.run(1)
 me:SetAttribute(A.Player,nil);me:SetAttribute('TutorialDone',nil);me:SetAttribute(A.At,nil)
 local function note()return text(s6,'Note')end
 local pr=s6.Svc.Pedestal.Prompt
 local LINE='finish the tutorial to claim';local REFUSAL='finish the tutorial to get your free void pack!'
 G.run(.6);check(note()==Rules.Hint and pr.Enabled==false,'R158c e2e: before the profile is loaded: the hint, and no prompt for you (as before: your state is not known yet)')
 s6.Data:load(me,{Tutorial=false});s6.Svc:Step();G.run(.6)
 check(me:GetAttribute('TutorialDone')==false and me:GetAttribute(A.Player)=='Open'and me:GetAttribute('VoidPlayLeft157')==nil,'R158c e2e: the profile loads with the tutorial not finished: your state is Open, and there is no play-time attribute')
 check(note()==LINE and pr.Enabled==false,'R158c e2e: ... your sign says "finish the tutorial to claim" and the prompt is off')
 for _=1,150 do s6.Clock.advance(2);s6.Svc:Step()end;G.run(.1)
 check(note()==LINE and pr.Enabled==false and s6.Data:GetPremium(me)[Rules.PlayField]==300,'R158c e2e: 5 minutes of play later it is still the tutorial line (play time does nothing; the counter is at 300)')
 local ok,why=s6.Svc:Claim(me)
 check(ok==false and why=='tutorial'and s6.Data:voidPacks(me)==0 and s6.Notes:last(me).Text==REFUSAL,'R158c e2e: pressing anyway is refused by the server: "finish the tutorial to get your free void pack!"')
 for _=1,450 do s6.Clock.advance(2);s6.Svc:Step()end;G.run(.1)
 check(note()==LINE and pr.Enabled==false and s6.Svc:Claim(me)==false and s6.Data:voidPacks(me)==0,'R158c e2e: 20 minutes in all: still the tutorial line, still refused (the old 20 minute rule opens nothing)')
 me:SetAttribute('TutorialDone',true);G.run(.1) -- (what TutorialProgress.PublishTutorial does when the tutorial is finished or skipped)
 check(note()==Rules.Hint and pr.Enabled==true,'R158c e2e: the tutorial is finished: the line is gone (the hint is back) and the prompt is on, at once')
 local ok2=s6.Svc:Claim(me);G.run(.2)
 check(ok2==true and s6.Data:voidPacks(me)==1 and me:GetAttribute(A.Player)=='Claimed'and note()=='CLAIMED ✓'and pr.Enabled==false,'R158c e2e: the claim works, and you see "CLAIMED ✓", no prompt')
 -- one pack per player: pressing again is refused and the sign stays on CLAIMED, with the tutorial finished or not
 local ok3,why3=s6.Svc:Claim(me);G.run(.2)
 check(ok3==false and why3=='claimed'and s6.Data:voidPacks(me)==1 and note()=='CLAIMED ✓'and pr.Enabled==false and s6.Notes:last(me).Text:find('already grabbed',1,true)~=nil,'R158c e2e: a second claim is refused ("already grabbed"): still one pack, the sign still says "CLAIMED ✓"')
 me:SetAttribute('TutorialDone',false);G.run(.1)
 local ok4,why4=s6.Svc:Claim(me);G.run(.1)
 check(ok4==false and why4=='claimed'and s6.Data:voidPacks(me)==1 and note()=='CLAIMED ✓'and s6.Notes:last(me).Text~=REFUSAL,'R158c e2e: even if TutorialDone read false, a player who claimed sees "CLAIMED ✓" and is told "already grabbed", never "finish the tutorial"')
 s6.Svc.Model:Destroy();G.run(.3)
end

print(string.format('giveaway client: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
