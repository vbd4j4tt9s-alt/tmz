-- Approved model selection. All transforms and fruit sockets share a stable crop seed.
local RS=game:GetService('ReplicatedStorage')
local Index=require(RS:WaitForChild('ApprovedPlantIndex'))
local Trees=require(RS:WaitForChild('TreeReworkArt'))
local Rarity=require(RS:WaitForChild('RarityPlantArt'))
local Art={};local loaded,variants,designCount={},{},{}
local function hash(id)
 local h=137;for i=1,#id do h=(h*33+string.byte(id,i))%2147483647 end;return h
end
local Mech=require(RS:WaitForChild('MechArt'))
local Verity=require(RS:WaitForChild('VerityPlantArt'))
local Desert149=require(RS:WaitForChild('DesertPlantArt149')) -- R148: the Aloe and the Sand Fruit cactus
-- R148: the Desert Aloe and Sand Fruit have four designs each, picked per crop like the approved plants' (hash of the crop id, then a small size / turn jitter).
local function multi(id)return Index[id]~=nil or Desert149.Is(id)end
-- The design a crop with hash h shows. The approved plants use h % count (their two designs follow the size digit h % 10); the Desert plants' four designs
-- use the digits above it, so every design comes with every size / turn jitter.
local function designOf(id,h,count)
 if Desert149.Is(id)then return math.floor(h/10)%count+1 end
 return h%count+1
end
function Art.Has(id)return Verity.Is(id)or Desert149.Is(id)or Mech.Get(id)~=nil or Rarity.Has(id)or Trees.Has(id)or Index[id]~=nil end
function Art.Key(id,crop)
 if require(RS.HologramProjection).Is(id)then return require(RS.HologramProjection).Key(id,crop)end
 if Rarity.Has(id)then return Rarity.Key(id)end
 if Trees.Has(id)then return Trees.Key(id,crop)end
 if not multi(id)then return id end
 if not crop or not crop.Id or crop.Id=='preview'then return id..':base'end
 local h=crop and crop.Id and hash(tostring(crop.Id))or 0
 -- (the design is part of the key: 4 designs are not decided by the jitter number h%10 the way an approved plant's 2 are)
 if Desert149.Is(id)then return id..':d'..tostring(designOf(id,h,Desert149.DesignCount))..':'..tostring(h%10)end
 -- R149: approved plants pick the design by h%#designs (designOf) and the size / turn jitter by h%10. When 10 is not a multiple of the
 -- design count (the Ash Tomato has 4) the jitter alone no longer names the design, so the key carries it too; 1, 2 and 5 designs keep their old keys.
 local n=designCount[id];if not n then n=#require(RS:WaitForChild(Index[id]));designCount[id]=n end
 return id..':'..tostring(h%10)..(10%n~=0 and('d'..tostring(h%n))or'')
end
function Art.Get(id,crop)
 if Verity.Is(id)then return Verity.Get(id)end
 local mech=Mech.Get(id);if mech then return require(RS.HologramForms).Get(id,mech,crop)end
 if Rarity.Has(id)then return Rarity.Get(id)end
 if Trees.Has(id)then return Trees.Get(id,crop)end
 if not multi(id)then return nil end
 if not loaded[id]then
  loaded[id]=Desert149.Is(id)and Desert149.Designs(id)or require(RS:WaitForChild(Index[id]))
  if id=='FirePepperSeed'then
   -- R148 (owner): the Mythic Fire Pepper is twice as big, peppers included (Roster149.FirePepperArtScale). Uniform: the lowest
   -- pepper hangs 2.57 studs under its socket, so scaling the fruit more than the plant would bury it.
   local f=require(RS:WaitForChild('Roster149')).FirePepperArtScale
   local scaled={};for i,source in ipairs(loaded[id])do
    local d=table.clone(source);d.Specs={};d.Sockets={};d.FruitCenters={};d.FruitRadii={};d.Height*=f;d.Radius*=f
    for j,s in ipairs(source.Specs)do local p=table.clone(s);p.z=table.clone(s.z);p.c=table.clone(s.c);for axis=1,3 do p.z[axis]*=f;p.c[axis]*=f end;d.Specs[j]=p end
    for _,field in ipairs({'Sockets','FruitCenters'})do for j,p in ipairs(source[field])do d[field][j]={p[1]*f,p[2]*f,p[3]*f}end end
    for j,r in ipairs(source.FruitRadii)do d.FruitRadii[j]=r*f end;scaled[i]=d
   end;loaded[id]=scaled
  end
  if id=='CactusSeed'or id=='AgaveSeed'then
   -- Enlarge the stem/shoulders 3x; fruit grows 2x around its relocated shoulder socket.
   local scaled={}
   for i,source in ipairs(loaded[id])do
    local d=table.clone(source);d.Specs={};d.Sockets={};d.FruitCenters={};d.FruitRadii={};d.Height*=3;d.Radius*=3
    for j,socket in ipairs(source.Sockets)do
     d.Sockets[j]={socket[1]*3,socket[2]*3,socket[3]*3}
     local c=source.FruitCenters[j];d.FruitCenters[j]={socket[1]*3+(c[1]-socket[1])*2,socket[2]*3+(c[2]-socket[2])*2,socket[3]*3+(c[3]-socket[3])*2};d.FruitRadii[j]=source.FruitRadii[j]*2
    end
    for j,s in ipairs(source.Specs)do
     local p=table.clone(s);p.z=table.clone(s.z);p.c=table.clone(s.c);local socket=s.g>0 and source.Sockets[s.g];local factor=socket and 2 or 3
     for axis=1,3 do p.z[axis]*=factor;p.c[axis]=socket and socket[axis]*3+(s.c[axis]-socket[axis])*2 or s.c[axis]*3 end
     d.Specs[j]=p
    end
    scaled[i]=d
   end
   loaded[id]=scaled
  end
  if id=='AncientWorldrootSeed'then
   local scaled={};for i,source in ipairs(loaded[id])do
    local d=table.clone(source);d.Specs={};d.Sockets={};d.FruitCenters={};d.FruitRadii={};d.Height*=1.20;d.Radius*=1.20
    for j,s in ipairs(source.Specs)do local p=table.clone(s);p.z=table.clone(s.z);p.c=table.clone(s.c);for axis=1,3 do p.z[axis]*=1.20;p.c[axis]*=1.20 end;d.Specs[j]=p end
    for _,field in ipairs({'Sockets','FruitCenters'})do for j,p in ipairs(source[field])do d[field][j]={p[1]*1.20,p[2]*1.20,p[3]*1.20}end end
    for j,r in ipairs(source.FruitRadii)do d.FruitRadii[j]=r*1.20 end;scaled[i]=d
   end;loaded[id]=scaled
  end
 end
 if not crop or not crop.Id or crop.Id=='preview'then return loaded[id][1]end
 local key=Art.Key(id,crop);if variants[key]then return variants[key]end
 local h=hash(tostring(crop.Id));local source=loaded[id][designOf(id,h,#loaded[id])]
 local shape=math.floor((h%10)/2)-2;local amount=1+shape*.01
 local turn=CFrame.Angles(0,shape*.04,0)
 local d={Specs={},Sockets={},FruitCenters={},FruitRadii={},Height=source.Height*amount,Radius=source.Radius*amount,RarityRework=source.RarityRework}
 for i,s in ipairs(source.Specs)do
  local p=table.clone(s);local at=CFrame.new(table.unpack(s.c));local cf=CFrame.new(turn:VectorToWorldSpace(at.Position)*amount)*turn*at.Rotation
  if s.mawFrame then local f=CFrame.new(table.unpack(s.mawFrame));p.mawFrame={(CFrame.new(turn:VectorToWorldSpace(f.Position)*amount)*turn*f.Rotation):GetComponents()}end
  p.c={cf:GetComponents()};p.z={s.z[1]*amount,s.z[2]*amount,s.z[3]*amount};d.Specs[i]=p
 end
 for _,field in ipairs({'Sockets','FruitCenters'})do for i,p in ipairs(source[field])do
  local v=turn:VectorToWorldSpace(Vector3.new(table.unpack(p)))*amount;d[field][i]={v.X,v.Y,v.Z}
 end end
 for i,r in ipairs(source.FruitRadii)do d.FruitRadii[i]=r*amount end
 variants[key]=d;return d
end
-- Which of an id's designs a crop shows (1 for a preview / no crop): the same hash Get uses. Tests and previews read it.
function Art.Design(id,crop)
 if not multi(id)or not crop or not crop.Id or crop.Id=='preview'then return 1 end
 Art.Get(id)
 return designOf(id,hash(tostring(crop.Id)),#loaded[id])
end
return Art
