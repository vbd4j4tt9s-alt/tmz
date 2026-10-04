-- R147 (owner): the Verity seed and plant art. "The Verity seed is just a small Verity ball which players can plant into
-- the ground; the ball grows into a giant Verity fruit which is just a ball, with leaves at its bottom."
--  * BuildSeed: the loose seed, one small glossy ball (SeedPackVisuals.Seed calls it for VeritySeed).
--  * Get: the plant art in the RarityRework spec format PlantVisuals reads (ApprovedPlantArt.Get calls it): 14 leaves
--    (group 0) and the fruit (group 1: the ball and its gloss). VerityGrowth then grows the ball from seed size to its
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
-- A thin lens lying on the ball: centred `distance` from the ball centre along `dir`, its thin axis (local Z) facing
-- outward, its wide axis (X) level. `slide` moves it across the ball (in its own X / Y), for a glint on a gloss patch.
local function lens(dir,distance,size,color,transparency,name,slideX,slideY)
 local zAxis=dir.Unit;local xAxis=V(0,1,0):Cross(zAxis).Unit;local yAxis=zAxis:Cross(xAxis)
 if slideX then zAxis=(zAxis+xAxis*slideX+yAxis*slideY).Unit;xAxis=V(0,1,0):Cross(zAxis).Unit;yAxis=zAxis:Cross(xAxis)end
 local c=V(A.Center[1],A.Center[2],A.Center[3])+zAxis*distance
 local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=CFrame.fromMatrix(c,xAxis,yAxis,zAxis):GetComponents()
 return {s='Ball',z=size,c={x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22},k=color,m='Neon',t=transparency,g=1,r='Fruit',f=name,decor=true}
end
local built,builtFace
function A.Get(id)
 if id~=nil and not Cat.Is(id)then return nil end
 local face=A.FaceTexture()
 if built and builtFace==face then return built end
 builtFace=face
 local P=Cat.Palette
 local outer,inner,ball,gloss=rgb(P.LeafOuter),rgb(P.LeafInner),rgb(P.Ball),rgb(P.Gloss)
 local specs={}
 local function add(s)s._ArtIndex=#specs+1;specs[#specs+1]=s end
 -- Leaves first (group 0): a ring of 8 long outer leaves (low, wide spread) with 6 shorter, steeper ones between them.
 -- The ball (Ø22, bottom at y 1.6) is round: a leaf steeper than ~30 degrees would sink into it, so they stay below it.
 for k=0,A.OuterLeaves-1 do add(leaf(k*math.rad(360/A.OuterLeaves),math.rad(A.OuterElevation),2.0,.5,{3.4,9,.35},outer,'Verity leaf'))end
 for k=0,A.InnerLeaves-1 do add(leaf(math.rad(22.5)+k*math.rad(360/A.InnerLeaves),math.rad(A.InnerElevation),1.2,.8,{2.6,6,.3},inner,'Verity leaf'))end
 -- The fruit (group 1): a plain ball, two gloss patches (upper front-left and upper back-right, so it shines from
 -- every side) with a small hot spot on each. The ball is a true sphere; the patches are flattened ellipsoids.
 add({s='Sphere',z={A.Ball,A.Ball,A.Ball},c={A.Center[1],A.Center[2],A.Center[3],1,0,0,0,1,0,0,0,1},k=ball,m='SmoothPlastic',t=0,g=1,r='Fruit',
  f='Verity fruit',rf=.18,face=face})
 for _,sign in ipairs({-1,1})do
  local dir=V(.42*sign,.62,.66*sign)
  add(lens(dir,10.75,{6.4,4.2,.8},gloss,.55,'Verity gloss'))
  add(lens(dir,11,{2,1.4,.4},gloss,.2,'Verity glint',-.07,.06))
 end
 built={Specs=specs,Sockets={{A.Socket[1],A.Socket[2],A.Socket[3]}},FruitCenters={{A.Center[1],A.Center[2],A.Center[3]}},FruitRadii={A.Ball/2},
  Height=A.Height,Radius=A.Radius,RarityRework=true,Verity=true}
 return built
end

-- The loose seed: a small glossy Verity ball, centred on `origin`. Returns the (unparented) model; SeedPackVisuals adds
-- the coat, the rarity sparkle, the motion tag and the parent, exactly as for every other seed.
function A.BuildSeed(origin,scale,weldRoot)
 scale=scale or 1
 local P=Cat.Palette
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
 local body=part('Verity seed',A.SeedBall,origin,P.Ball,Enum.Material.SmoothPlastic,0,.2)
 local face=A.FaceTexture()
 if face then local d=Instance.new('Decal');d.Name='VerityFace';d.Texture=face;d.Face=Enum.NormalId.Front;d.Parent=body end
 -- A soft gloss ball and a bright glint on the upper front-left (the front is -Z).
 local g=part('Verity gloss',.45,origin*CF(-.25*scale,.32*scale,-.38*scale),P.Gloss,Enum.Material.Neon,.35,0)
 local glint=part('Verity glint',.16,origin*CF(-.33*scale,.42*scale,-.47*scale),P.Gloss,Enum.Material.Neon,.05,0)
 g:SetAttribute('VerityDecor',true);glint:SetAttribute('VerityDecor',true) -- hidden under a Gold / Diamond coat (SeedPackVisuals)
 for _,p in ipairs({body,g,glint})do weld(p)end
 if scale>10 then for _,p in ipairs({body,g,glint})do game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end end
 return model
end
return A
