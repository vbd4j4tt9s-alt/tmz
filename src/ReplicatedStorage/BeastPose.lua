-- V106: grounded heavy chase gait layered on the approved lying sleep and animal strides.
local Config=require(script.Parent.KeeperRigConfig)
local UpgradePose=require(script.Parent.KeeperUpgradePose)
local Pose={Version=138,SnakeSegments=9}
local weight={
 [1]={Lean=.10,Press=.24,Roll=.032},[3]={Lean=.13,Press=.30,Roll=.035},
 [4]={Lean=.095,Press=.34,Roll=.025},[5]={Lean=.07,Press=.23,Roll=.030},
 [6]={Lean=.17,Press=.35,Roll=.060},[7]={Lean=.12,Press=.20,Roll=.026},
}
local V,CF=Vector3.new,CFrame.new
local rigs={}
local function vector(p) return V(p[1],p[2],p[3]) end
local function turn(p,x,y,z) return CF(p)*CFrame.Angles(x,y,z)*CF(-p) end
local styles={
 [1]={FrontFold=1.20,BackFold=-1.35,Splay=.42,Head=-.10,Swing=.62},
 [3]={FrontFold=1.30,BackFold=-1.45,Splay=.25,Head=-.24,Swing=.78},
 [4]={FrontFold=1.25,BackFold=1.40,Splay=.48,Head=-.48,Swing=.64},
 [5]={FrontFold=.75,BackFold=.75,Splay=1.10,Head=-.18,Swing=.68},
 [6]={FrontFold=.20,BackFold=-.55,Splay=.42,Head=-.18,Swing=.60,Roll=math.pi/2},
 [7]={FrontFold=1.70,BackFold=1.70,Splay=.08,Head=-.85,Swing=.80,Pitch=-.15},
}
for stage,source in pairs(Config) do
 local rig={Pivots={},FloorSamples={},SnakeJoints={}}
 for name,p in pairs(source.Pivots) do rig.Pivots[name]=vector(p) end
 for name,points in pairs(source.FloorSamples) do
  local samples={};for _,p in ipairs(points) do table.insert(samples,vector(p)) end
  rig.FloorSamples[name]=samples
 end
 for i,p in pairs(source.SnakeJoints or {}) do rig.SnakeJoints[i]=vector(p) end
 rigs[stage]=rig
end

local function legPhase(stage,group)
 local right=group:find('Right')~=nil
 if stage==5 then -- Two alternating three-foot groups.
  return (right and math.pi or 0)+(group:find('Middle') and math.pi or 0)
 end
 if stage==3 or stage==4 then -- Bounding front and rear pairs, slightly staggered.
  return (group:find('Back') and math.pi or 0)+(right and .35 or 0)
 end
 local front=group:find('Front') or group:find('Arm')
 return (right and math.pi or 0)+(front and 0 or math.pi)
end

function Pose.Frames(stage,t,awake,moving,phase,urgency,speed,turning)
 local replacement=UpgradePose.Frames(stage,t,awake,moving,phase,urgency,speed,turning)
 if replacement then return replacement end
 local rig=assert(rigs[stage],'Unknown keeper stage')
 awake=math.clamp(awake,0,1);moving=math.clamp(moving,0,1)*awake
 -- Smooth endpoints keep the body settled while the eyes start to wake.
 local blend=awake*awake*(3-2*awake);local sleep=1-blend
 local pivots=rig.Pivots;local frames={}
 local breath=math.sin(t*(stage==2 and 1.25 or 1.7))
 local cycle=phase or t*math.pi*4
 local effort=math.clamp(urgency or 0,0,1)*moving
 local contact=math.max(0,math.cos(cycle*2-.25))^4
 if stage==2 then
  local parent=CF();frames.Segment1=parent
  for i=2,9 do
   local bend=math.sin(cycle-i*.70)*(.007+.070*moving+.026*effort)*blend
   parent=parent*turn(rig.SnakeJoints[i],0,bend,0)
   frames['Segment'..i]=parent
  end
  frames.Head=turn(pivots.Head,-sleep*.46+breath*.008-.055*effort,
                   math.sin(cycle-.3)*(.07*moving+.025*effort),math.sin(cycle-.8)*.014*effort)
 elseif stage==3 then
  -- Feline walk-to-gallop blend: four staggered contacts, shorter airborne recovery.
  -- Legs are rigid groups in this rig; this does not pretend to add knee IK.
  local run=math.clamp(((speed or (urgency or 0)*34)-11)/23,0,1)
  run=run*run*(3-2*run)
  local turnLean=math.clamp(turning or 0,-1,1)*moving
  local pitch=math.sin(cycle*2-.5)*(.014+.048*run)*moving
  local body=turn(pivots.Body,-.025*moving-.065*effort+pitch+breath*.004,
      math.sin(cycle)*.012*moving,math.sin(cycle)*.015*moving-turnLean*.075)
  frames.Body=body
  -- Counter-motion keeps the gaze steadier than the shoulder bounce.
  frames.Head=body*turn(pivots.Head,-.24*sleep+breath*.006-pitch*.80,
      math.sin(t*.65)*.035*blend*(1-moving)-turnLean*.10,turnLean*.045)
  local walking={LeftFrontLeg=0,RightFrontLeg=.5,LeftBackLeg=.75,RightBackLeg=.25}
  local running={LeftFrontLeg=0,RightFrontLeg=.14,LeftBackLeg=.52,RightBackLeg=.67}
  for group,pivot in pairs(pivots)do
   if group:find('Leg')then
    local front=group:find('Front')~=nil;local side=group:find('Left')and -1 or 1
    local offset=walking[group]+(running[group]-walking[group])*run
    local u=(cycle/(math.pi*2)+offset)%1
    local stance=.66-.20*run
    local stride,lift
    if u<stance then
      local contactPhase=u/stance
      stride=math.cos(contactPhase*math.pi);lift=0
    else
      local recovery=(u-stance)/(1-stance)
      stride=-math.cos(recovery*math.pi);lift=math.sin(recovery*math.pi)^2*(.18+.34*run)
    end
    local swing=stride*moving*(.38+.30*run)*(front and 1 or 1.08)
    frames[group]=body*CF(0,lift*moving,0)*turn(pivot,
        sleep*(front and 1.30 or -1.45)+swing,0,-side*.25*sleep+side*.015*moving)
   elseif group=='Tail'then
    frames.Tail=body*turn(pivot,math.sin(cycle-.8)*.045*moving,
        (math.sin(t*1.4)*.09*(1-moving)+math.sin(cycle-1.15)*(.14+.09*run)*moving)*blend+turnLean*.22,
        math.sin(cycle-1.5)*.025*moving)
   end
  end
 else
  local style=styles[stage];local mass=weight[stage]
  local lean=(stage==6 and -.14*moving or -.025*moving)-mass.Lean*effort
  local body=turn(pivots.Body,(style.Pitch or 0)*sleep+lean+breath*.004+math.sin(cycle*2-.35)*.035*effort,
                  math.sin(cycle)*.014*moving,(style.Roll or 0)*sleep+math.sin(cycle)*(.018*moving+mass.Roll*effort))
  frames.Body=body
  frames.Head=body*turn(pivots.Head,style.Head*sleep+breath*.006+.06*effort*math.sin(cycle*2-1.05),
                        math.sin(t*.7)*.025*blend*(1-effort),0)
  for group,pivot in pairs(pivots) do
   local side=group:find('Left') and -1 or 1
   if group:find('Wing') then
    local bird=stage==7
    local wave=math.sin(t*2.2)*(1-moving)+math.sin(cycle-.4)*moving
    local flap=(wave*(bird and (.14+.40*moving) or (.06+.16*moving))
               +math.sin(cycle-.85)*(bird and .15 or .08)*effort)*blend
    frames[group]=body*turn(pivot,0,-side*sleep*(bird and 1.22 or 1.08),
                            -side*sleep*(bird and .53 or .57)+side*flap)
   elseif group:find('Leg') or group:find('Arm') then
    local arm=group:find('Arm')~=nil
    local front=group:find('Front') or arm
    local angle=cycle+legPhase(stage,group)
    -- A shorter recovery and firmer plant make the stride feel driven, not a uniform pendulum.
    local stride=math.sin(angle)+.20*effort*math.sin(angle*2)
    local swing=stride*moving*(arm and .48 or style.Swing)*(1+.24*effort)
    local fold=front and style.FrontFold or style.BackFold
    local splay=-side*style.Splay*sleep
    if stage==5 then splay=side*style.Splay*sleep end
    if stage==6 then splay=-side*(arm and .62 or .12)*sleep end
    -- Lift the feet relative to the torso on impact; final grounding lowers the torso.
    -- A uniform whole-body Y offset would be erased by the grounding pass below.
    frames[group]=body*CF(0,mass.Press*contact*effort,0)*turn(pivot,sleep*fold+swing,0,splay)
   elseif group=='Tail' then
    frames[group]=body*turn(pivot,0,(math.sin(t*1.7)*.025*(1-moving)+math.sin(cycle-.9)*(.185*moving+.065*effort))*blend,0)
   end
  end
 end
 if pivots.Jaw then
  local open=blend*(.015+moving*(stage==6 and .13 or .09)+.035*effort)*(.9+math.sin(t*2.8)*.1)
  frames.Jaw=frames.Head*turn(pivots.Jaw,-open,0,0)
 end
 -- Ground the entire visual assembly using its actual (length-adjusted) hull.
 -- Limbs fold relative to the body; this correction cannot undo the sleep pose.
 local lowest=math.huge
 for group,samples in pairs(rig.FloorSamples) do
  local frame=assert(frames[group],'Missing keeper pose group: '..group)
  for _,p in ipairs(samples) do lowest=math.min(lowest,(frame*p).Y) end
 end
 local lift=CF(0,-4-lowest,0)
 for group,frame in pairs(frames) do frames[group]=lift*frame end
 return frames
end

function Pose.Group(stage,group,t,awake,moving,phase,urgency)
 return assert(Pose.Frames(stage,t,awake,moving,phase,urgency)[group],'Missing keeper group')
end
return Pose
