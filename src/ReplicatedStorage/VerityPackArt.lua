-- R148 (owner: "verity pack should be using our default pack mesh and sizes and painting it yellow and adding a smiley face on top of
-- it, keep it simple for the verity pack design"): the Verity pack (BagVariant 'VerityReliquary', Stage 7) is our plain pack - the
-- default pouch mesh at the plain pack's size (SeedPackRules: the Standard design and scale), so Bounds, carry layout, hold, hotbar,
-- Bag, opening and tear are an ordinary pack's - painted yellow, with Verity's picture (VerityConfig.Image, the NPC card's: one source
-- of truth; a thin black smiley line drawing on a transparent background) on its front and back.
--  * Yellow 255,255,0 all over the pouch (no biome colours or textures); the seal and the tear strips a darker yellow so the pack
--    shape still reads. A Gold / Diamond coat paints it like any other pack; the picture stays on top.
--  * The picture is a Decal on a thin plate in the pack's yellow that sits on the outermost front and back surface (so no part of the
--    mesh can cover it, whatever the template's own orientation and details). Decals, not SurfaceGuis: SurfaceGuis do not render in a
--    ViewportFrame, and the hotbar / Bag pictures are viewports. The plates are ordinary opaque parts, painted by a coat too.
--  * A Decal follows only its own properties: SeedPackClient / PackOpeningFeedback / GiantVisualSafety hide and fade it like a part.
--  * The magic is VoidPackFx's gold set (Fx): subtle sparkle emitters and a warm light (no outline, debris or comets), nothing purple.
local Catalog=require(script.Parent.VerityCatalog)
local Config=require(script.Parent.VerityConfig)
local Renderer=require(script.Parent.SeedPackRenderer)
local RGB=Color3.fromRGB
local C=Catalog.Palette
local A={Image=Config.Image,Yellow=RGB(255,255,0),Dark=RGB(214,190,0),Revision=148,
 -- The picture's plate: its side as a share of the pouch's width / height at scale 1, its thickness, how far it sinks into the surface.
 FaceWidth=.75,FaceHeight=.62,PlateDepth=.02,PlateSink=.008}
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
-- Fx colours for VoidPackFx (same fields as VoidPackFx.Void; no Debris / Comet / Fill / Outline = none of those pieces): gold
-- sparkles, a soft gold glow and a warm light - nothing purple.
A.Fx={
 Haze={Texture=SPARK,Colors={C.Ball,C.Honey},Size={.5,1.1},Emission=.7,Alpha=.55},
 Nebula={Texture=SPARK,Colors={C.Amber,C.Gloss},Size={.5,1.1},Emission=1,Alpha=.35},
 Stars={Texture=SPARK,Colors={C.White,C.Honey},Size={.10,.03},Emission=1,Alpha=.15},
 Light=RGB(255,196,70),
}
-- The pouch's extent at scale 1 (every mesh of the design's template, as SpecialPackArt89.BodyBounds does for the shared body).
local cache={}
local function extent(key)
 if cache[key]then return cache[key]end
 local t=assert(Renderer.GetGeometry(key),'Approved pack template missing: '..tostring(key))
 local b={Radius=1,MinY=-1.22,MaxY=1.22,MinZ=0,MaxZ=0}
 for _,p in ipairs(t:GetChildren())do if p:IsA('MeshPart')then
  local f=p:GetAttribute('PackLocalFrame')
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=f*Vector3.new(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)
   b.Radius=math.max(b.Radius,Vector3.new(q.X,0,q.Z).Magnitude);b.MinY=math.min(b.MinY,q.Y);b.MaxY=math.max(b.MaxY,q.Y)
   b.MinZ=math.min(b.MinZ,q.Z);b.MaxZ=math.max(b.MaxZ,q.Z)
  end end end
 end end
 cache[key]=b;return b
end
-- The plate's side at scale 1 and the z of its centre for the front (-1) / back (+1): on the outermost surface of the pouch.
function A.Side(key)
 local b=extent(key)
 return math.min(A.FaceWidth*2*b.Radius,A.FaceHeight*(b.MaxY-b.MinY))
end
function A.PlateZ(key,direction)
 local b=extent(key)
 if direction<0 then return b.MinZ-A.PlateDepth/2+A.PlateSink end
 return b.MaxZ+A.PlateDepth/2-A.PlateSink
end
function A.Build(bag,isValid)
 if bag:GetAttribute('VerityPack')then return true end
 -- The ordinary pack for this design (SeedPackRules gives the Verity record the Standard design): the same mesh, parts and tear.
 local key=bag:GetAttribute('PackArtKey')or''
 if Renderer.BuildStandard(bag,key,isValid)==false then return false end
 local root=bag.PrimaryPart;local folder=bag:FindFirstChild('PackGeometry');local scale=bag:GetAttribute('VisualScale')or 1
 for _,p in ipairs(folder:GetChildren())do if p:IsA('MeshPart')then
  p.TextureID='';p.MaterialVariant='';p.Material=Enum.Material.SmoothPlastic;p.Color=A.Yellow;p.Reflectance=0
  for _,v in ipairs(p:GetChildren())do if v:IsA('SurfaceAppearance')then v:Destroy()end end
 end end
 for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')and(p.Name=='BottomSeal'or p:GetAttribute('TearIndex'))then p.Color=A.Dark;p.Material=Enum.Material.SmoothPlastic end end
 -- The picture: a plate on the front and one on the back, each with its Decal on its outer face.
 local side,depth=A.Side(key),A.PlateDepth
 local giant=(bag:GetAttribute('PackSize')or 1)>10
 for _,spec in ipairs({{'VerityFaceFront',-1,Enum.NormalId.Front},{'VerityFaceBack',1,Enum.NormalId.Back}})do
  local p=Instance.new('Part');p.Name=spec[1];p.Size=Vector3.new(side,side,depth)*scale
  local frame=CFrame.new(0,0,A.PlateZ(key,spec[2])*scale);p.CFrame=root.CFrame*frame;p:SetAttribute('PackLocalFrame',frame)
  p.Color=A.Yellow;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0;p.Transparency=0
  p.Anchored=root.Anchored;p.Massless=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if not p.Anchored then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end
  if giant then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end
  local d=Instance.new('Decal');d.Name='VerityPicture';d.Face=spec[3];d.Texture=A.Image;d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=p
  p.Parent=folder
 end
 bag:SetAttribute('CompactPackPartCount',(bag:GetAttribute('CompactPackPartCount')or 10)+2)
 bag:SetAttribute('PaperColor',A.Yellow);bag:SetAttribute('PreserveTextStyle',true)
 bag:SetAttribute('VerityPack',true);bag:SetAttribute('VerityPackDesign',A.Revision)
 return true
end
return A
