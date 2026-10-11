--!nocheck
-- R149 preview / diagnosis dump (not a test): builds the Verity pack with the REAL SeedPackVisuals / SeedPackRenderer / VerityPackArt of the
-- bundle in this directory on the Roblox mock and prints
--   "DIAG ..."  one line per instance of the pack in every context it is shown (on the ground, carried, hotbar / Bag picture, the opening
--               copy, a giant one): class, name, colour, material, transparency, size, centre and z range in the pack's own frame, Decals;
--   "SCENE <name> <json>"  the parts of a view for render_pack.mjs (front / side / back / in-hand angle / hotbar-sized).
-- The same script runs on the base commit's art (the R148 pack, "before") and on this checkout's ("after"): run_verity_pack_preview.sh bundles both.
-- Stand-ins: the approved pouch MeshPart's asset is not available offline, so it is drawn as a rounded pouch of its size with a SIMULATED
-- print in its vertex colours (parts[].vertex = 'storm', see pack.html: pale crimps, dark navy panel, orange sticks) - an approximation of
-- the live screenshots, which show the mesh's own colours multiplied by the part colour. The Verity picture is a smiley stand-in.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
F.packAssets(W);require('./verity_template')(W)
local Visuals=W.module('SeedPackVisuals')
local VERITY='VerityReliquary'
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function frameOf(bag,p)return bag.PrimaryPart.CFrame:Inverse()*p.CFrame end
local function zrange(bag,p)
 local f=frameOf(bag,p);local h=p.Size*.5;local lo,hi=1e9,-1e9
 for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do local q=f*V3(h.X*x,h.Y*y,h.Z*z);lo=math.min(lo,q.Z);hi=math.max(hi,q.Z)end end end
 return lo,hi
end
local function diag(context,bag)
 print('DIAG == '..context..' ==  (pack scale '..n(bag:GetAttribute('VisualScale')or 1)..', Anchored root '..tostring(bag.PrimaryPart.Anchored)..')')
 for _,d in ipairs(bag:GetDescendants())do
  local cls=d._class
  if d:IsA('BasePart')then
   local f=frameOf(bag,d);local lo,hi=zrange(bag,d)
   local extra={}
   if d:IsA('MeshPart')then extra[#extra+1]='TextureID='..string.format('%q',d.TextureID or'')end
   if d.Shape and d._class=='Part'then extra[#extra+1]='Shape='..enumName(d.Shape)end
   local kids={};for _,k in ipairs(d:GetChildren())do kids[#kids+1]=k._class..(k:IsA('Decal')and('('..enumName(k.Face)..' '..tostring(k.Texture)..' tint '..c3(k.Color3)..' T'..n(k.Transparency)..')')or'')end
   if #kids>0 then extra[#extra+1]='children: '..table.concat(kids,', ')end
   print(string.format('DIAG   %-9s %-15s color %-13s %-12s T %.2f size (%s,%s,%s) at (%s,%s,%s) z [%s..%s] %s',cls,d.Name,c3(d.Color),enumName(d.Material),d.Transparency,n(d.Size.X),n(d.Size.Y),n(d.Size.Z),n(f.Position.X),n(f.Position.Y),n(f.Position.Z),n(lo),n(hi),table.concat(extra,'; ')))
  elseif not d:IsA('Decal')and not d:IsA('WeldConstraint')and not d:IsA('Attachment')then
   print('DIAG   '..cls..' '..d.Name)
  end
 end
end
local function dump(model)
 local out={}
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and c~=model.PrimaryPart and(c.Transparency or 0)<.995 then
  local r=c.CFrame.R;local p=c.CFrame.Position;local s=c.Size
  local shape=c:IsA('MeshPart')and'Pouch'or(c.Shape and enumName(c.Shape))or'Block'
  local decals={}
  for _,d in ipairs(c:GetChildren())do if d:IsA('Decal')then table.insert(decals,string.format('{"face":"%s","tex":"%s","color":%s}',enumName(d.Face),tostring(d.Texture),c3(d.Color3)))end end
  table.insert(out,string.format('{"name":"%s","shape":"%s","vertex":%s,"size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s,"decals":[%s]}',
   c.Name,shape,c:IsA('MeshPart')and'"storm"'or'null',n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0),table.concat(decals,',')))
 end end
 return out
end
-- 1. Every context -----------------------------------------------------------------------------------------------------------------
do
 local ground=Visuals.Bag(CF(0,0,0),W.workspace,1,nil,7,VERITY,1,1,'None');diag('on the ground / dropped (anchored world pack)',ground)
 local char=R.new('Model');char.Name='Carrier';char.Parent=W.workspace
 local torso=R.new('Part');torso.Name='UpperTorso';torso.Size=V3(2,2,1);torso.CFrame=CF(0,5,0);torso.Anchored=false;torso.Parent=char
 local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,4,0);hrp.Parent=char
 local carry=Visuals.CarryBag(char,7,VERITY,1,1,'None');diag('held / carried (CarryBag: welded to the character)',carry)
 local pic=Visuals.Bag(R.CFrame.Angles(0,.22,-.025),nil,1,nil,7,VERITY,1,1,'None');diag('hotbar / Bag picture (ItemPictures builds exactly this into a ViewportFrame)',pic)
 local copy=carry:Clone();copy.Name='OpeningBag';diag('opening: the clone SeedPackClient animates',copy)
 local giant=Visuals.Bag(CF(0,0,0),W.workspace,1,nil,7,VERITY,1,25,'None');diag('giant (PackSize 25)',giant)
end
-- 2. Scenes -------------------------------------------------------------------------------------------------------------------------
local views={front='{"target":[0,0,0],"dist":8.2,"az":0,"el":0,"fov":30}',side='{"target":[0,0,0],"dist":8.2,"az":90,"el":0,"fov":30}',
 back='{"target":[0,0,0],"dist":8.2,"az":180,"el":0,"fov":30}',hand='{"target":[0,0.1,0],"dist":5.6,"az":-26,"el":16,"fov":38}',
 hotbar='{"target":[0,0,0],"dist":7.2,"az":0,"el":0,"fov":30}'}
for _,case in ipairs({{'verity','None'},{'verity_gold','Gold'}})do
 for view,json in pairs(views)do
  local origin=view=='hotbar'and R.CFrame.Angles(0,.22,-.025)or CF(0,0,0)
  local bag=Visuals.Bag(origin,W.workspace,1,nil,7,VERITY,1,1,case[2])
  print(string.format('SCENE %s_%s {"parts":[%s],"view":%s}',case[1],view,table.concat(dump(bag),','),json))
  bag:Destroy()
 end
end
