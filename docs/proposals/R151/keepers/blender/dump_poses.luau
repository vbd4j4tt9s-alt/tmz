--!nocheck
-- Group frames for every keeper from the REAL pose modules (BeastPose, KeeperSignatureStrike, VeiledKeeper81) on the Roblox mock.
-- Prints JSON: {stages:{"1":{poses:{name:{group:[12 comps]}}}}, veiled:{poses:{...}}}
local W=require('./world');local R=W.R
local Pose=W.module('BeastPose');local Sig=W.module('KeeperSignatureStrike');local Combat=W.module('KeeperCombat')
local Veiled=W.module('VeiledKeeper81')
local V,CF=R.Vector3.new,R.CFrame.new
local function comps(cf)local x,y,z,a,b,c,d,e,f,g,h,i=cf:GetComponents();return string.format('[%.5f,%.5f,%.5f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f]',x,y,z,a,b,c,d,e,f,g,h,i)end
local function framesJson(frames)
 local out={};local keys={};for k in pairs(frames)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do out[#out+1]=string.format('"%s":%s',k,comps(frames[k]))end
 return '{'..table.concat(out,',')..'}'
end
local stages={}
for stage=1,7 do
 local poses={}
 poses[#poses+1]='"stand":'..framesJson(Pose.Frames(stage,1,1,0,0,0,0,0))
 poses[#poses+1]='"sleep":'..framesJson(Pose.Frames(stage,1,0,0,0,0,0,0))
 -- chase stride: full urgency, mid-cycle, near top speed
 poses[#poses+1]='"run":'..framesJson(Pose.Frames(stage,2,1,1,1.3,1,60,0))
 poses[#poses+1]='"run2":'..framesJson(Pose.Frames(stage,2,1,1,1.3+math.pi,1,60,0))
 local started=10;local w=Combat.Get(stage).Windup
 poses[#poses+1]='"cock":'..framesJson(Sig.Frames(stage,started+w*.6,started,nil))
 poses[#poses+1]='"strike":'..framesJson(Sig.Frames(stage,started+w+.03,started,nil))
 stages[#stages+1]=string.format('"%d":{%s}',stage,table.concat(poses,','))
end
-- The Darkened: K.Frames on a mock model (root at origin), awake chasing, and the client's spectral lunge.
local function veiledModel(state,awakeAt,attackAt)
 local m=R.new('Model');local root=R.new('Part');root.Name='VeiledRoot';root.CFrame=CF(0,0,0);root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('GuardianBehavior',state);m:SetAttribute('VeiledAwakeAt',awakeAt);m:SetAttribute('KeeperTravelSpeed',40)
 if attackAt then m:SetAttribute('KeeperAttackAt',attackAt)end
 return m
end
local vposes={}
local now=R.clock
vposes[#vposes+1]='"stand":'..framesJson(Veiled.Frames(veiledModel('ALERTED',now-5,nil),now))
vposes[#vposes+1]='"sleep":'..framesJson(Veiled.Frames(veiledModel('GUARDING',now-5,nil),now))
vposes[#vposes+1]='"run":'..framesJson(Veiled.Frames(veiledModel('CHASING',now-5,nil),now+0.05))
local w=Combat.Get(7).Windup
vposes[#vposes+1]='"strike":'..framesJson(Veiled.ClientFrames(veiledModel('ATTACKING',now-5,now-w-.03),now,nil))
vposes[#vposes+1]='"cock":'..framesJson(Veiled.ClientFrames(veiledModel('ATTACKING',now-5,now-w*.6),now,nil))
local Acc=W.module('KeeperAccents');local Cfg=W.module('KeeperRigConfig')
local function col(c)return string.format('[%.4f,%.4f,%.4f]',c.R,c.G,c.B)end
local function accModel(stage)
 local m=R.new('Model');local body=R.new('Model');body.Name='BeastBody';body.Parent=m
 for _,p in ipairs(Cfg[stage].Parts)do if p.Group=='Body'then
  local part=R.new('Part');part.Size=V(p.Size[1],p.Size[2],p.Size[3]);part:SetAttribute('BeastGroup','Body');part.Parent=body end end
 return m
end
local accOut={}
for _,stage in ipairs({1,2,3,5,7})do
 local per={}
 for _,pn in ipairs({'stand','run','cock','strike','sleep'})do
  local frames
  local started=10;local w=Combat.Get(stage).Windup
  if pn=='stand'then frames=Pose.Frames(stage,1,1,0,0,0,0,0)elseif pn=='sleep'then frames=Pose.Frames(stage,1,0,0,0,0,0,0)
  elseif pn=='run'then frames=Pose.Frames(stage,2,1,1,1.3,1,60,0)elseif pn=='cock'then frames=Sig.Frames(stage,started+w*.6,started,nil)
  else frames=Sig.Frames(stage,started+w+.03,started,nil)end
  local acc=Acc.new(accModel(stage),stage);local parts,out={},{}
  Acc.Pose(acc,frames,CF(0,0,0),pn=='sleep'and 0 or 1,R.clock,pn~='stand'and pn~='sleep',parts,out,30,false)
  local items={}
  for i,it in ipairs(acc.Items)do
   local p=it.Part
   if (p.LocalTransparencyModifier or 0)>=.99 then continue end
   local shape=p.Shape and p.Shape.Name or 'Block';if p.ClassName=='WedgePart'then shape='Wedge'end
   items[#items+1]=string.format('{"m":%s,"s":[%.3f,%.3f,%.3f],"c":%s,"mat":"%s","t":%.2f,"sh":"%s"}',comps(out[i]),p.Size.X,p.Size.Y,p.Size.Z,col(p.Color),p.Material.Name,p.Transparency,shape)
  end
  per[#per+1]=string.format('"%s":[%s]',pn,table.concat(items,','))
 end
 accOut[#accOut+1]=string.format('"%d":{%s}',stage,table.concat(per,','))
end
print('{"accents":{'..table.concat(accOut,',')..'},"stages":{'..table.concat(stages,',')..'},"veiled":{'..table.concat(vposes,',')..'}}')
