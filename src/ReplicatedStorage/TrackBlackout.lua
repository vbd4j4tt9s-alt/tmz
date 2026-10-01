-- R64: opaque, roofed covers over every biome. Existing entrance collision stays authoritative.
-- R122: the cover is only the track's size: field width plus the side walls (±94 on a 180 field) and
-- just above the 48-stud track side walls (top Y 51), instead of a 300 x 500 stud black tower.
local B={}
B.SideMargin=4 -- side walls stand at ±(90..94) on a 180-stud field
B.Bottom=-15;B.Top=55 -- world Y; every track part sits below 51 (tallest tree crown 50.5)
function B.HalfWidth(fieldWidth)return math.max(90,tonumber(fieldWidth)or 180)/2+B.SideMargin end
function B.Bounds(map)
 local bounds={HalfWidth=B.HalfWidth(map:GetAttribute('FieldWidth')),Regions={}}
 for stage=1,7 do
  local a,b=map:GetAttribute('BiomeStartZ_'..stage),map:GetAttribute('BiomeEndZ_'..stage)
  if type(a)=='number'and type(b)=='number'then bounds.Regions[#bounds.Regions+1]={a-1,b+1}end
 end
 return bounds
end
function B.InBounds(bounds,position)
 if not bounds or math.abs(position.X)>bounds.HalfWidth or position.Y<B.Bottom or position.Y>B.Top then return false end
 for _,region in ipairs(bounds.Regions)do if position.Z>=region[1]and position.Z<=region[2]then return true end end
 return false
end
function B.Contains(map,position)return B.InBounds(B.Bounds(map),position)end
function B.Build(map,parent,fieldWidth)
 local folder=Instance.new('Folder');folder.Name='TrackRefreshBlackout';folder.Parent=parent
 for stage=1,7 do
  local a,b=map:GetAttribute('BiomeStartZ_'..stage),map:GetAttribute('BiomeEndZ_'..stage)
  if type(a)=='number'and type(b)=='number'and b>a then
   local n=math.ceil((b-a)/1800)
   for i=1,n do
    local lo=a+(b-a)*(i-1)/n;local hi=a+(b-a)*i/n
    local p=Instance.new('Part');p.Name='OpaqueBiome'..stage;p.Size=Vector3.new(2*B.HalfWidth(map:GetAttribute('FieldWidth')or fieldWidth),B.Top-B.Bottom,hi-lo+2)
    p.CFrame=CFrame.new(0,(B.Top+B.Bottom)/2,(lo+hi)/2);p.Color=Color3.new();p.Material=Enum.Material.SmoothPlastic;p.Transparency=0
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p:SetAttribute('TrackBlackout',true);p.Parent=folder
   end
  end
 end
 return folder
end
return B
