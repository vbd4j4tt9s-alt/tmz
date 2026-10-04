-- R149 (owner: "regarding verity pack i just need it to be pure yellow and the face plastered nice onto the pack thats the only design
-- needed", then "make sure the face is not floating on the pack ... make sure its nicely plastered on to the pack"): the Verity pack
-- (BagVariant 'VerityReliquary', Stage 7) is a pure yellow pouch with Verity's face (VerityConfig.Image, the NPC card's picture: one
-- source of truth) on its front and its back. Nothing else: no glow, no sparkles, no light, no other colour.
--  * Why it is built from plain parts and not from the approved pouch mesh (R148 painted that mesh yellow and the live pack showed a BLACK
--    panel with brown / orange sticks and no face): the approved pouch (Storm_02: ONE MeshPart, Color white, no TextureID, no
--    SurfaceAppearance) carries its whole print in the mesh's VERTEX COLOURS, and a part's Color is multiplied with them (yellow 255,255,0
--    x dark navy = black, x orange = brown, x the pale crimps = yellow). Colour can only be tinted, never replaced, so no Color value
--    can make that mesh pure yellow, and a Decal's transparent pixels show the mesh's own black. (The same reason the plants have a
--    _Neutral template with white vertex colours.) The picture plates R148 added floated off the curved pouch.
--  * The pack: a flat-faced yellow sachet with rounded long edges, the same footprint (width, height) as the plain pack's pouch, between
--    the plain pack's own BottomSeal / TearStrips (SeedPackVisuals), so Visuals.Bounds, the carry layout, the hold, the hotbar / Bag
--    picture, the opening and the tear are an ordinary pack's. Parts: VerityFace (a square block whose Front and Back faces carry the
--    picture) with a block above and below it, a rounded edge on each side and a pinched end (two thin slanted slabs) at the top and the
--    bottom, hiding the seal. The picture is a Decal ON the face block's own surface: nothing stands off the pack, so from the side
--    there is no step, and nothing is in front of it. Every other part's outer surface starts on the face plane or behind it.
--  * Decals, not SurfaceGuis: SurfaceGuis do not render in a ViewportFrame, and the hotbar / Bag pictures are viewports. A Decal follows only
--    its own properties: SeedPackClient / PackOpeningFeedback / GiantVisualSafety hide and fade it like a part.
--  * Every part is 255,255,0 SmoothPlastic (the seal and the tear strips too). A Gold / Diamond coat paints it like any other pack
--    (SeedPackVisuals: every part takes the coat's colour and material, a Diamond one at .10 transparency); the Decal stays white on top.
local Config=require(script.Parent.VerityConfig)
local Renderer=require(script.Parent.SeedPackRenderer)
local V,CF=Vector3.new,CFrame.new
local A={Image=Config.Image,Yellow=Color3.fromRGB(255,255,0),Revision=149,
 -- The sachet's thickness as a share of the plain pouch's front-to-back size, and the share of the height its square face block may take.
 DepthShare=.56,FaceHeightShare=.9,
 -- The blocks above / below the face block reach this far under it and sit this far behind its surface (so the face block alone is the
 -- outermost, never a coplanar overlap with the picture on it).
 Overlap=.01,Recess=.004,
 -- The pinched ends: how far the slanted slabs reach past the body, the crimp thickness they meet, their own thickness.
 TaperHeight=.16,TaperTip=.035,TaperThickness=.03}
-- The plain pack's pouch at scale 1: the x / y / z range of every MeshPart of the design's template (the default Storm_02 pouch when the
-- template is missing, so the pack always builds).
local cache={}
local function footprint(key)
 if cache[key]then return cache[key]end
 local t=Renderer.GetGeometry(key)
 local lo,hi=V(math.huge,math.huge,math.huge),V(-math.huge,-math.huge,-math.huge)
 for _,p in ipairs(t and t:GetChildren()or{})do if p:IsA('MeshPart')then
  local f=p:GetAttribute('PackLocalFrame')
  if typeof(f)=='CFrame'then for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=f*V(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)
   lo=V(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=V(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))
  end end end end
 end end
 local b=lo.X<hi.X and{MinX=lo.X,MaxX=hi.X,MinY=lo.Y,MaxY=hi.Y,MinZ=lo.Z,MaxZ=hi.Z}or{MinX=-.985,MaxX=.985,MinY=-1.04,MaxY=1.02,MinZ=-.549,MaxZ=.455}
 cache[key]=b;return b
end
-- The parts at scale 1, in the pack's root frame: {Name,Size,Frame,Shape?,Picture?}. Pure data: Build places them at the pack's scale.
function A.Layout(key)
 local b=footprint(key)
 local W,H=b.MaxX-b.MinX,b.MaxY-b.MinY;local cx,cy=(b.MinX+b.MaxX)/2,(b.MinY+b.MaxY)/2
 -- depth D, the width of the flat middle S = W - D (the two rounded edges are D wide each); S stays a square face block.
 local D=math.min(A.DepthShare*(b.MaxZ-b.MinZ),W*.5)
 if W-D>H*A.FaceHeightShare then D=W-H*A.FaceHeightShare end
 local S=W-D;local rest=(H-S)/2;local out={}
 local function add(name,size,frame,shape,picture)out[#out+1]={Name=name,Size=size,Frame=frame,Shape=shape,Picture=picture}end
 add('VerityFace',V(S,S,D),CF(cx,cy,0),nil,true)
 local h=rest+A.Overlap;local d=D-2*A.Recess
 add('VerityBodyTop',V(S,h,d),CF(cx,cy+S/2-A.Overlap+h/2,0))
 add('VerityBodyBottom',V(S,h,d),CF(cx,cy-S/2+A.Overlap-h/2,0))
 -- the rounded long edges: vertical cylinders (a Cylinder part runs along its X, so a quarter turn stands it up), tangent to the faces
 for _,side in ipairs({-1,1})do
  add(side<0 and'VerityEdgeLeft'or'VerityEdgeRight',V(H,D,D),CF(cx+side*S/2,cy,0)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
 end
 -- the pinched ends: a thin slanted slab from the body's top / bottom edge (flush with the face plane) in to the crimp of the plain pack's
 -- seal (the ordinary BottomSeal / TearStrips, which these hide), one slab per side, so the pouch tapers to a seam like the real one. Only
 -- the outer surface matters: each slab starts exactly on the body's outer edge and slopes inward, never in front of the face.
 local th,tip,tall=A.TaperThickness,A.TaperTip,A.TaperHeight
 local dz=(D-tip)/2;local len=math.sqrt(dz*dz+tall*tall);local theta=math.atan2(dz,tall)
 local ny,nz=dz/len,-tall/len -- outward normal of the front-top slab; its centre sits half a thickness inside the outer surface
 for _,up in ipairs({1,-1})do for _,zs in ipairs({-1,1})do -- up: top / bottom; zs: front (-Z) / back (+Z)
  add('VerityTaper'..(up>0 and'Top'or'Bottom')..(zs<0 and'Front'or'Back'),V(S+D*.5,len,th),
   CF(cx,cy+up*(H/2+tall/2-ny*th/2),zs*((D+tip)/4+nz*th/2))*CFrame.Angles(-up*zs*theta,0,0))
 end end
 return out,{Width=W,Height=H,Depth=D,Face=S}
end
-- The face block's side at scale 1.
function A.FaceSide(key)local _,m=A.Layout(key);return m.Face end
function A.Build(bag,isValid)
 if bag:GetAttribute('VerityPack')then return true end
 local key=bag:GetAttribute('PackArtKey')or''
 local root=bag.PrimaryPart;assert(root,'[R149] The Verity pack needs its root part.')
 if isValid and not isValid()then return false end
 local scale=bag:GetAttribute('VisualScale')or 1
 local giant=(bag:GetAttribute('PackSize')or 1)>10
 local folder=Instance.new('Folder');folder.Name='PackGeometry'
 local specs=A.Layout(key)
 for _,s in ipairs(specs)do
  local p=Instance.new('Part');p.Name=s.Name;if s.Shape then p.Shape=s.Shape end
  p.Size=s.Size*scale
  local frame=CF(s.Frame.Position*scale)*s.Frame.Rotation
  p.CFrame=root.CFrame*frame;p:SetAttribute('PackLocalFrame',frame)
  p.Color=A.Yellow;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0;p.Transparency=0
  p.Anchored=root.Anchored;p.Massless=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if not p.Anchored then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end
  if giant then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end
  if s.Picture then
   -- Verity's picture, as it is, white (untinted), on the block's own Front and Back faces.
   for _,side in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
    local d=Instance.new('Decal');d.Name='VerityPicture';d.Face=side;d.Texture=A.Image;d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=p
   end
  end
  p.Parent=folder
 end
 -- The seal and the tear strips of the ordinary pack: the same yellow.
 for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')and(p.Name=='BottomSeal'or p:GetAttribute('TearIndex'))then
  p.Color=A.Yellow;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0
 end end
 if isValid and not isValid()then folder:Destroy();return false end
 folder.Parent=bag
 -- (the root part and the seal / 8 tear strips are the ordinary pack's ten)
 bag:SetAttribute('CompactPackPartCount',#specs+10);bag:SetAttribute('CompactPackReady',true)
 bag:SetAttribute('PaperColor',A.Yellow);bag:SetAttribute('PreserveTextStyle',true)
 bag:SetAttribute('VerityPack',true);bag:SetAttribute('VerityPackDesign',A.Revision)
 return true
end
return A
