--!nocheck
-- R155 cinematic camera for the Secret / Cosmic / King story scenes (docs/proposals/R155/cinematic_camera.md): the REAL RarePullCamera155 on its
-- own, then inside the REAL RarePullCinematic / RarePullScenes / RarePullCard / RarePullAudio / SeedCollect154 on the Roblox mock (R151 / R152 test
-- environment: rare_env, rare152_env), at 30, 60 and 144 fps. The owner's four answers: (1) the cuts as designed, (2) the Cosmic seed's hero size
-- with the star, (3) NO world opening move and NO hand-back offset: the camera before the stage and after it is today's, (4) a depth of field on
-- every device (RarePullDof on the Camera).
--  1. the rig: every cut ON its beat (the timeline / cue sheet) and on its sound; the comfort limits (turn, orbit, dutch tilt, lens ramps, snaps,
--     no spin); the dead stop (the skip target is the silence frame); the depth of field modest and continuous; the seed hero 33-40 % of the
--     height, centred, on 16:9 / 19.5:9 / 4:3, through a 120 s wait; the wait steady (slow, bounded, never repeating, never wandering off);
--     Reduced Motion (Calm): still shots cut on the Calm beats, no roll, still focus; the camera keeps clear of every stage part (the real stages,
--     with / without the drawn images, desktop and lite).
--  2. the director, frame by frame: the camera before the stage = today's (the lens-only push, the player's own CFrame) and after it = today's
--     (restored exactly); in the stage = the rig (+ the R152 hit shake); every cut on the first frame of its beat with its sound heard within
--     0.01 s of that frame; RarePullDof made on entering the stage, updated with the shot, gone on leaving it, on every tier (desktop, phone,
--     low quality) and in Reduced Motion; one render binding; a 120 s wait on the hero shot, then the collect from it; every exit path (collect,
--     skip, abort, death, character removed, moved, a keeper, a replaced camera, a stage error, a camera error, the script destroyed); a skip at
--     every phase; "Skip pack animations" (no camera at all); Common..Mythic never touch the camera module (and their camera is today's).
-- (Common..Mythic, the onlookers and the world phases are also compared byte for byte against the R154 release: run_camera155.sh, step 3.)
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)else print('ok: '..msg)end;return c end -- (every check is in the log with its numbers)
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local fmt=string.format
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Cam=W.module('RarePullCamera155')
local Scenes=W.module('RarePullScenes');local Audio=W.module('RarePullAudio');local Sounds=W.module('RarePullSounds')
local Collect=W.module('SeedCollect154');local Visuals=W.module('SeedPackVisuals');local Art=W.module('RarePullArt')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local Lim=Cam.Limits
local function ang(a,b)return math.deg(math.acos(math.clamp(a:Dot(b),-1,1)))end
local function yaw(v)return math.deg(math.atan2(v.X,v.Z))end
local function dyaw(a,b)local d=math.abs(a-b)%360;return d>180 and 360-d or d end
check(M.Camera==Cam,'the director loads the cinematic camera (RarePullCamera155)')
-- the cuts the design asks for, and the sound each one is cut on
local function carrySwell(tl)for _,f in ipairs(L.Flights('Scene',8,tl))do if f.Name=='Pack carry'then return f.Peak end end;return nil end
local EXPECT={
 [6]=function(tl)return{{tl.Glitch1,'SecretGlitch','the 1st glitch'},{tl.Glitch2,'SecretGlitch','the 2nd glitch'},{tl.Lock,'PackShake','the 1st lock click'}}end,
 [7]=function()return{}end,
 [8]=function(tl)return{{carrySwell(tl),'Flight','the carry whoosh\'s swell'},{tl.CrownStart,'Sparkle','the crown\'s shimmer'},{tl.CrownOn+.25,'PackShake','the 2nd shake'}}end,
}
-- the black of the fade into the stage (RarePullCard:UpdateScene): a move under it is not seen
local function black(t,tl)
 if t<tl.SceneIn then return 1 end
 if t<tl.SceneIn+.3 then return 1-math.clamp((t-tl.SceneIn)/.3,0,1)end
 return 0
end
local function sample(rig,t,aspect)
 local e,g,f,r=Cam.Shot(rig,t,aspect or 16/9)
 return {T=t,Eye=e,Target=g,Fov=f,Roll=r,Index=rig.Index,Hero=rig.Hero,Focus=rig.Focus,Radius=rig.Radius,Far=rig.Far,Near=rig.Near,Name=rig.Name}
end
-- 1. the rig on its own ---------------------------------------------------------------------------------------------------------------------
for rank=6,8 do
 local tl=L.Timeline(rank,'Full');local rig=Cam.New(rank,'Full',tl);local tag=names[rank]..' Full'
 local want=EXPECT[rank](tl)
 check(#rig.Cuts==#want,fmt('%s: %d cuts inside the stage (%d designed: Secret 3, Cosmic one continuous take, King 3)',tag,#rig.Cuts,#want))
 local cues=L.SceneCues(rank,tl)
 for i,w in ipairs(want)do
  check(rig.Cuts[i]~=nil and near(rig.Cuts[i],w[1],1e-9),fmt('%s: cut %d on %s (%.3f s; the rig: %s)',tag,i,w[3],w[1],tostring(rig.Cuts[i])))
  local on=nil;for _,q in ipairs(cues)do if q.Slot==w[2]and near(q.PeakAt or q.At,w[1],1e-9)then on=q end end
  check(on~=nil,fmt('%s: cut %d lands on a sound of the cue sheet (%s%s at %.3f s)',tag,i,w[2],on and on.PeakAt and' swell'or'',w[1]))
 end
 -- every shot starts ON its beat (the timeline's; the carry whoosh's swell), and the picture changes shot exactly there
 local onBeat,names2=true,{}
 for i,sh in ipairs(Cam.Shots[rank])do
  local beat=tl[sh.From[1]]or rig.Beats[sh.From[1]];local want=beat and beat+(sh.From[2]or 0)
  if not want or not near(rig.From[i],want,1e-9)then onBeat=false end
  if i>1 and want then local a0,a1=sample(rig,want-1e-6),sample(rig,want);if a0.Index~=i-1 or a1.Index~=i then onBeat=false end end
  names2[#names2+1]=fmt('%s %s%+.2f',sh.Name,sh.From[1],sh.From[2]or 0)
 end
 check(onBeat,tag..': every shot starts on its beat ('..table.concat(names2,', ')..')')
 -- a joined shot carries on exactly where the one before stopped: the eye, the aim, the lens, the tilt and the focus (no step at the join)
 local joins={}
 for i,sh in ipairs(Cam.Shots[rank])do
  if i>1 and sh.Join and sh.From[1]~='Climax'then
   local b=rig.From[i];local a0,a1=sample(rig,b-1e-7),sample(rig,b)
   local step=math.max((a1.Eye-a0.Eye).Magnitude,(a1.Target-a0.Target).Magnitude,math.abs(a1.Fov-a0.Fov),math.abs(a1.Roll-a0.Roll),math.abs(a1.Far-a0.Far)*10,math.abs(a1.Radius-a0.Radius))
   if step>2e-3 then joins[#joins+1]=fmt('%s (%.4f)',sh.Name,step)end
  end
 end
 check(#joins==0,tag..': every joined shot carries on without a step ('..table.concat(joins,', ')..')')
 local h=Cam.Hero[rank];local keysOk=true
 for i,k in ipairs(h.Keys)do local beat=tl[k[1]]or rig.Beats[k[1]];if not beat or not near(rig.HeroT[i],beat+k[2],1e-9)then keysOk=false end end
 check(keysOk and near(rig.HeroStart,tl.Climax+h.Start,1e-9)and near(rig.Settle,tl.FloatEnd+Cam.SettleSeconds,1e-9),tag..': the hero shot\'s keys sit on their beats (the hit, Rise / StarIn, FloatEnd, Settle)')
 -- the scan, 240 Hz, from the scene entry to past the settle
 local dt=1/240;local prev;local t=tl.SceneIn-.05
 local hitFrom,hitTo=tl.Climax,tl.Climax+.5
 local snaps={}
 if rank==6 then for _,k in ipairs(L.LockTurns)do if tl.Lock+k<tl.Unlock then snaps[#snaps+1]=tl.Lock+k end end end
 if rank==8 then snaps[1]=tl.CrownOn end
 local function inSnap(x)for _,b in ipairs(snaps)do if x>=b-1e-9 and x<=b+Lim.SnapSeconds+dt then return true end end;return false end
 local st={turn=0,turnAt=0,roll=0,lens=0,lensAt=0,far=0,near=0,jumps={},seen={},dof=nil,minFocus=math.huge}
 local list={}
 while t<rig.Settle+1 do
  local s=sample(rig,t);list[#list+1]=s
  if prev then
   local cut=false;for _,c in ipairs(rig.Cuts)do if prev.T<c and s.T>=c then cut=true end end
   local hit=t>=hitFrom and t<hitTo
   local turned=ang((prev.Target-prev.Eye).Unit,(s.Target-s.Eye).Unit);local moved=(s.Eye-prev.Eye).Magnitude
   if cut then st.seen[#st.seen+1]={T=t,Moved=moved,Turned=turned}
   elseif not hit then
    if black(t,tl)<.8 and turned/dt>st.turn then st.turn,st.turnAt=turned/dt,t end
    if moved>.5 or turned>10 then st.jumps[#st.jumps+1]=fmt('%.3f',t)end
    local lens=math.abs(s.Fov-prev.Fov)/dt
    if not inSnap(t)and lens>st.lens then st.lens,st.lensAt=lens,t end
    if not st.dof and(math.abs(s.Far-prev.Far)>.01 or math.abs(s.Near-prev.Near)>.01 or math.abs(s.Radius-prev.Radius)>.05 or math.abs(s.Focus-prev.Focus)>.3)then st.dof=t end
   end
  end
  st.roll=math.max(st.roll,math.abs(s.Roll));st.far=math.max(st.far,s.Far);st.near=math.max(st.near,s.Near);st.minFocus=math.min(st.minFocus,s.Focus)
  prev=s;t+=dt
 end
 for i,s in ipairs(st.seen)do check(s.Moved>.5 or s.Turned>5,fmt('%s: cut %d is a real cut on its frame (moved %.2f studs, turned %.1f deg)',tag,i,s.Moved,s.Turned))end
 check(#st.seen==#rig.Cuts,fmt('%s: every cut seen in the picture (%d)',tag,#st.seen))
 check(#st.jumps==0,tag..': no jump anywhere else (a jump that is not a cut: '..table.concat(st.jumps,', ')..')')
 check(st.turn<=Lim.Turn,fmt('%s: the fastest visible turn of the view %.1f deg/s (limit %d; cuts, the black and the hit\'s 0.5 s left out) at %.2f s',tag,st.turn,Lim.Turn,st.turnAt))
 check(st.roll<=Lim.Roll,fmt('%s: the biggest dutch tilt %.1f deg (limit %d)',tag,st.roll,Lim.Roll))
 check(st.lens<=Lim.Lens,fmt('%s: the fastest lens ramp %.1f deg/s (limit %d; the snaps on their beats apart) at %.2f s',tag,st.lens,Lim.Lens,st.lensAt))
 -- the orbit around the subject: the yaw of the view over 0.1 s windows (the shudder, a 10 Hz shake, is not an orbit)
 local orbit,orbitAt=0,0;local spin={};local seg=1
 for i=1,#list-24 do
  local a,b=list[i],list[i+24]
  local cut=false;for _,c in ipairs(rig.Cuts)do if a.T<c and b.T>=c then cut=true end end
  if not cut and not(b.T>=hitFrom and a.T<hitTo)and black(a.T,tl)<.8 then
   local o=dyaw(yaw(a.Eye-a.Target),yaw(b.Eye-b.Target))/(b.T-a.T);if o>orbit then orbit,orbitAt=o,a.T end
  end
 end
 for i=2,#list do
  local a,b=list[i-1],list[i]
  local cut=false;for _,c in ipairs(rig.Cuts)do if a.T<c and b.T>=c then cut=true end end
  if cut or(a.T<hitFrom and b.T>=hitFrom)then seg+=1 end
  if not cut then spin[seg]=(spin[seg]or 0)+dyaw(yaw(a.Eye-a.Target),yaw(b.Eye-b.Target))end
 end
 local most=0;for _,v in pairs(spin)do most=math.max(most,v)end
 check(orbit<=Lim.Orbit,fmt('%s: the fastest orbit around the subject %.1f deg/s (limit %d) at %.2f s',tag,orbit,Lim.Orbit,orbitAt))
 check(most<=Lim.Spin,fmt('%s: no spin: the most a shot turns around its subject is %.1f deg (limit %d)',tag,most,Lim.Spin))
 -- lens snaps: only on the lock clicks / the crown, at most Snap degrees each, done in SnapSeconds and held
 for _,b in ipairs(snaps)do
  local a0,a1,a2=sample(rig,b),sample(rig,b+Lim.SnapSeconds),sample(rig,b+Lim.SnapSeconds+.03)
  local d=math.abs(a1.Fov-a0.Fov)
  check(d>1 and d<=Lim.Snap+1e-6 and near(a1.Fov,a2.Fov,.05),fmt('%s: the lens snap on %.2f s is %.2f deg in %.2f s, then held',tag,b,d,Lim.SnapSeconds))
 end
 -- shudder: at most this share of the pack's own shake
 local sh=0;for _,shot in ipairs(Cam.Shots[rank])do sh=math.max(sh,shot.Shudder or 0)end
 check(sh<=Lim.Shudder,fmt('%s: the camera shudders with the pack at most %.0f%% of its shake',tag,sh*100))
 -- the dead stop on the silence, and the skip target (Climax - 0.02) is that very frame
 local a,b,k=sample(rig,tl.Silence+1e-3),sample(rig,tl.Climax-1e-3),sample(rig,tl.Climax-.02)
 check(a.Eye==b.Eye and a.Target==b.Target and a.Fov==b.Fov and a.Roll==b.Roll,tag..': dead stop from the silence to the hit (nothing moves)')
 check(k.Eye==a.Eye and k.Target==a.Target and k.Fov==a.Fov,tag..': a skip (to Climax - 0.02 s) lands on exactly the silence frame')
 -- the depth of field: modest and smooth
 check(st.far<=Cam.Dof.MaxFar+1e-9 and st.near<=Cam.Dof.MaxNear+1e-9 and st.minFocus>.5,fmt('%s: depth of field modest (far at most %.2f, near at most %.2f, focus from %.1f studs)',tag,st.far,st.near,st.minFocus))
 check(st.dof==nil,tag..': the depth of field changes smoothly inside a shot (jumps only on cuts and the hit; first jump at '..tostring(st.dof)..')')
 -- the seed hero: centred, 33-40 % of the height, on three screens, from .3 s after the hit (Cosmic: the star) through a 120 s wait
 for _,asp in ipairs({{'16:9',16/9},{'19.5:9',19.5/9},{'4:3',4/3}})do
  local lo,hi,off=1,0,0;local t2=rank==7 and tl.StarIn or tl.Climax+.3
  while t2<=tl.FloatEnd+120 do
   local s=sample(rig,t2,asp[2]);local seed=L.SeedPose(rank,tl,t2)
   local x,y,z=L.Project(s.Eye,s.Target,s.Fov,asp[2],seed)
   if z then local share=2*L.ProjectedRadius(s.Fov,z,L.SeedHeroSize/2);lo=math.min(lo,share);hi=math.max(hi,share);off=math.max(off,math.abs(x-.5),math.abs(y-.5))else lo=0 end
   t2+=(t2<tl.FloatEnd+2)and 1/60 or .25
  end
  check(lo>=.32 and hi<=.40 and off<=.03,fmt('%s %s: the seed hero %.0f%% .. %.0f%% of the height, off centre at most %.3f, from %s through a 120 s wait',tag,asp[1],lo*100,hi*100,off,rank==7 and'the star'or'the hit'))
 end
 -- the wait: steady (slow, bounded around where the orbit settled, never repeating, never wandering off), the seed's size held
 do
  local seedAt=function(x)return L.SeedPose(rank,tl,x,true)-V3(0,L.SeedHeroSize*L.HeroAim,0)end
  local s0=sample(rig,rig.Settle);local d0=(s0.Eye-seedAt(rig.Settle)).Unit;local r0=(s0.Eye-seedAt(rig.Settle)).Magnitude
  local fast,away,far,size=0,0,0,0;local p=s0;local dirs={}
  local t2=rig.Settle+1/30
  while t2<=tl.FloatEnd+120 do
   local s=sample(rig,t2);local rel=s.Eye-seedAt(t2)
   fast=math.max(fast,ang((p.Target-p.Eye).Unit,(s.Target-s.Eye).Unit)/(1/30))
   away=math.max(away,ang(rel.Unit,d0));far=math.max(far,(s.Eye-s0.Eye).Magnitude);size=math.max(size,math.abs(rel.Magnitude-r0))
   if math.abs((t2-rig.Settle)*2-math.floor((t2-rig.Settle)*2+.5))<1e-6 then dirs[#dirs+1]=rel.Unit end
   p=s;t2+=1/30
  end
  check(fast<=.5,fmt('%s: waiting, the view turns at most %.2f deg/s (a slow idle drift)',tag,fast))
  check(away<=2.5 and far<=.3 and size<1e-6,fmt('%s: waiting, it stays within %.2f deg / %.2f studs of where it settled, the seed\'s size held (over 120 s)',tag,away,far))
  -- (never repeating: for no lag between 5 and 100 s does the path come back onto itself)
  local closest=math.huge
  for lag=10,200 do -- (half seconds)
   local worst=0;for i=7,60 do if dirs[i+lag]then worst=math.max(worst,ang(dirs[i],dirs[i+lag]))end end
   closest=math.min(closest,worst)
  end
  check(closest>=.1,fmt('%s: the idle drift never repeats (the closest it comes back onto itself: %.2f deg)',tag,closest))
 end
 -- the move under the fade in is not on screen; the first frame of the stage is the first shot
 local f0=sample(rig,tl.SceneIn-.05)
 check(f0.Index==1,tag..': the stage opens on its first shot ('..tostring(f0.Name)..')')
end
-- Calm (Reduced Motion): still shots, cut on the Calm beats; no move, no roll, no lens change, a still focus
for rank=6,8 do
 local tl=L.Timeline(rank,'Calm');local rig=Cam.New(rank,'Calm',tl);local tag=names[rank]..' Calm'
 local want={};for i=2,#Cam.Calm[rank]do want[#want+1]=tl[Cam.Calm[rank][i][1]]end;want[#want+1]=tl.Climax
 local same=#want==#rig.Cuts;for i,w in ipairs(want)do if not rig.Cuts[i]or not near(rig.Cuts[i],w,1e-9)then same=false end end
 check(same,tag..': cut ON the Calm beats only ('..#rig.Cuts..' cuts)')
 local moved,rolled,dof=0,0,0;local prev;local t=tl.SceneIn-.05
 while t<tl.FloatEnd+3 do
  local s=sample(rig,t)
  if prev then
   local cut=false;for _,c in ipairs(rig.Cuts)do if prev.T<c and s.T>=c then cut=true end end
   if not cut then
    if s.Eye~=prev.Eye or s.Target~=prev.Target or s.Fov~=prev.Fov then moved+=1 end
    if s.Focus~=prev.Focus or s.Far~=prev.Far or s.Near~=prev.Near or s.Radius~=prev.Radius then dof+=1 end
   end
  end
  if s.Roll~=0 then rolled+=1 end
  prev=s;t+=1/240
 end
 check(moved==0 and rolled==0,fmt('%s: no move, no lens change and no roll inside a still (%d moving frames, %d tilted)',tag,moved,rolled))
 check(dof==0 and prev.Far>0 and prev.Near==0,tag..': a still depth of field (the background soft, no focus pull)')
 local e,g,f=L.Shot(rank,'Calm',tl.Climax+1,tl);local s=sample(rig,tl.Climax+1)
 check(s.Eye==e and s.Target==g and s.Fov==f,tag..': the seed in R151\'s still hero shot (37%)')
end
-- the camera keeps clear of every stage part (no part closer than its near plane: no seam, no inside of a part seen), with the real stages
local function drawAll(ok)
 Art.Reset()
 Art.Hooks.Spawn=function(fn)fn()end;Art.Hooks.Wait=function()end
 Art.Hooks.Create=function(w,h,rgba)if not ok then error('EditableImage unavailable (test)')end;return {W=w,H=h,Destroy=function()end}end
 Art.Hooks.Content=function(o)return'rbxtemp://r155/'..o.W..'x'..o.H end
 Art.Request(Art.Order)
end
local function partDist(p,eye)
 local cf,s=p.CFrame,p.Size;if not cf or not s then return math.huge end
 local l=cf:Inverse()*eye
 if p.Shape and p.Shape.Name=='Ball'then return math.max(0,l.Magnitude-math.min(s.X,s.Y,s.Z)/2)end
 local dx,dy,dz=math.max(0,math.abs(l.X)-s.X/2),math.max(0,math.abs(l.Y)-s.Y/2),math.max(0,math.abs(l.Z)-s.Z/2)
 return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local CLEAR=.7 -- studs: Roblox's near plane is 0.5 in front of the camera
local clearRows={}
for _,withArt in ipairs({true,false})do
 drawAll(withArt)
 for _,variant in ipairs({'Full','Calm'})do for rank=6,8 do for _,lite in ipairs({false,true})do
  local tl=L.Timeline(rank,variant);local rig=Cam.New(rank,variant,tl)
  local sc=Scenes.Build(rank,{Lite=lite,Reduced=variant=='Calm',Pack=M.PackModel(nil,X.byRank[rank]),Seed=M.SeedModel(X.byRank[rank],'None')})
  local worst,at,what=math.huge,0,'-'
  local times={};local t=tl.SceneIn-.05;while t<tl.FloatEnd+3 do times[#times+1]=t;t+=1/30 end;times[#times+1]=tl.FloatEnd+60
  for _,x in ipairs(times)do
   sc:Update(x,tl);local eye=sc.Origin*(Cam.Shot(rig,x,16/9))
   for _,d in ipairs(sc.Folder:GetDescendants())do
    if d:IsA('BasePart')and 1-(1-(d.Transparency or 0))*(1-(d.LocalTransparencyModifier or 0))<.95 then
     local dd=partDist(d,eye);if dd<worst then worst,at,what=dd,x,d.Name end
    end
   end
  end
  sc:Destroy()
  local tag=fmt('%s %s %s %s',names[rank],variant,lite and'lite'or'desktop',withArt and'images'or'plain')
  clearRows[#clearRows+1]=fmt('%s %.2f (%s)',tag,worst,what)
  check(worst>=CLEAR,fmt('%s: the camera keeps %.2f studs from every stage part (closest: %s at %.2f s; at least %.1f)',tag,worst,what,at,CLEAR))
 end end end
end
print('clearance (studs): '..table.concat(clearRows,' | '))
-- 2. the director, frame by frame ----------------------------------------------------------------------------------------------------------
local cam=W.workspace.CurrentCamera;local baseCamera
local Enum=R.Enum
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear();M.Camera=Cam
 cam=W.workspace.CurrentCamera
 cam.CameraType=Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum;cam.ViewportSize=R.Vector2.new(1280,720)
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;X.lowFx=false
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 X.player:SetAttribute('SettingSkipCutscenes',nil)
 R.advance(4)
 baseCamera=X.camera()
end
local function packFor(rank,seedId)
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p'..rank,Stage=2},nil)
 return bag,tool
end
local function start(rank,extra)
 local seedId=X.byRank[rank];local bag,tool=packFor(rank,seedId)
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Tool=tool,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info),bag
end
local function dofs(c)local n=0;for _,d in ipairs((c or cam):GetChildren())do if d:IsA('DepthOfFieldEffect')then n+=1 end end;return n end
local function bound()local n,mine=0,0;for k in pairs(W.rsBound)do n+=1;if k==M.BindName then mine+=1 end end;return n,mine end
local function cfKey(c)local p,r=c.Position,c.R;return fmt('%.9f,%.9f,%.9f|%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f',p.X,p.Y,p.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3])end
local function cfNear(a,b,tol)
 if(a.Position-b.Position).Magnitude>tol then return false end
 for i=1,3 do for j=1,3 do if math.abs(a.R[i][j]-b.R[i][j])>tol then return false end end end
 return true
end
local function settle()
 M.Collect();local g=0;while(M.Active()or Collect.Flying()>0)and g<1500 do X.run(1/60,1/60);g+=1;M.Collect()end
end
local function restored(tag,c)
 c=c or cam
 local now=X.camera()
 check(now.Type==baseCamera.Type and now.CFrame==baseCamera.CFrame and now.Fov==baseCamera.Fov and now.Focus==baseCamera.Focus and now.Subject==baseCamera.Subject,tag..': the camera is restored exactly (type, CFrame, focus, FieldOfView, subject)')
 check(dofs(c)==0 and c:FindFirstChild('RarePullDof')==nil,tag..': the depth of field is gone')
 local _,mine=bound();check(mine==0 and W.actions[M.SkipAction]==nil,tag..': no render binding left')
end
-- plays one story scene frame by frame; returns the frames {T, CF, Key, Fov, Focus, Type, Dof, Dofs, InStage, Index, Name, Bound}
local function play(rank,dt,opts)
 opts=opts or{}
 local run,bag=start(rank,opts.Extra)
 local frames={}
 local function snap()
  local c=W.workspace.CurrentCamera;local d=c:FindFirstChild('RarePullDof')
  local n,mine=bound()
  frames[#frames+1]={T=run.Clock(),CF=c.CFrame,Key=cfKey(c.CFrame),Fov=c.FieldOfView,Focus=c.Focus and c.Focus.Position,Type=c.CameraType,
   Dof=d and{F=d.FocusDistance,R=d.InFocusRadius,Far=d.FarIntensity,Near=d.NearIntensity,Parent=d.Parent}or nil,Dofs=dofs(c),InStage=run.InStage==true,
   Index=run.Cam and run.Cam.Index,Name=run.Cam and run.Cam.Name,Hero=run.Cam and run.Cam.Hero,Bound=n,Mine=mine,Cam=run.Cam and{Focus=run.Cam.Focus,Radius=run.Cam.Radius,Far=run.Cam.Far,Near=run.Cam.Near}}
 end
 if opts.Record then Y.record(function()return run.Clock()end);Y.frames[1]={Clock=R.clock,T=run.Clock(),Voices={}}end
 local until_=opts.Until or(run.TL.Length+.4)
 local g=0
 while not run.Done and run.Clock()<until_ and g<200000 do X.run(dt,dt);snap();g+=1;if opts.Each then opts.Each(run,frames[#frames])end end
 return run,frames,bag
end
-- (the first frame at or after t)
-- (the same comparison the reveal makes: t >= beat, no tolerance: a beat on a frame's float edge is judged as the code judges it)
local function at(frames,t)for i,f in ipairs(frames)do if f.T>=t then return f,i end end;return nil end
for _,dt in ipairs({1/30,1/60,1/144})do
 for rank=6,8 do
  local fps=math.floor(1/dt+.5);local tag=fmt('%s Full @%dfps',names[rank],fps)
  -- today's camera: the same scene with the cinematic camera switched off (M.Camera = nil: RarePullRules.Shot, no depth of field)
  reset();M.Camera=nil
  local runT,today=play(rank,dt);settle();restored(tag..' (today)')
  reset();E.resetPlays()
  local run,frames,bag=play(rank,dt,{Record=true})
  local tl=run.TL;local rig=run.Cam
  check(run.Kind=='Scene'and run.Variant=='Full'and rig~=nil and rig.Rank==rank and not rig.Calm,tag..': the full scene runs the cinematic camera')
  -- before the stage: today's camera (the lens-only push; the player's own CFrame never moved)
  local pre,preSame,preFov=0,true,true
  for i,f in ipairs(frames)do
   if f.T<tl.SceneIn-.05-1e-9 then
    pre+=1
    local t0=today[i]
    if not t0 or not near(t0.T,f.T,1e-9)or not cfNear(t0.CF,f.CF,1e-9)or not near(t0.Fov,f.Fov,1e-9)or t0.Type~=f.Type or f.Dofs~=0 then preSame=false end
    if f.Key~=cfKey(CF(3,9,112))or not near(f.Fov,70-L.Tier(rank).Push*L.Smooth(f.T/tl.Cut),1e-9)then preFov=false end
   end
  end
  check(pre>0 and preSame,fmt('%s: before the stage (%d frames) the camera is today\'s, frame for frame: no world opening move, no depth of field',tag,pre))
  check(preFov,tag..': it is the player\'s own camera with today\'s lens-only push (FieldOfView 70 - '..L.Tier(rank).Push..' x smooth(t / Cut))')
  -- in the stage: the rig (+ the R152 hit shake), its depth of field on the Camera
  local stageN,match,dofOk,first=0,true,true,nil
  for _,f in ipairs(frames)do
   if f.InStage then
    stageN+=1;first=first or f
    local e,g,fov,roll=Cam.Shot(rig,f.T,1280/720)
    local origin=CF(L.StageOrigin.X,L.StageOrigin.Y,L.StageOrigin.Z)
    local want=origin*R.CFrame.lookAt(e,g)
    if roll~=0 then want=want*R.CFrame.Angles(0,0,-math.rad(roll))end
    local shaking=f.T>=tl.Climax and f.T<tl.Climax+.5
    if not shaking and(not cfNear(want,f.CF,1e-6)or not near(fov,f.Fov,1e-9))then match=false end
    if shaking and(want.Position-f.CF.Position).Magnitude>.2 then match=false end
    local d=f.Dof
    if f.Dofs~=1 or not d or d.Parent~=cam or not near(d.F,f.Cam.Focus,1e-9)or not near(d.R,f.Cam.Radius,1e-9)or not near(d.Far,f.Cam.Far,1e-9)or not near(d.Near,f.Cam.Near,1e-9)then dofOk=false end
   elseif f.Dofs~=0 then dofOk=false end
  end
  check(stageN>0 and match,fmt('%s: in the stage (%d frames) the camera is the cinematic camera\'s shot (the hit\'s shake on top)',tag,stageN))
  check(dofOk,tag..': RarePullDof on the Camera exactly while in the stage, with the shot\'s focus (one, updated every frame)')
  check(first and near(first.T,tl.SceneIn-.05,dt+1e-9)and first.Dof~=nil,tag..': the depth of field is made on entering the stage')
  local fb,fm=frames[#frames].Bound,frames[#frames].Mine
  local one=true;for _,f in ipairs(frames)do if f.Mine~=1 or f.Bound~=fb then one=false end end
  check(one and fm==1,tag..': one render binding while the scene runs (no other per-frame step)')
  -- every cut on the first frame of its beat, its sound heard within 0.01 s of that frame
  local Yf=Y.stop();local plays=Y.plays(R.clock-200)
  local function tOf(clock)for _,f in ipairs(Yf)do if math.abs(f.Clock-clock)<1e-9 then return f.T end end;return nil end
  for i,w in ipairs(EXPECT[rank](tl))do
   local f,k=at(frames,w[1]);local p=k and frames[k-1]
   local isCut=f and p and f.Index~=p.Index and(f.Index or 0)>1 and not Cam.Shots[rank][f.Index].Join
   check(isCut and f.T>=w[1]and p.T<w[1],fmt('%s: cut %d on the first frame of its beat (%.3f s: frame %.4f)',tag,i,w[1],f and f.T or -1))
   local moved=f and p and((f.CF.Position-p.CF.Position).Magnitude>.3 or ang(f.CF.LookVector,p.CF.LookVector)>5)
   check(moved,tag..': and the picture really cuts there')
   -- its sound
   local heard
   for _,pl in ipairs(plays)do
    if pl.Slot==w[2]and pl.Sound.Name:match('_1b?$')then
     local tp=tOf(pl.At)
     if tp then
      local l=Audio.Layers(w[2])[1];local def=Sounds.Get(w[2])
      if w[2]=='Flight'then
       if l.Swell then local sw=tp+(l.Swell-pl.Pos)/pl.Speed;if math.abs(sw-w[1])<.05 then heard=sw end end
      elseif f and math.abs(tp-f.T)<1e-9 then
       local owner=l.Owner and def and def.Id==pl.Id
       heard=tp+(((owner and l.Hit)or pl.Pos)-pl.Pos)/pl.Speed
      end
     end
    end
   end
   if w[2]=='Flight'then
    check(heard and math.abs(heard-w[1])<=.0101,fmt('%s: the carry whoosh swells on the cut\'s beat (%.4f s vs %.4f s)',tag,heard or -1,w[1]))
   else
    check(heard and f and math.abs(heard-f.T)<=.0101,fmt('%s: %s is heard within 0.01 s of the cut\'s frame (%+.4f s)',tag,w[2],heard and f and heard-f.T or -1))
   end
  end
  -- the result waits on the hero shot; a press collects it: the way out (its fade), then the world exactly as today
  check(M.Active()==run and M.Waiting()and run.InStage,tag..': the result waits on the hero shot')
  local pressT=run.Clock()
  local button=X.find(X.pg,'Backdrop');if button then button.Activated:Fire()end
  local exitAt,dofGone
  local g=0
  while(M.Active()or Collect.Flying()>0)and g<3000 do
   X.run(dt,dt);g+=1
   if not exitAt and cam.CameraType~=Enum.CameraType.Scriptable then exitAt=R.clock;dofGone=dofs(cam)==0
    local now=X.camera();check(now.CFrame==baseCamera.CFrame and now.Fov==baseCamera.Fov and now.Focus==baseCamera.Focus,tag..': the frame it leaves the stage the camera is the player\'s own again (no hand-back move)')
   end
   if exitAt and cam.CameraType~=Enum.CameraType.Scriptable and(X.camera().CFrame~=baseCamera.CFrame or cam.FieldOfView~=70)then check(false,tag..': after the stage the camera is never moved again');break end
  end
  check(run.Collected and run.Done and exitAt~=nil and dofGone,tag..': collected: the way out, the world, the depth of field gone')
  restored(tag)
  bag:Destroy()
 end
end
-- every device: the depth of field on desktop, phone and low quality (owner: "background blur on all devices"); Reduced Motion: still shots
local devices={{'phone',function()W.UIS.TouchEnabled=true;W.UIS.KeyboardEnabled=false;cam.ViewportSize=R.Vector2.new(844,390)end},
 {'low quality',function()X.lowFx=true end},{'desktop',function()end}}
for _,d in ipairs(devices)do for rank=6,8 do
 reset();d[2]()
 local run,frames,bag=play(rank,1/60)
 local tag=fmt('%s %s',names[rank],d[1])
 check(d[1]=='desktop'or run.Lite,tag..': the light version (Lite)')
 local inStage,withDof=0,0;for _,f in ipairs(frames)do if f.InStage then inStage+=1;if f.Dofs==1 and f.Dof and f.Dof.Far>=0 then withDof+=1 end end end
 check(inStage>0 and withDof==inStage,fmt('%s: the depth of field on every stage frame (%d of %d)',tag,withDof,inStage))
 settle();restored(tag);bag:Destroy()
end end
for rank=6,8 do
 reset();W.Gui.ReducedMotionEnabled=true
 local run,frames,bag=play(rank,1/60)
 local tl=run.TL;local tag=names[rank]..' Reduced Motion'
 check(run.Variant=='Calm'and run.Cam and run.Cam.Calm,tag..': the Calm scene with the still shots')
 local moved,tilted,dofN,stageN,shook=0,0,0,0,false
 local cuts=run.Cam.Cuts
 for i=2,#frames do
  local a,b=frames[i-1],frames[i]
  if a.InStage and b.InStage then
   stageN+=1
   local cut=false;for _,c in ipairs(cuts)do if a.T<c and b.T>=c then cut=true end end
   if not cut and(a.Key~=b.Key or a.Fov~=b.Fov)then moved+=1 end
   if math.abs(b.CF.RightVector.Y)>1e-9 then tilted+=1 end
   if b.Dofs==1 then dofN+=1 end
   if b.T>=tl.Climax and b.T<tl.Climax+.5 and a.T>=tl.Climax and a.Key~=b.Key then shook=true end
  end
 end
 check(moved==0 and tilted==0 and not shook,fmt('%s: still shots: no move, no roll, no shake (%d moving frames, %d tilted)',tag,moved,tilted))
 check(stageN>0 and dofN==stageN,tag..': the depth of field still on (a still focus)')
 settle();restored(tag);bag:Destroy()
end
-- the long wait: 120 s on the hero shot, then the collect from it
for rank=6,8 do
 reset()
 local run,frames,bag=play(rank,1/30,{Until=L.Timeline(rank,'Full').FloatEnd+120})
 local tl=run.TL;local tag=names[rank]..' 120 s wait'
 local fast,spread,ok=0,0,true;local ref
 for i=2,#frames do
  local a,b=frames[i-1],frames[i]
  if a.T>=run.Cam.Settle then
   ref=ref or a
   fast=math.max(fast,ang(a.CF.LookVector,b.CF.LookVector)/(b.T-a.T));spread=math.max(spread,(b.CF.Position-ref.CF.Position).Magnitude)
   if not b.InStage or b.Dofs~=1 then ok=false end
  end
 end
 check(M.Waiting()and ok,tag..': still waiting on the hero shot after 120 s, its depth of field on')
 check(fast<=.5 and spread<=.3,fmt('%s: steady: the view turns at most %.2f deg/s, the camera stays within %.2f studs',tag,fast,spread))
 X.find(X.pg,'Backdrop').Activated:Fire()
 local t0=R.clock;local back
 local g=0;while(M.Active()or Collect.Flying()>0)and g<3000 do X.run(1/30,1/30);g+=1;if not back and cam.CameraType~=Enum.CameraType.Scriptable then back=R.clock-t0 end end
 check(back and near(back,M.SceneExit,1/30+1e-6),fmt('%s: the collect: the fade to black (%.2f s), then the world',tag,back or -1))
 restored(tag);bag:Destroy()
end
-- every exit path: the camera restored, the depth of field gone
local function mid(rank,how,tag,result)
 reset()
 local run,bag=start(rank);X.run(run.TL.SceneIn+.6,1/60)
 check(run.InStage and cam:FindFirstChild('RarePullDof')~=nil,tag..': (in the stage, with its depth of field)')
 local c0=cam
 how(run)
 X.run(.3,1/60)
 local active=M.Active()
 if result then check(active and active.Kind=='Result',tag..': the result card follows')end
 check(dofs(c0)==0,tag..': the depth of field is gone at once')
 settle();restored(tag,c0)
 if bag then bag:Destroy()end
end
mid(6,function()M.Abort('test')end,'abort')
mid(7,function()X.hum.Died:Fire()end,'death')
mid(8,function()X.player.CharacterRemoving:Fire(X.char)end,'character removed')
mid(6,function()X.root.CFrame=CF(0,3,140)end,'moved / teleported',true)
mid(7,function()X.keeper(V3(10,3,170),{TargetUserId=7,GuardianBehavior='CHASING'})end,'a keeper starts chasing',true)
mid(8,function(run)run.Scene.Update=function()error('boom')end end,'an error in the stage',true)
do local holder=R.new('LocalScript');holder.Name='PackOpeningFeedback';M.Bind(holder)
 mid(6,function()holder.Destroying:Fire()end,'the script destroyed')end
do -- a replaced camera: the old one loses its depth of field, the new one is left alone
 reset();local run,bag=start(7);X.run(run.TL.SceneIn+.5,1/60)
 local old=W.workspace.CurrentCamera;check(old:FindFirstChild('RarePullDof')~=nil,'replaced camera: (in the stage)')
 local new=R.new('Camera');new.CameraType=Enum.CameraType.Custom;new.FieldOfView=70;new.CFrame=CF(1,2,3);new.Parent=W.workspace
 W.workspace.CurrentCamera=new;X.run(.2,1/60)
 check(dofs(old)==0 and dofs(new)==0 and new.CFrame.Position==V3(1,2,3)and new.FieldOfView==70,'replaced camera: no depth of field left on either, the new camera untouched')
 settle();W.workspace.CurrentCamera=old;old.CameraType=Enum.CameraType.Custom;new:Destroy();bag:Destroy()
end
do -- the camera module failing: one bad frame shows today's framing for that frame; three in a row and the scene goes on with today's camera
 reset();local run,bag=start(8);X.run(run.TL.SceneIn+.6,1/60)
 local real=Cam.Shot;local n=0
 Cam.Shot=function(...)n+=1;if n<=1 then error('camera boom (test)')end;return real(...)end
 X.run(1/60,1/60);X.run(1/60,1/60)
 check(run.InStage and cam:FindFirstChild('RarePullDof')~=nil and run.CamErrors==nil,'camera error once: the scene goes on with the cinematic camera')
 Cam.Shot=function()error('camera boom (test)')end
 X.run(.1,1/60)
 local e,g,f=L.Shot(8,'Full',run.Clock(),run.TL)
 local want=CF(L.StageOrigin.X,L.StageOrigin.Y,L.StageOrigin.Z)*R.CFrame.lookAt(e,g)
 check(run.InStage and not run.Done and cam:FindFirstChild('RarePullDof')==nil and(want.Position-cam.CFrame.Position).Magnitude<.25 and near(cam.FieldOfView,f,1e-9),'camera failing: the scene goes on with today\'s camera, its depth of field removed')
 Cam.Shot=real
 settle();restored('camera failing');bag:Destroy()
end
-- a skip at every phase (R153: the first press jumps to the hit, the next collects): it lands on the silence frame, then everything goes home
for rank=6,8 do
 local tl=L.Timeline(rank,'Full')
 for _,when in ipairs({.3,tl.SkipFrom-.05,tl.SkipFrom+.01,(tl.SkipFrom+tl.Silence)/2,tl.Silence-.04,tl.Silence+.03,tl.Climax+.1,L.ShownAt(tl)+.1,L.ShownAt(tl)+.4,tl.FloatEnd+.5,tl.Length+5})do
  reset()
  local run,bag=start(rank);X.run(when,1/60)
  local tag=fmt('%s skip at %.2f s',names[rank],run.Clock())
  local t=run.Clock();local did=M.Skip()
  if t<tl.SkipFrom then check(not did,tag..': too early, nothing happens')
  elseif t<tl.Climax-.02 then
   check(did and near(run.Clock(),tl.Climax-.02,1e-6),tag..': it jumps to the hit')
   X.run(1/60,1/60)
   local s=sample(run.Cam,tl.Silence+1e-3);local e=CF(L.StageOrigin.X,L.StageOrigin.Y,L.StageOrigin.Z)*R.CFrame.lookAt(s.Eye,s.Target)
   check(run.Clock()<tl.Climax or(cam.CFrame.Position-e.Position).Magnitude<.6,tag..': the next frame is the silence frame / the hit')
   X.run(L.ShownAt(tl)+M.CollectAfter+.05-run.Clock(),1/60)
   check(M.Skip()and run.Collected,tag..': the next press collects it')
  elseif t<L.ShownAt(tl)+M.CollectAfter then check(not did,tag..': the result is on its way: nothing yet')
  else check(did and run.Collected,tag..': the press collects it')end
  settle();restored(tag);bag:Destroy()
 end
end
-- "Skip pack animations": the result card in place for Secret / Cosmic / King: no camera at all
for rank=6,8 do
 reset();X.player:SetAttribute('SettingSkipCutscenes',true)
 local run,frames,bag=play(rank,1/60,{Until=L.Timeline(rank,'InPlace').Length+.5})
 local tag=names[rank]..' "Skip pack animations"'
 local touched=false;for _,f in ipairs(frames)do if f.Type~=Enum.CameraType.Custom or f.Key~=cfKey(CF(3,9,112))or f.Fov~=70 or f.Dofs~=0 or f.InStage then touched=true end end
 check(run.Kind=='InPlace'and run.Cam==nil and not touched,tag..': the in-place card; the camera never touched, no depth of field')
 settle();restored(tag);X.player:SetAttribute('SettingSkipCutscenes',nil);bag:Destroy()
end
-- Common..Mythic: the camera module is never used; their camera is today's (the Legendary / Mythic push), frame for frame
do
 local calls=0;local realNew,realShot=Cam.New,Cam.Shot
 Cam.New=function(...)calls+=1;return realNew(...)end;Cam.Shot=function(...)calls+=1;return realShot(...)end
 for rank=1,5 do
  reset();M.Camera=nil;local _,today=play(rank,1/60,{Until=L.CardTimeline(rank).Length+.5});settle()
  reset();local run,frames,bag=play(rank,1/60,{Until=L.CardTimeline(rank).Length+.5})
  local same=#frames==#today
  for i,f in ipairs(frames)do local t0=today[i];if not t0 or not cfNear(t0.CF,f.CF,1e-12)or not near(t0.Fov,f.Fov,1e-9)or t0.Type~=f.Type or f.Dofs~=0 then same=false end end
  check(run.Kind=='Ladder'and same,names[rank]..': the card\'s camera is today\'s, frame for frame (no depth of field)')
  settle();restored(names[rank]);bag:Destroy()
 end
 Cam.New,Cam.Shot=realNew,realShot
 check(calls==0,'Common..Mythic never call the cinematic camera ('..calls..' calls)')
end

-- 3. the SKIP button (R155, owner: "for some cutscenes u can skip it by spam clicking disable this feature and u can only skip at the bottom right
-- of the screen") -----------------------------------------------------------------------------------------------------------------------------
local Card=W.module('RarePullCard');local Hud=W.module('HudLayout')
do -- where it goes: the bottom right of the safe area, clear of every HUD box (the hotbar and its details, the status / timer stack, the
 -- balances, a phone's thumb controls) by 8 px and of the screen's edge by 12 px; a thumb-sized target on a touch screen
 local screens={{1280,720,false,'desktop 1280x720'},{1920,1080,false,'desktop 1920x1080'},{1366,768,false,'laptop 1366x768'},{1024,600,false,'small window 1024x600'},
  {800,450,false,'narrow window 800x450'},{844,390,true,'phone 844x390'},{667,375,true,'phone 667x375'},{932,430,true,'phone 932x430'},
  {1024,768,true,'tablet 1024x768'},{1180,820,true,'tablet 1180x820'},{390,844,true,'phone portrait 390x844'}}
 for _,s in ipairs(screens)do
  local w,h,touch=s[1],s[2],s[3];local tag='SKIP button on a '..s[4]
  local boxes=Hud.HudBoxes(Hud.Read(R.Vector2.new(w,h),touch,nil),w,h,false)
  local x,y,bw,bh=Card.SkipRect(w,h,touch,boxes)
  local hits={};for _,b in ipairs(boxes)do if x<b.X+b.W+8 and x+bw>b.X-8 and y<b.Y+b.H+8 and y+bh>b.Y-8 then hits[#hits+1]=b.N end end
  local names_={};for _,b in ipairs(boxes)do names_[#names_+1]=b.N end
  check(x>=12 and y>=12 and x+bw<=w-12 and y+bh<=h-12,fmt('%s: on screen, 12 px from its edges (%d,%d %dx%d)',tag,x,y,bw,bh))
  check(#hits==0,fmt('%s: clear of every HUD box by 8 px (%s)%s',tag,table.concat(names_,' '),#hits>0 and' - overlaps '..table.concat(hits,' ')or''))
  check(x+bw/2>=w*.5 and y>=h*.45 and w-(x+bw)<=w*.35,fmt('%s: at the bottom right (right edge %d px from the screen\'s, top at %.0f %% of the height)',tag,w-(x+bw),100*y/h))
  check(bh>=(touch and 40 or 34)and bh<=48 and near(bw/bh,2.75,.05),fmt('%s: %d px high (at least %d: %s), a pill %.2f x its height',tag,bh,touch and 40 or 34,touch and'a thumb\'s target'or'a pointer\'s',bw/bh))
 end
end
do -- the real button, frame by frame at 60 fps: a card and a story scene, on a desktop and on a phone with a notch (its safe area), a gamepad on
 -- (and on screens the mock's GuiService:GetInsetArea - always 1280 x 720 - overstates: the button keeps to the screen itself)
 local Gui=W.Gui;local origInset=Gui.GetInsetArea
 for _,c in ipairs({{4,1280,720,false},{7,1280,720,false},{3,844,390,true,true},{8,844,390,true,true},{5,768,432,false},{6,844,390,true}})do
  reset()
  local w,h=c[2],c[3];cam.ViewportSize=R.Vector2.new(w,h);W.UIS.TouchEnabled=c[4];W.UIS.KeyboardEnabled=not c[4];W.UIS.GamepadEnabled=true
  local area={X=0,Y=0,W=w,H=h}
  if c[5]then area={X=48,Y=0,W=w-96,H=h-21};Gui.GetInsetArea=function()return{Min=R.Vector2.new(area.X,area.Y),Width=area.W,Height=area.H}end end
  local run,bag=start(c[1]);local tl=run.TL;local hit=tl.Climax or tl.Burst
  local tag=fmt('the SKIP button, %s %s on %dx%d%s',names[c[1]],run.Kind,w,h,c[5]and' (a notch: its safe area)'or(w~=1280 and' (a safe area reported bigger than the screen)'or''))
  local function gui()return X.pg:FindFirstChild('RarePullReveal')end
  local early,shown,inside,badge,above,presses,box=false,0,true,true,true,0,nil
  local g=0
  while not run.Done and run.Clock()<math.min(tl.SkipFrom+.5,hit-.1)and g<3000 do
   -- a burst of clicks on the world every frame (a story scene: on its full-screen button too)
   W.UIS.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,KeyCode=Enum.KeyCode.Unknown,Position=V3(400,300,0)},false)
   local bd=X.find(gui(),'Backdrop');if bd then bd.Activated:Fire()end
   presses+=1;X.run(1/60,1/60);g+=1
   local b=X.find(gui(),'Skip button');local t=run.Clock()
   if b and b.Visible then
    if t<tl.SkipFrom then early=true end
    shown+=1
    local p,s=b.Position,b.Size;box={p.X.Offset,p.Y.Offset,s.X.Offset,s.Y.Offset}
    if box[1]<area.X+12 or box[2]<area.Y+12 or box[1]+box[3]>area.X+area.W-12 or box[2]+box[4]>area.Y+area.H-12 or box[1]+box[3]/2<area.X+area.W/2 then inside=false end
    local pad=b:FindFirstChild('Gamepad B');if not(pad and pad.Visible)then badge=false end
    if b.Parent~=gui()or(bd and not(b.ZIndex>bd.ZIndex))then above=false end
   end
  end
  check(not early and shown>0,tag..': it shows from SkipFrom ('..fmt('%.2f',tl.SkipFrom)..' s), not before')
  check(not run.Skipped and run.Clock()>tl.SkipFrom+.3,tag..': '..presses..' spam clicks (one a frame from the first frame) never skip')
  check(inside,tag..': inside the safe area, at its bottom right ('..(box and fmt('%d,%d %dx%d',box[1],box[2],box[3],box[4])or'-')..')')
  check(badge,tag..': with a gamepad its B badge shows (B / R2 press it)')
  check(above,tag..': on the reveal\'s screen'..(run.Kind=='Scene'and', above the story scene\'s full-screen button'or''))
  local b=X.find(gui(),'Skip button');b.Activated:Fire()
  check(run.Skipped==1 and near(run.Clock(),hit-.02,.03),tag..': pressed: straight to the hit ('..fmt('%.2f',run.Clock())..', the hit '..fmt('%.2f',hit)..')')
  local gone=true;local t0=run.Clock()
  while not run.Done and run.Clock()<L.ShownAt(tl)+.5 and g<6000 do X.run(1/60,1/60);g+=1;if run.Clock()>hit+.12 and b.Visible then gone=false end end
  check(gone and run.SawResult,tag..': it is gone once the hit has played; the result is up')
  settle();restored(tag);bag:Destroy()
  Gui.GetInsetArea=origInset;W.UIS.GamepadEnabled=false
 end
end
-- 3b. Shift Lock and first person (R155 review): the mouse is locked to the middle of the screen there, so nothing on it could be clicked and the pill was dead for those
-- players. The SKIP button is MODAL for exactly as long as it shows (Roblox frees the mouse for a visible modal button); a keyboard's pill carries its Enter key (the gamepad's
-- its B); the card makes nothing and asks no service for it on a frame; the pity bars (PityBars155, above the hotbar) are never under it.
do
 local UIS=W.UIS
 local function gui()return X.pg:FindFirstChild('RarePullReveal')end
 local function modalButtons() -- the visible modal buttons on the player's screens: each one frees the mouse
  local n=0;for _,d in ipairs(X.pg:GetDescendants())do if d:IsA('GuiButton')and d.Modal==true and d.Visible then n+=1 end end;return n
 end
 local Bars=W.module('PityBars155');local HudL=W.module('HudLayout')
 local inputs={{'keyboard',{Keyboard=true}},{'gamepad',{Gamepad=true}},{'keyboard and gamepad',{Keyboard=true,Gamepad=true}},{'touch',{Touch=true}}}
 for _,c in ipairs({{4,'Legendary card'},{7,'Cosmic scene'}})do for _,inp in ipairs(inputs)do
  reset();UIS.TouchEnabled=inp[2].Touch==true;UIS.KeyboardEnabled=inp[2].Keyboard==true;UIS.GamepadEnabled=inp[2].Gamepad==true
  local run,bag=start(c[1]);local tl=run.TL;local hit=tl.Climax or tl.Burst
  local tag=fmt('the SKIP button, %s, %s',c[2],inp[1])
  local shown,early,wrong,keyN,padN,both,maxModal,keyText,overBars=0,0,0,0,0,0,0,nil,0
  local g=0
  while not run.Done and run.Clock()<hit-.15 and g<4000 do
   X.run(1/60,1/60);g+=1
   local b=X.find(gui(),'Skip button')
   if b then
    local key,pad=b:FindFirstChild('Enter key'),b:FindFirstChild('Gamepad B')
    if b.Visible~=(b.Modal==true)then wrong+=1 end
    if b.Visible then
     shown+=1;if run.Clock()<tl.SkipFrom then early+=1 end
     local k=key and key.Visible;local p=pad and pad.Visible
     if k then keyN+=1;local l=key:FindFirstChild('Enter');keyText=l and l.Text end
     if p then padN+=1 end
     if k and p then both+=1 end
     -- the real pill against the bars' extent (the same screen, the same HUD metrics)
     local view=cam.ViewportSize;local m=HudL.Read(view,UIS.TouchEnabled,nil);local ext=Bars.Reserved(view.X,view.Y,m,nil)
     local pos,size=b.Position,b.Size
     if pos.X.Offset<ext.X+ext.W and pos.X.Offset+size.X.Offset>ext.X and pos.Y.Offset<ext.Y+ext.H and pos.Y.Offset+size.Y.Offset>ext.Y then overBars+=1 end
    end
   end
   maxModal=math.max(maxModal,modalButtons())
  end
  check(shown>0 and wrong==0 and early==0,fmt('%s: modal exactly while it shows (%d frames visible, %d frames where Modal and Visible disagree, %d before SkipFrom)',tag,shown,wrong,early))
  check(maxModal<=1,tag..': at most one modal button at a time ('..maxModal..')')
  if inp[2].Gamepad then check(padN==shown and keyN==0,fmt('%s: the gamepad\'s B shows, not the Enter key (%d / %d frames)',tag,padN,shown))
  elseif inp[2].Keyboard then check(keyN==shown and padN==0 and keyText=='Enter',fmt('%s: the Enter key shows on the pill ("%s", %d / %d frames), not the B',tag,tostring(keyText),keyN,shown))
  else check(keyN==0 and padN==0,tag..': a touch screen shows neither key') end
  check(both==0,tag..': never both badges')
  check(overBars==0,tag..': never over the pity bars ('..overBars..' frames)')
  settle();bag:Destroy()
  check(modalButtons()==0,tag..': when the opening is over no modal button is left (the mouse lock is back)')
 end end
 -- every way out hands the mouse back (the button hidden, or destroyed): while it was showing and pressed, aborted, the player dying, the next pack replacing it, the script going
 local exits={
  {'pressed, then collected',function(run)X.find(gui(),'Skip button').Activated:Fire();X.run(.8,1/60);M.Collect();X.run(.2,1/60)end},
  {'aborted',function()M.Abort('test')end},
  {'the player died',function()X.hum.Died:Fire()end},
  {'the character removed',function()X.player.CharacterRemoving:Fire(X.char)end},
  {'the next pack replacing it',function()local _,b2=start(5);X.run(.1,1/60)end},
  {'left to run out and collected',function(run)X.run(run.TL.Length+.5,1/60)end},
 }
 for _,c in ipairs({{4,'Legendary card'},{7,'Cosmic scene'}})do for _,e in ipairs(exits)do
  reset();UIS.TouchEnabled=false;UIS.KeyboardEnabled=true;UIS.GamepadEnabled=false
  local run,bag=start(c[1]);X.run(run.TL.SkipFrom+.3,1/60)
  local tag=fmt('the SKIP button, %s, %s',c[2],e[1])
  check(modalButtons()==1,tag..': (up and modal: one visible modal button)')
  e[2](run);X.run(.4,1/60)
  local pills=0;for _,d in ipairs(X.pg:GetDescendants())do if d.Name=='Skip button'and d.Visible then pills+=1 end end
  -- (a card goes on after the player dies and a story scene goes on while the next pack is being opened: the pill, and the free mouse, with it)
  check(modalButtons()==pills and(M.Active()or pills==0),tag..fmt(': the mouse is free exactly while a pill shows (%d pills, %d modal, the opening %s)',pills,modalButtons(),M.Active()and'goes on'or'is over'))
  settle();X.run(.6,1/60)
  check(modalButtons()==0,tag..': ... and none left when it is all over ('..modalButtons()..')')
  bag:Destroy()
 end end
 reset()
 -- the card makes nothing per frame for the pill: no UDim2, no service lookup (a probe card driven by hand, the keyboard on)
 UIS.KeyboardEnabled=true;UIS.GamepadEnabled=false
 local probe=R.new('ScreenGui');probe.Name='SkipProbe';probe.Parent=X.pg
 local card=Card.Create(probe,'Ladder',{Rank=4,Skip=true,SeedName='Probe',Odds='1 in 100'})
 local ptl={SkipFrom=.3,Burst=6}
 card:_skip(2,ptl);card:_skip(2.01,ptl)
 local udim,svc=0,0
 local saved={};for _,k in ipairs({'fromOffset','new','fromScale'})do local f=R.UDim2[k];saved[k]=f;R.UDim2[k]=function(...)udim+=1;return f(...)end end
 local gs=W.game.GetService;W.game.GetService=function(self,n)svc+=1;return gs(self,n)end
 for i=1,120 do card:_skip(2+i/60,ptl)end
 W.game.GetService=gs;for k,f in pairs(saved)do R.UDim2[k]=f end
 check(udim==0 and svc==0,fmt('the pill on a steady frame: 120 frames, %d UDim2 made, %d service lookups',udim,svc))
 local kb=probe:FindFirstChild('Skip button',true)
 check(kb and kb.Visible and kb.Modal==true and kb:FindFirstChild('Enter key').Visible,'... (the probe pill is up, modal, with its Enter key)')
 card:_skip(0,ptl);check(not kb.Visible and kb.Modal==false,'a card before SkipFrom: hidden, not modal')
 card:_skip(2,ptl);card:Destroy();check(not probe:FindFirstChild('Skip button',true),'Destroy takes the pill with it')
 probe:Destroy()
end
reset()
print(('R155 camera checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
