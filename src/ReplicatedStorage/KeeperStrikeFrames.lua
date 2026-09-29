local Pose=require(script.Parent.BeastPose)
local Attack=require(script.Parent.KeeperAttackPose)
local S={}
function S.Frames(stage,now,started)
 return Attack.Apply(stage,Pose.Frames(stage,now,1,0,0,0,0,0),now,started)
end
return S
