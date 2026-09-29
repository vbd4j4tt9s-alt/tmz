-- Same basal-surface check on client visibility and authoritative server teleport.
local C={Distance=3,GroundHeight=12}
function C.IsStem(p)
 local role=p:GetAttribute('GrowthRole');local name=p.Name:lower()
 return role=='Stem'or name:find('root',1,true)~=nil or name:find('stem',1,true)~=nil or name:find('trunk',1,true)~=nil
end
function C.Find(model,position,candidates)
 local pivot=model and model.PrimaryPart;if not pivot then return nil end
 if math.abs(position.Y-pivot.Position.Y)>C.GroundHeight then return nil end
 local parts=model:FindFirstChild('SolidPlant');if not parts then return nil end
 local best,nearest=nil,C.Distance
 for _,p in ipairs(candidates or parts:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then
  if C.IsStem(p)then
   local q=p.CFrame:PointToObjectSpace(position);local h=p.Size*.5
   local at=p.CFrame:PointToWorldSpace(Vector3.new(math.clamp(q.X,-h.X,h.X),math.clamp(q.Y,-h.Y,h.Y),math.clamp(q.Z,-h.Z,h.Z)))
   local gap=(position-at).Magnitude
   if gap<=nearest then nearest=gap;best=at end
  end
 end end
 return best
end
return C
