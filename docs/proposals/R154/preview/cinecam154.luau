--!nocheck
-- R154 PROPOSAL (preview only; nothing in src/ uses this): the cinematic camera for the Secret / Cosmic / King story scenes, written in the
-- shape a later `RarePullCamera` module would take. It ADDS camera moves on top of the existing R151 / R152 / R153 scenes: same stages, same
-- beats, same sounds, same clock. Everything here is a pure function of the scene's clock t and its timeline tl (RarePullRules.Timeline):
-- no springs, no state, so a skip (the clock jumps) lands on exactly the designed frame, and 30 / 60 / 144 fps give the same picture.
-- Usage (preview): local Cam=require('./cinecam154')(R, Rules); local s=Cam.Shot(rank, variant, t, tl, ctx)
--   ctx = {Origin = the stage CFrame, Live = the player's own camera CFrame, LiveFov, Head = the head position, Reduced, Aspect}
--   -> s = {World = true for the world phases (before the cut, the hand-back), Eye, Target, Fov, Roll (degrees), Dof = {Focus, Radius, Far,
--          Near} (Roblox DepthOfFieldEffect values) or nil, Name = the shot's name, Move = what the camera does}
-- See docs/proposals/R154/cinematic_camera.md for the shot lists in words.
return function(R,L)
 local V=R.Vector3.new
 local Y=V(0,1,0)
 local function clamp01(x)return math.clamp(x,0,1)end
 local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
 local EASE={
  linear=function(u)return clamp01(u)end,
  inout=smooth,
  ['in']=function(u)u=clamp01(u);return u*u*u end, -- accelerating (into a cut / the silence)
  in2=function(u)u=clamp01(u);return u*u end, -- a gentler start, still moving at the next cut
  out=function(u)u=clamp01(u);return 1-(1-u)^3 end, -- decelerating (out of a cut / a hit)
  expo=function(u)u=clamp01(u);return u>=1 and 1 or 1-2^(-10*u)end, -- the snap-back on a hit
  creep=function(u)u=clamp01(u);return .65*u+.35*smooth(u)end, -- nearly linear: still moving at the cut ("cut on motion")
 }
 local function lerp(a,b,u)return a+(b-a)*u end
 local function rad(d)return math.rad(d)end
 -- a point on an orbit: azimuth 0 = in front (+Z: every stage is looked at from +Z), positive = to the right (+X); elevation up
 local function around(centre,radius,az,el)
  local a,e=rad(az),rad(el or 0)
  return centre+V(math.sin(a)*math.cos(e),math.sin(e),math.cos(a)*math.cos(e))*radius
 end
 local function jitter(t,seed)return math.sin(t*61+seed)*math.sin(t*23+seed*2.3)end
 local C={}
 -- Comfort limits (Full). Calm (Reduced Motion) has no moves at all: still shots and cuts.
 C.MaxOrbitDegPerSec=35;C.MaxRollDeg=10
 -- Shot lists ---------------------------------------------------------------------------------------------------------------------------
 -- A shot runs [From, To) (beat name + offset). Eye / Target: {a, b} (stage-local) or functions of (t, tl, u); Fov / Roll: {a, b};
 -- Ease: how u runs; Dof: {Focus = {a,b} studs from the eye or 'target', Radius, Far, Near}. A shot starts with a CUT unless Join=true.
 local function at(tl,beat,off)return(tl[beat]or 0)+(off or 0)end
 local S={}
 -- SECRET: mysterious and dark. Creeping low moves, a rack focus out of the dark, glitch jump-cuts with a dutch tilt, a ratchet push on
 -- every lock click, a slow push into the cracks, dead stop on the silence, a snap-back on the hit, a crane up with the seed.
 S[6]={
  {Name='S1 OUT OF THE DARK',Move='low creeping dolly-in, rack focus from the runes to the pack',From={'SceneIn',-.05},To={'Glitch1'},
   Eye={V(-3.0,3.0,13.5),V(-2.0,3.4,10.6)},Target={V(0,4.3,0),V(0,4.9,0)},Fov={38,36},Roll={0,-2},Ease='creep',
   Dof={Focus=function(t,tl)return lerp(6.5,11.4,smooth((t-tl.SceneIn-.15)/.4))end,Radius=1.4,Far=.55,Near=.8}},
  {Name='S2 GLITCH',Move='jump cut, dutch tilt +8 deg, jitter',From={'Glitch1'},To={'Glitch1',.22},
   Orbit={Centre=V(0,6,0),Radius={7.4,7.4},Az={36,36},El={10,10}},Target={V(0,6,0),V(0,6,0)},Fov={40,40},Roll={8,8},Ease='linear',Jitter=.09,Dof={Focus='target',Radius=2,Far=.45,Near=0}},
  {Name='S2 GLITCH',Move='a slow drift left, the tilt eases out',From={'Glitch1',.22},To={'Glitch2'},Join=true,
   Orbit={Centre=V(0,6,0),Radius={7.4,7.1},Az={36,30},El={10,7}},Target={V(0,6,0),V(0,6,0)},Fov={40,40},Roll={8,2},Ease='in2',Dof={Focus='target',Radius=2,Far=.45,Near=0}},
  {Name='S3 GLITCH',Move='jump cut to the other side, low, dutch -8.5 deg',From={'Glitch2'},To={'Glitch2',.22},
   Orbit={Centre=V(0,6,0),Radius={7.2,7.2},Az={-42,-42},El={-12,-12}},Target={V(0,6.2,0),V(0,6.2,0)},Fov={42,42},Roll={-8.5,-8.5},Ease='linear',Jitter=.1,Dof={Focus='target',Radius=2,Far=.45,Near=0}},
  {Name='S3 GLITCH',Move='a slow drift right, the tilt eases out',From={'Glitch2',.22},To={'Lock'},Join=true,
   Orbit={Centre=V(0,6,0),Radius={7.2,7.0},Az={-42,-38},El={-12,-9}},Target={V(0,6.2,0),V(0,6.1,0)},Fov={42,42},Roll={-8.5,-3},Ease='in2',Dof={Focus='target',Radius=2,Far=.45,Near=0}},
  {Name='S4 THE LOCK',Move='cut on the 1st click; a ratchet push-in on every click',From={'Lock'},To={'Unlock'},
   Eye={V(0,6.25,7.4),V(0,6.25,7.4)},Target={V(0,6.0,0),V(0,6.0,0)},Fov={44,44},Roll={0,0},Ease='linear',Ratchet={Beats={0,.22,.44},Step=-2.5,Tick=.8},
   Dof={Focus='target',Radius=1.8,Far=.5,Near=0}},
  {Name='S5 CRACKS OF LIGHT',Move='push-in to an extreme close-up, accelerating; the camera shudders with the pack',From={'Unlock'},To={'Silence'},Join=true,
   Eye={V(0,6.25,7.4),V(0,5.8,5.2)},Target={V(0,6.0,0),V(0,6.05,0)},Fov={36.5,33},Roll={0,0},Ease='in',Shudder=.6,Dof={Focus='target',Radius=1.2,Far=.7,Near=0}},
  {Name='SILENCE',Move='dead stop: nothing moves',From={'Silence'},To={'Climax'},Join=true,
   Eye={V(0,5.8,5.2),V(0,5.8,5.2)},Target={V(0,6.05,0),V(0,6.05,0)},Fov={33,33},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=1.2,Far=.7,Near=0}},
  {Name='S6 THE HIT',Move='snap back, roll kick, shake; then a hang',From={'Climax'},To={'Climax',.4},Join=true,
   Eye={V(0,5.8,5.2),V(0,5.8,5.2)},Target={V(0,6.05,0),V(0,6.05,0)},Fov={33,44},Roll={0,0},Ease='expo',EaseSeconds=.2,Kick=2.5,Dof={Focus='target',Radius=2.5,Far=.4,Near=0}},
 }
 -- the seed hero (every tier): the seed centred, its size from RarePullRules.HeroDiameter (33% -> 39% of the height), the camera's angle
 -- around it from Az / El (degrees), blended in over Blend seconds from the hit shot
 local H={}
 H[6]={Name='S7 THE SEED RISES',Move='crane up with the seed, then a slow orbit as it floats down',Start=0,Blend=.2,
  Keys={{'Climax',0,0,-3},{'Rise',.3,5,3},{'FloatEnd',0,-6,3},{'Back',0,-9,5}}}
 -- COSMIC: vast, a space pull-out. A cosmic zoom-out from the pack to deep space, the camera settling onto the line of the planets, a
 -- vortex push-in with a gentle counter-orbit, a crash push into the core, the supernova blowing the camera back, the star leading it home.
 S[7]={
  {Name='C1 COSMIC ZOOM-OUT',Move='pull out from the tumbling pack to deep space (decelerating); a breath on each planet',From={'SceneIn',-.05},To={'SpinUp'},
   Track='Pack',Dir={V(.42,.10,.90),V(.55,.02,.83)},Dist={3.2,19},Aim={V(0,0,0),V(-1.1,1.9,-2.8)},Fov={42,54},Roll={0,0},Ease='out',
   Breaths={'Align1','Align2','Align3'},Dof={Focus='target',Radius=4,Far=.25,Near=0}},
  {Name='C2 VORTEX',Move='push-in with a slow counter-orbit (peak 25 deg/s) and a 5 deg tilt as the galaxy spins up',From={'SpinUp'},To={'Implode'},Join=true,
   Orbit={Centre='Pack',Radius={19,8.5},Az={33.5,12},El={1.2,3}},Target={V(-1.1,1.9,-2.8),V(0,.2,0)},TargetRel='Pack',Fov={54,46},Roll={0,5},Ease='inout',Dof={Focus='target',Radius=4,Far=.3,Near=0}},
  {Name='C3 COLLAPSE',Move='crash push-in on the imploding core',From={'Implode'},To={'Silence'},Join=true,
   Orbit={Centre='Pack',Radius={8.5,3.4},Az={12,9},El={3,4}},Target={V(0,.2,0),V(0,0,0)},TargetRel='Pack',Fov={46,36},Roll={5,0},Ease='in2',Dof={Focus='target',Radius=2,Far=.5,Near=0}},
  {Name='SILENCE',Move='dead stop',From={'Silence'},To={'Climax'},Join=true,
   Orbit={Centre='Pack',Radius={3.4,3.4},Az={9,9},El={4,4}},Target={V(0,0,0),V(0,0,0)},TargetRel='Pack',Fov={36,36},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=2,Far=.5,Near=0}},
  {Name='C4 SUPERNOVA',Move='the blast throws the camera back (pull-out + wide lens), shake',From={'Climax'},To={'Climax',.55},Join=true,
   Orbit={Centre='Pack',Radius={3.4,13},Az={9,9},El={4,4}},Target={V(0,0,0),V(0,0,0)},TargetRel='Pack',Fov={36,58},Roll={0,0},Ease='expo',EaseSeconds=.45,Kick=1.5,Dof=nil},
 }
 H[7]={Name='C5 THE FALLING STAR',Move='follow the star home; a slow orbit with the nebula drifting behind',Start=.4,Blend=.5,
  Keys={{'Climax',.4,9,4},{'StarIn',0,5,5},{'FloatEnd',0,-10,2},{'Back',0,-14,3}}}
 -- KING: regal, epic. A grand crane down at the doors, a low tracking shot through the colonnade, an orbit and crane up that meets the
 -- descending crown on the pack, a low-angle push-in on the crowned pack, the hit, a crane up with the crowned seed and a slow royal orbit.
 S[8]={
  {Name='K1 THE GRAND HALL',Move='crane down from the rafters behind the procession',From={'SceneIn',-.05},To={'SceneIn',1.08},
   Eye={V(0,21.5,33.4),V(2.4,9.6,30.5)},Target={V(0,7,10),V(0,5.6,8)},Fov={60,52},Roll={0,0},Ease='inout',Dof=nil},
  {Name='K2 THE PROCESSION',Move='cut on the carry whoosh: low tracking shot alongside the pack, past the pillars; it comes to rest with the pack',From={'SceneIn',1.08},To={'CrownStart'},
   Track='Pack',TrackFn=function(p,t,tl) -- (down the right side of the carpet, outside the candelabras, 5.5 studs behind the pack; it eases in
    -- a little as the pack slows onto the cushion, so it comes to rest with it)
    local z=p.Z+5.5;local w=smooth((10-z)/9.1);return V(5.6-1.2*w,2.6+.2*w,z)end,
   Aim={V(0,.6,-1.2),V(0,.3,0)},Fov={50,46},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=3,Far=.35,Near=0}},
  {Name='K3 THE CROWN DESCENDS',Move='cut on the crown\'s shimmer: look up into the beam, orbit 16 deg and crane up to meet the crown on the pack',From={'CrownStart'},To={'CrownOn',.25},
   Orbit={Centre=V(0,0,-4.6),Radius={7.6,5.6},Az={28,16},Height={3.4,6.0}},Target=function(t,tl,u)
    local crown=L.CrownPose(tl,t);local pack=L.Points[8].Pack+V(0,.9,0)
    local w=smooth((t-tl.CrownStart)/(tl.CrownOn-tl.CrownStart))
    return crown:Lerp(pack,.65+.35*w)end,
   Fov={50,45},Roll={0,0},Ease='inout',EaseTo='CrownOn',Snap={Beat='CrownOn',Fov=-3},Dof={Focus='target',Radius=2.5,Far=.4,Near=0}},
  {Name='K4 LONG LIVE THE KING',Move='cut on the 2nd shake: low-angle push-in on the crowned pack, it shakes harder',From={'CrownOn',.25},To={'Silence'},
   Eye={V(1.4,3.4,2.4),V(.35,4.0,.4)},Target={V(0,5.9,-4.6),V(0,5.3,-4.6)},Fov={44,38},Roll={0,0},Ease='in',Shudder=.3,Dof={Focus='target',Radius=1.6,Far=.5,Near=0}},
  {Name='SILENCE',Move='dead stop',From={'Silence'},To={'Climax'},Join=true,
   Eye={V(.35,4.0,.4),V(.35,4.0,.4)},Target={V(0,5.3,-4.6),V(0,5.3,-4.6)},Fov={38,38},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=1.6,Far=.5,Near=0}},
  {Name='K5 THE HIT',Move='snap back, roll kick, shake; gold rays, confetti',From={'Climax'},To={'Climax',.4},Join=true,
   Eye={V(.35,4.0,.4),V(.35,4.0,.4)},Target={V(0,5.3,-4.6),V(0,5.3,-4.6)},Fov={38,48},Roll={0,0},Ease='expo',EaseSeconds=.22,Kick=-2.5,Dof=nil},
 }
 H[8]={Name='K6 THE CROWNED SEED',Move='crane up with the rising seed, then a slow royal orbit (28 deg over 2.4 s) as it floats down',Start=0,Blend=.22,
  Keys={{'Climax',0,4,-14},{'Rise',.3,14,4},{'FloatEnd',0,-14,4},{'Back',0,-17,6}}}
 -- The world phases: offsets on the player's OWN live camera (never a new position): a push along the camera -> head line (always clear:
 -- the Roblox camera already keeps it free of walls), a turn of the camera where it stands (pitch / roll), and the field of view.
 local W={
  [6]={Open={Push=.35,Pitch=-4,Roll=3,Fov=-6,Ease='in',Jolt=.25},Back={Push=.45,Pitch=-3,Roll=-2,Fov=-6}},
  [7]={Open={Push=0,Pitch=18,Roll=0,Fov=6,Ease='inout'},Back={Push=0,Pitch=16,Roll=0,Fov=5}},
  [8]={Open={Push=.30,Pitch=8,Roll=0,Fov=-6,Ease='inout'},Back={Push=.40,Pitch=6,Roll=0,Fov=-5}},
 }
 C.HandBackSeconds=.7
 -- Calm (Reduced Motion): still shots only, cut on the Calm timeline's beats (R151's Calm, recomposed after the Full shots): no move,
 -- no tilt, no shake, no zoom, no focus pull; the seed in one still hero shot at 37% (RarePullRules.Shot 'Calm'). The world is untouched.
 local CALM={
  [6]={{'SceneIn',V(-2.4,1.6,11.5),V(0,6.2,0),38},{'Lock',V(0,6.25,7.6),V(0,6.0,0),42}},
  [7]={{'SceneIn',V(5.7,4.0,15.0),V(-.9,8.2,-5.6),54},{'Implode',V(1.3,7.0,5.4),V(0,6.6,-3),46}},
  [8]={{'SceneIn',V(2.6,3.2,1.6),V(0,7.2,-4.6),50}}, -- (the Calm King is short: one low still that the crown comes down into)
 }
 C.Calm=CALM
 function C.CalmShot(rank,tl,t)
  if t>=tl.Climax then local e,tg,f=L.Shot(rank,'Calm',t,tl);return {Eye=e,Target=tg,Fov=f,Roll=0,Name='CALM HERO',Move='still'}end
  local k=CALM[rank];local pick=k[1]
  for _,c in ipairs(k)do if t>=(tl[c[1]]or 0)-.05 then pick=c end end
  return {Eye=pick[2],Target=pick[3],Fov=pick[4],Roll=0,Name='CALM '..pick[1]:upper(),Move='still (cut on the beat)'}
 end
 C.Shots,C.Hero,C.World=S,H,W
 -- Evaluation -------------------------------------------------------------------------------------------------------------------------------
 local function packAt(rank,tl,t)local p=L.PackPose(rank,tl,t);return p end
 local function val(x,u,t,tl)if type(x)=='function'then return x(t,tl,u)end;if type(x)=='table'and x[1]~=nil then return lerp(x[1],x[2],u)end;return x end
 local function shotEye(sh,rank,tl,t,u)
  if sh.Orbit then
   local o=sh.Orbit;local c=o.Centre=='Pack'and packAt(rank,tl,t)or o.Centre
   local r=lerp(o.Radius[1],o.Radius[2],u);local az=lerp(o.Az[1],o.Az[2],u)
   if o.Height then local h=lerp(o.Height[1],o.Height[2],u);local p=around(c,r,az,0);return V(p.X,h,p.Z)end
   return around(c,r,az,lerp(o.El[1],o.El[2],u))
  end
  if sh.Track then
   local p=packAt(rank,tl,t)
   if sh.TrackFn then return sh.TrackFn(p,t,tl)end
   local dir=sh.Dir[1]:Lerp(sh.Dir[2],u).Unit;return p+dir*lerp(sh.Dist[1],sh.Dist[2],u)
  end
  return val(sh.Eye,u,t,tl)
 end
 local function shotTarget(sh,rank,tl,t,u)
  if sh.Track then return packAt(rank,tl,t)+sh.Aim[1]:Lerp(sh.Aim[2],u)end
  local tg=val(sh.Target,u,t,tl)
  if sh.TargetRel=='Pack'then tg=packAt(rank,tl,t)+tg end
  return tg
 end
 -- the hero rig: the seed centred at its hero size; Az / El keyed on beats (smooth between keys)
 -- (one flowing path through the keys, like R152's camera: a Hermite curve whose speed carries on through each key; it eases out of the
 -- first key and into the last)
 local function heroAngles(h,tl,t)
  local k=h.Keys;local function kt(i)return at(tl,k[i][1],k[i][2])end
  if t<=kt(1)then return k[1][3],k[1][4]end
  local function slope(i,f)if i<=1 or i>=#k then return 0 end;return(k[i+1][f]-k[i-1][f])/math.max(.01,kt(i+1)-kt(i-1))end
  for i=1,#k-1 do if t<kt(i+1)then
   local span=math.max(.01,kt(i+1)-kt(i));local u=clamp01((t-kt(i))/span);local u2,u3=u*u,u*u*u
   local function hm(f)return k[i][f]*(2*u3-3*u2+1)+k[i+1][f]*(3*u2-2*u3)+slope(i,f)*(u3-2*u2+u)*span+slope(i+1,f)*(u3-u2)*span end
   return hm(3),hm(4)
  end end
  return k[#k][3],k[#k][4]
 end
 local function hero(rank,tl,t,fov)
  local h=H[rank];local az,el=heroAngles(h,tl,t)
  local seed=L.SeedPose(rank,tl,t,true)-V(0,L.SeedHeroSize*L.HeroAim,0)
  local k=smooth((t-tl.Climax)/math.max(.01,tl.FloatEnd-tl.Climax))
  local dia=L.HeroDiameter.From+(L.HeroDiameter.To-L.HeroDiameter.From)*k
  if t>tl.FloatEnd then dia=L.HeroDiameter.To-.02*smooth((t-tl.FloatEnd)/math.max(.01,tl.Back-tl.FloatEnd))end
  return around(seed,L.HeroDistance(dia,fov),az,el),seed
 end
 local function shake(t,tl,phone)
  local a=t-tl.Climax;if a<0 or a>.5 then return 0,0,0 end
  local k=(1-a/.5)^2*(phone and .35 or 1)*smooth(a/.03)
  return math.sin(t*90)*.12*k,math.sin(t*73)*.09*k,math.deg(math.sin(t*61)*math.rad(1.1)*k)
 end
 -- the stage camera at t (Full)
 local function stage(rank,tl,t,ctx)
  local list=S[rank];local sh=list[1]
  local index=1
  for i=#list,1,-1 do if t>=at(tl,list[i].From[1],list[i].From[2])then sh=list[i];index=i;break end end
  local t0,t1=at(tl,sh.From[1],sh.From[2]),at(tl,sh.To[1],sh.To[2])
  local span=sh.EaseSeconds or(sh.EaseTo and tl[sh.EaseTo]-t0)or(t1-t0)
  local u=(EASE[sh.Ease]or EASE.inout)((t-t0)/math.max(.01,span))
  local eye,target=shotEye(sh,rank,tl,t,u),shotTarget(sh,rank,tl,t,u)
  local fov,roll=lerp(sh.Fov[1],sh.Fov[2],u),lerp(sh.Roll[1],sh.Roll[2],u)
  local name,move=sh.Name,sh.Move
  if sh.Jitter then local k=1-smooth((t-t0)/math.max(.01,t1-t0));eye=eye+V(jitter(t,1)*sh.Jitter*k,jitter(t,2)*sh.Jitter*.6*k,0);roll+=jitter(t,3)*1.5*k end
  if sh.Ratchet then -- a snap push-in on every click: -Step degrees in 60 ms, held (a ratchet), plus a small roll tick
   for i,b in ipairs(sh.Ratchet.Beats)do local a=t-(t0+b);if a>=0 then fov+=sh.Ratchet.Step*EASE.out(a/.06);roll+=(i%2==1 and 1 or -1)*sh.Ratchet.Tick*math.max(0,1-a/.15)*EASE.out(a/.03)end end
  end
  if sh.Snap then local a=t-tl[sh.Snap.Beat];if a>=0 then fov+=sh.Snap.Fov*EASE.out(a/.06)end end
  if sh.Shudder then local _,_,_,_,sk=L.PackPose(rank,tl,t);eye=eye+V(math.sin(t*67)*sk*sh.Shudder,math.sin(t*59+1)*sk*sh.Shudder*.6,0)end
  if sh.Kick then roll+=sh.Kick*math.max(0,1-(t-t0)/.4)^2*smooth((t-t0)/.03)end
  if sh.Breaths then for _,b in ipairs(sh.Breaths)do local a=t-tl[b];if a>=0 and a<.6 then fov-=1.6*math.sin(math.pi*clamp01(a/.6))^2 end end end
  local dof=sh.Dof
  -- after the hit: the seed hero takes over
  local h=H[rank]
  if t>=tl.Climax+h.Start then
   local he,ht=hero(rank,tl,t,fov)
   local w=smooth((t-tl.Climax-h.Start)/h.Blend)
   eye,target=eye:Lerp(he,w),target:Lerp(ht,w)
   if w>0 then name,move=h.Name,h.Move;dof={Focus='target',Radius=2,Far=.45*w,Near=0}end
  end
  -- the hit's shake (R152's: a 30 ms swell, 0.5 s) in the camera's own frame
  local sx,sy,sr=shake(t,tl,ctx and ctx.Phone)
  if sx~=0 then local f=(target-eye).Unit;local r=f:Cross(Y).Unit;local up=r:Cross(f);eye=eye+r*sx+up*sy;target=target+r*sx+up*sy;roll+=sr end
  local d=nil
  if dof then
   local focus=dof.Focus=='target'and(target-eye).Magnitude or val(dof.Focus,u,t,tl)
   d={Focus=focus,Radius=dof.Radius,Far=dof.Far,Near=dof.Near}
  end
  return {Eye=eye,Target=target,Fov=fov,Roll=roll,Dof=d,Name=name,Move=move,Index=index,Join=sh.Join==true}
 end
 -- the world (player's live camera + an offset): w = 0..1 of the offset
 local function world(rank,ctx,o,w,t,jolt)
  local live=ctx.Live;local eye=live.Position;local look=live.LookVector;local head=ctx.Head
  local dist=(head-eye).Magnitude
  local push=(dist>1.5)and o.Push*w or 0 -- (first person: no push)
  local pos=eye+(head-eye).Unit*dist*push
  local f=look;local r=f:Cross(Y).Unit
  -- pitch about the camera's own right axis (a turn where it stands)
  local p=rad(o.Pitch*w);f=(f*math.cos(p)+Y*math.sin(p)).Unit
  local roll=o.Roll*w
  if jolt and t>=jolt and t<jolt+.12 then local k=1-(t-jolt)/.12;pos=pos+r*.12*k;roll+=2*k end
  return {World=true,Eye=pos,Target=pos+f*10,Fov=(ctx.LiveFov or 70)+o.Fov*w,Roll=roll,Dof=nil}
 end
 function C.Shot(rank,variant,t,tl,ctx)
  rank=math.clamp(rank,6,8);ctx=ctx or{}
  local reduced=variant=='Calm'or ctx.Reduced
  if t<tl.SceneIn-.05 then
   if reduced then return world(rank,ctx,{Push=0,Pitch=0,Roll=0,Fov=0},0,t)end -- (Calm: the world untouched, as today)
   local o=W[rank].Open;local s=world(rank,ctx,o,(EASE[o.Ease]or smooth)(t/math.max(.01,tl.SceneIn-.05)),t,o.Jolt)
   s.Name='OPEN';s.Move=rank==7 and'the player\'s camera tilts up to the sky, the lens widens'or rank==8 and'the player\'s camera leans in and up, the lens narrows'or'the player\'s camera leans in, a slow dutch tilt, a glitch jolt'
   return s
  end
  if t>=tl.Back then
   local o=W[rank].Back
   local w=reduced and 0 or 1-smooth((t-tl.Back)/C.HandBackSeconds)
   local s=world(rank,ctx,o,w,t);s.Name='HAND-BACK';s.Move='eases into the player\'s own camera ('..C.HandBackSeconds..' s)'
   return s
  end
  local s
  if reduced then s=C.CalmShot(rank,tl,t)else s=stage(rank,tl,t,ctx)end
  local origin=ctx.Origin
  if origin then s.Eye=origin*s.Eye;s.Target=origin*s.Target end
  return s
 end
 -- a stage-local point -> world (for the tests / preview)
 C.At=at
 return C
end
