-- R113: client-only pose polish layered after BeastPose / KeeperAttackPose / KeeperStrikeFrames.
-- The server never requires this module (KeeperContact -> KeeperStrikeFrames), so hit frames are unchanged.
-- Layers: head look-at, wake roar (anticipation + rear + settle), weight shift on speed changes,
-- tail / snake-body follow-through on turns, sleep breathing and a sleepy stir, a short catch taunt,
-- and a crossfade across the strike window edges. Inside the strike window no layer is added.
local Config=require(script.Parent.KeeperRigConfig)
local P={}
local CF,V=CFrame.new,Vector3.new
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
-- Look: max head yaw (rad); Pitch: max head pitch; Lean: weight-shift pitch; Roar: head lift on wake;
-- Crouch: wake anticipation drop (studs); Arms: roar arm flare; Breath: sleep rise (studs); Taunt: catch style.
P.Tune={
 [1]={Look=.40,Pitch=.22,Lean=.045,Roar=.30,Crouch=.9,Arms=.50,Breath=0,Rear=0,Taunt='Roar'},
 [2]={Look=.70,Pitch=.35,Lean=0,Roar=.40,Crouch=0,Rise=1.3,Breath=.05,Rear=0,Taunt='Hiss'},
 [3]={Look=.60,Pitch=.30,Lean=.07,Roar=.45,Crouch=.45,Breath=.06,Rear=.10,Taunt='Roar'},
 [4]={Look=.55,Pitch=.30,Lean=.06,Roar=.50,Crouch=.50,Breath=.07,Rear=.09,Taunt='Roar'},
 [5]={Look=.40,Pitch=.20,Lean=.035,Roar=.22,Crouch=.8,Arms=.20,Breath=.05,Rear=0,Taunt='Roar'},
 [6]={Look=.55,Pitch=.30,Lean=.07,Roar=.45,Crouch=.50,Arms=.55,Breath=.07,Rear=.08,Taunt='Beat'},
 [7]={Look=.35,Pitch=.18,Lean=.035,Roar=.22,Crouch=1.3,Arms=.40,Breath=.06,Rear=0,Taunt='Roar'},
}
P.WakeSeconds=1.35;P.TauntSeconds=1.6;P.StrikeBlendIn=.08;P.StrikeBlendOut=.16
local rigs={}
local function rig(stage)
 local r=rigs[stage];if r then return r end
 local source=Config[stage];r={Pivots={},Legs={},Arms={},Tails={},Joints={},Upper={}}
 for name,p in pairs(source.Pivots)do r.Pivots[name]=V(p[1],p[2],p[3])end
 for name in pairs(source.Pivots)do
  if name:find('Leg')then r.Legs[name]=true else table.insert(r.Upper,name)end
  if name=='Tail'then table.insert(r.Tails,name)end
  local side=name:match('^(%a-)Arm$')or name:match('^(%a-)Forearm$')or(name=='Sword'and'Right')
  if side and source.Pivots[side..'Arm']then table.insert(r.Arms,{Group=name,Pivot=side..'Arm'})end
 end
 for i,p in pairs(source.SnakeJoints or {})do r.Joints[i]=V(p[1],p[2],p[3])end
 local body=source.Bounds.Body;local bp=r.Pivots.Body or V()
 r.Ground=V(bp.X,-4,bp.Z)
 r.Rear=body and V(0,-4,math.max(body[1][3],body[2][3])*.8)or r.Ground
 r.Scale=math.max(1,(source.Scale or 1)*.6)
 rigs[stage]=r;return r
end
function P.new()
 return {Last=nil,Strike=false,BlendAt=-1,BlendFor=0,Snapshot=nil,PrevSpeed=0,PrevYaw=nil,Stir=0}
end
-- Damped spring, substepped for stability at low frame rates. freq in Hz, damp < 1 overshoots.
local function spring(s,key,target,freq,damp,dt)
 local x,v=s[key]or 0,s[key..'V']or 0;local w=freq*math.pi*2
 local steps=math.max(1,math.ceil(dt*120));local h=dt/steps
 for _=1,steps do v+=(w*w*(target-x)-2*damp*w*v)*h;x+=v*h end
 s[key],s[key..'V']=x,v;return x
end
local function rotateAbout(frames,point,x)
 local d=CF(point)*CFrame.Angles(x,0,0)*CF(-point)
 for g,f in pairs(frames)do frames[g]=d*f end
end
-- Wake envelope: crouch (anticipation) then rear (hold) then settle. Returns crouch, rear.
function P.WakeCurve(u)
 if u<0 or u>=P.WakeSeconds then return 0,0 end
 local crouch=u<.22 and smooth(u/.22)or 1-smooth((u-.22)/.18)
 local rear=smooth((u-.2)/.2)*(1-smooth((u-.8)/(P.WakeSeconds-.8)))
 return crouch,rear
end
function P.TauntCurve(u)
 if u<0 or u>=P.TauntSeconds then return 0 end
 return smooth(u/.25)*(1-smooth((u-1.05)/(P.TauntSeconds-1.05)))
end
-- c: Now, Dt, Awake, Moving, Speed, Frame (visual root), Asleep, Look (world Vector3|nil), Stir (bool),
-- Strike (inside the R110 strike window), Impact (server impact time), WakeAt, TauntAt.
function P.Apply(state,stage,frames,c)
 local r=rig(stage);local tune=P.Tune[stage];local dt=math.clamp(c.Dt or 0,0,.1);local now=c.Now
 local out=table.clone(frames)
 local awake=math.clamp(c.Awake or 0,0,1);local moving=math.clamp(c.Moving or 0,0,1)
 -- Springs always advance so nothing pops when the strike window ends.
 local look=c.Look;local yawT,pitchT=0,0
 local head=r.Pivots.Head
 if look and head and frames.Head and awake>.5 and not c.Asleep then
  local hp=frames.Head*head;local d=c.Frame:PointToObjectSpace(look)-hp
  local flat=math.sqrt(d.X*d.X+d.Z*d.Z)
  if flat>1 then
   local yaw=math.atan2(-d.X,-d.Z)
   if math.abs(yaw)<2.3 then yawT=math.clamp(yaw,-tune.Look,tune.Look);pitchT=math.clamp(math.atan2(d.Y,flat),-tune.Pitch,tune.Pitch)end
  end
 end
 local lookYaw=spring(state,'Yaw',yawT,2.2,.72,dt);local lookPitch=spring(state,'Pitch',pitchT,2.2,.72,dt)
 local speed=c.Speed or 0;local accel=dt>0 and(speed-state.PrevSpeed)/dt or 0;state.PrevSpeed=speed
 local leanT=-tune.Lean*math.clamp(accel/(4*(math.abs(speed)+10)),-1,1)*awake
 local lean=spring(state,'Lean',leanT,1.6,.42,dt)
 local lv=c.Frame.LookVector;local yawNow=math.atan2(-lv.X,-lv.Z);local rate=0
 if state.PrevYaw and dt>0 then local dy=(yawNow-state.PrevYaw+math.pi)%(math.pi*2)-math.pi;rate=dy/dt end
 state.PrevYaw=yawNow
 local tail=spring(state,'Tail',math.clamp(-rate*.14,-.55,.55)*awake,1.4,.32,dt)
 state.Stir=spring(state,'StirW',(c.Stir and c.Asleep)and 1 or 0,.6,1,dt)
 local strike=c.Strike==true
 if strike~=state.Strike then
  -- Crossfade across the strike window edges; the fade-in always ends before the impact pose.
  state.Snapshot=state.Last;state.BlendAt=now
  state.BlendFor=strike and math.min(P.StrikeBlendIn,math.max(0,(c.Impact or now)-now-.01))or P.StrikeBlendOut
  state.Strike=strike
 end
 if not strike then
  -- Snake body: turn lag rolls down the chain from the head (joint 2) to the tail tip (joint 9).
  if stage==2 and r.Joints[2]then
   local acc=CFrame.identity
   for i=2,9 do
    local g='Segment'..i;local f=out[g];local j=r.Joints[i]
    if f and j then
     local joint=(acc*f)*j;acc=CF(joint)*CFrame.Angles(0,tail*.16,0)*CF(-joint)*acc;out[g]=acc*f
    end
   end
  end
  for _,g in ipairs(r.Tails)do
   local f=out[g];if f then local p=f*r.Pivots[g];out[g]=CF(p)*CFrame.Angles(0,tail,0)*CFrame.Angles(-lean*2.2,0,0)*CF(-p)*f end
  end
  -- Wake roar and catch taunt share one head/jaw/arm vocabulary.
  local crouch,rear=0,0
  if c.WakeAt then crouch,rear=P.WakeCurve(now-c.WakeAt)end
  local taunt=c.TauntAt and P.TauntCurve(now-c.TauntAt)or 0
  local calm=1-.65*moving
  rear=math.max(rear,taunt*(tune.Taunt=='Beat'and .45 or .8))*calm;crouch*=calm
  local tremble=math.sin(now*43)*.035*rear
  local headPitch=lookPitch+tune.Roar*rear-.16*crouch+tremble
  local headYaw=lookYaw
  local rise=0
  if tune.Taunt=='Hiss'then
   headYaw+=math.sin(now*6.5)*.28*taunt*calm;rise=(tune.Rise or 0)*math.max(rear,.6*state.Stir)
  end
  if state.Stir>.01 and head then headPitch+=.10*state.Stir end
  if head and out.Head then
   local hp=out.Head*head
   local d=CF(hp+V(0,rise,0))*CFrame.Angles(0,headYaw,0)*CFrame.Angles(headPitch,0,0)*CF(-hp)
   out.Head=d*out.Head;if out.Jaw then out.Jaw=d*out.Jaw end
  end
  if out.Jaw and r.Pivots.Jaw then
   local open=(.55*rear+.08*crouch)*awake
   if open>0 then local jp=r.Pivots.Jaw;out.Jaw=out.Jaw*CF(jp)*CFrame.Angles(-open,0,0)*CF(-jp)end
  end
  local flare=(tune.Arms or 0)*rear
  local beat=tune.Taunt=='Beat'and taunt*calm or 0
  if (flare>0 or beat>0)and #r.Arms>0 then
   for _,a in ipairs(r.Arms)do
    local f=out[a.Group];local shoulder=out[a.Pivot]and out[a.Pivot]*r.Pivots[a.Pivot]
    if f and shoulder then
     local side=r.Pivots[a.Pivot].X>=0 and 1 or -1
     local pound=beat>0 and beat*(.75+.45*math.max(0,math.sin(now*13+(side>0 and 0 or math.pi))))or 0
     out[a.Group]=CF(shoulder)*CFrame.Angles(pound,0,side*flare-side*.35*beat)*CF(-shoulder)*f
    end
   end
  end
  -- Whole-body weight: lean on speed changes, rear back on the roar, drop in the anticipation.
  if math.abs(lean)>1e-4 then rotateAbout(out,r.Ground,lean)end
  if (tune.Rear or 0)*rear>1e-4 then rotateAbout(out,r.Rear,tune.Rear*rear)end
  local drop=(tune.Crouch or 0)*crouch
  -- Sleep breathing: the torso rises and falls; feet stay planted.
  local asleepW=c.Asleep and math.clamp(1-awake/.3,0,1)or 0
  local breath=(tune.Breath or 0)*asleepW*math.sin(now*1.25)*r.Scale
  if drop>0 or breath~=0 then
   for _,g in ipairs(r.Upper)do local f=out[g];if f then out[g]=CF(0,breath-drop,0)*f end end
  end
 end
 if state.Snapshot and now-state.BlendAt<state.BlendFor then
  local u=smooth((now-state.BlendAt)/state.BlendFor)
  for g,f in pairs(out)do local s=state.Snapshot[g];if s then out[g]=s:Lerp(f,u)end end
 else state.Snapshot=nil end
 state.Last=out
 return out
end
return P
