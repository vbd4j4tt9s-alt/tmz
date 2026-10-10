-- R147 (owner): the Verity seed and plant art. "The Verity seed is just a small Verity ball which players can plant into
-- the ground; the ball grows into a giant Verity fruit which is just a ball, with leaves at its bottom."
--  * BuildSeed: the loose seed, one small yellow ball with Verity's face (SeedPackVisuals.Seed calls it for VeritySeed).
--  * Get: the plant art in the RarityRework spec format PlantVisuals reads (ApprovedPlantArt.Get calls it): 14 leaves
--    (group 0) and the fruit (group 1: the yellow ball with Verity's face, R148; no gloss patch, R151). VerityGrowth grows the ball from seed size to its
--    full size on the leaf ring. The full-size art is built once; sockets / centres / radii / height / radius live here
--    so the catalog entry can stay a plain copy of them.
-- No requires except VerityCatalog, so ApprovedPlantArt and SeedPackVisuals can load it without a cycle.
local Cat=require(script.Parent.VerityCatalog)
local A={}
local V,CF=Vector3.new,CFrame.new
local function rgb(c)return {math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
-- Full-size plant, in studs at PlantScale 1 (FruitRadii / Height / Radius match the catalog entry).
A.Ball=22                 -- fruit diameter
A.SeedBall=1.3            -- seed (and the fruit's starting) diameter
A.Socket={0,1.6,0}        -- the bottom of the ball: it grows from here
A.Center={0,12.6,0}       -- the full ball's centre (socket + radius)
A.Height=23.6;A.Radius=11.2
A.OuterLeaves,A.InnerLeaves=8,6
A.OuterElevation,A.InnerElevation=18,28 -- degrees above level
function A.Is(id)return Cat.Is(id)end
-- An image id as the Decal wants it (a number, a digit string or a full rbxassetid:// url); nil when unset.
local function texture(id)
 if id==nil or id==''or id==0 then return nil end
 if type(id)=='number'then return 'rbxassetid://'..string.format('%d',id)end
 if type(id)=='string'and id:match('^%d+$')then return 'rbxassetid://'..id end
 return tostring(id)
end
A.FaceTexture=function()return texture(Cat.FaceImageId)end
-- R148 (owner: "the exact same smile that Verity has" on the seed, the fruit and the plant): the face is Verity's own picture, used
-- unaltered (white Decal colour, no tint). R151 (owner: "verity fruit also has 2 faces"): ONE face, on ONE side of the ball. A Decal on a Ball part scales
-- with the part, so it follows the growth by itself.
-- Which side is the side the viewer sees:
--  * Front (-Z of the part): the seed and the fruit as an item. The Bag / hotbar / Index pictures look at it from -Z (ItemPictures: (.45,.35,-1); the Index
--    card: (sin, .22, -cos)), the held fruit and seed sit in the hand with -Z forward, and the seed art's front faces -Z (SeedSignatures).
--  * Back (+Z): the PLANTED fruit. The plant's own surface details (bark grooves, cactus ribs, grain marks: PlantVisuals surfacePoint) lie on +Z, and the
--    garden's front is +Z (the pad's entrance side, GardenBaseLayout / HubDecor151), so the face looks at the path. The fruit that flies off the plant keeps
--    that side and flies toward the harvester, who stands on the path.
function A.AddFace(part,image,side)
 local d=Instance.new('Decal');d.Name='VerityBallFace';d.Texture=image;d.Face=side or Enum.NormalId.Front;d.Color3=Color3.new(1,1,1);d.Transparency=0;d.Parent=part
 return d
end
-- The side of the ball the face is on for a crop: a planted crop (a garden plant, its regrowing fruit, its far proxy) faces the path; everything detached from
-- a plant (a harvested item, the hotbar / Bag / Sell pictures, the held fruit) and the Index card's preview crop (Id 'preview...') face front.
function A.FaceSide(crop)
 if crop==nil or crop._DetachedHarvest then return Enum.NormalId.Front end
 if string.sub(tostring(crop.Id or'preview'),1,7)=='preview'then return Enum.NormalId.Front end
 return Enum.NormalId.Back
end
-- Verity's own yellow (her body, SmoothPlastic): the seed is literally a small Verity ball.
A.Yellow=Color3.fromRGB(255,255,0)

-- Leaf spec: LeafBlade size {width,length,thickness}. The blade's length runs along local Y, its width along X and its
-- thin side along Z (PlantVisuals.sculptedLeaf), so after tipping it outward by `elevation` a quarter turn about its own
-- length lays it flat (broad side up) with the folded ridge on top. `base` (where it starts, at the ring) is stored so
-- VerityGrowth can grow each leaf from its base.
local function leaf(angle,elevation,r0,y0,size,color,name)
 local rot=CFrame.Angles(0,angle,0)*CFrame.Angles(0,0,-(math.pi/2-elevation))*CFrame.Angles(0,-math.pi/2,0)
 local base=V(r0*math.cos(angle),y0,-r0*math.sin(angle))
 local at=base+rot.UpVector*(size[2]/2)
 local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=(CF(at)*rot):GetComponents()
 return {s='LeafBlade',z=size,c={x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22},k=color,m='SmoothPlastic',t=0,g=0,r='Leaf',f=name,
  base={base.X,base.Y,base.Z}}
end
local built,builtFace
function A.Get(id)
 if id~=nil and not Cat.Is(id)then return nil end
 local face=A.FaceTexture()
 if built and builtFace==face then return built end
 builtFace=face
 local P=Cat.Palette
 local outer,inner,ball=rgb(P.LeafOuter),rgb(P.LeafInner),rgb(A.Yellow)
 local specs={}
 local function add(s)s._ArtIndex=#specs+1;specs[#specs+1]=s end
 -- Leaves first (group 0): a ring of 8 long outer leaves (low, wide spread) with 6 shorter, steeper ones between them.
 -- The ball (Ø22, bottom at y 1.6) is round: a leaf steeper than ~30 degrees would sink into it, so they stay below it.
 for k=0,A.OuterLeaves-1 do add(leaf(k*math.rad(360/A.OuterLeaves),math.rad(A.OuterElevation),2.0,.5,{3.4,9,.35},outer,'Verity leaf'))end
 for k=0,A.InnerLeaves-1 do add(leaf(math.rad(22.5)+k*math.rad(360/A.InnerLeaves),math.rad(A.InnerElevation),1.2,.8,{2.6,6,.3},inner,'Verity leaf'))end
 -- The fruit (group 1): Verity's yellow ball, a true sphere, with her face on one side (R151: one face, no white gloss patches).
 add({s='Sphere',z={A.Ball,A.Ball,A.Ball},c={A.Center[1],A.Center[2],A.Center[3],1,0,0,0,1,0,0,0,1},k=ball,m='SmoothPlastic',t=0,g=1,r='Fruit',
  f='Verity fruit',rf=.18,face=face})
 built={Specs=specs,Sockets={{A.Socket[1],A.Socket[2],A.Socket[3]}},FruitCenters={{A.Center[1],A.Center[2],A.Center[3]}},FruitRadii={A.Ball/2},
  Height=A.Height,Radius=A.Radius,RarityRework=true,Verity=true}
 return built
end

-- The loose seed: a small Verity ball with her face (front, -Z), centred on `origin`. Returns the (unparented) model; SeedPackVisuals adds
-- the coat, the rarity sparkle, the motion tag and the parent, exactly as for every other seed.
function A.BuildSeed(origin,scale,weldRoot)
 scale=scale or 1
 local model=Instance.new('Model');model.Name='LooseSeed'
 local anchored=weldRoot==nil or weldRoot.Anchored
 local function part(name,size,frame,color,material,transparency,reflectance)
  local p=Instance.new('Part');p.Name=name;p.Shape=Enum.PartType.Ball;p.Size=V(size,size,size)*scale;p.CFrame=frame
  p.Color=color;p.Material=material;p.Transparency=transparency;p.Reflectance=reflectance
  p.Anchored=anchored;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=model;return p
 end
 local root=Instance.new('Part');root.Name='VisualRoot';root.Size=V(.1,.1,.1);root.CFrame=origin;root.Transparency=1
 root.Anchored=anchored;root.Massless=true;root.CanCollide=false;root.CanTouch=false;root.CanQuery=false;root.Parent=model;model.PrimaryPart=root
 local function weld(p)if not anchored then local w=Instance.new('WeldConstraint');w.Part0=weldRoot;w.Part1=p;w.Parent=p end end
 weld(root)
 local body=part('Verity seed',A.SeedBall,origin,A.Yellow,Enum.Material.SmoothPlastic,0,.2)
 local face=A.FaceTexture()
 if face then A.AddFace(body,face)end
 weld(body)
 if scale>10 then game:GetService('CollectionService'):AddTag(body,'GiantVisualPart')end
 return model
end
return A
