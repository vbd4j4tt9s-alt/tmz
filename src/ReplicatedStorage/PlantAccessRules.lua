-- V145: shared interaction distances, with authoritative checks repeated by the server.
local Access={HarvestDistance=55,GiantHeight=60,TeleportDistance=5,TeleportGroundHeight=12,TeleportCooldown=3,TreeCollisionHeight=10}
function Access.IsGiant(def,scale)return def~=nil and def.Height*scale>=Access.GiantHeight end
function Access.IsSolid(def,scale)return def~=nil and def.Tree==true and scale<=10 and def.Height*scale>=Access.TreeCollisionHeight end
function Access.NearBase(position,base)
 local delta=position-base
 return delta.X==delta.X and delta.Y==delta.Y and delta.Z==delta.Z
  and math.abs(delta.Y)<=Access.TeleportGroundHeight and delta.X*delta.X+delta.Z*delta.Z<=Access.TeleportDistance^2
end
return Access
