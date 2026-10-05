--!nocheck
-- R150 (owner: "polish the pack pedestal that players have in base"): the client side of the mystery pedestal on the Roblox mock with the REAL scripts -
-- MysteryPackClient and MysteryPedestalFx as the local player, MysteryPackService / MysteryPedestalArt building the pedestals and driving them the way
-- Publish does (attributes first, then the pack): the three states' looks (LOCKED calm, UNLOCKED lit up, TAKEN dim), the sign (a friendlier pill, the
-- same size, place and ranges as R148), the unlock moment (once: ring, flash, sparks, chime, padlock opens and drops, the pack hops, the sign pops),
-- the take (the pack lifts off and flies to the player with a pop), owner-only things, reduced motion, low quality, nothing running for far / hidden /
-- streamed-out pedestals, streaming in and out, and a clean teardown. Mock time = R.clock = server time.
local H=require('./pedestal_harness');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
local function rgb(c,r,g,b)return c and math.abs(c.R*255-r)<.5 and math.abs(c.G*255-g)<.5 and math.abs(c.B*255-b)<.5 end
local function vnear(a,b,tol)return a and b and(a-b).Magnitude<=(tol or 1e-6)end
local function notNaN(v)return v and v.X==v.X and v.Y==v.Y and v.Z==v.Z end
local M=W.module('MysteryPackRules');local Fx=W.module('MysteryPedestalFx');local PlantFx=W.module('PlantGrowthFx')
R.clock=20000*86400+3600
local me=H.player(77,'Tester',true);local ben=H.player(88,'Ben')
local _,myRoot,myHum=H.character(me,V3(22,7.5,71))
local _,benRoot=H.character(ben,V3(400+22,7.5,71))
local recs={}
for i=1,4 do recs[i]=H.base(i,CF((i-1)*400,4.5,0))end -- (base 1 at the origin; the others 400, 800, 1200 studs away along X)
local rec=recs[1];local ORIGIN=V3(34,5,75);local PACK=V3(34,5+M.AnchorHeight,75)
local function look()H.look(V3(12,16,60),V3(34,14,75))end
local function lookAway()H.look(V3(12,16,60),V3(-200,16,-100))end
look()
local function mine(state,o)o=o or{};o.Owner=77;H.publish(rec,state,o)end
local function sign(r)return H.model(r or rec):FindFirstChild('MysteryLabel')end
local function fx(r)return H.fxFolder(r or rec)end
local function runes(r)local f=fx(r);local out={};if f then for i=1,8 do out[i]=f:FindFirstChild('Rune'..i)end end;return out end
local function lock(r)local f=fx(r);return f and f:FindFirstChild('Padlock')end
local function wisps(r)local f=fx(r);local e=f and f:FindFirstChild('Emitters');return e and e:FindFirstChild('Wisps')end
local function rise(r)local f=fx(r);local e=f and f:FindFirstChild('Emitters');return e and e:FindFirstChild('Rise')end
local function shaft(r)local f=fx(r);return f and f:FindFirstChild('Light shaft')end
local function pivotY(r)local p=H.pack(r or rec);return p and p:GetPivot().Position.Y end
local function flightsFolder()return W.workspace:FindFirstChild('MysteryPackFlights')end
local function flightsCount()local f=flightsFolder();return f and #f:GetChildren()or 0 end
-- Counts PivotTo calls per instance and CFrame writes per part (what runs per frame).
local pivots,writes={},0
do
 local raw=R.Inst.PivotTo;R.Inst.PivotTo=function(self,cf)pivots[self]=(pivots[self]or 0)+1;return raw(self,cf)end
end
local function noRenderConnections()return H.renderConnections()==0 end

-- 1. The pure parts --------------------------------------------------------------------------------------------------------------------------------------
check(near(Fx.Hop(0),0)and near(Fx.Hop(-1),0)and near(Fx.Hop(Fx.Tuning.HopSeconds),0)and near(Fx.Hop(5),0)and Fx.Hop(0/0)==0 and Fx.Hop('x')==0,'the hop is 0 before the unlock and after its 1.1 s')
local hopMax=0;for k=0,220 do hopMax=math.max(hopMax,Fx.Hop(k/200))end
check(hopMax<=Fx.Tuning.HopHeight and hopMax>.25 and Fx.Tuning.HopHeight+.35<=.9-.1,'the hop peaks at '..string.format('%.2f',hopMax)..' studs: with the bob (.35) still .1+ under the sign\'s .9 gap')
local same=true
for _,u in ipairs({0,.1,.25,.5,.75,.9,1})do
 local a,b,c=Fx.Flight(u);local x,y,z=PlantFx.Flight(u)
 if not(near(a,x,1e-12)and near(b,y,1e-12)and near(c,z,1e-12))then same=false end
end
check(same,'the take flight has the same shape (ease, arc, shrink) as a harvested fruit\'s (PlantGrowthFx.Flight)')
check(near(Fx.FlightSeconds(0),PlantFx.FlightSeconds(0))and near(Fx.FlightSeconds(20),PlantFx.FlightSeconds(20))and near(Fx.FlightSeconds(500),PlantFx.FlightSeconds(500))and near(Fx.Tuning.ShrinkTo,PlantFx.Tuning.ShrinkTo)and near(Fx.Tuning.AimUp,PlantFx.Tuning.AimUp),'and the same duration rule (.4 s + .012 per stud, at most .7 s), end size and aim point')
local p0,p1,p2=Fx.LockPose(0),Fx.LockPose(.28),Fx.LockPose(1)
check(p0.Open==0 and p0.Up==0 and p0.Fade==0 and near(p1.Open,1)and near(p1.Up,0)and near(p2.Fade,1)and p2.Up<-2,'the padlock: closed at first, the shackle open at .28, then it drops away (2+ studs) and has faded out at the end')
local risen=0;for k=0,100 do risen=math.max(risen,Fx.LockPose(.28+k*.0072).Up)end
check(risen>.3 and risen<.8,'it hops up a little before it drops ('..string.format('%.2f',risen)..' studs)')

-- 2. A pedestal with nobody home: nothing of ours ------------------------------------------------------------------------------------------------------
H.publish(rec,'Empty');H.loadClient()
local client=H.client
H.run(1)
check(fx()==nil and noRenderConnections(),'[empty] no owner: no fx, no per-frame function, the sign is off')
check(sign()and sign().Enabled==false,'(the sign exists and is off)')
check(H.count(W.workspace,'ParticleEmitter')==0,'(and no particle emitter exists in the world)')

-- 3. LOCKED: calm ----------------------------------------------------------------------------------------------------------------------------------------
mine('Locked',{UnlockIn=12*60+41})
H.run(.7)
local f=fx()
check(f~=nil and f.Parent==H.model(rec),'[locked] the fx are one Folder "MysteryFx" inside the pedestal\'s model')
local rs=runes()
local allRunes=#rs==8;for i=1,8 do if not rs[i]then allRunes=false end end
check(allRunes,'[locked] eight halo gems (Rune1 .. Rune8)')
local runeProps=true
for _,p in ipairs(rs)do
 if not(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow and p.Material==R.Enum.Material.Neon and rgb(p.Color,176,118,255)and near(p.Transparency,.5,1e-9))then runeProps=false end
end
check(runeProps,'[locked] violet, neon, a little see-through (dim), anchored, not solid, no touch / query / shadow')
local sig=sign()
check(sig.Enabled==true and sig.Status.Text:find('🔒 12:',1,true)==1 and sig.Title.Text=='❓ YOUR MYSTERY PACK','[locked] the sign: ❓ YOUR MYSTERY PACK / 🔒 12:xx')
-- The halo orbits the pack: a tilted ring of radius 3.4 around (a little under) its centre, clear of the pack, moving.
local centre=PACK+V3(0,-.2,0)
local function radiusOk()for _,p in ipairs(runes())do if not near((p.Position-centre).Magnitude,Fx.Tuning.Radius,1e-6)then return false end end;return true end
local before={};for i,p in ipairs(runes())do before[i]=p.Position end
H.run(.5)
local moved=0;for i,p in ipairs(runes())do if(p.Position-before[i]).Magnitude>.3 then moved+=1 end end
check(radiusOk()and moved==8,'[locked] the eight gems orbit on a ring of radius 3.4 around the pack and have all moved after half a second ('..moved..')')
local worstHorizontal,highest=math.huge,0
for k=1,60 do
 H.run(1/30)
 for _,p in ipairs(runes())do
  local d=p.Position-centre;worstHorizontal=math.min(worstHorizontal,math.sqrt(d.X^2+d.Z^2));highest=math.max(highest,d.Y)
 end
end
local pack=H.pack(rec);local _,psize=pack:GetBoundingBox()
check(worstHorizontal>=3.4*math.cos(Fx.Tuning.Tilt)-1e-6 and worstHorizontal-.49>math.sqrt((psize.X/2)^2+(psize.Z/2)^2),'[locked] the gems stay clear of the spinning pack (horizontal distance '..string.format('%.2f',worstHorizontal)..' from its axis, the pack is '..string.format('%.2f',psize.X)..' wide)')
local sigBottom=PACK.Y+sig.StudsOffsetWorldSpace.Y-sig.Size.Y.Scale/2
check(highest+.49<=sigBottom-PACK.Y-.5,'[locked] the halo never reaches the sign (its highest gem is '..string.format('%.2f',highest)..' over the pack, the sign starts '..string.format('%.2f',sigBottom-PACK.Y)..' over it)')
check(wisps()and wisps().Enabled==true and rise()and rise().Enabled==false and shaft()and shaft().Transparency==1,'[locked] faint wisps rise off the pad (the sparkles and the light shaft are off)')
local w=wisps()
check(rgb(w.Color.A,176,118,255)and w.Rate<=6 and w.Lifetime.Max<=3 and w.Rate*w.Lifetime.Max<=20,'[locked] the wisps are violet and sparse (at most ~15 alive: rate '..w.Rate..', life '..w.Lifetime.Max..')')
-- The padlock hangs on the column's front, facing the aisle (pad-space -X).
local pl=lock()
local body=pl and pl:FindFirstChild('Lock body')
check(pl and #pl:GetDescendants()>=9 and body and pl.PrimaryPart==body,'[locked] a padlock (body, face plate, keyhole, shackle) hangs on the column')
local pad=rec.Pad
local at=pad.CFrame:PointToObjectSpace(body.Position);local look_=pad.CFrame:VectorToObjectSpace(body.CFrame.LookVector)
check(near(at.X,34-(M.ColumnRadius+.075+.275),1e-6)and near(at.Z,75,1e-6)and near(at.Y-pad.Size.Y/2,3.4,1e-6),'[locked] on the column\'s front, 3.4 studs up, in pad space X '..string.format('%.3f',at.X))
check(near(look_.X,-1,1e-6)and near(look_.Y,0,1e-6),'[locked] facing -X (the aisle side)')
local gapToColumn=(34-at.X)-.275-M.ColumnRadius
check(near(gapToColumn,.075,1e-6),'[locked] its back is just in front of the column ('..string.format('%.3f',gapToColumn)..' stud: clear, not floating away)')
local lockParts=H.parts(pl);local lockOk=true
for _,p in ipairs(lockParts)do if not(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow)then lockOk=false end end
check(lockOk,'[locked] every padlock part is anchored, not solid, no query / touch / shadow')
-- Counts: what a pedestal costs while it is near.
local fparts=#H.parts(f);local emitters=H.count(f,'ParticleEmitter');local alive=0
for _,e in ipairs(f:GetDescendants())do if e:IsA('ParticleEmitter')and e.Enabled then alive+=e.Rate*e.Lifetime.Max end end
check(fparts<=22 and emitters==2 and alive<=40,'[locked] cost: '..fparts..' parts, '..emitters..' emitters, at most ~'..math.floor(alive)..' sparkles alive')
-- One per-frame function, connected because a pedestal is near.
check(H.renderConnections()==1,'[locked] exactly one per-frame function is connected (spin, orbit, flights)')
-- The server's pedestal has no scripts, emitters or per-part lights of its own: the fx are the client's alone.
check(H.count(H.model(rec),'ParticleEmitter')==H.count(f,'ParticleEmitter')+H.count(pack,'ParticleEmitter'),'[locked] the only emitters in the pedestal are the client\'s two (and the pack\'s own art)')

-- 4. The sign: a friendlier pill ----------------------------------------------------------------------------------------------------------------------
do
 local g=sign()
 check(g.Size.X.Scale==10 and g.Size.Y.Scale==3.6 and g.Size.X.Offset==0 and g.MaxDistance==120 and g.DistanceLowerLimit==18 and g.AlwaysOnTop==false and g.LightInfluence==0,'[sign] still 10 x 3.6 studs, shown up to 120 over your own pedestal, 18 studs close limit (R148)')
 local pill=g:FindFirstChild('Pill')
 check(pill and pill:IsA('Frame')and pill:FindFirstChild('UICorner')and pill:FindFirstChild('Outline')and pill:FindFirstChild('UIGradient'),'[sign] a rounded pill (corner, outline, shade) behind the text')
 check(pill.Size.X.Scale==1 and pill.Size.Y.Scale==1 and pill.ZIndex<g.Title.ZIndex and pill.ZIndex<g.Status.ZIndex and pill.ZIndex<g.Bar.ZIndex,'[sign] it fills the sign and sits behind the caption, the state line and the bar')
 local t,s,b=g.Title,g.Status,g.Bar
 check(t.Position.Y.Scale<s.Position.Y.Scale and s.Position.Y.Scale+s.Size.Y.Scale<=b.Position.Y.Scale+1e-9 and b.Position.Y.Scale+b.Size.Y.Scale<=1,'[sign] top to bottom: caption, state line, bar - nothing overlaps')
 check(s.Size.Y.Scale>t.Size.Y.Scale and s.Size.Y.Scale>=.4 and t.Size.Y.Scale>=.25,'[sign] the state line is the biggest thing on it, the caption is still readable')
 check(rgb(pill.BackgroundColor3,30,22,58)and rgb(pill.Outline.Color,150,112,236)and pill.Outline.Transparency==0,'[sign] Locked: a deep violet pill with a violet outline')
 -- Ready
 mine('Ready');H.run(.6)
 check(rgb(pill.BackgroundColor3,58,40,10)and rgb(pill.Outline.Color,255,214,90)and rgb(t.TextColor3,255,214,90)and rgb(s.TextColor3,255,214,90),'[sign] Ready: warm gold pill, gold outline, gold caption and state line')
 check(s.Text=='UNLOCKED! TAKE IT 🎁'and t.Text=='✨ YOUR MYSTERY PACK'and b.Visible==true and b.Fill.Size.X.Scale==1,'[sign] Ready: ✨ YOUR MYSTERY PACK / UNLOCKED! TAKE IT 🎁 and a full bar')
 check(near(g.Size.X.Scale,10,1e-9)and near(g.Size.Y.Scale,3.6,1e-9),'[sign] (the pop at the change settles back to exactly 10 x 3.6)')
 -- Someone else's pill is quieter
 H.publish(recs[2],'Ready',{Owner=88,Name='Ben',Variant='Pack04'})
 local og=sign(recs[2])
 check(og.Pill.BackgroundTransparency>pill.BackgroundTransparency and og.Pill.Outline.Transparency>0 and og.Status.Text=='UNLOCKED!','[sign] another player\'s pill is quieter (more see-through, softer outline) and says UNLOCKED!')
 H.publish(recs[2],'Empty')
 -- Claimed
 mine('Claimed',{Variant='Pack03',NextIn=2*3600+46*60+30});H.run(.6)
 check(rgb(pill.BackgroundColor3,14,36,30)and rgb(pill.Outline.Color,72,160,108)and rgb(t.TextColor3,120,236,110)and pill.BackgroundTransparency>=.3,'[sign] Taken: a quiet dark-mint pill, mint caption')
 check(t.Text=='✓ TAKEN TODAY'and s.Text=='NEW PACK IN 2h 46m'and b.Visible==false,'[sign] Taken: ✓ TAKEN TODAY / NEW PACK IN 2h 46m, no bar')
end
H.run(1.2)
check(fx()==nil,'[taken] the fx are gone once it is taken (a dim pedestal and the sign is all that is left)')
check(noRenderConnections(),'[taken] nothing runs per frame for a taken pedestal')

-- 5. Taken -> a new day: Locked again ---------------------------------------------------------------------------------------------------------------------
mine('Locked',{UnlockIn=900});H.run(.8)
check(fx()and#runes()==8 and lock()~=nil and wisps().Enabled==true and H.bursts()==0,'[new day] a new Locked pack: the fx and the padlock are back, no burst')

-- 6. UNLOCKED: the moment, once --------------------------------------------------------------------------------------------------------------------------
do
 table.clear(H.sounds);local b0=H.bursts();local label0=sign()
 local packBefore=H.pack(rec);local anchorY=packBefore:GetAttribute('MysteryOrigin').Position.Y
 mine('Ready',{Variant='Pack03'})
 local pl2=lock()
 check(H.bursts()==b0+1 and H.named('MysteryFlash')==1,'[unlock] a ring and a flash of light around the pack when MY pack unlocks, once')
 local chime=H.sounds[1]
 check(H.soundCount('Sound:MysteryUnlockChime')==1 and #H.sounds==1 and chime.At==R.clock,'[unlock] one chime, nothing else, in the very same call as the ring (no frame between)')
 local Mixer=W.module('AudioMixer')
 check(chime.Sound.SoundId=='rbxassetid://82559527540705'and chime.Sound.Parent==W.service('SoundService')and chime.Sound._plays>=1,'[unlock] the chime is the GemClaim file (an existing asset, no new upload)')
 check(chime.Group~=nil and chime.Group==Mixer.Group('Effects')and chime.Group.Name=='GardenEffects','[unlock] and it plays in the Effects group (AudioMixer)')
 local keep=Mixer.Get('Effects');Mixer.Set('Effects',0)
 check(chime.Sound.SoundGroup.Volume==0,'[unlock] so Effects volume 0 mutes it');Mixer.Set('Effects',keep)
 local ring=nil;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='MysteryBurst'then ring=c end end
 check(ring and rgb(ring.Color,255,214,90)and ring.Size.Y<16 and ring.Anchored and not ring.CanCollide and not ring.CanQuery and not ring.CanTouch,'[unlock] a gold ring that starts small, anchored and not solid')
 local spark=W.workspace:FindFirstChild('MysterySparks');local emitter=nil
 if spark then for _,d in ipairs(spark:GetDescendants())do if d:IsA('ParticleEmitter')then emitter=d end end end
 check(spark and emitter and emitter._emitted==40 and near(spark.Position.Y,PACK.Y,1e-6)and near(ring.Position.Y,PACK.Y-(M.AnchorHeight-M.PadTop-.12),1e-6),'[unlock] 40 sparks burst from the pack itself, while the ring spreads over the glowing pad under it')
 check(pl2~=nil,'[unlock] the padlock is still there at the moment it unlocks...')
 local g=sign()
 check(g.Size.X.Scale<9 and g.Size.X.Scale>=8-1e-9,'[unlock] the sign pops (starts at 80% size: '..string.format('%.2f',g.Size.X.Scale)..' studs wide)')
 -- the lock opens and drops; the pack hops but stays under the sign
 local maxTop=-math.huge;local labelBottomMin=math.huge;local minLock=math.huge;local openSeen=false
 for k=1,45 do
  H.run(1/30)
  local pk=H.pack(rec);local _,sz=pk:GetBoundingBox();local top=pk:GetPivot().Position.Y+sz.Y/2
  local sg=sign();local bottom=PACK.Y+sg.StudsOffsetWorldSpace.Y-sg.Size.Y.Scale/2
  maxTop=math.max(maxTop,top);labelBottomMin=math.min(labelBottomMin,bottom)
  local l=lock();if l then minLock=math.min(minLock,l.PrimaryPart.Position.Y);if l:FindFirstChild('Shackle'):GetPivot().Position.Y>l.PrimaryPart.Position.Y+1.3 then openSeen=true end end
 end
 check(openSeen,'[unlock] the shackle pops open')
 check(minLock<=ORIGIN.Y+3.4-1.5,'[unlock] and the lock drops away ('..string.format('%.2f',minLock-ORIGIN.Y)..' studs above the pad at its lowest)')
 check(lock()==nil,'[unlock] the padlock is gone after a second')
 check(maxTop<=labelBottomMin-.1,'[unlock] the hop never lifts the pack into the sign (its top at most '..string.format('%.2f',maxTop)..', the sign\'s bottom edge '..string.format('%.2f',labelBottomMin)..')')
 check(near(sign().Size.X.Scale,10,1e-9)and sign()==label0,'[unlock] the sign has settled at 10 x 3.6 (the same sign object)')
 H.run(.4)
 check(H.bursts()==0 and H.named('MysteryFlash')==0,'[unlock] the ring and the flash are cleaned up after ~1 s')
 -- Ready look
 local ready=true;for _,p in ipairs(runes())do if not(rgb(p.Color,255,214,90)and near(p.Transparency,.1,1e-9))then ready=false end end
 check(ready,'[unlocked] the halo is gold and bright')
 check(wisps().Enabled==false and rise().Enabled==true and rgb(rise().Color.A,255,214,90),'[unlocked] gold sparkles rise instead of the wisps')
 local sh=shaft()
 check(sh.Transparency>=.85 and sh.Transparency<.96 and rgb(sh.Color,255,214,90)and sh.Material==R.Enum.Material.Neon,'[unlocked] a soft column of gold light over MY pedestal ('..string.format('%.2f',sh.Transparency)..')')
 local topShaft=sh.Position.Y+sh.Size.X/2
 check(near(sh.Position.Y-sh.Size.X/2,ORIGIN.Y+M.PadTop,1e-6)and topShaft<PACK.Y+sig.StudsOffsetWorldSpace.Y-sig.Size.Y.Scale/2,'[unlocked] it stands on the glowing pad and ends under the sign')
 -- faster than locked
 local a1={};for i,p in ipairs(runes())do a1[i]=p.Position end;H.run(.2)
 local sp=0;for i,p in ipairs(runes())do sp+=(p.Position-a1[i]).Magnitude end
 check(sp/8>Fx.Tuning.Radius*Fx.Tuning.SlowSpin*.2*1.5,'[unlocked] the halo turns faster than while it was locked')
 -- the same state again: nothing repeats
 local b1=H.bursts();local s1=#H.sounds
 H.publish(rec,'Ready',{Owner=77,Variant='Pack03'});H.run(.6)
 check(H.bursts()==b1 and #H.sounds==s1 and lock()==nil,'[unlock] publishing Ready again (or the half-second tick) repeats nothing: once')
end

-- 7. TAKEN: the pack lifts off and flies to the player ---------------------------------------------------------------------------------------------------
do
 table.clear(H.sounds);local b0=H.bursts()
 local pk=H.pack(rec);local pivot=pk:GetPivot()
 mine('Claimed',{Variant='Pack03',NextIn=3*3600}) -- (attributes first; the server removes the pack right after, in Publish's order)
 check(flightsCount()==1 and H.pack(rec)==nil,'[take] a copy of the pack leaves the pedestal while the real one is gone')
 local mint=nil;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='MysteryBurst'and rgb(c.Color,120,236,110)then mint=c end end
 check(H.bursts()==b0+1 and mint and near(mint.Position.Y,PACK.Y-(M.AnchorHeight-M.PadTop-.12),1e-6)and mint.Size.Y<9,'[take] a small mint ring spreads over the glowing pad as it lifts off')
 local whoosh=H.sounds[1]
 check(H.soundCount('Reveal:Whoosh')==1 and #H.sounds==1 and whoosh.At==R.clock and whoosh.Pitch==1.6,'[take] a whoosh (RarityRevealAudio\'s, in the Effects group) in the same call as the lift-off, and nothing else yet: the pickup cue waits for the pack to reach you')
 local ghost=flightsFolder():GetChildren()[1]
 check(ghost.Name=='SeedPacket'and ghost:GetPivot().Position.Y>=pivot.Position.Y-.2,'[take] it starts where the pack was')
 local aimUp=Fx.Tuning.AimUp;local aim=myRoot.Position+V3(0,aimUp,0)
 local maxY=-math.huge;local arrived=false;local frames=0;local lastDist=math.huge;local monotone=true;local lastAt,firstExt,lastExt,firstAt,sane
 sane=true;local start=R.clock
 for k=1,45 do
  H.run(1/30);frames+=1
  local g=flightsFolder()and flightsFolder():GetChildren()[1]
  if not g then arrived=true;break end
  -- the REAL position of the copy's parts (its root part) and its real size: not just the pivot the script asked for
  local at=g.PrimaryPart.Position;local ext=g:GetExtentsSize().Y
  if not notNaN(at)then sane=false;break end
  firstAt=firstAt or at;firstExt=firstExt or ext;lastAt=at;lastExt=ext;maxY=math.max(maxY,at.Y)
  local d=(at-aim).Magnitude
  if k>8 and d>lastDist+.05 then monotone=false end;lastDist=d
 end
 local took=R.clock-start
 check(sane and arrived and took>=.2+.4-.05 and took<=.2+.7+.1,'[take] it flies to the player and lands within ~'..string.format('%.2f',took)..' s (.2 lift + .4-.7 flight)')
 check(vnear(firstAt,PACK,Fx.Tuning.LiftHeight+.6)and firstAt.Y>PACK.Y-.5,'[take] its parts start at the pack on the pedestal and lift off it')
 check(maxY>=PACK.Y+Fx.Tuning.LiftHeight-.3 and monotone,'[take] they rise (the lift), then close in on the player the whole way')
 check((lastAt-aim).Magnitude<2.2,'[take] and by the last frame they are at the player\'s chest ('..string.format('%.2f',(lastAt-aim).Magnitude)..' studs away)')
 check(lastExt<=firstExt*(Fx.Tuning.ShrinkTo+.3)and lastExt>0,'[take] the real parts shrink on the way ('..string.format('%.2f',lastExt/firstExt)..' of the size near the end)')
 check(flightsCount()==0 and H.named('MysteryPop')==1,'[take] it is gone when it lands, and a small pop of sparks is left at the player')
 check(H.soundCount('Bubble06')==1 and H.soundCount('Bubble04')==0 and #H.sounds==2,'[take] the game\'s pack pickup cue (Bubble06, not the generic Bubble04 click) plays once, when the pack arrives: two sounds in all')
 local pop=nil;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='MysteryPop'then pop=c end end
 check(pop and near(pop.Position.Y,myRoot.Position.Y+aimUp,1e-6)and near(pop.Position.X,myRoot.Position.X,1e-6),'[take] the pop is at the player\'s chest')
 H.run(1.5)
 check(H.named('MysteryPop')==0 and H.bursts()==0,'[take] and cleaned up after a second')
 check(noRenderConnections()and fx()==nil,'[take] then nothing runs per frame for the taken pedestal')
end

-- 7b. A refused take makes no sound and changes nothing here ------------------------------------------------------------------------------------------------
do
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack03'});H.run(2.5);table.clear(H.sounds)
 local b0=H.bursts();local prompt=H.pedestal(rec).Prompt
 local refused,why=H.svc:Claim(ben,rec) -- (the server's own refusal: not his pedestal)
 prompt.Triggered:Fire(ben);prompt.Triggered:Fire(ben) -- (and through the prompt, twice)
 H.run(1.2)
 check(refused==false and why=='NOT YOURS','[refused] the server refuses somebody else\'s take (NOT YOURS)')
 check(#H.sounds==0 and H.bursts()==b0 and flightsCount()==0 and H.model(rec):GetAttribute('State')=='Ready'and H.pack(rec)~=nil,'[refused] no success sound, no burst, no flight: the pedestal is still Ready with its pack')
 -- A take that is not confirmed (the state does not change: a full Bag, a hold that was let go) is silent too: the cues follow the pedestal's State, never the key press.
 prompt.Triggered:Fire(me);H.run(1)
 check(#H.sounds==0 and flightsCount()==0,'[refused] pressing Take with nothing confirmed by the server (a full Bag) makes no sound either')
 mine('Claimed',{Variant='Pack03',NextIn=3*3600});H.run(1.5)
 check(H.soundCount('Reveal:Whoosh')==1 and H.soundCount('Bubble06')==1,'[refused] only the confirmed take (the pedestal turning Claimed) plays the whoosh and the pickup cue')
end

-- 7c. Joining: a pedestal that wakes up already taken makes no take moment; one that wakes up unlocked announces itself once -------------------------------------
do
 H.publish(rec,'Empty');H.run(1);table.clear(H.sounds);local b0=H.bursts()
 mine('Claimed',{Variant='Pack03',NextIn=3*3600}) -- (the owner joins having taken today's pack: the pedestal goes Empty -> Claimed in front of the client)
 H.run(1.5)
 check(H.bursts()==b0 and #H.sounds==0 and flightsCount()==0 and H.named('MysteryPop')==0,'[join] a pedestal that wakes up Taken (the owner joined, today\'s pack is long gone) makes no ring, no sound and no flight: nothing was taken just now')
 check(fx()==nil and sign().Title.Text=='✓ TAKEN TODAY','[join] it is simply shown as taken')
 H.publish(rec,'Empty');H.run(1)
 mine('Ready',{Variant='Pack03'});H.run(.5)
 check(H.bursts()==b0+1 and H.soundCount('Sound:MysteryUnlockChime')==1 and #H.sounds==1,'[join] joining with an unlocked pack waiting: one ring and one chime (as in R147: your pack is ready), no flight')
 check(lock()==nil,'[join] (and no padlock to open: there was none)')
 H.run(2.5)
end

-- 8. The order of the take: the pack still there when the state says Claimed, and a take that nobody sees ----------------------------------------------
do
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack05'});H.run(1.4)
 table.clear(H.sounds)
 -- (a) the state arrives first and the pack is still on the pedestal: the flight copies the live pack
 local m=H.model(rec);m:SetAttribute('State','Claimed')
 check(flightsCount()==1,'[take] State first, pack still there: it flies from a copy of the live pack')
 check(H.pack(rec)~=nil,'(the real one is left for the server to remove)')
 H.run(1.2);check(flightsCount()==0 and H.soundCount('Bubble06')==1,'[take] and it lands')
 H.svc:_look(H.pedestal(rec),'Claimed',1,'Pack05');H.run(.2)
 check(H.pack(rec)==nil,'[take] (the server then removes the real pack)')
 -- (b) the pack was removed before the State change reached us: the copy kept while it was Ready flies
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack05'});H.run(1.4)
 table.clear(H.sounds)
 H.svc:_look(H.pedestal(rec),'Claimed',1,'Pack05') -- (the pack goes first)
 check(H.pack(rec)==nil and flightsCount()==0,'[take] the pack is removed before the state arrives: no flight yet')
 H.model(rec):SetAttribute('State','Claimed')
 check(flightsCount()==1,'[take] the state arrives: it flies from the copy kept while it was Ready')
 H.run(1.2);check(flightsCount()==0 and H.soundCount('Bubble06')==1,'[take] and lands')
end

-- 9. Someone else's pedestal near me: they see the same moments, quietly --------------------------------------------------------------------------------
do
 table.clear(H.sounds);H.publish(rec,'Empty');H.run(.6)
 H.publish(rec,'Locked',{Owner=88,Name='Ben',UnlockIn=900});H.run(.8)
 -- Ben's character stands next to his pedestal for the flight
 benRoot.CFrame=CF(22,7.5,70)
 check(fx()~=nil and lock()~=nil and shaft().Transparency==1,'[others] Ben\'s locked pedestal wears the same fx (the shaft is only for its owner)')
 local b0=H.bursts()
 H.publish(rec,'Ready',{Owner=88,Name='Ben',Variant='Pack03'});H.run(.5)
 check(H.bursts()==b0 and #H.sounds==0,'[others] his unlock makes no ring and no sound for me')
 check(lock()==nil or lock().PrimaryPart~=nil,'(his padlock still opens)')
 H.run(1)
 check(shaft().Transparency==1 and rgb(runes()[1].Color,255,214,90),'[others] his unlocked pedestal lights up gold for me, without a light shaft')
 H.publish(rec,'Claimed',{Owner=88,Name='Ben',Variant='Pack03'})
 check(flightsCount()==1 and #H.sounds==0,'[others] when Ben takes it I see the pack fly to him (no sound)')
 H.run(1.2)
 check(flightsCount()==0 and H.named('MysteryPop')==1 and #H.sounds==0,'[others] it lands on him with the pop of sparks, and no sound for me')
 check(H.bursts()==b0 or H.bursts()==b0+0,'(no burst of mine either)')
 H.run(1.2)
end

-- 10. Streaming: a pedestal found already Ready / Locked, re-streamed copies -----------------------------------------------------------------------------
do
 H.publish(rec,'Empty');H.run(.6);table.clear(H.sounds);local b0=H.bursts()
 -- found already Ready (joined late, or streamed in)
 mine('Ready',{Variant='Pack02'});H.run(2.5);table.clear(H.sounds);b0=H.bursts() -- (the unlock ring and its sounds are over)
 local m=H.model(rec)
 -- streamed out: its fx go with it; streamed back in as a NEW instance: fresh fx, no unlock moment for a pack that was already Ready
 local oldFx=fx();local oldSign=sign()
 m.Parent=nil
 check(oldFx.Parent==nil or oldFx:IsDescendantOf(W.workspace)==false,'[streaming] a pedestal that streams out takes its fx with it (they are inside its model)')
 check(oldSign.Parent==nil,'[streaming] and its sign')
 H.run(1)
 check(noRenderConnections(),'[streaming] and the per-frame function ends once no pedestal is near')
 -- a new copy appears with the same attributes
 local nm=R.new('Model');nm.Name='MysteryPedestal'
 for k,v in pairs(m._attrs)do nm._attrs[k]=v end
 for _,c in ipairs(m:GetChildren())do c.Parent=nm end
 nm.Parent=H.records[1].Model;W.CS:AddTag(nm,'MysteryPedestal')
 H.run(1.2)
 local nf=nm:FindFirstChild('MysteryFx')
 check(nf~=nil and nf~=oldFx and #H.parts(nf)>=10,'[streaming] the streamed-back copy gets fresh fx of its own')
 check(nm:FindFirstChild('MysteryLabel')~=nil and nm.MysteryLabel~=oldSign and nm.MysteryLabel.Status.Text=='UNLOCKED! TAKE IT 🎁','[streaming] and its own sign, up to date')
 check(H.bursts()==b0 and #H.sounds==0 and nf:FindFirstChild('Padlock')==nil,'[streaming] no ring, no sound and no padlock for a pack that was already Ready')
 -- parts arriving late: a pedestal whose PackAnchor streams in after the model
 nm:Destroy();H.run(.5)
 H.svc.Pedestals[rec]=nil;H.svc:_build(rec);H.publish(rec,'Empty')
end

-- 11. Reduced motion: the same parts, standing still ------------------------------------------------------------------------------------------------------
do
 W.Gui.ReducedMotionEnabled=true
 mine('Locked',{UnlockIn=900});H.run(1.2)
 local f2=fx();check(f2~=nil and #runes()==8 and lock()~=nil,'[reduced] the halo and the padlock are there')
 check(wisps()==nil and rise()==nil and H.count(f2,'ParticleEmitter')==0,'[reduced] but no particle emitters at all')
 local a={};for i,p in ipairs(runes())do a[i]=p.Position end
 local py=pivotY();H.run(.7)
 local still=true;for i,p in ipairs(runes())do if(p.Position-a[i]).Magnitude>1e-9 then still=false end end
 check(still and near(pivotY(),py,1e-9),'[reduced] nothing moves: the gems stand still and the pack does not spin or bob')
 table.clear(H.sounds);local b0=H.bursts();local s0=sign().Size.X.Scale
 mine('Ready',{Variant='Pack03'})
 check(H.bursts()==b0+1,'[reduced] the burst still happens...')
 local ring;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='MysteryBurst'then ring=c end end
 check(ring.Transparency==1 and H.named('MysteryFlash')==0,'[reduced] ...but its ring is invisible (no tween) and there is no flash')
 check(lock()==nil and sign().Size.X.Scale==10 and H.tweens()==0,'[reduced] the padlock is simply taken down (no animation) and the sign does not pop')
 check(H.soundCount('Sound:MysteryUnlockChime')==1,'[reduced] the chime still plays')
 H.run(.5);for i=1,45 do H.run(1/30)end
 check(H.tweens()==0 and shaft().Transparency>=.88,'[reduced] the light shaft is steady, not breathing ('..string.format('%.3f',shaft().Transparency)..')')
 local s2=shaft().Transparency;H.run(.5);check(shaft().Transparency==s2,'[reduced] (it does not change over time)')
 table.clear(H.sounds)
 mine('Claimed',{Variant='Pack03'})
 check(flightsCount()==0 and H.soundCount('Bubble06')==1 and H.soundCount('Bubble04')==0 and H.soundCount('Reveal:Whoosh')==0,'[reduced] taking it: no flight; the pack just goes, with the same small burst and the pickup cue at once (no whoosh)')
 -- the module itself stands still too when it is built still, even if something calls Step
 local host=R.new('Folder');host.Parent=W.workspace
 local sfx=Fx.Build(host,CF(0,20,0),true);Fx.SetState(sfx,'Ready',true)
 local p1={};for i,p in ipairs(sfx.Runes)do p1[i]=p.Position end
 Fx.Step(sfx,100);Fx.Step(sfx,200.5)
 local frozen=true;for i,p in ipairs(sfx.Runes)do if(p.Position-p1[i]).Magnitude>1e-9 then frozen=false end end
 check(frozen and sfx.Wisps==nil and sfx.Rise==nil and sfx.Shaft.Transparency==.9,'[reduced] (Fx.Step on a still build moves nothing, makes no emitters and does not breathe the shaft)')
 Fx.Destroy(sfx);host:Destroy()
 -- switching reduced motion off while the pedestal is Locked rebuilds the fx moving
 mine('Locked',{UnlockIn=900});H.run(1)
 local stillFolder=fx()
 W.Gui.ReducedMotionEnabled=false;H.run(1)
 check(fx()~=stillFolder and wisps()~=nil and wisps().Enabled==true,'[reduced] turning it off in the settings brings the moving fx in within half a second (rebuilt)')
 W.Gui.ReducedMotionEnabled=true;H.run(1)
 check(fx()~=nil and wisps()==nil,'[reduced] and turning it on takes them away again')
 W.Gui.ReducedMotionEnabled=false;H.run(1)
end

-- 12. Quality ------------------------------------------------------------------------------------------------------------------------------------------------
do
 H.tier=1;H.run(1)
 check(fx()==nil and lock()==nil,'[quality] lowest tier: no fx at all (the sign, the glow and the pack\'s spin stay)')
 local py=pivotY();H.run(.5);check(pivotY()~=py,'[quality] the pack still spins on the lowest tier (as before R150)')
 table.clear(H.sounds);mine('Ready',{Variant='Pack03'});H.run(.5)
 check(H.bursts()==1 and H.soundCount('Sound:MysteryUnlockChime')==1 and #H.sounds==1 and fx()==nil,'[quality] the unlock burst and chime are unchanged on the lowest tier')
 table.clear(H.sounds);mine('Claimed',{Variant='Pack03'})
 check(flightsCount()==0 and H.soundCount('Bubble06')==1 and #H.sounds==1,'[quality] no take flight on the lowest tier: the burst and the pickup cue at once')
 H.run(1.2)
 H.tier=2;mine('Locked',{UnlockIn=900});H.run(1)
 check(fx()~=nil and lock()~=nil,'[quality] medium: the fx are on')
 mine('Ready',{Variant='Pack03'});H.run(1.5);table.clear(H.sounds)
 mine('Claimed',{Variant='Pack03'});check(flightsCount()==1,'[quality] medium: the take flight plays')
 H.run(1.2);H.tier=3
 mine('Locked',{UnlockIn=900});H.run(1)
 H.tier=1;H.run(1);check(fx()==nil,'[quality] dropping to the lowest tier while looking takes the fx away within half a second')
 H.tier=3;H.run(1);check(fx()~=nil,'[quality] and back up brings them back')
end

-- 13. Nothing runs for pedestals that are far, hidden or not showing -------------------------------------------------------------------------------------
do
 mine('Locked',{UnlockIn=900});H.run(1)
 check(fx()~=nil and H.renderConnections()==1,'[far] near and looking: fx on, one per-frame function')
 -- the same pedestals, many bases: far ones never get fx
 for i=2,4 do H.publish(recs[i],'Locked',{Owner=100+i,Name='P'..i,UnlockIn=900})end
 H.run(1)
 local farFx=0;for i=2,4 do if fx(recs[i])then farFx+=1 end end
 check(farFx==0 and H.renderConnections()==1,'[far] three more Locked pedestals 400 - 1200 studs away have no fx, and still only one per-frame function')
 local farPackY={};for i=2,4 do farPackY[i]=pivotY(recs[i])end
 H.run(.7)
 local farStill=true;for i=2,4 do if pivotY(recs[i])~=farPackY[i]then farStill=false end end
 check(farStill,'[far] their packs do not spin')
 -- looking away: the loop stays (they are near) but nothing is written
 lookAway()
 local piv0=0;for _,c in pairs(pivots)do piv0+=c end
 local r1={};for i,p in ipairs(runes())do r1[i]=p.Position end;local pk0=pivotY()
 H.run(.7)
 local piv1=0;for _,c in pairs(pivots)do piv1+=c end
 local unmoved=true;for i,p in ipairs(runes())do if(p.Position-r1[i]).Magnitude>1e-9 then unmoved=false end end
 check(piv1==piv0 and unmoved and near(pivotY(),pk0,1e-9),'[far] looking away from it (off screen, 32 studs away): no pack, no gem is moved ('..(piv1-piv0)..' pivots)')
 look();H.run(.3)
 check(pivotY()~=pk0,'[far] looking back brings the spin back')
 -- moving far away
 H.look(V3(34+260,16,75),V3(34,14,75));H.run(1)
 check(fx()==nil and noRenderConnections(),'[far] 260 studs away: the fx are taken down and no per-frame function is left')
 H.look(V3(34-90,16,75),V3(34,14,75));H.run(1)
 check(fx()==nil,'[far] 90 studs away it does not come back yet (it needs 75)')
 H.look(V3(34-70,16,75),V3(34,14,75));H.run(1)
 check(fx()~=nil and H.renderConnections()==1,'[far] at 70 studs it is back')
 H.look(V3(34-90,16,75),V3(34,14,75));H.run(1)
 check(fx()~=nil,'[far] and it stays until 100 (no flicker at the edge)')
 H.look(V3(34-110,16,75),V3(34,14,75));H.run(1)
 check(fx()==nil and noRenderConnections(),'[far] and goes at 110')
 look();H.run(1)
 for i=2,4 do H.publish(recs[i],'Empty')end
 -- sign range: the label's own distance limits are unchanged (and the countdown text is kept up to date in range)
 H.run(.5)
 check(sign().MaxDistance==120 and sign(recs[2]).MaxDistance==90,'[far] the sign shows up to 120 studs on mine, 90 on others (R148)')
 H.look(V3(34-130,16,75),V3(34,14,75));local t0=sign().Status.Text;H.run(30)
 check(sign().Status.Text~=t0,'[far] the countdown text is still kept up to date at 130 studs')
 look();H.run(.5)
end

-- 14. A flight cut short, the owner leaving, a pedestal that goes away -------------------------------------------------------------------------------------
do
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack03'});H.run(1.4)
 table.clear(H.sounds);mine('Claimed',{Variant='Pack03'});H.run(.35)
 check(flightsCount()==1,'[cut] a flight in the air...')
 myHum.Health=0;H.run(.1)
 check(flightsCount()==0 and H.soundCount('Bubble06')==0 and H.named('MysteryPop')==0,'[cut] ...the player dies: it just disappears (no pop, no pickup cue, no error)')
 myHum.Health=100
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack03'});H.run(1.4);table.clear(H.sounds)
 local savedChar=me.Character;me.Character=nil
 mine('Claimed',{Variant='Pack03'})
 check(flightsCount()==0 and H.soundCount('Bubble06')==1,'[cut] no character (respawning): no flight, the burst and the pickup cue at once')
 me.Character=savedChar
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack03'});H.run(1.4)
 mine('Claimed',{Variant='Pack03'});H.run(.3)
 -- the pedestal goes away (streamed out) mid-flight: the flight in the air finishes on its own
 H.model(rec).Parent=nil;H.run(1.2)
 check(flightsCount()==0 and noRenderConnections(),'[cut] the pedestal streams out mid-flight: the pack in the air still lands and the loop ends')
 H.svc.Pedestals[rec]=nil;H.svc:_build(rec);H.publish(rec,'Empty');H.run(.6)
end

-- 15. A rotated base: everything is in the pedestal's own space ---------------------------------------------------------------------------------------------
do
 local turned=H.base(9,CF(-600,4.5,300)*R.CFrame.Angles(0,math.pi/2,0))
 local tp=H.pedestal(turned).Anchor.Position
 H.look(tp+V3(0,2,-22),tp)
 H.publish(turned,'Locked',{Owner=100,Name='Z',UnlockIn=900});H.run(1)
 local tf=H.fxFolder(turned)
 check(tf~=nil,'[rotated] a base turned 90 degrees gets its fx too')
 local tpad=turned.Pad;local body=tf.Padlock['Lock body']
 local at=tpad.CFrame:PointToObjectSpace(body.Position);local fwd=tpad.CFrame:VectorToObjectSpace(body.CFrame.LookVector)
 check(near(at.X,34-(M.ColumnRadius+.075+.275),1e-5)and near(at.Z,75,1e-5)and near(fwd.X,-1,1e-6),'[rotated] the padlock is on the front of the column in the pad\'s own space (X '..string.format('%.3f',at.X)..', facing '..string.format('%.2f',fwd.X)..')')
 local rr=H.fxFolder(turned):FindFirstChild('Rune1')
 check(near((rr.Position-(tp+V3(0,-.2,0))).Magnitude,Fx.Tuning.Radius,1e-6),'[rotated] the halo is centred on its pack')
 H.publish(turned,'Empty');H.run(.6);look()
end

-- 16. Teardown ---------------------------------------------------------------------------------------------------------------------------------------------------
do
 mine('Locked',{UnlockIn=900});H.run(.8);mine('Ready',{Variant='Pack03'});H.run(1.4)
 table.clear(H.sounds);mine('Claimed',{Variant='Pack03'});H.run(.2)
 check(flightsCount()==1,'[teardown] a flight in the air when the script is removed...')
 local label=sign()
 client.Destroying:Fire()
 check(sign()==nil and fx()==nil and flightsFolder()==nil,'[teardown] removing the script removes every sign, every fx and the flights')
 check(noRenderConnections(),'[teardown] and leaves no per-frame function connected')
 H.run(1.2)
 mine('Locked',{UnlockIn=900});H.run(1)
 check(sign()==nil and fx()==nil,'[teardown] new state changes make nothing after that (no errors)')
end
-- 17. The fx are cosmetic: three errors switch them off, and nothing else notices (a fresh client, after the teardown above) ----------------------------------------
do
 H.loadClient();H.run(.6)
 local warned={};local rawWarn=W.env.warn;W.env.warn=function(...)warned[#warned+1]=table.concat({...},' ')end
 mine('Locked',{UnlockIn=900});H.run(1)
 check(fx()~=nil,'[errors] (a Locked pedestal with its fx)')
 local realStep=Fx.Step;Fx.Step=function()error('boom')end
 local py=pivotY();H.run(.5)
 Fx.Step=realStep
 check(#warned==3 and warned[1]:find('[R150] Mystery pedestal fx',1,true)==1,'[errors] three errors are reported (3 warnings, not one per frame: '..#warned..')')
 check(fx()==nil and pivotY()~=py,'[errors] then the fx are gone and the pack still spins')
 H.run(1);check(fx()==nil and #warned==3,'[errors] they stay off for the session and nothing else is reported')
 mine('Ready',{Variant='Pack03'});H.run(.5)
 check(sign().Status.Text=='UNLOCKED! TAKE IT 🎁'and sign().Pill.Outline.Color.R*255>254,'[errors] the sign keeps working (it follows the state)')
 check(H.model(rec):FindFirstChild('MysteryFx')==nil and H.pedestal(rec).Prompt.Enabled==true,'[errors] no fx are built again, and the take prompt is untouched')
 table.clear(H.sounds);mine('Claimed',{Variant='Pack03'})
 check(flightsCount()==0 and H.soundCount('Bubble06')==1,'[errors] taking it still works: no flight, the pickup cue at once')
 W.env.warn=rawWarn
end

print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
