local Pose=require(script.Parent.BeastPose)
local Attack=require(script.Parent.KeeperAttackPose)
local S={}
-- R112: lead is client-only (late replication); the server passes nil and gets the exact timeline.
-- R152: variant 'R152' = a keeper built from the baked rev 6 model (grounded with its own floor samples); nil = today's.
function S.Frames(stage,now,started,lead,variant)
 return Attack.Apply(stage,Pose.Frames(stage,now,1,0,0,0,0,0,variant),now,started,lead)
end
return S
