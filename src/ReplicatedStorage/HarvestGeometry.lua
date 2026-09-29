local G={}
function G.Bounds(model)
 local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo;local count=0
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then
  count+=1;local size=(p:GetAttribute('ArtSize')or p.Size)*.5
  if p:IsA('Part')and p.Shape==Enum.PartType.Cylinder then size=p.Size*.5 end
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
   local q=p.CFrame*Vector3.new(size.X*x,size.Y*y,size.Z*z)
   lo=Vector3.new(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=Vector3.new(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))
  end end end
 end end
 if count==0 then return Vector3.zero,Vector3.one end
 return(lo+hi)*.5,hi-lo
end
function G.Grip(model)
 local best,score
 for _,part in ipairs(model:GetDescendants())do if part:IsA('BasePart')and part.Transparency<.95 then
  local size=part:GetAttribute('ArtSize')or part.Size;local weight=size.X*size.Y*size.Z
  if part.Name=='Flower cup base'or part.Name:lower():find('core',1,true)then weight*=8 end
  if part.Name:lower():find('petal',1,true)or part:GetAttribute('PlantSurfaceDetail')then weight*=.04 end
  if not score or weight>score then best=part;score=weight end
 end end
 if not best then return Vector3.zero end
 local size=best:GetAttribute('ArtSize')or best.Size
 if best:IsA('Part')and best.Shape==Enum.PartType.Cylinder then size=best.Size end
 -- Attach an actual fruit surface to the hand; no radius-based air gap.
 return best.CFrame:PointToWorldSpace(Vector3.new(0,-size.Y*.08,size.Z*.43))
end
return G
