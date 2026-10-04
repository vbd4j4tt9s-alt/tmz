--!nocheck
-- R147 preview dump (not a test): builds a Void pack and a Verity pack with the REAL SeedPackVisuals / SeedPackRenderer / EclipsePackArt /
-- VerityPackArt on the Roblox mock and prints one JSON scene per view for render_pack.mjs ("SCENE <name> <json>").
-- The approved Forest_01 pouch mesh is not available offline: the mock's stand-in body (named Body) is drawn as a rounded pouch of the same
-- bounds, and the stand-in Band / Label pieces are skipped. Particles, the Highlight outline and the light are not drawn.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
F.packAssets(W)
local Visuals=W.module('SeedPackVisuals')
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function dump(model)
 local out={}
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and c~=model.PrimaryPart and(c.Transparency or 0)<.995 then
  local skip=c:IsA('MeshPart')and c.Name~='Body'
  if not skip then
   local r=c.CFrame.R;local p=c.CFrame.Position;local s=c.Size
   local shape=c:IsA('MeshPart')and'Pouch'or(c.Shape and enumName(c.Shape))or'Block'
   table.insert(out,string.format('{"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
    c.Name,shape,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
    c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
  end
 end end
 return out
end
local views={front='{"target":[0,0,0],"dist":8.2,"az":0,"el":0,"fov":30}',angle='{"target":[0,0,0],"dist":9.4,"az":-34,"el":14,"fov":30}'}
for _,case in ipairs({{'void','EclipseReliquary'},{'verity','VerityReliquary'}})do
 for view,json in pairs(views)do
  local bag=Visuals.Bag(CF(0,0,0),W.workspace,1,nil,7,case[2],1,1,'None')
  print(string.format('SCENE %s_%s {"parts":[%s],"view":%s}',case[1],view,table.concat(dump(bag),','),json))
  bag:Destroy()
 end
end
