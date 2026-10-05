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
local G=require('./giveaway_harness');local H,W,R=G.H,G.W,G.R;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=G.Rules;local A=Rules.Attr
local warns={};W.env.warn=function(...)local t={};for _,v in ipairs({...})do t[#t+1]=tostring(v)end;warns[#warns+1]=table.concat(t,' ')end
R.clock=20000*86400+3600
local me=H.player(77,'Tester',true);H.character(me,V3(0,5,-370))
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
check(text(s,'Note')==Rules.Hint,'a quiet line: LIMITED · ONE PER PLAYER')
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
local anyUnanchored,collides=0,0;for _,d in ipairs(pack:GetDescendants())do if d:IsA('BasePart')then if not d.Anchored then anyUnanchored+=1 end;if d.CanCollide or d.CanQuery or d.CanTouch then collides+=1 end end end
check(anyUnanchored==0 and collides==0,'every part anchored, no collision, not queryable')
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

print(string.format('giveaway client: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
