-- R38: rigid tree-to-golem morph and grounded biped poses, driven by the existing client loop.
local Data=require(script.Parent.KeeperUpgradeData)
local Pose={}
local CF,V=CFrame.new,Vector3.new
local pivots={}
for stage,rig in pairs(Data)do
 pivots[stage]={};for name,p in pairs(rig.Pivots)do pivots[stage][name]=V(table.unpack(p))end
end
local function turn(p,x,y,z)return CF(p)*CFrame.Angles(x,y,z)*CF(-p)end
-- R152: variant 'R152' (the baked rev 6 model, KeeperRigConfig152) grounds with that model's feet; nil = today's.
local floors={}
local function floor(stage,rig,variant)
 if variant~='R152'then return rig.FloorSamples end
 local f=floors[stage];if not f then f=require(script.Parent.KeeperRigConfig152).Stages[stage].FloorSamples;floors[stage]=f end
 return f
end
function Pose.Frames(stage,t,awake,moving,phase,urgency,speed,turning,variant)
 local rig=Data[stage];if not rig then return nil end
 local scale=rig.Scale or 1
 local a=math.clamp(awake,0,1);local blend=a*a*(3-2*a)
 local walk=math.clamp(moving,0,1)*blend;local cycle=phase or t*4
 local effort=math.clamp(urgency or 0,0,1)*walk;local p=pivots[stage]
 local body=turn(p.Body,-.055*walk-.065*effort+math.sin(cycle*2)*.018*walk,
  math.sin(cycle)*.018*walk,-math.clamp(turning or 0,-1,1)*.045*walk)
 local frames={Body=body,Head=body*turn(p.Head,.06*(1-blend),math.sin(t*.55)*.025*blend,0)}
 for _,side in ipairs({'Left','Right'})do
  local sign=side=='Left'and -1 or 1;local angle=cycle+(sign<0 and 0 or math.pi)
  local swing=math.sin(angle)*walk
  frames[side..'Leg']=CF(0,math.max(0,math.cos(angle))*.32*scale*walk,0)*turn(p[side..'Leg'],swing*.48,0,0)
  frames[side..'Arm']=body*turn(p[side..'Arm'],-swing*(stage==5 and .24 or .44),0,sign*(.04+.035*effort))
 end
 -- Ground only the actual feet; preserve torso weight and lifting recovery foot.
 local low=math.huge
 for group,samples in pairs(floor(stage,rig,variant))do
  for _,point in ipairs(samples)do low=math.min(low,(frames[group]*V(table.unpack(point))).Y)end
 end
 local lift=CF(0,-4-low,0)
 for group,f in pairs(frames)do frames[group]=lift*f end
 if stage==5 then frames=require(script.Parent.CrystalKnightPose).Adapt(frames,a,moving,cycle,t,0,0)end
 return frames
end
function Pose.PartPose(rest,treeRest,size,treeSize,groupFrame,awake)
 if not treeRest then return groupFrame*rest,size end
 local a=math.clamp(awake,0,1);local blend=a*a*(3-2*a)
 return treeRest:Lerp(groupFrame*rest,blend),treeSize:Lerp(size,blend)
end
return Pose
