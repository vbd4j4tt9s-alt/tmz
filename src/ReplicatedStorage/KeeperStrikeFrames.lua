local Pose=require(script.Parent.BeastPose)
local Attack=require(script.Parent.KeeperAttackPose)
local S={}
-- R112: lead is client-only (late replication); the server passes nil and gets the exact timeline.
function S.Frames(stage,now,started,lead)
 return Attack.Apply(stage,Pose.Frames(stage,now,1,0,0,0,0,0),now,started,lead)
end
return S
