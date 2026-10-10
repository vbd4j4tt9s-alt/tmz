--!nocheck
-- Shared setup of the R149 growth-style tests (run_growth.sh): the Roblox mock world with the real modules of this checkout, the mock gaps these tests
-- need (a lookAt with an up vector, CFrame.fromMatrix, Color3 equality by value, a BulkMoveTo that really moves), a counter of property writes, and
-- helpers that build a plant the way GardenVisuals does and snapshot / compare what is on its parts.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
do local mt=getmetatable(R.Color3.new(0,0,0));mt.__eq=function(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end end -- (Roblox compares Color3 by value)
-- Counting of property writes on parts (the engine cost the proposal measured: ~18,600 a second per growing plant).
local C={W=W,R=R,V3=V3,CF=CF,Counts={},Bulk=0,Counting=false}
local rawNewindex=R.instMeta.__newindex
local partClass={Part=true,MeshPart=true,WedgePart=true,CornerWedgePart=true}
R.instMeta.__newindex=function(o,k,v)
 if C.Counting and partClass[o._class]and k~='Parent'then C.Counts[k]=(C.Counts[k]or 0)+1;C.Counts.Total=(C.Counts.Total or 0)+1 end
 return rawNewindex(o,k,v)
end
function C.Count(f)
 C.Counts={};C.Bulk=0;C.Counting=true;f();C.Counting=false
 local out=C.Counts;out.Bulk=C.Bulk;C.Counts={};return out
end
W.workspace.BulkMoveTo=function(_,parts,frames)
 C.Bulk+=#parts
 for i,p in ipairs(parts)do rawNewindex(p,'CFrame',frames[i])end
end
-- Checks.
local fails,checks=0,0
function C.check(cond,msg)checks+=1;if not cond then fails+=1;print('FAIL: '..msg)end;return cond end
function C.near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
function C.done(name)print(('%s: %d checks, %d failures'):format(name,checks,fails));if fails>0 then error('FAILED')end end
function C.stats()return checks,fails end
-- Real modules.
C.Catalog=W.module('PlantCatalog');C.Visuals=W.module('PlantVisuals');C.Rules=W.module('PlantRules')
C.Growth=W.module('PlantGrowth');C.Base=W.module('PlantGrowthBase')
-- The stub of the baked meshes (ServerStorage) the way the fruit-model tests do it: a Part tagged ApprovedMesh.
do
 local Meshes=W.module('ApprovedPlantMeshes')
 Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
 Meshes.Status=function()return 'Ready'end
end
C.origin=CF(0,0,0)
function C.ids()
 local ids={};for id,d in pairs(C.Catalog)do if type(d)=='table'and d.Seconds then ids[#ids+1]=id end end;table.sort(ids);return ids
end
function C.crop(id,extra)
 local d=C.Catalog[id]
 local c={Id='g149-'..id,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
-- A ripe model and its growth state, built by `Growth` (the base module or the new one) exactly as PlantVisuals.BuildGrowing does it.
function C.grow(Growth,id,crop,options)
 local def=C.Catalog[id];local ripe=table.clone(crop);ripe.ReadyAt=0
 local model=C.Visuals.Build(id,C.origin,ripe,4,math.huge,nil,nil);model.Parent=W.workspace
 local sockets={};for i=1,def.FruitCount do sockets[i]=C.Visuals.FruitSocket(crop,def,i)end
 return model,Growth.Capture(model,id,def,crop,C.origin,sockets,options)
end
-- A fruit model (Harvest_n of a mature plant) and its growth state, as syncFruit builds it for a regrowing fruit.
function C.growFruit(Growth,id,crop,index)
 local def=C.Catalog[id];local source=table.clone(crop);source.ReadyAt=0
 local art=C.Visuals.Build(id,C.origin,source,4,math.huge,index,nil)
 local child=art:FindFirstChild('Harvest_'..index);child.Parent=W.workspace;art:Destroy()
 local sockets={};for i=1,def.FruitCount do sockets[i]=C.Visuals.FruitSocket(crop,def,i)end
 return child,Growth.Capture(child,id,def,crop,C.origin,sockets)
end
-- Everything on the parts of a model, in descendant order.
local function comps(cf)local x,y,z,a,b,c,d,e,f,g,h,i=cf:GetComponents();return{x,y,z,a,b,c,d,e,f,g,h,i}end
function C.snapshot(model)
 local out={}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
  out[#out+1]={Part=p,Name=p.Name,Size=p.Size,CF=comps(p.CFrame),Transparency=p.Transparency,Color=p.Color,Material=p.Material,CanQuery=p.CanQuery,CanCollide=p.CanCollide,Parent=p.Parent~=nil}
 end end
 return out
end
-- Equal as drawn: a part that is hidden (Transparency 1) in both is equal whatever else it holds (nobody sees it); every other property compares exactly.
function C.sameParts(a,b)
 if #a~=#b then return false,'part count '..#a..' / '..#b end
 for i=1,#a do
  local x,y=a[i],b[i]
  if x.Name~=y.Name then return false,'part '..i..' name '..x.Name..' / '..y.Name end
  if x.Transparency~=y.Transparency then return false,x.Name..'#'..i..' Transparency '..x.Transparency..' / '..y.Transparency end
  if x.Transparency<1 then
   if x.Size~=y.Size then return false,x.Name..'#'..i..' Size '..tostring(x.Size)..' / '..tostring(y.Size)end
   for k=1,12 do if x.CF[k]~=y.CF[k]then return false,x.Name..'#'..i..' CFrame['..k..'] '..x.CF[k]..' / '..y.CF[k]end end
   if x.Color~=y.Color then return false,x.Name..'#'..i..' Color' end
   if x.Material~=y.Material then return false,x.Name..'#'..i..' Material '..tostring(x.Material.Name)..' / '..tostring(y.Material.Name)end
  end
  if x.CanQuery~=y.CanQuery then return false,x.Name..'#'..i..' CanQuery' end
  if x.CanCollide~=y.CanCollide then return false,x.Name..'#'..i..' CanCollide' end
 end
 return true
end
function C.sameAs(a,b)return select(1,C.sameParts(a,b))end
-- Finish a growth the way Visuals.EndGrowth does: the last pose, then the temporary parts go.
function C.finish(Growth,state,crop,now)
 Growth.Apply(state,crop,math.max(now or 0,crop.ReadyAt or 0,crop.MatureAt or 0))
 if state.Seed then state.Seed:Destroy()end;for _,p in ipairs(state.Sprout)do p:Destroy()end;for _,b in pairs(state.Buds)do b.Part:Destroy();b.Stem:Destroy()end
 if state.Twins then for _,p in ipairs(state.Twins)do p:Destroy()end end
end
return C
