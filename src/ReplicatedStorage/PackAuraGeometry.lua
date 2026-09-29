-- V146: orbit geometry is authored in the pack's own frame, using its visible bounds.
local G={}
function G.Bounds(parts,frames,scale)
 local low=Vector3.new(math.huge,math.huge,math.huge);local high=-low;local found=false
 for index,part in ipairs(parts)do if part.Transparency<.95 then
  local cf=frames[index];local half=part.Size/2
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
   local point=cf:PointToWorldSpace(Vector3.new(x*half.X,y*half.Y,z*half.Z))
   low=Vector3.new(math.min(low.X,point.X),math.min(low.Y,point.Y),math.min(low.Z,point.Z))
   high=Vector3.new(math.max(high.X,point.X),math.max(high.Y,point.Y),math.max(high.Z,point.Z));found=true
  end end end
 end end
 if not found then return {Center=Vector3.zero,Half=Vector3.new(.95,1.12,.4)*scale}end
 return {Center=(low+high)/2,Half=(high-low)/2}
end
function G.Frame(rootFrame,bounds)return rootFrame*CFrame.new(bounds.Center)end
function G.Ellipse(angle,record,scale,bounds)
 local rx=(bounds.Half.X+.20*scale)*(record.Radius/1.22)
 local ry=(bounds.Half.Y+.22*scale)*(record.Height/1.48)
 local position=Vector3.new(math.cos(angle)*rx,math.sin(angle)*ry,0)
 local tangent=Vector3.new(-math.sin(angle)*rx,math.cos(angle)*ry,0)
 -- No world-space tilt/depth offset: the ring plane follows the bag front exactly.
 return CFrame.fromMatrix(position,tangent.Unit,Vector3.zAxis),tangent.Magnitude
end
return G
