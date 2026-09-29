local D=require(script.Parent.MechPlantData)
local Catalog=require(script.Parent.MechCatalog)
local PackShape=require(script.Parent.PackMeshShape88)
local M={};local models={};local arts={}
for _,m in ipairs(D.models)do models[m.id]=m end
local shapes={'Block','Ball','CylinderX','Wedge','Corner'};local materials={'SmoothPlastic','Metal','Neon'}
function M.Get(id)
 local def=Catalog.ById[id];if not def then return nil end
 if arts[id]then return arts[id]end
 local m=assert(models[def.Model],'Missing mech geometry: '..tostring(id)..' / '..tostring(def.Model));local out={Specs={},Sockets=def.Sockets,FruitCenters=def.FruitCenters,FruitRadii=def.FruitRadii,Height=def.Height,Radius=def.Radius,MechRework=true}
 for index,p in ipairs(m.parts)do
  local group=m.groups[p[5]];local g=tonumber(group:match('^Fruit_(%d+)$'))or 0
  local c={p[6],p[7],p[8]};for _,v in ipairs(D.rotations[p[13]])do table.insert(c,v)end
  local s={s=shapes[p[2]],z={p[9],p[10],p[11]},c=c,k=D.colors[p[4]],m=materials[p[3]],t=p[12],g=g,
   f=D.names[p[1]],r=g>0 and'Fruit'or'Part',_ArtIndex=index,mech=true,mechFixed=group=='PlantBase'and(id=='HoloMelonSeed'or id=='HoloAppleTreeSeed'),mechGroup=group}
  local motion=m.motions[group]
  if motion then s.tm='mech'..motion.axis;s.tp=motion.pivot;s.rate=motion.speed;s.mechBob=motion.bob end
  table.insert(out.Specs,s)
 end
 arts[id]=out;return out
end
function M.Growth(id)local def=Catalog.ById[id];return def and models[def.Model].growth end
function M.BuildNative(id,origin,parent,scale,weldRoot,mutation)
 local m=assert(models[id],'Unknown mech model '..tostring(id));scale=scale or 1
 local model=Instance.new('Model');model.Name=id
 local root=Instance.new('Part');root.Name='VisualRoot';root.Size=Vector3.new(.05,.05,.05);root.CFrame=origin
 root.Anchored=weldRoot==nil or weldRoot.Anchored;root.Transparency=1;root.CanCollide=false;root.CanTouch=false;root.CanQuery=false;root.Massless=true;root.Parent=model;model.PrimaryPart=root
 if weldRoot and not root.Anchored then local w=Instance.new('WeldConstraint');w.Part0=weldRoot;w.Part1=root;w.Parent=root end
 for _,p in ipairs(m.parts)do
  local q=Instance.new(p[2]==4 and'WedgePart'or p[2]==5 and'CornerWedgePart'or'Part')
  q.Name=D.names[p[1]];if p[2]==2 then
   if id=='MechPack'then PackShape.Sphere(q)else q.Shape=Enum.PartType.Ball end
  elseif p[2]==3 then q.Shape=Enum.PartType.Cylinder end
  local r=D.rotations[p[13]];q.Size=Vector3.new(p[9],p[10],p[11])*scale
  local cf=CFrame.new(p[6]*scale,p[7]*scale,p[8]*scale,table.unpack(r));q.CFrame=origin*cf
  q.Color=Color3.fromRGB(table.unpack(D.colors[p[4]]));q.Material=Enum.Material[materials[p[3]]];q.Transparency=p[12]
  if mutation=='Gold'or mutation=='Diamond'then
   q.Color=mutation=='Gold'and Color3.fromRGB(240,186,67)or Color3.fromRGB(193,239,255)
   q.Material=mutation=='Gold'and Enum.Material.Metal or Enum.Material.Glass;q.Transparency=mutation=='Gold'and 0 or .18
  end
  q.Anchored=root.Anchored;q.Massless=true;q.CanCollide=false;q.CanTouch=false;q.CanQuery=false;q.CastShadow=false
  q.TopSurface=Enum.SurfaceType.Smooth;q.BottomSurface=Enum.SurfaceType.Smooth;q:SetAttribute('PackLocalFrame',cf);q.Parent=model
  if not q.Anchored then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=q;w.Parent=q end
 end
 if id~='MechPack'then require(script.Parent.ItemEffectAnchor).Set(model,'None',true,scale*.75,scale*1.8)end
 model.Parent=parent;return model
end
function M.Pack(bag)return require(script.Parent.SpecialPackArt89).Build(bag,'MechLimited')end
return M
