-- Server-derived lift landing. Nearby canopy raises the landing instead of rejecting the lift.
local L={}
function L.Find(world,surface,width,height,exclude)
 local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances=exclude;overlap.RespectCanCollide=true;overlap.MaxParts=40
 for _=1,12 do
  local raised=surface.Y;local blocked=false
  local box=CFrame.new(surface+Vector3.new(0,height/2+.3,0))
  for _,part in ipairs(world:GetPartBoundsInBox(box,Vector3.new(width,height,width),overlap))do
   if part:IsA('BasePart')and part.CanCollide then
    local cf,z=part.CFrame,part.Size
    local half=(math.abs(cf.RightVector.Y)*z.X+math.abs(cf.UpVector.Y)*z.Y+math.abs(cf.LookVector.Y)*z.Z)*.5
    raised=math.max(raised,part.Position.Y+half+.4);blocked=true
   end
  end
  if not blocked then return surface end
  surface=Vector3.new(surface.X,math.max(surface.Y+.4,raised),surface.Z)
 end
 return nil -- Exceptional moving obstruction: leave the player in place without a rejection banner.
end
return L
