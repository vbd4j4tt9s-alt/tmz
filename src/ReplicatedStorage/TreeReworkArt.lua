-- Production art and attachment frames share one deterministic crop variant.
local RS=game:GetService('ReplicatedStorage')
local Index={["AncientWorldrootSeed"]="TreeReworkData1",["AppleSeed"]="TreeReworkData2",["CocoaSeed"]="TreeReworkData3",["ElderbloomSeed"]="TreeReworkData4",["EmberEmperorSeed"]="TreeReworkData5",["MirageFigSeed"]="TreeReworkData6",["PrismMonarchSeed"]="TreeReworkData7",["PulsarStarfruitSeed"]="TreeReworkData8",["SolarStarfruitSeed"]="TreeReworkData9",["StarfruitSeed"]="TreeReworkData10",["StormSovereignSeed"]="TreeReworkData11",["WinterCrownwoodSeed"]="TreeReworkData12"}
local M={};local loaded,variants={},{}
local function hash(id)local h=137;for i=1,#id do h=(h*33+id:byte(i))%2147483647 end;return h end
function M.Has(id)return Index[id]~=nil end
function M.Key(id,crop)
 if not Index[id]then return nil end
 if id=='StarfruitSeed'then return 'StarfruitSeed:sky-star38'end
 if not crop or not crop.Id or crop.Id=='preview'then return id..':tree33:base'end
 return id..':tree33:'..tostring(hash(tostring(crop.Id))%16)
end
function M.Base(id)
 if not Index[id]then return nil end
 if not loaded[id]then loaded[id]=require(RS:WaitForChild(Index[id]))end
 return loaded[id]
end
function M.Get(id,crop)
 local source=M.Base(id);if not source then return nil end
 if id=='StarfruitSeed'then return source end -- the star stays flat and faces the sky
 if not crop or not crop.Id or crop.Id=='preview'then return source end
 local key=M.Key(id,crop);if variants[key]then return variants[key]end
 local h=hash(tostring(crop.Id))%16
 local function rand(n)return ((h+1)*n*7919%65521)/65520 end
 local turn=CFrame.Angles((rand(23)-.5)*.06,(rand(41)-.5)*.26,(rand(71)-.5)*.09)
 local d={Specs={},Sockets={},FruitCenters={},FruitRadii=table.clone(source.FruitRadii),Height=source.Height*1.13,Radius=source.Radius*1.18,TreeRework=true}
 for i,s in ipairs(source.Specs)do
  local p=table.clone(s);local at=CFrame.new(table.unpack(s.c));p.z=table.clone(s.z)
  -- Root spread varies separately; the storm's channels remain joined to its root paths.
  if s.root and id~='StormSovereignSeed'then
   local f=.94+rand(97)*.14;local pos=at.Position
   at=CFrame.new(pos.X*f,pos.Y,pos.Z*f)*at.Rotation;p.z[1]*=f;p.z[3]*=f
  end
  p.c={(turn*at):GetComponents()}
  if s.tp then local v=turn:PointToWorldSpace(Vector3.new(table.unpack(s.tp)));p.tp={v.X,v.Y,v.Z}end
  if s.seam then p.z[1]*=.85+rand(113)*.28 end
  if s.g==0 and s.r=='Canopy'and s.m~='Neon'then
   local amount=(rand(i*31)-.5)*8;p.k={math.clamp(s.k[1]+amount,0,255),math.clamp(s.k[2]+amount,0,255),math.clamp(s.k[3]+amount,0,255)}
  end
  d.Specs[i]=p
 end
 for _,field in ipairs({'Sockets','FruitCenters'})do for i,xyz in ipairs(source[field])do
  local v=turn:PointToWorldSpace(Vector3.new(table.unpack(xyz)));d[field][i]={v.X,v.Y,v.Z}
 end end
 variants[key]=d;return d
end
function M.ApplyCatalog(catalog)
 for id in pairs(Index)do
  local d=catalog[id];local a=M.Base(id)
  -- Keep seed IDs, rarity, fruit counts, timings, values and the established growth profile.
  d.Sockets=a.Sockets;d.FruitCenters=a.FruitCenters;d.FruitRadii=a.FruitRadii
  d.Height=math.max(d.Height,a.Height*1.16);d.Radius=math.max(d.Radius,a.Radius*1.23+a.Height*.07)
 end
end
return M
