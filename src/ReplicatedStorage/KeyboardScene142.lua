local Core=require(game:GetService('ReplicatedStorage'):WaitForChild('KeyboardCore142'))
local S={Backing=Color3.fromRGB(36,23,29)}
function S.floors(map)
 local list={}
 for _,p in ipairs(map:GetDescendants())do
  if p:IsA('BasePart')and(p.Name=='LobbyFloor'or p.Name:match('^BiomeGround_%d')or(p.Name=='Pad'and p.Parent.Parent.Name=='Bases'and p.Size.X>=60 and p.Size.Z>=60))then
   assert(p.Anchored and p.CFrame.UpVector.Y>.999,'R142 requires anchored level floor '..p:GetFullName())
   list[#list+1]=p
  end
 end
 table.sort(list,function(a,b)
  local pa,pb=a.Name=='Pad'and 2 or 1,b.Name=='Pad'and 2 or 1
  if pa~=pb then return pa>pb end;return a:GetFullName()<b:GetFullName()
 end)
 return list
end
function S.describe(map)
 local rows={}
 for i,p in ipairs(S.floors(map))do rows[i]={Id=i,Part=p,Frame=p.CFrame*CFrame.new(0,p.Size.Y/2,0),Grid=Core.grid(p.Size.X,p.Size.Z),Enabled=true,Stage=tonumber(p.Name:match('^BiomeGround_(%d+)'))or 0}end
 return rows
end
-- Highest priority pad beats underlying lobby; exact rotated bounds shared by every consumer.
function S.at(rows,point)
 for _,s in ipairs(rows)do
  if s.Enabled~=false and(not s.Part or s.Part.Parent)then
   local p=s.Frame:PointToObjectSpace(point);local g=s.Grid
   if math.abs(p.X)<=g.X/2 and math.abs(p.Z)<=g.Z/2 then return s,p end
  end
 end
 return nil
end
function S.contact(rows,point,rx,rz,keys)
 local s,p=S.at(rows,point)
 if not s or math.abs(p.Y)>.65 then return end
 local right,forward=s.Frame.RightVector,s.Frame.LookVector
 local localX=math.abs(right.X)*rx+math.abs(right.Z)*rz
 local localZ=math.abs(forward.X)*rx+math.abs(forward.Z)*rz
 Core.cells(s.Grid,p.X,p.Z,localX,localZ,function(x,z)
  local lx,lz=Core.center(s.Grid,x,z)
  local chosen=S.at(rows,s.Frame:PointToWorldSpace(Vector3.new(lx,0,lz)))
  if chosen==s then keys[Core.id(s.Id,x,z)]=true end
 end)
end
function S.palette(stage,x,z)
 local brown={Color3.fromRGB(127,78,49),Color3.fromRGB(162,112,80),Color3.fromRGB(108,60,39),Color3.fromRGB(188,140,106)}
 local candy={Color3.fromRGB(138,76,187),Color3.fromRGB(215,124,181),Color3.fromRGB(170,105,205),Color3.fromRGB(235,156,200)}
 local colors=(stage%2==0)and candy or brown
 return colors[(x*7+z*11)%#colors+1]
end
-- AABB in world space; only used for narrow permanently pressed support footprints, never removal.
function S.extents(part)
 local c,h=part.CFrame,part.Size*.5;local a,b,d=c.RightVector,c.UpVector,c.LookVector
 return Vector3.new(math.abs(a.X)*h.X+math.abs(b.X)*h.Y+math.abs(d.X)*h.Z,
  math.abs(a.Y)*h.X+math.abs(b.Y)*h.Y+math.abs(d.Y)*h.Z,
  math.abs(a.Z)*h.X+math.abs(b.Z)*h.Y+math.abs(d.Z)*h.Z)
end
return S
