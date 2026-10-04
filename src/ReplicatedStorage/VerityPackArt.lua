-- R147 (owner: "VERITY PACK CAN JUST BE THE VERITY'S SMILING FACE"): the Verity pack (BagVariant 'VerityReliquary', Stage 7) IS Verity's
-- picture - VerityConfig.Image, the same one her NPC card shows (one source of truth) - on a square card, on its front AND back face.
--  * Decals, not SurfaceGuis: SurfaceGuis do not render in a ViewportFrame, and the hotbar / Bag pictures are viewports.
--  * The card sits inside the Void pack's bounds (side = the smaller of their width and height), so SeedPackVisuals.Bounds, the carry
--    layout and the platform are the Void pack's. No pouch, seal, tear strips, rings, runes, eye, halo or debris: just the face.
--  * A Decal is drawn at its own Transparency whatever its part's is, so the card is nearly invisible (CardTransparency, under the
--    0.95 "invisible" cut-off of ItemPictures / HarvestGeometry, which would drop a fully transparent part and its picture).
--    Set CardTransparency to 0 for an opaque gold card if a Decal ever turns out to follow its part's transparency.
--  * Coats: SeedPackVisuals.Bag paints every part of a Gold / Diamond pack, but not one marked CoatSkip: the card stays unpainted, its
--    two Decals take a light tint (CoatTint) and a thin rim of four bars (painted by the coat as usual) frames it.
--  * Opening: the copy SeedPackClient / PackOpeningFeedback make fades and hides parts; Decals follow only their own properties, so
--    those two scripts hide / fade them too (as BaseParts).
--  * The magic is VoidPackFx's gold set (Fx): sparkle emitters and a warm light, no outline, debris or comets.
local Catalog=require(script.Parent.VerityCatalog)
local Config=require(script.Parent.VerityConfig)
local Eclipse=require(script.Parent.EclipsePackArt)
local RGB=Color3.fromRGB
local C=Catalog.Palette
local A={Image=Config.Image,CardName='VerityCard',CardTransparency=.94,CardDepth=.05,RimWidth=.07,Revision=147}
A.CoatTint={Gold=RGB(255,225,150),Diamond=RGB(200,235,255)}
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
-- Fx colours for VoidPackFx (same fields as VoidPackFx.Void; no Debris / Comet / Fill / Outline = none of those pieces): gold
-- sparkles, a soft gold glow and a warm light - nothing purple.
A.Fx={
 Haze={Texture=SPARK,Colors={C.Ball,C.Honey},Size={.5,1.1},Emission=.7,Alpha=.55},
 Nebula={Texture=SPARK,Colors={C.Amber,C.Gloss},Size={.5,1.1},Emission=1,Alpha=.35},
 Stars={Texture=SPARK,Colors={C.White,C.Honey},Size={.10,.03},Emission=1,Alpha=.15},
 Light=RGB(255,196,70),
}
-- The card's side at scale 1 and the height of its centre: the Void pack's bounds are the limit - its width (twice the radius, less
-- the card's own depth) or its height, whichever is less; the card is centred in the bounds' height (they are not quite symmetric).
function A.Side()
 local b=Eclipse.Bounds(1);local half=(A.CardDepth+.03)/2
 return math.min(2*math.sqrt(b.Radius*b.Radius-half*half),b.MaxY-b.MinY)
end
function A.CentreY()local b=Eclipse.Bounds(1);return(b.MaxY+b.MinY)/2 end
function A.Tint(mutation)return A.CoatTint[mutation]or Color3.new(1,1,1)end
function A.Build(bag)
 if bag:GetAttribute('SpecialPackDesign89')then return true end
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1
 local mutation=bag:GetAttribute('PackMutation')or'None'
 -- The generic bag's seal and tear strips are not part of a picture.
 for _,p in ipairs(bag:GetChildren())do if p.Name=='BottomSeal'or p:GetAttribute('TearIndex')then p:Destroy()end end
 local folder=Instance.new('Folder');folder.Name='PackGeometry'
 local giant=(bag:GetAttribute('PackSize')or 1)>10
 local function piece(name,size,at)
  local p=Instance.new('Part');p.Name=name;p.Size=size*scale
  local frame=CFrame.new(at.X*scale,at.Y*scale,at.Z*scale);p.CFrame=root.CFrame*frame;p:SetAttribute('PackLocalFrame',frame)
  p.Color=C.Ball;p.Material=Enum.Material.SmoothPlastic;p.Transparency=0;p.Reflectance=0
  p.Anchored=root.Anchored;p.Massless=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if not p.Anchored then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end
  if giant then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end
  p.Parent=folder;return p
 end
 local side,depth,cy=A.Side(),A.CardDepth,A.CentreY()
 local card=piece(A.CardName,Vector3.new(side,side,depth),Vector3.new(0,cy,0))
 card.Transparency=A.CardTransparency;card:SetAttribute('CoatSkip',true);card:SetAttribute('VerityFace',true)
 for _,face in ipairs({{'VerityFaceFront',Enum.NormalId.Front},{'VerityFaceBack',Enum.NormalId.Back}})do
  local d=Instance.new('Decal');d.Name=face[1];d.Face=face[2];d.Texture=A.Image;d.Color3=A.Tint(mutation);d.Transparency=0;d.Parent=card
 end
 -- A Gold / Diamond pack: a thin rim in the coat (SeedPackVisuals.Bag paints these four bars like any other part of the pack).
 if mutation~='None'then
  local w,r=A.RimWidth,A.RimWidth*.5;local rimDepth=depth+.03
  for i,spec in ipairs({{side,w,0,side/2-r},{side,w,0,-side/2+r},{w,side-2*w,side/2-r,0},{w,side-2*w,-side/2+r,0}})do
   piece('VerityRim'..i,Vector3.new(spec[1],spec[2],rimDepth),Vector3.new(spec[3],cy+spec[4],0))
  end
 end
 folder.Parent=bag
 local count=0;for _,d in ipairs(bag:GetDescendants())do if d:IsA('BasePart')then count+=1 end end
 bag:SetAttribute('CompactPackPartCount',count);bag:SetAttribute('CompactPackReady',true)
 bag:SetAttribute('SpecialPackDesign89',true);bag:SetAttribute('PaperColor',C.Ball);bag:SetAttribute('PreserveTextStyle',true)
 bag:SetAttribute('VerityPack',true);bag:SetAttribute('VerityPackDesign',A.Revision)
 return true
end
-- The Void pack's bounds, scaled (SeedPackVisuals.Bounds asks for exactly this).
function A.Bounds(scale)return Eclipse.Bounds(scale)end
return A
