local Core=require(game:GetService('ReplicatedStorage'):WaitForChild('KeyboardCore143'))
local S={Backing=Color3.fromRGB(36,23,29)}
function S.floors(map)
 local list={}
 for _,p in ipairs(map:GetDescendants())do
  if p:IsA('BasePart')and(p.Name=='LobbyFloor'or p.Name:match('^BiomeGround_%d')or(p.Name=='Pad'and p.Parent.Parent.Name=='Bases'and p.Size.X>=60 and p.Size.Z>=60))then
   assert(p.Anchored and p.CFrame.UpVector.Y>.999,'R143 requires anchored level floor '..p:GetFullName())
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
 for i,p in ipairs(S.floors(map))do rows[i]={Id=i,Part=p,Frame=p.CFrame*CFrame.new(0,p.Size.Y/2,0),Grid=Core.grid(p.Size.X,p.Size.Z),Enabled=true,Keyboard=p.Name:match("^BiomeGround_%d+")~=nil,Stage=tonumber(p.Name:match('^BiomeGround_(%d+)'))or 0}end
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
 if not s or s.Keyboard==false or math.abs(p.Y)>.65 then return end
 local right,forward=s.Frame.RightVector,s.Frame.LookVector
 local localX=math.abs(right.X)*rx+math.abs(right.Z)*rz
 local localZ=math.abs(forward.X)*rx+math.abs(forward.Z)*rz
 Core.cells(s.Grid,p.X,p.Z,localX,localZ,function(x,z)
  local lx,lz=Core.center(s.Grid,x,z)
  local chosen=S.at(rows,s.Frame:PointToWorldSpace(Vector3.new(lx,0,lz)))
  if chosen==s then keys[Core.id(s.Id,x,z)]=true end
 end)
end
S.Biomes={
 [1]={Name='SUNNY_MEADOW',Fill={82,180,87},Ink={38,83,44}},
 [2]={Name='GOLDEN_DESERT',Fill={224,188,103},Ink={112,80,43}},
 [3]={Name='FROSTLAND',Fill={176,194,204},Ink={77,106,123}},
 [4]={Name='EMBER_WASTES',Fill={62,55,66},Ink={32,27,32}},
 [5]={Name='CRYSTAL_WILDS',Fill={91,67,132},Ink={43,31,67}},
 [6]={Name='JUNGLE',Fill={78,133,62},Ink={35,65,33}},
 [7]={Name='STORM_PEAKS',Fill={88,111,144},Ink={41,53,77}},
}
function S.palette(stage,x,z)
 local biome=assert(S.Biomes[stage],'R143 unknown track stage')
 local delta=({0,5,-4,2})[(x*7+z*11)%4+1];local c=biome.Fill
 return Color3.fromRGB(math.clamp(c[1]+delta,0,255),math.clamp(c[2]+delta,0,255),math.clamp(c[3]+delta,0,255))
end
function S.fill(stage)return Color3.fromRGB(table.unpack(assert(S.Biomes[stage]).Fill))end
function S.ink(stage)return Color3.fromRGB(table.unpack(assert(S.Biomes[stage]).Ink))end
-- AABB in world space; only used for narrow permanently pressed support footprints, never removal.
function S.extents(part)
 local c,h=part.CFrame,part.Size*.5;local a,b,d=c.RightVector,c.UpVector,c.LookVector
 return Vector3.new(math.abs(a.X)*h.X+math.abs(b.X)*h.Y+math.abs(d.X)*h.Z,
  math.abs(a.Y)*h.X+math.abs(b.Y)*h.Y+math.abs(d.Y)*h.Z,
  math.abs(a.Z)*h.X+math.abs(b.Z)*h.Y+math.abs(d.Z)*h.Z)
end

-- Convex subtraction preserves garden/row edges without dropping entire border cells.
local function cross(a,b,p)return(b[1]-a[1])*(p[2]-a[2])-(b[2]-a[2])*(p[1]-a[1])end
local function half(poly,a,b,inside)
 local result={}
 for i,p in ipairs(poly)do
  local q=poly[i%#poly+1];local dp,dq=cross(a,b,p),cross(a,b,q)
  local pin,qin=inside and dp>=-1e-8 or not inside and dp<=1e-8,inside and dq>=-1e-8 or not inside and dq<=1e-8
  if pin then result[#result+1]=p end
  if pin~=qin then local t=dp/(dp-dq);result[#result+1]={p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t}end
 end
 return result
end
function S.area(poly)
 local sum=0;for i,p in ipairs(poly)do local q=poly[i%#poly+1];sum+=p[1]*q[2]-q[1]*p[2]end
 return math.abs(sum)/2
end
function S.masks(rows,row)
 local masks={}
 for _,other in ipairs(rows)do
  if other==row then break end
  if other.Enabled~=false then
   local g=other.Grid;local poly={}
   for _,p in ipairs({{-g.X/2,-g.Z/2},{g.X/2,-g.Z/2},{g.X/2,g.Z/2},{-g.X/2,g.Z/2}})do
    local v=row.Frame:PointToObjectSpace(other.Frame:PointToWorldSpace(Vector3.new(p[1],0,p[2])));poly[#poly+1]={v.X,v.Z}
   end
   masks[#masks+1]=poly
  end
 end
 return masks
end
function S.subtract(poly,masks)
 local pieces={poly}
 for _,mask in ipairs(masks)do
  local nextPieces={}
  for _,piece in ipairs(pieces)do
   local remaining=piece
   for i,a in ipairs(mask)do
    if #remaining<3 then break end
    local b=mask[i%#mask+1];local outside=half(remaining,a,b,false)
    if #outside>=3 and S.area(outside)>1e-6 then nextPieces[#nextPieces+1]=outside end
    remaining=half(remaining,a,b,true)
   end
  end
  pieces=nextPieces
 end
 return pieces
end
function S.rectangle(x0,z0,x1,z1)return{{x0,z0},{x1,z0},{x1,z1},{x0,z1}}end
function S.insideCell(row,x,z,masks)
 local cx,cz,w,d=Core.bounds(row.Grid,x,z)
 local pieces=S.subtract(S.rectangle(cx-w/2,cz-d/2,cx+w/2,cz+d/2),masks)
 local area=0;for _,poly in ipairs(pieces)do area+=S.area(poly)end
 return math.abs(area-w*d)<1e-5
end
function S.segments(a,b,masks,margin)
 local pieces={{a,b}}
 for _,mask in ipairs(masks)do
  local nextPieces={}
  for _,segment in ipairs(pieces)do
   local p,q=segment[1],segment[2];local enter,leave=0,1;local intersects=true
   for i,v in ipairs(mask)do
    local w=mask[i%#mask+1];local length=math.sqrt((w[1]-v[1])^2+(w[2]-v[2])^2)
    local dp,dq=cross(v,w,p)+(margin or 0)*length,cross(v,w,q)+(margin or 0)*length
    if dp<0 and dq<0 then intersects=false;break end
    if dp<0 then enter=math.max(enter,dp/(dp-dq))elseif dq<0 then leave=math.min(leave,dp/(dp-dq))end
   end
   if not intersects or enter>leave then nextPieces[#nextPieces+1]=segment
   else
    local function at(t)return{p[1]+(q[1]-p[1])*t,p[2]+(q[2]-p[2])*t}end
    if enter>1e-6 then nextPieces[#nextPieces+1]={p,at(enter)}end
    if leave<1-1e-6 then nextPieces[#nextPieces+1]={at(leave),q}end
   end
  end
  pieces=nextPieces
 end
 return pieces
end

return S
