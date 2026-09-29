-- V147. Mature-size placement for owner test collections. Never moves saved crops.
local RS=game:GetService('ReplicatedStorage')
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Layout={};local radii={}
function Layout.Radius(id,scale)
 if not radii[id]then
  local radius=0
  for _,s in ipairs(Visuals.Specs(id)or{})do
   local ex=(math.abs(s.c[4])*s.z[1]+math.abs(s.c[5])*s.z[2]+math.abs(s.c[6])*s.z[3])*.5
   local ez=(math.abs(s.c[10])*s.z[1]+math.abs(s.c[11])*s.z[2]+math.abs(s.c[12])*s.z[3])*.5
   radius=math.max(radius,math.sqrt((math.abs(s.c[1])+ex)^2+(math.abs(s.c[3])+ez)^2))
  end
  radii[id]=math.max(1.5,radius)
 end
 return radii[id]*scale
end
function Layout.Find(config,garden,id,scale,infos)
 local radius=Layout.Radius(id,scale)
 local function world(slot,x,z)
  local info=infos and infos[slot]
  return info and info.Part and info.Part.CFrame:PointToWorldSpace(Vector3.new(x,0,z))or nil
 end
 for slot=1,config.GardenPlotCount do
  local width,depth=config.GetGardenBedSize(slot)
  local px=math.min(radius+.6,width/2);local pz=math.min(radius+.6,depth/2)
  -- Very large specimens can stand at a bed centre, but still need space from other crops.
  for z=depth/2-pz,-depth/2+pz,-2 do
   for x=-width/2+px,width/2-px,2 do
    local list=garden.Plots[tostring(slot)]or{}
    local free=config.ValidateGardenPlacement(list,x,z,width,depth)
    local point=world(slot,x,z)
    if free then
     for otherSlot,others in pairs(garden.Plots)do
      for _,crop in ipairs(others)do
       local other=world(tonumber(otherSlot),crop.OffsetX,crop.OffsetZ)
       local dx,dz
       if point and other then dx=point.X-other.X;dz=point.Z-other.Z
       elseif tonumber(otherSlot)==slot then dx=x-crop.OffsetX;dz=z-crop.OffsetZ end
       if dx then
        local clearance=radius+Layout.Radius(crop.SeedId,crop.PlantScale or 1)+.8
        if dx*dx+dz*dz<clearance*clearance then free=false;break end
       end
      end
      if not free then break end
     end
    end
    if free then return {slot,x,z}end
   end
  end
 end
 return nil
end
return Layout
