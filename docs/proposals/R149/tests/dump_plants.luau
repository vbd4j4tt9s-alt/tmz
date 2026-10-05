--!nocheck
-- R149 regression fingerprint (run_fruit_models.sh runs it on the BASE commit and on this checkout, then compares): for EVERY plant in
-- the catalog (retired ones included), on the real modules on the Roblox mock, one line per crop and mode with a digest of
--  * the art (PlantVisuals.Specs with every field, the approved art's sockets / fruit centres / radii / height / radius, the catalog row);
--  * the built plant: ripe, growing at 10 / 50 / 90 %, every part's class, name, shape, size, position, rotation, colour, material,
--    transparency, reflectance, query flag and growth attributes;
--  * every fruit's harvest item (the hotbar / Bag / Index model) plain, Gold, Diamond and with weather; its far proxy; its prompt
--    position, reach and socket; the distant supports; the detail cost.
-- Output: "<plant>\t<crop>\t<mode>\t<digest>\t<parts>". A baked mesh part is a stub (ApprovedPlantMeshes lives in ServerStorage).
-- R149 review part 2 (finding 5): the Ash Tomato's "Flat ash patch" blocks were touched up (thicker, higher). Every mode of the Ash Tomato (except key and
-- catalog) therefore has a twin "<mode>~np" computed WITHOUT those parts / specs, so check_plants_diff.py can allow exactly the patch lines to differ.
-- R151 (owner: no white shine dots on fruit): the gloss / glint parts of the fruit are gone. Every mode of the nine plants that had them (GLOSS_PLANTS) therefore has a twin
-- "<mode>~ng" computed WITHOUT those parts / specs (by name), so check_plants_diff.py can allow exactly the removed parts to differ: a mode may differ between the base and
-- this checkout only when its twin is identical (the twins of the plants R149 redesigned are not compared: those plants differ by design).
-- R149 fruit meshes (FruitMeshes149, only in trees that have it): `luau dump_plants.luau -a mesh|parts|fail`. mesh (the default): the server bake
-- runs first on the mock AssetService (fruit_mesh_mock.luau), so the Watermelon / Snow Melon / Ember Pumpkin get their mesh bodies; parts: no
-- bake ran (no template folder: the part-built fruit); fail: the bake runs and fails (no EditableMesh: every key Failed, the part-built fruit).
local MODE=... or 'mesh'
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
if W.RS:FindFirstChild('FruitMeshes149')and MODE~='parts'then
 local Mock=require('./fruit_mesh_mock');Mock.install(W,{Missing=MODE=='fail'})
 local ready=Mock.prepare(W);assert(ready==(MODE=='mesh'),'fruit mesh bake: '..tostring(ready)..' in mode '..MODE)
end
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation');local Approved=W.module('ApprovedPlantArt')
local ids={};for id in pairs(Catalog)do if type(id)=='string'and type(Catalog[id])=='table'and Catalog[id].FruitCount then ids[#ids+1]=id end end
table.sort(ids)
local function fnv(s)
 local h=2166136261
 for i=1,#s do h=bit32.bxor(h,string.byte(s,i));h=(h*16777619)%4294967296 end
 return string.format('%08x',h)
end
local function n(v)return string.format('%.4f',v)end
local function ser(v,depth)
 local t=type(v)
 if t=='number'then return n(v)elseif t=='table'then
  if depth>6 then return '{..}'end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local o={};for _,k in ipairs(keys)do o[#o+1]=tostring(k)..'='..ser(v[k],depth+1)end
  return '{'..table.concat(o,',')..'}'
 end
 return tostring(v)
end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local patchless=nil -- (set while a "~np" twin is computed: the name of the parts / specs that are left out)
local GLOSS={['Fruit gloss']=true,['Berry glint']=true,['Moon glint']=true,['Verity gloss']=true,['Verity glint']=true}
local GLOSS_PLANTS={SunflowerSeed=true,SnowdropSeed=true,EmberBloomSeed=true,AppleSeed=true,ElderbloomSeed=true,BluebellSeed=true,IceberrySeed=true,MoonflowerSeed=true,VeritySeed=true}
local glossless=false -- (set while a "~ng" twin is computed: the shine parts / specs are left out)
local function fingerprint(model,skipIndex)
 local out={};local count=0
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and not(patchless and c.Name==patchless)and not(glossless and GLOSS[c.Name])then
  count+=1
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size;local sm=c:FindFirstChildOfClass('SpecialMesh')
  local attrs={};for _,k in ipairs({'GrowthGroup','GrowthRole','GrowthForm',skipIndex and'-'or'ArtSpecIndex','HarvestFeature','HarvestIndex','FruitProxy','Mutation','ApprovedMesh','LeafVariantGroup','PlantSurfaceDetail','PlantSurfaceShading','FruitScale'})do local v=c:GetAttribute(k)if v~=nil then attrs[#attrs+1]=k..'='..tostring(v)end end
  local col=c.Color or{R=0,G=0,B=0};local parent=c.Parent;local group=parent and parent:GetAttribute('HarvestIndex')
  out[#out+1]=table.concat({c.ClassName,c.Name,c.Shape and enumName(c.Shape)or'-',sm and'mesh'or'-',n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),
   n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   string.format('%.3f,%.3f,%.3f',col.R,col.G,col.B),c.Material and enumName(c.Material)or'-',n(c.Transparency or 0),n(c.Reflectance or 0),tostring(c.CanQuery),table.concat(attrs,';'),tostring(group)},'|')
 end end
 return fnv(table.concat(out,'\n')),count
end
local function emit(id,crop,mode,digest,count)print(table.concat({id,crop,mode,digest,tostring(count or 0)},'\t'))end
local seenError={}
local try0
local function try(id,crop,mode,fn)
 try0(id,crop,mode,fn)
 if id=='AshRoseSeed'and crop~='-'and mode~='key'then patchless='Flat ash patch';try0(id,crop,mode..'~np',fn);patchless=nil end
 if GLOSS_PLANTS[id]and crop~='-'and mode~='key'then glossless=true;try0(id,crop,mode..'~ng',fn);glossless=false end
end
function try0(id,crop,mode,fn)
 local ok,a,b=pcall(fn)
 if ok then emit(id,crop,mode,a,b)else
  emit(id,crop,mode,'ERR '..fnv(tostring(a)),0)
  if not seenError[tostring(a)]then seenError[tostring(a)]=true;print('#error\t'..id..'\t'..mode..'\t'..tostring(a))end
 end
end
local origin=CF(0,0,0)
local MANY={AshRoseSeed=true,CactusSeed=true}
for _,id in ipairs(ids)do
 local d=Catalog[id]
 try(id,'-','catalog',function()
  local keys={'Name','Rarity','Biome','FruitCount','Sockets','FruitCenters','FruitRadii','Height','Radius','BaseScale','Value','Seconds','RegrowSeconds','Tree','Mode','Retired','HarvestName','Rank','ArtBiome'}
  local o={};for _,k in ipairs(keys)do o[#o+1]=k..'='..ser(d[k],0)end;return fnv(table.concat(o,';')),0
 end)
 local crops=MANY[id]and 8 or 2
 for ci=1,crops do
  local cid='reg-'..id..'-'..ci
  local crop={Id=cid,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
  local cn='c'..ci
  try(id,cn,'key',function()return tostring(Approved.Key(id,crop)),0 end)
  try(id,cn,'specs',function()
   local specs=Visuals.Specs(id,crop);if not specs then return 'nil',0 end
   local o={};for _,s in ipairs(specs)do if not(patchless and s.f==patchless)and not(glossless and GLOSS[s.f])then o[#o+1]=ser(s,0)end end
   local art=Approved.Get(id,crop);local meta=art and ser({art.Sockets,art.FruitCenters,art.FruitRadii,art.Height,art.Radius},0)or'-'
   return fnv(table.concat(o,'\n')..meta),#o
  end)
  try(id,cn,'ripe',function()return fingerprint(Visuals.Build(id,origin,crop,4,math.huge))end)
  if ci<=2 then
   for _,f in ipairs({.1,.5,.9})do try(id,cn,'grow'..f,function()return fingerprint(Visuals.BuildGrowing(id,origin,crop,f*d.Seconds))end)end
   try(id,cn,'detail',function()
    if not glossless then return tostring(Visuals.DetailCost(id,crop)),0 end
    -- the twin without the shine parts: Visuals.DetailCost's own sum (R151: it counts every spec, so it falls by the cost of the removed parts), minus theirs
    local layout=Visuals.LeafLayout(id,crop);local cost=1
    for _,s in ipairs(Visuals.Specs(id,crop)or{})do if not GLOSS[s.f]and(not s.vg or not layout or layout.Selected[s.vg])then cost+=Visuals.PartCost(s)end end
    return tostring(cost),0
   end)
   try(id,cn,'supports',function()local m=R.new('Model');Visuals.Supports(id,origin,crop,4,m);return fingerprint(m)end)
   -- the plant's own parts (no fruit group) without the art-list index: a redesigned fruit shifts the index of the body specs after it
   try(id,cn,'bodyonly',function()local m=Visuals.Build(id,origin,crop,4,math.huge);local b=m:FindFirstChild('PlantBase');if not b then return 'none',0 end;return fingerprint(b,true)end)
   try(id,cn,'supportsnoidx',function()local m=R.new('Model');Visuals.Supports(id,origin,crop,4,m);return fingerprint(m,true)end)
   try(id,cn,'coatplant',function()local c2=table.clone(crop);c2.Mutation='Gold';return fingerprint(Visuals.Build(id,origin,c2,4,math.huge))end)
   if d.Mode~='whole'then
    for index=1,d.FruitCount do
     local tag='f'..index
     for _,mut in ipairs({'None','Gold','Diamond'})do
      try(id,cn,'harvest'..tag..mut,function()
       return fingerprint((Harvest.Build({SeedId=id,Mutation=mut,Weather=mut=='None'and'Rain'or'None',VisualCrop={SourceCropId=cid,FruitIndex=index,HarvestCycle=0}})))
      end)
     end
     try(id,cn,'proxy'..tag,function()local f=R.new('Folder');Visuals.FruitProxy(f,id,crop,index,origin);return fingerprint(f)end)
     try(id,cn,'prompt'..tag,function()
      local pos=Visuals.FruitPosition(crop,d,index,math.huge);local sock=Visuals.FruitSocket(crop,d,index);local reach=Visuals.FruitReach(crop,d,index)
      return fnv(table.concat({n(pos.X),n(pos.Y),n(pos.Z),n(sock.X),n(sock.Y),n(sock.Z),n(reach)},',')),0
     end)
    end
   end
  end
 end
end
