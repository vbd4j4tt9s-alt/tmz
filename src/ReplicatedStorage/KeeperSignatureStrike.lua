-- R123: a signature hit animation per keeper (client only; the server never requires this module).
-- The server's contact test still uses KeeperStrikeFrames (unchanged), so hit timing, reach and damage are identical.
-- Every move keeps the server timeline: wind-up to Cock*W, a held cock to Release*W, an accelerating strike
-- that lands at exactly W (the server impact), the contact pose held to W+HitHold, a follow-through that
-- peaks Peak of the way through the rest, and a settle to the idle pose by W+Recovery (the R110 window end).
-- Contact poses keep each keeper's striking limb about where the server's contact geometry is.
local Config=require(script.Parent.KeeperRigConfig)
local Combat=require(script.Parent.KeeperCombat)
local Pose=require(script.Parent.BeastPose)
local M={};local CF,V=CFrame.new,Vector3.new
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
local function around(p,x,y,z)return CF(p)*CFrame.Angles(0,y,0)*CFrame.Angles(x,0,z)*CF(-p)end
-- Cock/Release: fractions of W; Peak: follow-through peak as a fraction of the post-hold recovery.
-- R124 Ground: the move smashes the ground (KeeperFx plays the ground-slam sound at the visual impact).
M.Moves={
 [1]={Name='Overhead hammer',Cock=.55,Release=.66,Peak=.35,Accent='Dust',Tip={'LeftArm','RightArm'},Ground=true},
 [2]={Name='Coil strike',Cock=.55,Release=.68,Peak=.30,Accent='Sand',Tip={'Head'}},
 [3]={Name='Pounce swipe',Cock=.50,Release=.62,Peak=.35,Accent='Frost',Tip={'RightFrontLeg'}},
 [4]={Name='Rear-up rake',Cock=.55,Release=.66,Peak=.40,Accent='Fire',Tip={'RightFrontLeg'}},
 [5]={Name='Diagonal slash',Cock=.55,Release=.66,Peak=.35,Accent='Crystal',Tip={'Sword'}},
 [6]={Name='Chest-beat slam',Cock=.62,Release=.72,Peak=.30,Accent='Slam',Tip={'LeftArm','RightArm'},Ground=true},
 [7]={Name='Storm uppercut',Cock=.55,Release=.64,Peak=.40,Accent='Lightning',Tip={'RightArm'}},
 Veiled={Name='Spectral lunge',Cock=.58,Release=.70,Peak=.40,Accent='Spectral'},
}
-- Phase weights for one move at elapsed seconds since KeeperAttackAt.
-- k: wound (cocked) pose weight, c: contact pose weight, f: follow-through weight (k+c+f <= 1, the rest is idle);
-- a: wind-up progress 0..1 (for sub-beats), s: strike progress 0..1, h: 1 while the cocked pose is held.
-- lead: seconds of the windup this client missed (late replication); the wind-up restarts from it (R112).
function M.Weights(move,windup,elapsed,lead)
 if type(elapsed)~='number'or elapsed<0 or elapsed>windup+Combat.Recovery then return 0,0,0,0,0,0 end
 local cock,release=windup*move.Cock,windup*move.Release
 if elapsed<cock then
  local start=math.clamp(tonumber(lead)or 0,0,cock*.6)
  local a=math.clamp((elapsed-start)/(cock-start),0,1)
  return smooth(a),0,0,a,0,0
 end
 if elapsed<release then return 1,0,0,1,0,1 end
 if elapsed<windup then local s=(elapsed-release)/(windup-release);local c=s*s;return 1-c,c,0,1,s,0 end
 local after=elapsed-windup-Combat.HitHold
 if after<0 then return 0,1,0,1,1,0 end
 local v=after/(Combat.Recovery-Combat.HitHold);local p=move.Peak
 if v<p then local u=smooth(v/p);return 0,1-u,u,1,1,0 end
 return 0,0,1-smooth((v-p)/(1-p)),1,1,0
end
-- The instant the strike lands on this client: always the server's impact time.
function M.ContactAt(stage,started)return started+Combat.Get(stage).Windup end

local K,C,F,A,S,H,E=0,0,0,0,0,0,0
local function mix(k,c,f)return k*K+c*C+f*F end
local rigs={}
local function rig(stage)
 local r=rigs[stage];if r then return r end
 local source=Config[stage];r={Scale=source.Scale or 1,P={}}
 for name,p in pairs(source.Pivots)do r.P[name]=V(p[1],p[2],p[3])end
 for i,p in pairs(source.SnakeJoints or {})do r['J'..i]=V(p[1],p[2],p[3])end
 rigs[stage]=r;return r
end
-- +1 rolls/yaws a limb toward the body midline (pivot.X decides the side).
local function inward(p)return p.X<0 and 1 or -1 end
local function headJaw(out,frames,P,B,hx,hy,open)
 local d=around(P.Head,hx,hy,0)
 out.Head=B*frames.Head*d
 if frames.Jaw then
  local jaw=frames.Head:Inverse()*frames.Jaw
  out.Jaw=out.Head*jaw*(P.Jaw and around(P.Jaw,-open,0,0)or CFrame.identity)
 end
end
local tremble=function(amount)return math.sin(E*57)*amount*H end

local moves={}
-- 1 Timber Golem: rises tall with both fists flung up in a wide V over the crown, then hammers them down together into the ground.
moves[1]=function(out,frames,r)
 local P,s=r.P,r.Scale
 local B=CF(0,mix(.35,-1.55,-1.85)*s,mix(.30,-.45,-.55)*s)*around(P.Body,mix(.20,-.12,-.18)+tremble(.02),0,0)
 out.Body=B*frames.Body
 out.Head=B*frames.Head*around(P.Head,mix(.24,-.14,-.22),0,0)
 for _,g in ipairs({'LeftArm','RightArm'})do
  local p=P[g];local i=inward(p)
  out[g]=B*frames[g]*around(p,mix(2.85,.62,.82)+tremble(.05),mix(0,-i*.28,-i*.34),mix(-i*.80,i*.12,0))
 end
end
-- 2 Sand Snake: coils back into a raised S with the jaw gaping, lunges the head forward and snaps shut,
-- then a whip runs down the body to the tail tip.
moves[2]=function(out,frames,r)
 local P=r.P
 local lift=around(r.J2,mix(.62,-.04,.10),0,0)
 out.Segment1=lift*frames.Segment1
 local acc=CFrame.identity
 for i=2,9 do
  local g='Segment'..i;local f=frames[g];local j=r['J'..i]
  if f and j then
   local coil=(i<=6 and(i%2==0 and .45 or -.45)or 0)*K
   local whip=i>=3 and F*.55*math.sin(E*24-i*.95)*math.min(1,(i-2)/4)or 0
   local joint=(acc*f)*j;acc=CF(joint)*CFrame.Angles(0,coil+whip,0)*CF(-joint)*acc;out[g]=acc*f
  end
 end
 local B=CF(0,mix(2.4,.25,.65),mix(2.2,-2.2,-1.1))*lift
 headJaw(out,frames,P,B,mix(-.26,.10,.06)+tremble(.03),math.sin(E*9)*.10*K,mix(.70,-.08,.28))
end
-- 3 Ice Fang: crouches with tail high and a paw cocked, springs forward in a short arc, swipes the paw across.
moves[3]=function(out,frames,r)
 local P=r.P
 local hop=1.25*math.sin(math.pi*S)*(1-C)
 local B=CF(0,mix(-1.0,-.25,-.55)+hop,mix(.85,-1.8,-2.1))*around(P.Body,mix(-.10,.04,-.03),mix(.06,-.04,-.08),0)
 for g,f in pairs(frames)do
  if g:find('BackLeg')then out[g]=f
  elseif g=='RightFrontLeg'or g=='LeftFrontLeg'then
   local p=P[g];local i=inward(p);local swipe=g=='RightFrontLeg'
   if swipe then out[g]=B*f*around(p,mix(1.60,.95,.25)+tremble(.06),0,mix(-i*.45,i*.35,i*.60))
   else out[g]=B*f*around(p,mix(-.30,.75,.30),0,0)end
  elseif g=='Tail'then out[g]=B*f*around(P.Tail,mix(-.45,-.15,.10),mix(math.sin(E*14)*.20,0,.45*math.sin(E*16)),0)
  elseif g~='Head'and g~='Jaw'then out[g]=B*f end
 end
 headJaw(out,frames,P,B,mix(-.16,.12,0),mix(0,-.10,-.14),mix(.30,.45,.20))
end
-- 4 Lava Dragon: rears up with wings raised and claws high, comes down raking one claw across with a wing
-- buffet, and the tail sweeps round in the follow-through.
moves[4]=function(out,frames,r)
 local P=r.P
 local hip=V(0,1.5,4.55)
 local B=CF(0,mix(.30,-.30,-.40),mix(.40,-2.8,-3.1))*around(hip,mix(.50,-.06,-.10)+tremble(.02),mix(0,-.05,-.10),0)
 for g,f in pairs(frames)do
  local p=P[g]
  if g:find('BackLeg')then out[g]=f
  elseif g:find('FrontLeg')then
   local i=inward(p)
   if g=='RightFrontLeg'then out[g]=B*f*around(p,mix(1.10,.85,.35),0,mix(-i*.50,i*.35,i*.60))
   else out[g]=B*f*around(p,mix(.90,.60,.30),0,mix(-i*.30,0,0))end
  elseif g:find('Wing')then
   local out_=p.X>0 and 1 or -1
   out[g]=B*f*around(p,0,out_*mix(-.25,.35,.10),out_*mix(.55,-.35,-.10))
  elseif g=='Tail'then out[g]=B*f*around(p,mix(-.40,0,.05),mix(math.sin(E*10)*.10,-.35,.75),0)
  elseif g~='Head'and g~='Jaw'then out[g]=B*f end
 end
 headJaw(out,frames,P,B,mix(.35,-.15,-.05),mix(0,-.06,.12),mix(.50,.20,.45))
end
-- 5 Crystal Knight: blade drawn high over the sword shoulder with the torso turned away, a diagonal cut
-- across the front, the blade carried past the far hip, then back to guard.
local Knight
local knightKeys
moves[5]=function(out,frames)
 Knight=Knight or require(script.Parent.CrystalKnightPose)
 if not knightKeys then
  local d=Knight.Direction
  knightKeys={Rest=d(V(0,.88,-.48)),Wound=d(V(-.30,.75,.59)),Cut=d(V(.05,-.60,-.80)),Past=d(V(.75,-.55,.25))}
 end
 local k=knightKeys
 local function lerpV(a,b,c,d)return a*(1-K-C-F)+b*K+c*C+d*F end
 -- Rest -> Wound (wind-up), Wound -> Cut over the top (strike), Cut -> Past (follow-through), Past -> Rest.
 local rotation
 if C>0 and K>0 then rotation=k.Wound:Lerp(k.Cut,C)
 elseif C>0 then rotation=k.Cut:Lerp(k.Past,F)
 elseif F>0 then rotation=k.Rest:Lerp(k.Past,F)
 else rotation=k.Rest:Lerp(k.Wound,K)end
 local custom={Twist=V(mix(-.10,.12,.18)+tremble(.015),mix(.45,-.35,-.60),0),
  Right=lerpV(V(7.5,16.6,5),V(9.5,25,-1.5),V(-2,11.5,10.5),V(-6,9,6)),
  Left=lerpV(V(-9.0,8.5,1.8),V(-6,16,7),V(-7.5,13,1),V(-8,15,-1)),Rotation=rotation}
 local adapted=Knight.Adapt(frames,1,0,0,E,0,0,custom)
 for g,f in pairs(adapted)do out[g]=f end
end
-- 6 Jungle King: rears back pounding its chest (two quick alternating beats), throws both fists overhead,
-- then slams them two-handed into the ground; roars through the bounce.
moves[6]=function(out,frames,r)
 local P=r.P
 local ground=V(0,-4,1.9)
 local B=CF(0,mix(.25,-.40,-.60),mix(.30,-1.8,-2.0))*around(ground,mix(.34,-.16,-.20),0,0)
 local raise=smooth((A-.70)/.30)
 for g,f in pairs(frames)do
  local p=P[g]
  if g=='LeftArm'or g=='RightArm'then
   local i=inward(p);local beat=math.max(0,math.sin(A/.70*math.pi*4+(p.X<0 and 0 or math.pi)))*(1-raise)
   local cockPitch=(1.35+.40*beat)*(1-raise)+2.75*raise
   out[g]=B*f*around(p,mix(cockPitch,.55,.66),mix(0,-i*.12,-i*.16),mix(i*.55*(1-raise)+i*.12*raise,i*.10,0))
  elseif g:find('BackLeg')then out[g]=f
  elseif g~='Head'and g~='Jaw'then out[g]=B*f end
 end
 headJaw(out,frames,P,B,mix(.22,-.10,.30),0,mix(.35,.15,.55))
end
-- 7 Storm Colossus: crouches and twists away with the fist drawn back low (charging), then a rising
-- uppercut that connects low in front and carries high overhead.
moves[7]=function(out,frames,r)
 local P,s=r.P,r.Scale
 local B=CF(0,mix(-1.1,-2.2,.15)*s,mix(.35,-.55,-.75)*s)*around(P.Body,mix(-.12,-.08,.22),mix(.50,-.15,-.40)+tremble(.02),0)
 out.Body=B*frames.Body
 out.Head=B*frames.Head*around(P.Head,mix(-.15,0,.25),mix(-.20,.10,.20),0)
 local i=inward(P.RightArm)
 out.RightArm=B*frames.RightArm*around(P.RightArm,mix(-1.35,.55,2.50)+tremble(.05),mix(0,-i*.15,-i*.25),mix(-i*.25,0,i*.10))
 local j=inward(P.LeftArm)
 out.LeftArm=B*frames.LeftArm*around(P.LeftArm,mix(.55,-.25,-.45),mix(-j*.20,0,0),mix(j*.20,0,0))
end

function M.Apply(stage,frames,now,started,lead)
 local move=M.Moves[stage]
 if not move or type(started)~='number'then return frames end
 local windup=Combat.Get(stage).Windup
 K,C,F,A,S,H=M.Weights(move,windup,now-started,lead);E=now-started
 if K==0 and C==0 and F==0 then return frames end
 local out=table.clone(frames)
 moves[stage](out,frames,rig(stage))
 return out
end
-- Client strike frames (replaces KeeperStrikeFrames.Frames on the client only); same idle base as the server.
function M.Frames(stage,now,started,lead,variant)
 return M.Apply(stage,Pose.Frames(stage,now,1,0,0,0,0,0,variant),now,started,lead)
end

-- The Veiled One: rides VeiledKeeper81's joint chain (its K.Frames, used by the server, is unchanged).
-- Sinks and leans back with the head cocked and claws spread wide, twitches, then a low lunge with both
-- claws thrust forward, a glitching stutter, and a slow drift back.
function M.Veiled(now,started,lead)
 local move=M.Moves.Veiled
 local k,c,f,_,_,h=M.Weights(move,Combat.Get(7).Windup,type(started)=='number'and now-started or -1,lead)
 if k==0 and c==0 and f==0 then return nil end
 K,C,F,H,E=k,c,f,h,now-started
 local glitch=(math.sin(E*47)>0 and 1 or -1)*.30*F*(1-F)*4
 return {Sink=mix(-1.0,-.45,-.70),Forward=mix(.60,-.80,-.95)+glitch,Lean=mix(.25,-.30,-.36),
  Tilt=mix(.55,.08,-.25)+tremble(.08),HeadPitch=mix(-.20,.15,.10),Blend=math.min(1,K+C+F),
  PitchR=mix(-.40,1.55,1.75),PitchL=mix(-.40,1.40,1.55),RollOut=mix(1.50,-.15,-.05)+tremble(.10),Elbow=mix(-.60,-.05,-.15)}
end
return M
