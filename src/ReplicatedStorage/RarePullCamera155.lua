-- R155 (owner: "i like the pack animations that we currently have rn but could we improve it if possible by having dynamic camera movement
-- like a cinema scene ... only secret to king. legendary and mythic no work has to be done"): the cinematic camera of the Secret / Cosmic /
-- King story scenes, as approved (docs/proposals/R154/cinematic_camera.md and its preview rig, preview/cinecam154.luau) with the owner's four
-- answers (docs/proposals/R155/cinematic_camera.md):
--  1. the cuts inside the scenes as designed: Secret 3 and King 3, each on its sound; Cosmic one continuous take;
--  2. the Cosmic seed reaches its hero size with the star (StarIn), after the supernova has blown the camera back;
--  3. NO world opening move and NO hand-back offset: before the cut to black the player's own camera keeps today's lens-only push, and the cut
--     back to the world at the end is today's (RarePullCinematic); this camera lives only inside the stage, from today's scene entry to today's exit;
--  4. a depth of field (RarePullDof on the Camera, written by RarePullCinematic) on every device and quality, phones / Lite included; modest values.
-- R154 seed collect: the result waits on the hero shot (no timer) until the collect. The hero's orbit settles (Settle), then only a slow,
-- bounded idle drift is left (two slow, incommensurate sways well under 1 deg/s: it never repeats visibly and never wanders off), for minutes.
-- ONE CLOCK: a pure function of the scene's clock t and its timeline (RarePullRules.Timeline): no springs, no state between frames, so a skip
-- (the clock jumps) lands on exactly the designed frame, 30 / 60 / 144 fps give the same picture, and every cut / snap / stop sits on a beat the
-- sound cue sheets use (RarePullRules.SceneCues: a cut shows on the first frame at or after its beat, the frame its sound is heard on).
-- Reduced Motion (the Calm timeline): still shots cut on the Calm beats, no move / roll / lens change / focus pull (a still depth of field stays),
-- the seed in R151's still hero shot (RarePullRules.Shot 'Calm'). Common..Mythic never come here (their reveals are unchanged).
-- Usage (RarePullCinematic, stage only): local rig=Cam.New(rank,variant,tl); every frame local eye,target,fov,roll=Cam.Shot(rig,t,aspect)
--  -> eye / target stage-local, FieldOfView (vertical, degrees), roll (degrees about the view; the dutch tilt). The frame's depth of field is
--  rig.Focus / rig.Radius / rig.Far / rig.Near (DepthOfFieldEffect FocusDistance / InFocusRadius / FarIntensity / NearIntensity); rig.Name /
--  rig.Move name the shot; rig.Cuts lists the cut times. Nothing per frame makes a table or a closure (the tests read this file for it).
local Rules=require(script.Parent.RarePullRules)
local C={}
local V=Vector3.new
local sin,cos,rad,deg=math.sin,math.cos,math.rad,math.deg
local function clamp01(x)return math.clamp(x,0,1)end
local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
local function lerp(a,b,u)return a+(b-a)*u end
-- how u (0..1) runs through a shot's move
local EASE={
 linear=clamp01,
 inout=smooth,
 ['in']=function(u)u=clamp01(u);return u*u*u end, -- accelerating: fastest into the cut / the silence
 in2=function(u)u=clamp01(u);return u*u end, -- a gentler start, still moving at the next cut
 out=function(u)u=clamp01(u);return 1-(1-u)^3 end, -- decelerating (its fast start under the fade in)
 expo=function(u)u=clamp01(u);return u>=1 and 1 or 1-2^(-10*u)end, -- the snap back on a hit, then it hangs
 creep=function(u)u=clamp01(u);return .65*u+.35*smooth(u)end, -- nearly linear: still moving at the cut ("cut on motion")
}
C.Ease=EASE
-- Comfort (Full; the tests measure them at 240 Hz on what can be seen, not under the black fades): the fastest turn of the view, the orbit
-- around a subject, the dutch tilt, the lens ramps (a snap: at most Snap degrees in SnapSeconds, only on a lock click or the crown), no spin
-- (Spin: the most any shot turns around its subject), the camera's own shudder at most this share of the pack's shake. Calm: none of it.
C.Limits={Turn=60,Orbit=32,Roll=10,Lens=60,Snap=3,SnapSeconds=.06,Spin=90,Shudder=.6}
-- the depth of field (decision 4: every device): modest (Far / Near at most these), the seed sharp in the hero shot
C.Dof={MaxFar=.5,MaxNear=.35,Hero={Radius=2,Far=.4},Calm={Radius=2.5,Far=.3}}
C.SettleSeconds=.9 -- after FloatEnd the hero's orbit eases to rest over this (it used to fade to black here: R154's result waits instead)
-- the idle drift while the result waits: azimuth A1 sin(2 pi t / P1) + A2 sin(2 pi t / P2 + phase), elevation E sin(2 pi t / P3 + phase), in over In s
C.Idle={A1=1.2,P1=41,A2=.45,P2=17.3,Ph2=1.3,E=.4,P3=29,Ph3=.7,In=6}
local function jitter(t,seed)return sin(t*61+seed)*sin(t*23+seed*2.3)end
-- (shot pieces that are functions of the clock: defined once here, never per frame)
local function rackFocus(t,tl)return lerp(6.5,11.4,smooth((t-tl.SceneIn-.15)/.4))end -- out of the dark: the near runes, then the pack
-- King, the procession: low, down the right side of the carpet behind the pack, in the lane between the candelabra (x 3.6 - 4.05, z 4) and
-- the windows' slanting light shafts (x 5.7 - 6.4 at this height), past the pillars; as the pack slows onto the cushion it rises a little and
-- drops back a little, coming to rest with it short of the heralds' trumpets (R155: the preview's path, x 5.6, ran through the shafts and
-- ended under a trumpet)
local function procession(p,t,tl)
 local w=smooth((4.5-p.Z)/9.1);local z=p.Z+5.5+1.5*w
 return V(4.75+.25*smooth((8-z)/4),2.7+.3*w,z)
end
-- King, the crown descends: the aim follows the crown down its beam onto the pack (they meet on CrownOn)
local K3PACK=Rules.Points[8].Pack+V(0,.9,0)
local function crownAim(t,tl)
 local crown=Rules.CrownPose(tl,t)
 local w=smooth((t-tl.CrownStart)/math.max(.01,tl.CrownOn-tl.CrownStart))
 return crown:Lerp(K3PACK,.65+.35*w)
end
-- Shot lists (Full) ------------------------------------------------------------------------------------------------------------------------
-- A shot runs from From to the next shot's From (beat name + offset; To ends its move). Eye / Target: {from, to} (stage-local) or a function of
-- (t, tl, u); Orbit: around Centre (a point or 'Pack') at Radius, azimuth Az (0 = in front, +Z: every stage is looked at from +Z; positive =
-- to the right), elevation El or a Height; Track: following the pack (Dir / Dist, or TrackFn) with Aim; Fov / Roll: {from, to}; Ease: how u
-- runs (to To, or EaseTo / EaseSeconds); Dof: {Focus = studs, 'target' or a function, Radius, Far, Near (each a value or {from, to}: a joined
-- shot's focus carries on smoothly)}, nil = none. A shot starts with a CUT unless Join (it carries on from the one before). Extras: Jitter (the
-- glitch), Ratchet (a lens snap on each lock click), Snap (one on a beat), Shudder (the camera shakes with the pack, this share), Kick (a roll
-- kick on the hit). (Cosmic: a lens breath on each planet locking in, rig.Breaths.)
local S={}
-- SECRET: mysterious and dark. A creeping low dolly out of the dark with a rack focus, two glitch jump-cuts with a dutch tilt, the lock: a
-- ratchet push on every click, a slow push into the cracks of light, dead stop on the silence, the hit throws it back.
S[6]={
 {Name='S1 OUT OF THE DARK',Move='low creeping dolly-in, rack focus from the runes to the pack',From={'SceneIn',-.05},To={'Glitch1'},
  Eye={V(-3.0,3.0,13.5),V(-2.0,3.4,10.6)},Target={V(0,4.3,0),V(0,4.9,0)},Fov={38,36},Roll={0,-2},Ease='creep',Dof={Focus=rackFocus,Radius=1.4,Far=.5,Near=.35}},
 {Name='S2 GLITCH',Move='cut on the glitch: dutch tilt +8 deg, jitter',From={'Glitch1'},To={'Glitch1',.22},
  Orbit={Centre=V(0,6,0),Radius={7.4,7.4},Az={36,36},El={10,10}},Target={V(0,6,0),V(0,6,0)},Fov={40,40},Roll={8,8},Ease='linear',Jitter=.09,Dof={Focus='target',Radius=2,Far=.45,Near=0}},
 {Name='S2 GLITCH',Move='a slow drift left, the tilt eases out',From={'Glitch1',.22},To={'Glitch2'},Join=true,
  Orbit={Centre=V(0,6,0),Radius={7.4,7.1},Az={36,30},El={10,7}},Target={V(0,6,0),V(0,6,0)},Fov={40,40},Roll={8,2},Ease='in2',Dof={Focus='target',Radius=2,Far=.45,Near=0}},
 {Name='S3 GLITCH',Move='cut on the glitch to the other side, low: dutch tilt -8.5 deg',From={'Glitch2'},To={'Glitch2',.22},
  Orbit={Centre=V(0,6,0),Radius={7.2,7.2},Az={-42,-42},El={-12,-12}},Target={V(0,6.2,0),V(0,6.2,0)},Fov={42,42},Roll={-8.5,-8.5},Ease='linear',Jitter=.1,Dof={Focus='target',Radius=2,Far=.45,Near=0}},
 {Name='S3 GLITCH',Move='a slow drift right, the tilt eases out',From={'Glitch2',.22},To={'Lock'},Join=true,
  Orbit={Centre=V(0,6,0),Radius={7.2,7.0},Az={-42,-38},El={-12,-9}},Target={V(0,6.2,0),V(0,6.1,0)},Fov={42,42},Roll={-8.5,-3},Ease='in2',Dof={Focus='target',Radius=2,Far=.45,Near=0}},
 {Name='S4 THE LOCK',Move='cut on the 1st click; the lens ratchets in on every click',From={'Lock'},To={'Unlock'},
  Eye={V(0,6.25,7.4),V(0,6.25,7.4)},Target={V(0,6.0,0),V(0,6.0,0)},Fov={44,44},Roll={0,0},Ease='linear',Ratchet={Step=-2.5,Tick=.8},Dof={Focus='target',Radius=1.8,Far=.5,Near=0}},
 {Name='S5 CRACKS OF LIGHT',Move='push-in to an extreme close-up, accelerating; it shudders with the pack',From={'Unlock'},To={'Silence'},Join=true,
  Eye={V(0,6.25,7.4),V(0,5.8,5.2)},Target={V(0,6.0,0),V(0,6.05,0)},Fov={36.5,33},Roll={0,0},Ease='in',Shudder=.6,Dof={Focus='target',Radius={1.8,1.2},Far=.5,Near=0}},
 {Name='SILENCE',Move='dead stop: nothing moves',From={'Silence'},To={'Climax'},Join=true,
  Eye={V(0,5.8,5.2),V(0,5.8,5.2)},Target={V(0,6.05,0),V(0,6.05,0)},Fov={33,33},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=1.2,Far=.5,Near=0}},
 {Name='S6 THE HIT',Move='thrown back, a roll kick, the hit\'s shake',From={'Climax'},To={'Climax',.4},Join=true,
  Eye={V(0,5.8,5.2),V(0,5.8,5.2)},Target={V(0,6.05,0),V(0,6.05,0)},Fov={33,44},Roll={0,0},Ease='expo',EaseSeconds=.2,Kick=2.5,Dof={Focus='target',Radius=2.5,Far=.4,Near=0}},
}
local function dirOf(az,el)local a,e=rad(az),rad(el);return V(sin(a)*cos(e),sin(e),cos(a)*cos(e))end -- (the way an orbit at az / el looks back)
-- COSMIC: vast, one continuous take. A cosmic zoom-out from the tumbling pack to deep space settling on the planets' line (a lens breath on each
-- planet locking in), a vortex push-in with a gentle counter-orbit, a crash into the core, dead stop, the supernova blows the camera back.
S[7]={
 {Name='C1 COSMIC ZOOM-OUT',Move='pull out from the tumbling pack to deep space; a breath on each planet',From={'SceneIn',-.05},To={'SpinUp'},
  Track='Pack',Dir={V(.42,.10,.90),dirOf(33.5,1.2)},Dist={3.2,19},Aim={V(0,0,0),V(-1.1,1.9,-2.8)},Fov={42,54},Roll={0,0},Ease='out',Dof={Focus='target',Radius=4,Far=.25,Near=0}},
 {Name='C2 VORTEX',Move='push-in with a slow counter-orbit and a 5 deg tilt as the galaxy spins up',From={'SpinUp'},To={'Implode'},Join=true,
  Orbit={Centre='Pack',Radius={19,8.5},Az={33.5,12},El={1.2,3}},Target={V(-1.1,1.9,-2.8),V(0,.2,0)},TargetRel=true,Fov={54,46},Roll={0,5},Ease='inout',Dof={Focus='target',Radius=4,Far={.25,.3},Near=0}},
 {Name='C3 COLLAPSE',Move='crash push-in on the imploding core',From={'Implode'},To={'Silence'},Join=true,
  Orbit={Centre='Pack',Radius={8.5,3.4},Az={12,9},El={3,4}},Target={V(0,.2,0),V(0,0,0)},TargetRel=true,Fov={46,36},Roll={5,0},Ease='in2',Dof={Focus='target',Radius={4,2},Far={.3,.5},Near=0}},
 {Name='SILENCE',Move='dead stop',From={'Silence'},To={'Climax'},Join=true,
  Orbit={Centre='Pack',Radius={3.4,3.4},Az={9,9},El={4,4}},Target={V(0,0,0),V(0,0,0)},TargetRel=true,Fov={36,36},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=2,Far=.5,Near=0}},
 {Name='C4 SUPERNOVA',Move='the blast throws the camera back (pull-out and a wide lens), the hit\'s shake',From={'Climax'},To={'Climax',.55},Join=true,
  Orbit={Centre='Pack',Radius={3.4,13},Az={9,9},El={4,4}},Target={V(0,0,0),V(0,0,0)},TargetRel=true,Fov={36,58},Roll={0,0},Ease='expo',EaseSeconds=.45,Kick=1.5},
}
-- KING: regal, epic. A crane down the great hall, a cut on the carry whoosh to a low tracking shot past the pillars, a cut on the crown's shimmer:
-- an orbit and crane up meeting the descending crown on the pack (a lens snap on the fanfare), a cut on the 2nd shake to a low-angle push-in.
S[8]={
 {Name='K1 THE GRAND HALL',Move='crane down from the rafters behind the procession',From={'SceneIn',-.05},To={'SceneIn',1.08},
  Eye={V(0,21.5,33.4),V(2.4,9.6,30.5)},Target={V(0,7,10),V(0,5.6,8)},Fov={60,52},Roll={0,0},Ease='inout'},
 {Name='K2 THE PROCESSION',Move='cut on the carry whoosh: a low tracking shot beside the pack, past the pillars; it comes to rest with it',From={'CarrySwell'},To={'CrownStart'},
  Track='Pack',TrackFn=procession,Aim={V(0,.6,-1.2),V(0,.3,0)},Fov={50,46},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=3,Far=.35,Near=0}},
 {Name='K3 THE CROWN DESCENDS',Move='cut on the crown\'s shimmer: look up the beam, orbit and crane up to meet the crown on the pack',From={'CrownStart'},To={'CrownOn',.25},
  Orbit={Centre=V(0,0,-4.6),Radius={7.6,5.8},Az={28,18},Height={3.6,5.8}},Target=crownAim,Fov={50,45},Roll={0,0},Ease='inout',EaseTo='CrownOn',Snap={Beat='CrownOn',Fov=-3},
  Dof={Focus='target',Radius=2.5,Far=.4,Near=0}},
 {Name='K4 LONG LIVE THE KING',Move='cut on the 2nd shake: a low-angle push-in on the crowned pack; it shudders with it',From={'CrownOn',.25},To={'Silence'},
  Eye={V(1.4,3.4,2.4),V(.9,4.0,.4)},Target={V(0,5.9,-4.6),V(0,5.3,-4.6)},Fov={44,38},Roll={0,0},Ease='in',Shudder=.3,Dof={Focus='target',Radius=1.6,Far=.5,Near=0}},
 {Name='SILENCE',Move='dead stop',From={'Silence'},To={'Climax'},Join=true,
  Eye={V(.9,4.0,.4),V(.9,4.0,.4)},Target={V(0,5.3,-4.6),V(0,5.3,-4.6)},Fov={38,38},Roll={0,0},Ease='linear',Dof={Focus='target',Radius=1.6,Far=.5,Near=0}},
 {Name='K5 THE HIT',Move='thrown back, a roll kick, the hit\'s shake; gold rays, confetti',From={'Climax'},To={'Climax',.4},Join=true,
  Eye={V(.9,4.0,.4),V(.9,4.0,.4)},Target={V(0,5.3,-4.6),V(0,5.3,-4.6)},Fov={38,48},Roll={0,0},Ease='expo',EaseSeconds=.22,Kick=-2.5},
}
C.Shots=S
-- The seed hero (every tier): the seed centred at its hero size (RarePullRules.HeroDiameter, 33% -> 39% of the height by FloatEnd, then held),
-- the camera's angle around it keyed on beats (azimuth, elevation in degrees) through one Hermite curve; it takes over Start s after the hit,
-- blending in over Blend s. After the last key (Settle) the idle drift.
local H={
 [6]={Name='S7 THE SEED RISES',Move='crane up with the seed, then a slow orbit as it floats down',Start=0,Blend=.2,
  Keys={{'Climax',0,0,-3},{'Rise',.3,5,3},{'FloatEnd',0,-6,3},{'Settle',0,-9,5}}},
 [7]={Name='C5 THE FALLING STAR',Move='the star leads it home; a slow orbit, the nebula drifting behind',Start=.4,Blend=.5,
  Keys={{'Climax',.4,9,4},{'StarIn',0,5,5},{'FloatEnd',0,-10,2},{'Settle',0,-14,3}}},
 [8]={Name='K6 THE CROWNED SEED',Move='crane up with the rising seed, then a slow royal orbit as it floats down the beam',Start=0,Blend=.22,
  Keys={{'Climax',0,4,-14},{'Rise',.3,14,4},{'FloatEnd',0,-14,4},{'Settle',0,-17,6}}},
}
C.Hero=H
C.WaitName='THE RESULT WAITS';C.WaitMove='the hero shot holds: a slow idle drift until the collect'
-- Calm (Reduced Motion): still shots only, cut ON the Calm timeline's beats (the first is the scene entry): {beat, eye, target, FieldOfView}.
local CALM={
 [6]={{'SceneIn',V(-2.4,1.6,11.5),V(0,6.2,0),38},{'Lock',V(0,6.25,7.6),V(0,6.0,0),42}},
 [7]={{'SceneIn',V(5.7,4.0,15.0),V(-.9,8.2,-5.6),54},{'Implode',V(1.3,7.0,5.4),V(0,6.6,-3),46}},
 [8]={{'SceneIn',V(2.6,3.2,1.6),V(0,7.2,-4.6),50}}, -- (the Calm King is short: one low still that the crown comes down into)
}
C.Calm=CALM
-- Setting up (once per scene) -------------------------------------------------------------------------------------------------------------
-- beats the shots use that the timeline does not name: the carry whoosh's swell (its fastest moment, RarePullRules.Flights) and Settle
local function extraBeats(rank,tl)
 local b={Settle=tl.FloatEnd+C.SettleSeconds}
 if rank==8 then
  b.CarrySwell=(tl.SceneIn+tl.Glide)/2
  for _,f in ipairs(Rules.Flights('Scene',8,tl))do if f.Name=='Pack carry'then b.CarrySwell=f.Peak end end
 end
 return b
end
local function beatAt(tl,extra,beat,offset)return(tl[beat]or extra[beat]or 0)+(offset or 0)end
-- rank 6..8, variant 'Full' | 'Calm', tl = the scene's timeline. Returns the rig Shot reads.
function C.New(rank,variant,tl)
 rank=math.clamp(math.floor(tonumber(rank)or 6),6,8)
 tl=tl or Rules.Timeline(rank,variant)
 local extra=extraBeats(rank,tl)
 local rig={Rank=rank,TL=tl,Calm=variant=='Calm'or tl.Variant=='Calm',Beats=extra,Cuts={},Name='',Move='',Index=0,Hero=0,Focus=10,Radius=2,Far=0,Near=0}
 if rig.Calm then
  local list=CALM[rank];rig.Stills=list;rig.StillAt={}
  for i,c in ipairs(list)do rig.StillAt[i]=i==1 and tl.SceneIn-.05 or beatAt(tl,extra,c[1])end
  for i=2,#list do rig.Cuts[#rig.Cuts+1]=rig.StillAt[i]end
  rig.Cuts[#rig.Cuts+1]=tl.Climax
  return rig
 end
 local list=S[rank];rig.List=list;rig.From={};rig.To={};rig.Span={}
 for i,sh in ipairs(list)do
  local t0=beatAt(tl,extra,sh.From[1],sh.From[2]);local t1=beatAt(tl,extra,sh.To[1],sh.To[2])
  rig.From[i]=t0;rig.To[i]=t1
  rig.Span[i]=math.max(.01,sh.EaseSeconds or(sh.EaseTo and beatAt(tl,extra,sh.EaseTo)-t0)or(t1-t0))
  if i>1 and not sh.Join then rig.Cuts[#rig.Cuts+1]=t0 end
  if sh.Ratchet then rig.Clicks={};rig.Tick=sh.Ratchet.Tick;for _,k in ipairs(Rules.LockTurns)do if tl.Lock+k<tl.Unlock then rig.Clicks[#rig.Clicks+1]=tl.Lock+k end end end
 end
 if rank==7 then rig.Breaths={tl.Align1,tl.Align2,tl.Align3}end -- (Cosmic: a lens breath as each planet locks into line, whichever shot it falls in)
 local h=H[rank];rig.HeroDef=h;rig.HeroStart=tl.Climax+h.Start;rig.HeroT={};rig.HeroAz={};rig.HeroEl={}
 for i,k in ipairs(h.Keys)do rig.HeroT[i]=beatAt(tl,extra,k[1],k[2]);rig.HeroAz[i]=k[3];rig.HeroEl[i]=k[4]end
 rig.Settle=extra.Settle
 return rig
end
-- Per frame (no table, no closure) ---------------------------------------------------------------------------------------------------------
local function around(centre,radius,az,el)
 local a,e=rad(az),rad(el)
 return centre+V(sin(a)*cos(e),sin(e),cos(a)*cos(e))*radius
end
local function packAt(rig,t)return(Rules.PackPose(rig.Rank,rig.TL,t))end
-- Roblox's field of view is vertical: a screen narrower than 4:3 (portrait) widens it so the 4:3 centre still fits ("Vert+")
local function vertPlus(fov,aspect)
 if not aspect or aspect>=4/3 or aspect<=0 then return fov end
 return math.max(fov,deg(2*math.atan(math.tan(rad(fov)/2)*(4/3)/aspect)))
end
local function shotEye(sh,rig,t,u)
 local o=sh.Orbit
 if o then
  local c=o.Centre;if c=='Pack'then c=packAt(rig,t)end
  local r,az=lerp(o.Radius[1],o.Radius[2],u),lerp(o.Az[1],o.Az[2],u)
  if o.Height then local p=around(c,r,az,0);return V(p.X,lerp(o.Height[1],o.Height[2],u),p.Z)end
  return around(c,r,az,lerp(o.El[1],o.El[2],u))
 end
 if sh.Track then
  local p=packAt(rig,t)
  if sh.TrackFn then return sh.TrackFn(p,t,rig.TL)end
  return p+sh.Dir[1]:Lerp(sh.Dir[2],u).Unit*lerp(sh.Dist[1],sh.Dist[2],u)
 end
 local e=sh.Eye;if type(e)=='function'then return e(t,rig.TL,u)end
 return e[1]:Lerp(e[2],u)
end
local function shotTarget(sh,rig,t,u)
 if sh.Track then return packAt(rig,t)+sh.Aim[1]:Lerp(sh.Aim[2],u)end
 local g=sh.Target;local tg
 if type(g)=='function'then tg=g(t,rig.TL,u)else tg=g[1]:Lerp(g[2],u)end
 if sh.TargetRel then tg=packAt(rig,t)+tg end
 return tg
end
-- the hero's angle around the seed at t: one flowing Hermite path through the keys (its speed carries on through each key; it eases out of
-- the first and into the last), then the idle drift
local function heroAngles(rig,t)
 local T,A,E=rig.HeroT,rig.HeroAz,rig.HeroEl;local n=#T
 local az,el
 if t<=T[1]then az,el=A[1],E[1]
 elseif t>=T[n]then az,el=A[n],E[n]
 else
  local i=1;while t>=T[i+1]do i+=1 end
  local span=math.max(.01,T[i+1]-T[i]);local u=clamp01((t-T[i])/span);local u2,u3=u*u,u*u*u
  local h00,h01,h10,h11=2*u3-3*u2+1,3*u2-2*u3,(u3-2*u2+u)*span,(u3-u2)*span
  local ma,me,mb,mf=0,0,0,0
  if i>1 then local s=math.max(.01,T[i+1]-T[i-1]);ma=(A[i+1]-A[i-1])/s;me=(E[i+1]-E[i-1])/s end
  if i+1<n then local s=math.max(.01,T[i+2]-T[i]);mb=(A[i+2]-A[i])/s;mf=(E[i+2]-E[i])/s end
  az=A[i]*h00+A[i+1]*h01+ma*h10+mb*h11;el=E[i]*h00+E[i+1]*h01+me*h10+mf*h11
 end
 local idle=t-rig.Settle
 if idle>0 then
  local I=C.Idle;local w=smooth(idle/I.In);local tau=2*math.pi*idle
  az+=w*(I.A1*sin(tau/I.P1)+I.A2*sin(tau/I.P2+I.Ph2));el+=w*I.E*sin(tau/I.P3+I.Ph3)
 end
 return az,el
end
local function hero(rig,t,fov)
 local tl=rig.TL;local az,el=heroAngles(rig,t)
 local seed=Rules.SeedPose(rig.Rank,tl,t,true)
 seed=seed-V(0,Rules.SeedHeroSize*Rules.HeroAim,0)
 local D=Rules.HeroDiameter
 local dia=lerp(D.From,D.To,smooth((t-tl.Climax)/math.max(.01,tl.FloatEnd-tl.Climax)))
 return around(seed,Rules.HeroDistance(dia,fov),az,el),seed
end
local function num(x,u)if type(x)=='table'then return lerp(x[1],x[2],u)end;return x or 0 end -- (a value, or {from, to} over the shot)
local function dofOf(rig,d,t,u,eye,target)
 if not d then rig.Far,rig.Near=0,0;return end
 local f=d.Focus
 if f=='target'then f=(target-eye).Magnitude elseif type(f)=='function'then f=f(t,rig.TL)end
 rig.Focus,rig.Radius,rig.Far,rig.Near=f,num(d.Radius,u),math.min(num(d.Far,u),C.Dof.MaxFar),math.min(num(d.Near,u),C.Dof.MaxNear)
end
-- the stage camera at t (Full)
local function full(rig,t,aspect)
 local list,from=rig.List,rig.From
 local i=1;for k=#list,1,-1 do if t>=from[k]then i=k;break end end
 local sh=list[i];local tl=rig.TL;local t0,t1=from[i],rig.To[i]
 local u=(EASE[sh.Ease]or smooth)((t-t0)/rig.Span[i])
 local eye,target=shotEye(sh,rig,t,u),shotTarget(sh,rig,t,u)
 local fov,roll=lerp(sh.Fov[1],sh.Fov[2],u),lerp(sh.Roll[1],sh.Roll[2],u)
 rig.Index,rig.Name,rig.Move,rig.Hero=i,sh.Name,sh.Move,0
 if sh.Jitter then
  local k=1-smooth((t-t0)/math.max(.01,t1-t0))
  eye+=V(jitter(t,1)*sh.Jitter*k,jitter(t,2)*sh.Jitter*.6*k,0);roll+=jitter(t,3)*1.5*k
 end
 local clicks=rig.Clicks
 if clicks then -- the lock: the lens snaps in on every click (Step degrees in SnapSeconds, held through the lock shot) with a little roll tick
  for j=1,#clicks do -- (the tick dies away over .15 s, into the next shot too)
   local a=t-clicks[j]
   if a>=0 then
    if sh.Ratchet then fov+=sh.Ratchet.Step*EASE.out(a/C.Limits.SnapSeconds)end
    if a<.15 then roll+=(j%2==1 and 1 or -1)*rig.Tick*(1-a/.15)*EASE.out(a/.03)end
   end
  end
 end
 if sh.Snap then local a=t-tl[sh.Snap.Beat];if a>=0 then fov+=sh.Snap.Fov*EASE.out(a/C.Limits.SnapSeconds)end end
 if sh.Shudder then local _,_,_,_,sk=Rules.PackPose(rig.Rank,tl,t);eye+=V(sin(t*67)*sk*sh.Shudder,sin(t*59+1)*sk*sh.Shudder*.6,0)end
 if sh.Kick then roll+=sh.Kick*math.max(0,1-(t-t0)/.4)^2*smooth((t-t0)/.03)end
 local b=rig.Breaths
 if b then for j=1,#b do local a=t-b[j];if a>=0 and a<.6 then fov-=1.6*sin(math.pi*clamp01(a/.6))^2 end end end
 fov=vertPlus(fov,aspect)
 -- from the hit (Cosmic: a moment after it) the seed hero takes over
 local hs=rig.HeroStart
 if t>=hs then
  local h=rig.HeroDef;local w=smooth((t-hs)/h.Blend)
  if w>0 then
   local he,ht=hero(rig,t,fov)
   dofOf(rig,sh.Dof,t,u,eye,target)
   local far0,near0=rig.Far,rig.Near
   eye,target=eye:Lerp(he,w),target:Lerp(ht,w)
   rig.Hero=w;rig.Focus=(target-eye).Magnitude;rig.Radius=C.Dof.Hero.Radius;rig.Far=lerp(far0,C.Dof.Hero.Far,w);rig.Near=lerp(near0,0,w)
   if t>=rig.Settle then rig.Name,rig.Move=C.WaitName,C.WaitMove else rig.Name,rig.Move=h.Name,h.Move end
   return eye,target,fov,roll
  end
 end
 dofOf(rig,sh.Dof,t,u,eye,target)
 return eye,target,fov,roll
end
-- the still shots (Calm)
local function calm(rig,t,aspect)
 local tl=rig.TL
 if t>=tl.Climax then
  local eye,target,fov=Rules.Shot(rig.Rank,'Calm',t,tl)
  local f2=vertPlus(fov,aspect)
  if f2~=fov then local dir=(eye-target).Unit;eye=target+dir*Rules.HeroDistance(Rules.HeroDiameter.Calm,f2);fov=f2 end
  rig.Index,rig.Hero,rig.Name,rig.Move=#rig.Stills+1,1,'CALM HERO','still: the seed at its hero size'
  rig.Focus,rig.Radius,rig.Far,rig.Near=(target-eye).Magnitude,C.Dof.Calm.Radius,C.Dof.Calm.Far,0
  return eye,target,fov,0
 end
 local at=rig.StillAt;local i=1;for k=#at,2,-1 do if t>=at[k]then i=k;break end end
 local s=rig.Stills[i]
 rig.Index,rig.Hero,rig.Name,rig.Move=i,0,'CALM STILL '..i,'still (cut on the beat)'
 rig.Focus,rig.Radius,rig.Far,rig.Near=(s[3]-s[2]).Magnitude,C.Dof.Calm.Radius,C.Dof.Calm.Far,0
 return s[2],s[3],vertPlus(s[4],aspect),0
end
-- eye, target (stage-local), FieldOfView, roll (degrees) at the scene's clock t; aspect = the screen's width / height (optional)
function C.Shot(rig,t,aspect)
 if rig.Calm then return calm(rig,t,aspect)end
 return full(rig,t,aspect)
end
return C
