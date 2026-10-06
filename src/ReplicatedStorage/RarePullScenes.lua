-- R151: the Secret / Cosmic / King story scenes. Built on demand on the OPENER's client only, at a hidden spot far above the map
-- (RarePullRules.StageOrigin), out of plain parts in the game's own style, and destroyed when the scene ends: nobody else ever sees them.
-- The two stars are the SEED PACK being opened (a clone of the real pack in the player's hands: its art, coat and colours) and the SEED that
-- comes out of it (its real model with its rarity aura, SeedPackVisuals.CreateSeedMotion). Every scene ends on the seed: big, centred,
-- floating down toward the camera. Where the pack, the seed, the crown and the camera are at each moment is RarePullRules (PackPose /
-- SeedPose / CrownPose / Shot), so tests and previews read the same numbers.
--  SECRET  a dark void: the pack hangs in the dark and glitches, a ring of lock plates closes around it and turns (click, click), the bolts
--          pull back, light spills from cracks in the pack, it shudders, silence, it bursts in violet light; the seed floats out of the dark.
--  COSMIC  deep space: the pack drifts in like a planet, three planets swing into line around it, a galaxy swirls and the pack spins up,
--          implodes to a point, silence, supernova; the seed flies out of the star as a falling star and settles, floating down.
--  KING    a throne room (red carpet, pillars, banners, windows with light shafts, chandelier, heralds' trumpets): the pack is carried down
--          the carpet in a beam of light to a royal cushion on the throne, trumpets, a crown descends onto the PACK, the crowned pack shakes,
--          silence, it bursts in gold rays and confetti; the seed rises crowned out of the light and floats down to the camera.
-- Budget (the backdrop; the pack and the seed add their own ~15 + 35-65): King <= 190 parts (phone / low quality <= 125), Cosmic <= 95 (55),
-- Secret <= 80 (55); at most 4 lights; CastShadow off; nothing is touched after Destroy().
local RS=game:GetService('ReplicatedStorage')
local Rules=require(script.Parent.RarePullRules)
local Fx=require(script.Parent.RarePullFx)
local Art=require(script.Parent.RarePullArt)
local S={}
-- R152 (owner: "planets have to look good by texturing", "improve look on the beam and assets used in the animations"): the same stages,
-- dressed better. Images drawn on the client (RarePullArt, ready a while after the client starts) where they help: textured planets with
-- atmospheres and a ring, nebula clouds and a star map in deep space, a glowing rune circle under the Secret pack, the throne room's carpet,
-- banners, stained glass and damask walls, a soft halo behind every seed. Without those images (not drawn yet, EditableImage off, low
-- quality) each piece keeps a dressed fallback of plain parts (a textured material, an atmosphere shell). The King's carry / crown beams are
-- the layered beam of RarePullFx in gold; every hit is a layered burst (flash, sparks, smoke: RarePullFx.Burst); the pack has a rim of light.
S.ArtNames={[6]={'runes','glow','halo'},[7]={'planet_gas','planet_rock','planet_ring','nebula_rose','nebula_blue','starmap','glow','halo'},[8]={'carpet','banner','glass','damask','glow','halo'}}
local V,CF,ANG=Vector3.new,CFrame.new,CFrame.Angles
local C=Color3.fromRGB
local NEON,SMOOTH,METAL,MARBLE,FABRIC,WOOD=Enum.Material.Neon,Enum.Material.SmoothPlastic,Enum.Material.Metal,Enum.Material.Marble,Enum.Material.Fabric,Enum.Material.Wood
local BALL,CYL=Enum.PartType.Ball,Enum.PartType.Cylinder
local SPARK='rbxasset://textures/particles/sparkles_main.dds';local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local FRONT=ANG(0,math.pi,0) -- packs and seeds face -Z in their own frame; the camera looks at the stage from +Z
local function clamp01(x)return math.clamp(x,0,1)end
local Scene={};Scene.__index=Scene
function Scene:Part(name,size,cf,color,mat,trans,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 if shape then p.Shape=shape end
 p.Size=size;p.CFrame=self.Origin*cf;p.Color=color;p.Material=mat or SMOOTH;p.Transparency=trans or 0;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Parent=self.Folder;self.Count+=1;return p
end
function Scene:Place(p,cf)p.CFrame=self.Origin*cf end
function Scene:Light(parent,color,brightness,range)
 local l=Instance.new('PointLight');l.Color=color;l.Brightness=brightness;l.Range=range;l.Shadows=false;l.Parent=parent;self.Lights+=1;return l
end
-- An image drawn by RarePullArt, if it is ready (nil otherwise: the caller keeps its fallback).
function Scene:Art(name)
 if self.NoArt then return nil end
 local state,content=Art.Get(name)
 if state=='ready'then return content end
 return nil
end
-- A camera-facing image (BillboardGui, unlit) of `size` studs on `parent` (it follows it), or nil when the image is not ready.
function Scene:Billboard(parent,size,name,color,z)
 local content=self:Art(name);if not content then return nil end
 local g=Instance.new('BillboardGui');g.Name='Art '..name;g.Size=UDim2.fromScale(size,size);g.LightInfluence=0;g.AlwaysOnTop=false;g.ResetOnSpawn=false
 pcall(function()g.MaxDistance=1e5 end)
 local img=Instance.new('ImageLabel');img.Name='Image';img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.ImageColor3=color or C(255,255,255);img.ZIndex=z or 1
 local ok=pcall(function()img.ImageContent=content end)
 if not ok then g:Destroy();img:Destroy();return nil end
 img:SetAttribute('RarePullArt',name);img.Parent=g;g.Parent=parent;self.Images+=1
 return {Gui=g,Image=img}
end
-- An image on a face of a part: unlit (a SurfaceGui: glass, runes, stars) or lit (a Decal / tiled Texture), or nil when not ready.
function Scene:FaceArt(target,face,name,opts)
 opts=opts or{}
 local content=self:Art(name);if not content then return nil end
 if opts.Unlit then
  local g=Instance.new('SurfaceGui');g.Name='Art '..name;g.Face=face;g.LightInfluence=0;g.AlwaysOnTop=false;g.ResetOnSpawn=false
  pcall(function()g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;g.PixelsPerStud=opts.PixelsPerStud or 20 end)
  local img=Instance.new('ImageLabel');img.Name='Image';img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.ImageColor3=opts.Color or C(255,255,255)
  if opts.Tile then img.ScaleType=Enum.ScaleType.Tile;img.TileSize=UDim2.fromOffset(opts.Tile,opts.Tile)end
  local ok=pcall(function()img.ImageContent=content end)
  if not ok then g:Destroy();img:Destroy();return nil end
  img:SetAttribute('RarePullArt',name);img.Parent=g;g.Parent=target;self.Images+=1
  return {Gui=g,Image=img}
 end
 local d=Instance.new(opts.StudsPerTile and'Texture'or'Decal');d.Name='Art '..name;d.Face=face
 if opts.StudsPerTile then d.StudsPerTileU=opts.StudsPerTile[1];d.StudsPerTileV=opts.StudsPerTile[2]end
 if opts.Color then d.Color3=opts.Color end
 local ok=pcall(function()d.TextureContent=content end)
 if not ok then d:Destroy();return nil end
 d:SetAttribute('RarePullArt',name);d.Parent=target;self.Images+=1
 return {Decal=d}
end
function Scene:Emitter(parent,props)
 local e=Instance.new('ParticleEmitter');e.Texture=SPARK;e.LightEmission=1;e.LightInfluence=0;e.Enabled=false
 for k,v in pairs(props)do e[k]=v end
 e.Parent=parent;return e
end
-- an enclosure: floor, ceiling and four walls (the camera is always inside, so the map and the sky are never seen)
function Scene:Box(w,d,h,zc,floorColor,wallColor,floorMat,wallMat)
 local t=1
 self:Part('Floor',V(w,t,d),CF(0,-t/2,zc),floorColor,floorMat or SMOOTH)
 self:Part('Ceiling',V(w,t,d),CF(0,h+t/2,zc),wallColor,wallMat or SMOOTH)
 self:Part('Wall back',V(w,h,t),CF(0,h/2,zc-d/2),wallColor,wallMat or SMOOTH)
 self:Part('Wall front',V(w,h,t),CF(0,h/2,zc+d/2),wallColor,wallMat or SMOOTH)
 self:Part('Wall left',V(t,h,d),CF(-w/2,h/2,zc),wallColor,wallMat or SMOOTH)
 self:Part('Wall right',V(t,h,d),CF(w/2,h/2,zc),wallColor,wallMat or SMOOTH)
end
-- a flat ring of segments (radius set per frame); plane: 'XZ' (the floor) or 'XY' (facing the camera)
function Scene:Ring(name,n,color,plane)
 local r={Plane=plane,Segs={}}
 for i=1,n do r.Segs[i]=self:Part(name,V(.4,.08,.12),CF(0,-50,0),color,NEON,1)end
 return r
end
function Scene:PlaceRing(r,centre,radius,width,trans)
 local n=#r.Segs
 for i,seg in ipairs(r.Segs)do
  local a=(i-.5)/n*math.pi*2;local len=2*math.pi*radius/n*1.06
  seg.Size=V(math.max(.05,len),.08,width)
  if r.Plane=='XY'then self:Place(seg,CF(centre+V(math.cos(a)*radius,math.sin(a)*radius,0))*ANG(0,0,a+math.pi/2)*ANG(math.pi/2,0,0))
  else self:Place(seg,CF(centre+V(math.cos(a)*radius,0,math.sin(a)*radius))*ANG(0,-a+math.pi/2,0))end
  seg.Transparency=trans
 end
end
-- The pack: a clone of the real pack (or a stand-in), scaled to the hero height, centred on its bounding box.
local function prepare(model,height,maxSide)
 local parts={}
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false;d.CastShadow=false;parts[#parts+1]=d
  elseif d:IsA('Decal')then parts[#parts+1]=d end
 end
 -- sized and centred by what is visible (RarePullRules.VisibleBounds: a seed's SpecialMesh parts are smaller than their boxes)
 local function bounds()
  local ok,c,s=pcall(Rules.VisibleBounds,model)
  if ok and c then return CF(c),s end
  local ok2,cf,size=pcall(function()return model:GetBoundingBox()end)
  if ok2 and cf then return cf,size end
  return nil
 end
 local cf,size=bounds()
 if cf and size then
  local side=height and size.Y or math.max(size.X,size.Y,size.Z)
  local target=height or maxSide
  if side>.01 then pcall(function()model:ScaleTo(model:GetScale()*target/side)end)end
  cf,size=bounds()
 end
 if not cf then cf,size=model:GetPivot(),V(2,2.6,.6)end
 return parts,CF(cf.Position):Inverse()*model:GetPivot(),size
end
local function setAlpha(parts,alpha,base)
 local m=1-clamp01(alpha)
 for _,p in ipairs(parts)do if p.Parent then p.LocalTransparencyModifier=math.max(m,base or 0)end end
end
-- opts: {Lite, Reduced, Pack=Model, Seed=Model, Origin=Vector3, Parent}
function S.Build(rank,opts)
 opts=opts or{}
 local folder=Instance.new('Folder');folder.Name='_RarePullStage'
 local self=setmetatable({Rank=rank,Folder=folder,Origin=CF(opts.Origin or Rules.StageOrigin),Count=0,Lights=0,Images=0,Lite=opts.Lite==true,Reduced=opts.Reduced==true,Fx={},
  NoArt=opts.NoArt==true or not Art.Allowed(),FxTier=opts.FxTier or(opts.Lite and math.min(2,Fx.Tier())or Fx.Tier())},Scene)
 local tier=Rules.Tier(rank)
 if Art.Allowed()then pcall(Art.Request,S.ArtNames[rank]or{})end -- (drawn now if they were not yet: ready for the next scene; on low quality they would never be shown, so never drawn)
 -- the stars
 if opts.Pack then
  local pack=opts.Pack;pack.Parent=folder
  self.PackParts,self.PackRel,self.PackSize=prepare(pack,Rules.PackHeroHeight)
  self.Pack=pack
 end
 if opts.Seed then
  local seed=opts.Seed;seed.Parent=folder
  self.SeedParts,self.SeedRel,self.SeedSize=prepare(seed,nil,Rules.SeedHeroSize)
  self.Seed=seed;self.SeedScale=1
  pcall(function()self.SeedScale=seed:GetScale()end)
  local ok,Visuals=pcall(require,RS:FindFirstChild('SeedPackVisuals'))
  if ok and Visuals and Visuals.CreateSeedMotion then
   local ok2,motion=pcall(Visuals.CreateSeedMotion,seed,folder,not self.Lite)
   if ok2 then self.Motion=motion end
  end
  setAlpha(self.SeedParts,0)
 end
 self.Key=self:Part('Seed key light',V(.1,.1,.1),CF(0,-60,0),C(255,255,255),SMOOTH,1)
 self.KeyLight=self:Light(self.Key,C(255,246,232),0,11)
 self.FlashPart=self:Part('Burst light',V(.1,.1,.1),CF(0,-60,0),tier.Glow,SMOOTH,1)
 self.FlashLight=self:Light(self.FlashPart,tier.Theme or tier.Glow,0,24)
 -- the hit: a layered burst at the pack (flash, sparks, a puff of smoke) in the tier's colours
 self.Burst=Fx.Burst({Parent=folder,Host=self.FlashPart,Name='Pack burst',Color=tier.Theme or tier.Hint,Glow=tier.Glow,Size=rank==8 and 1.25 or 1.1,Tier=self.FxTier})
 -- the seed's halo: a soft ring and glow behind it, in the tier's colours, following it (images; without them, none)
 if opts.Seed then
  self.HaloAnchor=self:Part('Seed halo',V(.1,.1,.1),CF(0,-60,0),tier.Glow,SMOOTH,1)
  self.SeedGlow=self:Billboard(self.HaloAnchor,Rules.SeedHeroSize*3.2,'glow',tier.Theme or tier.Glow,1)
  self.SeedHalo=self:Billboard(self.HaloAnchor,Rules.SeedHeroSize*2.1,'halo',tier.Glow,2)
 end
 -- a rim of light around the pack until it bursts (not on low quality / phones)
 if self.Pack and not self.Lite then
  local h=Instance.new('Highlight');h.Name='Pack rim';h.Adornee=self.Pack;h.FillTransparency=1;h.OutlineColor=tier.Theme or tier.Glow;h.OutlineTransparency=.45
  h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=folder;self.PackRim=h
 end
 if rank==6 then self:_void()elseif rank==7 then self:_space()else self:_throne()end
 folder.Parent=opts.Parent or workspace
 return self
end
-- SECRET -------------------------------------------------------------------------------------------------------------------------------------
function Scene:_void()
 local lite=self.Lite;local violet=C(150,80,255);local pale=C(232,210,255)
 self:Box(70,70,34,0,C(10,6,16),C(5,3,10),Enum.Material.Glass,SMOOTH)
 local pack=Rules.Points[6].Pack
 -- the seal under the pack: a glowing rune circle on the black glass that turns slowly and flares as the lock opens (an image; without it,
 -- the neon seams of R151)
 local seal=self:Art('runes')and self:Part('Rune circle',V(34,.04,34),CF(pack.X,.03,pack.Z),C(8,4,14),SMOOTH,0)
 self.Runes=seal and self:FaceArt(seal,Enum.NormalId.Top,'runes',{Unlit=true,Color=C(186,130,255),PixelsPerStud=8}) -- (34 studs across: it reaches out to where the floor is in view)
 if seal and not self.Runes then seal:Destroy();self.Count-=1 end
 if not self.Runes then
  for i=1,(lite and 4 or 8)do
   local a=(i-1)/(lite and 4 or 8)*math.pi
   self:Part('Floor seam',V(40,.04,.08),CF(pack.X,.02,pack.Z)*ANG(0,a,0),C(110,50,190),NEON,.62)
  end
 end
 local disc=self:Part('Rim glow',V(.1,5,5),CF(pack.X,.04,pack.Z)*ANG(0,0,math.pi/2),violet,NEON,.55,CYL)
 self.Rim=self:Light(disc,violet,1.6,13)
 local fogAnchor=self:Part('Void fog',V(30,4,30),CF(0,2,-4),C(0,0,0),SMOOTH,1)
 self.Fog=self:Emitter(fogAnchor,{Texture=SMOKE,LightEmission=.2,Color=ColorSequence.new(C(70,26,110),C(20,6,40)),Rate=lite and 3 or 7,Lifetime=NumberRange.new(5,8),
  Speed=NumberRange.new(.2,.6),Size=NumberSequence.new(8,13),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4,.84),NumberSequenceKeypoint.new(1,1)}),Enabled=true})
 pcall(function()self.Fog:Emit(lite and 6 or 14)end)
 local n=lite and 6 or 8
 self.Plates={};self.Bolts={};self.Inlays={}
 for i=1,n do
  -- (R152: a dark iron plate with a violet inlay along its face that lights up as the lock opens)
  self.Plates[i]=self:Part('Lock plate',V(1.1,.55,.18),CF(0,-60,0),C(34,26,48),METAL,1)
  self.Bolts[i]=self:Part('Lock bolt',V(.22,.22,.22),CF(0,-60,0),violet,NEON,1,BALL)
  if not lite then -- (a lit strip on its face: a SurfaceGui, no extra part)
   local g=Instance.new('SurfaceGui');g.Name='Plate inlay';g.Face=Enum.NormalId.Back;g.LightInfluence=0;g.ResetOnSpawn=false;g.CanvasSize=Vector2.new(110,55)
   local f=Instance.new('Frame');f.Name='Strip';f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.5);f.Size=UDim2.fromScale(.74,.16);f.BorderSizePixel=0
   f.BackgroundColor3=violet;f.BackgroundTransparency=1;f.Parent=g
   local cr=Instance.new('UICorner');cr.CornerRadius=UDim.new(.5,0);cr.Parent=f
   local gr=Instance.new('UIGradient');gr.Color=ColorSequence.new(violet,pale);gr.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,.5)});gr.Parent=f
   g.Parent=self.Plates[i];self.Inlays[i]=f
  end
 end
 self.Cracks={}
 local crackSpecs={{-.25,.35,.9,-.9},{.2,.1,1.1,.7},{-.05,-.35,.8,.2},{.35,-.2,.6,-1.2},{-.4,-.1,.55,1.1},{.05,.55,.5,-.3},{-.1,-.65,.6,1.4}}
 for i=1,(lite and 4 or 7)do local s=crackSpecs[i];self.Cracks[i]={Part=self:Part('Crack',V(.04,.04,.03),CF(0,-60,0),pale,NEON,1),X=s[1],Y=s[2],L=s[3],R=s[4]}end
 self.Leaks={}
 for i=1,(lite and 4 or 6)do self.Leaks[i]=self:Part('Light leak',V(.18,.18,.05),CF(0,-60,0),pale,NEON,1)end
 self.Shards={}
 for i=1,(lite and 8 or 14)do self.Shards[i]=self:Part('Pack shard',V(.22,.16,.05),CF(0,-60,0),i%3==0 and pale or violet,NEON,1)end
 self.Wave=self:Ring('Shockwave',lite and 10 or 16,pale,'XY')
 self.Wisps=self:Emitter(self.Key,{Texture=SMOKE,LightEmission=.4,Color=ColorSequence.new(C(150,80,255),C(40,10,70)),Rate=lite and 6 or 14,Lifetime=NumberRange.new(1.2,2),
  Speed=NumberRange.new(.3,.9),SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new(.6,1.6),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.6),NumberSequenceKeypoint.new(1,1)})})
end
-- COSMIC -------------------------------------------------------------------------------------------------------------------------------------
function Scene:_space()
 local lite=self.Lite
 self:Box(130,130,90,-10,C(3,4,14),C(4,5,18),SMOOTH,SMOOTH)
 local starAnchor=self:Part('Starfield',V(110,70,110),CF(0,30,-10),C(0,0,0),SMOOTH,1)
 self.Starfield=self:Emitter(starAnchor,{Rate=lite and 2 or 5,Lifetime=NumberRange.new(14,20),Speed=NumberRange.new(0,0),Size=NumberSequence.new(.35),
  Color=ColorSequence.new(C(255,255,255),C(190,210,255)),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.1,.1),NumberSequenceKeypoint.new(.9,.2),NumberSequenceKeypoint.new(1,1)}),Enabled=true})
 pcall(function()self.Starfield:Emit(lite and 90 or 220)end)
 local stars={{-30,22,-55},{24,30,-60},{-12,40,-58},{36,12,-50},{-44,8,-48},{10,48,-62},{-22,-6,-55},{42,34,-40}}
 for i=1,(lite and 4 or 8)do local s=stars[i];self:Part('Bright star',V(.5,.5,.5),CF(s[1],s[2],s[3]),C(255,255,255),NEON,0,BALL)end
 -- the star map on the far walls and the ceiling (unlit, tiled; without the image, the particle starfield alone)
 local box=self.Folder
 local farWall
 -- (and, dimmer, on the floor: space all around, no floor line under the far wall's stars)
 for _,w in ipairs({{'Wall back',Enum.NormalId.Back},{'Wall left',Enum.NormalId.Right},{'Wall right',Enum.NormalId.Left},{'Ceiling',Enum.NormalId.Bottom},{'Floor',Enum.NormalId.Top,C(110,118,160)}})do
  local wall=box:FindFirstChild(w[1]);if wall then local a=self:FaceArt(wall,w[2],'starmap',{Unlit=true,PixelsPerStud=6,Tile=180,Color=w[3]or C(220,225,255)});if w[1]=='Wall back'then farWall=a and{Art=a,Part=wall}end end
 end
 self.Nebula={}
 -- nebulae: clouds of gas drawn on the client, painted on the far wall over its star map (as camera-facing images, clouds this big cut into
 -- the floor and the walls), wholly on it, turning very slowly. Without the images: the soft neon discs of R151.
 local neb={{C(255,90,200),-18,18,-62,34,'nebula_rose'},{C(120,90,255),14,26,-66,40,'nebula_blue'},{C(60,200,255),-2,10,-70,46,'nebula_blue'},{C(255,140,90),26,4,-64,26,'nebula_rose'},{C(150,60,220),-30,34,-60,30,'nebula_rose'}}
 self.NebulaBase={};self.NebulaArt={}
 for i=1,(lite and 3 or 5)do
  local n=neb[i];local content=farWall and self:Art(n[6])
  if content then
   local ws=farWall.Part.Size;local size=n[5]*1.2;local y=math.max(n[3],size/2+2)
   local img=Instance.new('ImageLabel');img.Name='Nebula';img.BackgroundTransparency=1;img.AnchorPoint=Vector2.new(.5,.5);img.ZIndex=2
   img.Position=UDim2.fromScale((n[2]+ws.X/2)/ws.X,1-y/ws.Y);img.Size=UDim2.fromScale(size/ws.X,size/ws.Y)
   img.ImageColor3=n[1]:Lerp(C(255,255,255),.15);img.ImageTransparency=.3
   if pcall(function()img.ImageContent=content end)then img:SetAttribute('RarePullArt',n[6]);img.Parent=farWall.Art.Gui;self.Images+=1;self.NebulaArt[i]={Gui=farWall.Art.Gui,Image=img}
   else img:Destroy()end
  end
  if not self.NebulaArt[i]then
   local k=#self.Nebula+1
   self.Nebula[k]=self:Part('Nebula',V(.3,n[5],n[5]),CF(n[2],n[3],n[4])*ANG(0,math.pi/2,0)*ANG(0,0,0),n[1],NEON,.88,CYL);self.NebulaBase[k]=self.Nebula[k].CFrame
  end
 end
 self.Planets={}
 -- textured planets: a lit sphere drawn on the client (its image is the planet and its atmosphere rim; the third is ringed). Without the
 -- images: a ball of a material with its own texture, a soft atmosphere shell, and the neon ring
 local specs={{1.4,'planet_rock',C(150,160,182),Enum.Material.Slate,5.2,.35,false,C(150,190,255),.74},{2.0,'planet_gas',C(228,150,92),Enum.Material.Sand,7.4,-.25,false,C(255,200,140),.74},
  {1.1,'planet_ring',C(190,215,240),Enum.Material.Glacier,9.6,.5,true,C(170,220,255),.42}}
 for i,s in ipairs(specs)do
  local size=s[1]
  local body=self:Part('Planet',V(size,size,size),CF(0,-60,0),s[3],s[4],0,BALL)
  local art=self:Billboard(body,size/s[9],s[2])
  local shell,ring
  if art then body.Transparency=1
  else
   shell=self:Part('Planet atmosphere',V(size*1.16,size*1.16,size*1.16),CF(0,-60,0),s[8],NEON,.84,BALL)
   if s[7]then ring=self:Part('Planet ring',V(.06,size*2.1,size*2.1),CF(0,-60,0),s[3]:Lerp(C(255,255,255),.4),NEON,.45,CYL)end
  end
  self.Planets[i]={Body=body,Art=art,Shell=shell,Ring=ring,Radius=s[5],Tilt=s[6],Phase=i*2.2}
 end
 self.Galaxy={}
 for arm=1,2 do for j=1,(lite and 7 or 12)do
  self.Galaxy[#self.Galaxy+1]={Part=self:Part('Galaxy star',V(.18,.18,.18),CF(0,-60,0),arm==1 and C(190,170,255)or C(140,220,255),NEON,1,BALL),Arm=arm,J=j}
 end end
 self.Core=self:Part('Implosion core',V(1,1,1),CF(0,-60,0),C(230,240,255),NEON,1,BALL)
 self.Nova=self:Part('Supernova',V(1,1,1),CF(0,-60,0),C(200,220,255),NEON,1,BALL)
 self.Waves={self:Ring('Shockwave',lite and 12 or 18,C(200,220,255),'XY')}
 if not lite then self.Waves[2]=self:Ring('Shockwave',18,C(255,170,230),'XY')end
 self.Star=self:Part('Falling star',V(1,1,1),CF(0,-60,0),C(235,245,255),NEON,1,BALL)
 local a0=Instance.new('Attachment');a0.Position=V(0,.25,0);a0.Parent=self.Star
 local a1=Instance.new('Attachment');a1.Position=V(0,-.25,0);a1.Parent=self.Star
 local trail=Instance.new('Trail');trail.Attachment0=a0;trail.Attachment1=a1;trail.Lifetime=.45;trail.LightEmission=1;trail.FaceCamera=true
 trail.Color=ColorSequence.new(C(255,255,255),C(150,180,255));trail.Transparency=NumberSequence.new(.1,1);trail.WidthScale=NumberSequence.new(1,0);trail.Enabled=false;trail.Parent=self.Star
 self.Trail=trail
end
-- KING ----------------------------------------------------------------------------------------------------------------------------------------
function Scene:_throne()
 local lite=self.Lite
 local gold,deepGold,crimson,cream,stone=C(255,200,72),C(196,132,32),C(170,22,40),C(238,226,200),C(214,200,176)
 self:Box(30,48,24,11,C(232,222,204),cream,MARBLE,SMOOTH)
 -- (R152) damask on the walls (tiled; without the image, the plain cream walls)
 for _,w in ipairs({{'Wall back',Enum.NormalId.Back},{'Wall left',Enum.NormalId.Right},{'Wall right',Enum.NormalId.Left}})do
  local wall=self.Folder:FindFirstChild(w[1]);if wall then self:FaceArt(wall,w[2],'damask',{StudsPerTile={3.4,3.4}})end
 end
 -- floor trim and carpet (R152: woven with gold borders and a running diamond; without the image, plain crimson)
 local carpet=self:Part('Carpet',V(4.2,.08,38),CF(0,.04,15.5),crimson,FABRIC)
 self:FaceArt(carpet,Enum.NormalId.Top,'carpet',{StudsPerTile={4.2,8.4}})
 self:Part('Carpet edge',V(.22,.1,38),CF(-2.2,.05,15.5),gold,METAL);self:Part('Carpet edge',V(.22,.1,38),CF(2.2,.05,15.5),gold,METAL)
 -- wainscot trims
 for _,x in ipairs({-14.4,14.4})do
  self:Part('Wall trim',V(.25,.4,46),CF(x,2.6,11),gold,METAL);if not lite then self:Part('Wall trim',V(.25,.4,46),CF(x,19.5,11),gold,METAL)end
 end
 -- pillars with banners
 local zs=lite and{25,7}or{25,16,7}
 for _,x in ipairs({-9,9})do for _,z in ipairs(zs)do
  self:Part('Pillar',V(18,1.6,1.6),CF(x,10,z)*ANG(0,0,math.pi/2),stone,MARBLE,0,CYL)
  self:Part('Pillar base',V(2.4,1,2.4),CF(x,.5,z),stone,MARBLE)
  self:Part('Pillar capital',V(2.4,.8,2.4),CF(x,19.2,z),stone,MARBLE)
  self:Part('Gold collar',V(.3,1.75,1.75),CF(x,3,z)*ANG(0,0,math.pi/2),gold,METAL,0,CYL)
  local side=x<0 and 1 or -1
  local banner=self:Part('Banner',V(.1,7,2.2),CF(x+side*.9,13,z),crimson,FABRIC)
  self:FaceArt(banner,side>0 and Enum.NormalId.Right or Enum.NormalId.Left,'banner')
  self:Part('Banner rod',V(.2,.2,2.8),CF(x+side*.92,16.6,z),gold,METAL)
  if not lite then self:Part('Banner crown',V(.14,.8,1),CF(x+side*.95,13.6,z),gold,NEON,.15)end
 end end
 -- windows with slanting light shafts
 local wz=lite and{20,2}or{20,11,2}
 for _,x in ipairs({-14.3,14.3})do for _,z in ipairs(wz)do
  local window=self:Part('Window',V(.2,6,2.4),CF(x,12,z),C(255,236,190),NEON,.12)
  self:FaceArt(window,x<0 and Enum.NormalId.Right or Enum.NormalId.Left,'glass',{Unlit=true,PixelsPerStud=24})
  if not lite then self:Part('Window frame',V(.3,.3,2.8),CF(x,15.1,z),gold,METAL)end
  local inward=x<0 and 1 or -1
  self:Part('Light shaft',V(.4,20,3),CF(x+inward*6,6,z)*ANG(0,0,inward*.62),C(255,240,200),NEON,.9)
 end end
 -- chandelier
 local cz=10
 self:Part('Chandelier chain',V(.12,5,.12),CF(0,21.5,cz),deepGold,METAL)
 self:Part('Chandelier ring',V(.25,5,5),CF(0,19,cz)*ANG(0,0,math.pi/2),gold,METAL,0,CYL)
 local candles=lite and 4 or 8
 for i=1,candles do
  local a=i/candles*math.pi*2;local p=V(math.cos(a)*2.4,19.5,cz+math.sin(a)*2.4)
  self:Part('Candle',V(.18,.8,.18),CF(p),C(250,244,226),SMOOTH)
  self:Part('Flame',V(.2,.32,.2),CF(p+V(0,.55,0)),C(255,196,90),NEON,0,BALL)
 end
 self.Chandelier=self:Light(self.Folder:FindFirstChild('Chandelier ring'),C(255,214,150),1.4,26)
 -- candelabras along the carpet
 if not lite then
  for _,x in ipairs({-3.6,3.6})do for _,z in ipairs({4})do
   self:Part('Candelabra',V(.25,3,.25),CF(x,1.5,z),deepGold,METAL)
   for k=-1,1 do self:Part('Flame',V(.2,.3,.2),CF(x+k*.35,3.25,z),C(255,196,90),NEON,0,BALL)end
  end end
 end
 -- the throne on its dais, with the royal cushion
 local tz=-4.6
 for i,s in ipairs({{11,3.6},{9,3},{7,2.4}})do self:Part('Dais step',V(s[1],.4,s[2]),CF(0,.2+(i-1)*.4,tz-.3-(i-1)*.3),i%2==1 and stone or cream,MARBLE)end
 self:Part('Dais trim',V(11.1,.12,.12),CF(0,.4,tz+1.5),gold,METAL)
 -- (R152: the seat and back upholstered in a crimson brocade - the wall's damask, tinted - instead of plain fabric)
 local seat=self:Part('Throne seat',V(4,.6,3),CF(0,2.6,tz-.1),crimson,FABRIC)
 self:FaceArt(seat,Enum.NormalId.Top,'damask',{StudsPerTile={1.5,1.5},Color=C(196,40,58)})
 self:Part('Throne base',V(4.2,1.4,3.1),CF(0,1.9,tz-.1),gold,METAL)
 local back=self:Part('Throne back',V(4.4,6.5,.6),CF(0,6.1,tz-1.75),crimson,FABRIC)
 self:FaceArt(back,Enum.NormalId.Back,'damask',{StudsPerTile={1.5,1.5},Color=C(196,40,58)})
 self:Part('Throne frame',V(4.9,7,.4),CF(0,6.0,tz-2.05),gold,METAL)
 self:Part('Throne crest',V(2.2,1.4,.4),CF(0,10.1,tz-2.05),gold,METAL)
 self:Part('Throne gem',V(.7,.7,.7),CF(0,10.1,tz-1.8),C(220,30,60),NEON,0,BALL)
 for _,x in ipairs({-2.3,2.3})do self:Part('Throne arm',V(.5,1.2,3),CF(x,3.4,tz-.1),gold,METAL);if not lite then self:Part('Arm knob',V(.6,.6,.6),CF(x,4.1,tz+1.3),gold,METAL,0,BALL)end end
 local pk=Rules.Points[8].Pack
 local cushion=self:Part('Royal cushion',V(3.0,.42,2.3),CF(pk.X,pk.Y-Rules.PackHeroHeight*.5-.2,pk.Z),C(150,14,34),FABRIC)
 self:FaceArt(cushion,Enum.NormalId.Top,'damask',{StudsPerTile={1.2,1.2},Color=C(176,30,48)})
 for _,o in ipairs(lite and{}or{{-1.5,-1.15},{1.5,-1.15},{-1.5,1.15},{1.5,1.15}})do self:Part('Tassel',V(.25,.25,.25),CF(pk.X+o[1],pk.Y-Rules.PackHeroHeight*.5-.38,pk.Z+o[2]),gold,METAL,0,BALL)end
 -- the great crown relief on the back wall
 self:Part('Wall crown band',V(7,1.2,.3),CF(0,15,-12.3),gold,METAL)
 for i=-2,2,lite and 2 or 1 do self:Part('Wall crown point',V(1,2.2+(i==0 and 1 or 0)-math.abs(i)*.3,.3),CF(i*1.5,16.6+(i==0 and .5 or 0)-math.abs(i)*.15,-12.3),gold,METAL);self:Part('Wall crown jewel',V(.5,.5,.3),CF(i*1.5,15,-12.1),i%2==0 and C(220,30,60)or C(60,120,255),NEON,0,BALL)end
 -- heralds' trumpets on stands
 self.Trumpets={}
 for _,x in ipairs({-4.2,4.2})do
  self:Part('Herald stand',V(.22,4.2,.22),CF(x,2.1,-1.4),deepGold,METAL)
  local tube=self:Part('Trumpet',V(2.6,.16,.16),CF(0,-60,0),gold,METAL,0,CYL)
  local bell=self:Part('Trumpet bell',V(.5,.7,.7),CF(0,-60,0),gold,METAL,0,CYL)
  local flag=self:Part('Trumpet banner',V(.06,.9,1.1),CF(0,-60,0),crimson,FABRIC)
  self.Trumpets[#self.Trumpets+1]={Tube=tube,Bell=bell,Flag=flag,X=x}
 end
 -- the beams (R152: the layered beam of RarePullFx in gold, coming down from the ceiling): one carries the pack in, following it down the
 -- carpet; one crowns it on the throne (it has the light)
 local tl=Rules.Timeline(8,self.Reduced and'Calm'or'Full')
 self.CarryBeam=Fx.Beam({Parent=self.Folder,Name='Carry beam',Ground=self.Origin.Position,Height=20,Width=2.4,Color=gold,Glow=C(255,244,214),Arrive='fade',
  Land=tl.SceneIn,Hold=math.max(.1,tl.Land+.3-tl.SceneIn),Fade=.4,Impact=false,Light=false,Strength=.8,Tier=self.FxTier,Reduced=self.Reduced})
 self.CrownBeam=Fx.Beam({Parent=self.Folder,Name='Crown beam',Ground=(self.Origin*CF(pk.X,pk.Y-Rules.PackHeroHeight*.5,pk.Z)).Position,Height=19,Width=2.2,Color=gold,Glow=C(255,246,220),Arrive='fade',Strength=.6,
  Land=tl.CrownStart+.4,Hold=tl.Climax+.6-(tl.CrownStart+.4),Fade=1.2,Impact=false,Light=true,Tier=self.FxTier,Reduced=self.Reduced})
 self.BeamLight=self.CrownBeam.Light;self.Lights+=1
 -- the crown: band, points with jewels
 self.Crown={}
 local seg=lite and 6 or 8
 for i=1,seg do self.Crown[#self.Crown+1]={Part=self:Part('Crown band',V(.7,.42,.16),CF(0,-60,0),gold,METAL),Kind='Band',A=(i-.5)/seg*math.pi*2}end
 for i=1,5 do
  local a=(i-1)/5*math.pi*2
  self.Crown[#self.Crown+1]={Part=self:Part('Crown point',V(.26,.62,.14),CF(0,-60,0),gold,METAL),Kind='Point',A=a}
  self.Crown[#self.Crown+1]={Part=self:Part('Crown tip',V(.22,.22,.22),CF(0,-60,0),C(255,236,150),NEON,0,BALL),Kind='Tip',A=a}
  if not lite then self.Crown[#self.Crown+1]={Part=self:Part('Crown jewel',V(.18,.18,.12),CF(0,-60,0),i%2==0 and C(60,120,255)or C(225,30,60),NEON,0,BALL),Kind='Jewel',A=a+math.pi/5}end
 end
 -- the burst: rays, a floor shockwave, confetti
 self.Rays={}
 for i=1,(lite and 8 or 10)do self.Rays[i]=self:Part('Gold ray',V(.22,.22,.05),CF(0,-60,0),i%2==0 and C(255,244,200)or gold,NEON,1)end
 self.Wave=self:Ring('Floor shockwave',lite and 12 or 14,C(255,226,130),'XZ')
 local confetti=self:Part('Confetti source',V(4,.2,2),CF(pk.X,pk.Y+5,pk.Z+1),C(0,0,0),SMOOTH,1)
 self.Confetti=self:Emitter(confetti,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,gold),ColorSequenceKeypoint.new(.5,C(255,255,255)),ColorSequenceKeypoint.new(1,crimson)}),
  LightEmission=.6,Lifetime=NumberRange.new(1.6,2.6),Speed=NumberRange.new(10,18),SpreadAngle=Vector2.new(70,70),Acceleration=V(0,-14,0),Drag=1.2,
  Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-300,300),Size=NumberSequence.new(.35,.2),Transparency=NumberSequence.new(0,.4),EmissionDirection=Enum.NormalId.Top})
 self.Sparkles=self:Emitter(self.Key,{Color=ColorSequence.new(C(255,244,200),gold),Rate=lite and 8 or 18,Lifetime=NumberRange.new(.6,1.2),Speed=NumberRange.new(.5,2),
  SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new(.25,0)})
end
-- Every frame --------------------------------------------------------------------------------------------------------------------------------
function Scene:_placePack(pos,yaw,roll,alpha,shake,t)
 if not self.Pack then return end
 local sx=self.Reduced and 0 or shake
 local jig=V(math.sin(t*71)*sx,math.sin(t*53+1)*sx*.6,0)
 local cf=CF(pos+jig)*ANG(0,yaw,roll+(self.Reduced and 0 or math.sin(t*63)*shake*.6))*FRONT
 pcall(function()self.Pack:PivotTo(self.Origin*cf*self.PackRel)end)
 if self.LastPackAlpha~=alpha then self.LastPackAlpha=alpha;setAlpha(self.PackParts,alpha)end
 self.PackCF=cf
end
function Scene:_placeSeed(pos,alpha,t)
 if not self.Seed then return end
 local cf=CF(pos)*ANG(0,Rules.SeedYaw(t,self.Reduced),0)*FRONT
 pcall(function()self.Seed:PivotTo(self.Origin*cf*self.SeedRel)end)
 if self.LastSeedAlpha~=alpha then self.LastSeedAlpha=alpha;setAlpha(self.SeedParts,alpha)end
 if self.Motion then pcall(function()self.Motion:Update(self.Origin*cf,t,self.SeedScale or 1,alpha)end)end
 -- one key light from the camera side: on the pack until the seed is out (the stages are dark at night), then on the seed
 if alpha<=0 and self.PackCF and self.LastPackAlpha~=0 then
  self:Place(self.Key,CF(self.PackCF.Position+V(0,1.4,3.4)));self.KeyLight.Brightness=1.3
 else
  self:Place(self.Key,CF(pos+V(0,1.2,3.2)));self.KeyLight.Brightness=1.8*alpha
 end
 -- the halo behind the seed (it follows it)
 if self.HaloAnchor then
  self:Place(self.HaloAnchor,CF(pos-V(0,0,1.1))) -- (just behind the seed: its glow never lies over the seed itself)
  if self.SeedGlow then self.SeedGlow.Image.ImageTransparency=1-.5*alpha end
  if self.SeedHalo then self.SeedHalo.Image.ImageTransparency=1-.7*alpha;self.SeedHalo.Image.Rotation=self.Reduced and 0 or t*25 end
 end
end
function Scene:Update(t,tl)
 if self.Destroyed then return end
 local rank=self.Rank
 local pos,yaw,roll,alpha,shake=Rules.PackPose(rank,tl,t)
 self:_placePack(pos,yaw,roll,alpha,shake,t)
 local spos,salpha,glow=Rules.SeedPose(rank,tl,t)
 self:_placeSeed(spos,salpha,t)
 local burst=t-tl.Climax
 self:Place(self.FlashPart,CF(pos))
 self.FlashLight.Brightness=burst>=0 and 6*math.max(0,1-burst/.6)or 0
 if burst<0 then self.Burst:Place(self.Origin*CF(pos))elseif not self.Burst.Fired then self.Burst:Fire(self.Origin*CF(pos))end
 if self.PackRim then self.PackRim.Enabled=burst<0 and alpha>.05 end
 if rank==6 then self:_updateVoid(t,tl,pos,burst)elseif rank==7 then self:_updateSpace(t,tl,pos,burst,spos,glow)else self:_updateThrone(t,tl,pos,burst,spos)end
end
function Scene:_updateVoid(t,tl,pos,burst)
 local n=#self.Plates
 local lockIn=clamp01((t-tl.Lock)/.3);local open=clamp01((t-tl.Unlock)/math.max(.05,tl.Silence-tl.Unlock))
 local turns=0;for _,k in ipairs(Rules.LockTurns)do if t>=tl.Lock+k and tl.Lock+k<tl.Unlock then turns+=1 end end -- (one click each: RarePullRules)
 local spin=turns*math.rad(15)+(self.Reduced and 0 or math.sin(t*2)*.02)
 for i=1,n do
  local a=(i-1)/n*math.pi*2+spin;local r=2.0+.7*open
  local c=pos+V(math.cos(a)*r,math.sin(a)*r,.1)
  self:Place(self.Plates[i],CF(c)*ANG(0,0,a+math.pi/2))
  local fade=t<tl.Lock and 1 or 1-lockIn+clamp01((t-tl.Unlock-.2)/.4)
  self.Plates[i].Transparency=clamp01(fade);self:Place(self.Bolts[i],CF(pos+V(math.cos(a)*(1.55+1.2*open),math.sin(a)*(1.55+1.2*open),.25)))
  self.Bolts[i].Transparency=clamp01(t<tl.Lock and 1 or 1-lockIn+open)
 end
 local front=(self.PackSize and self.PackSize.Z or .6)*.5+.03
 for _,c in ipairs(self.Cracks)do
  local g=clamp01((t-tl.Unlock-.1)/math.max(.05,tl.Silence-tl.Unlock-.1))
  local len=c.L*g
  c.Part.Size=V(.05,math.max(.02,len),.03)
  self:Place(c.Part,CF(pos+V(c.X,c.Y,front))*ANG(0,0,c.R))
  c.Part.Transparency=(g<=0 or burst>=0)and 1 or .05
 end
 for i,l in ipairs(self.Leaks)do
  local g=clamp01((t-tl.Unlock)/math.max(.05,tl.Climax-tl.Unlock));local a=i/#self.Leaks*math.pi*2+.4
  local len=.5+5*g*g
  l.Size=V(.12+.3*g,len,.04)
  self:Place(l,CF(pos+V(math.cos(a)*(.9+len*.5),math.sin(a)*(1.1+len*.5),-.2))*ANG(0,0,a-math.pi/2))
  l.Transparency=(g<=0 or burst>.3)and 1 or math.clamp(.9-.5*g+(burst>0 and burst*2 or 0),0,1)
 end
 for i,s in ipairs(self.Shards)do
  local k=clamp01(burst/.8);local a=i*2.399
  local d=V(math.cos(a),math.sin(a)*.8,.4+.6*((i%3)/2))*(k*(3+i%4))
  self:Place(s,CF(pos+d)*ANG(burst*4+i,burst*3,burst*5))
  s.Transparency=(burst<0 or k>=1)and 1 or .1+.9*k
 end
 local wk=clamp01(burst/.7)
 self:PlaceRing(self.Wave,pos,.6+wk*(self.Reduced and 2 or 7),.18*(1-wk)+.02,burst<0 and 1 or .15+.85*wk)
 self.Wisps.Enabled=burst>=0 and t<tl.FloatEnd
 self.Rim.Brightness=1.2+(t>=tl.Unlock and t<tl.Climax and 1.5*clamp01((t-tl.Unlock)/.5)or 0)
 -- the rune circle turns slowly, brightens as the lock opens, flares on the hit and dims as the seed takes over
 local open=clamp01((t-tl.Unlock)/math.max(.05,tl.Silence-tl.Unlock))
 if self.Runes then
  local img=self.Runes.Image;img.Rotation=self.Reduced and 0 or t*4
  local glow=.42+.4*open+(burst>=0 and .18*math.max(0,1-burst/.6)or 0)
  if burst>=0 then glow*=1-.55*clamp01((burst-.5)/1.2)end
  img.ImageTransparency=1-glow
 end
 for i,inlay in pairs(self.Inlays or{})do
  local plate=self.Plates[i]
  if plate then inlay.BackgroundTransparency=math.max(plate.Transparency,.6-.55*open)end
 end
end
function Scene:_updateSpace(t,tl,pos,burst,spos,glow)
 for i,p in ipairs(self.Planets)do
  local align=tl['Align'..i]or tl.Align3
  local free=p.Phase+t*(.35+.08*i)
  local aligned=math.pi*.5+.25 -- behind the pack, stacked up and to the left
  local k=Rules.Smooth((t-(align-.6))/.6)
  local a=free+(aligned-free)*k
  if t>tl.SpinUp then a=aligned+(t-tl.SpinUp)*(1.5+i*.6)*clamp01((t-tl.SpinUp)/.8)end
  local out=clamp01((t-tl.Implode)/.5)
  local r=p.Radius*(1+1.5*out)
  local c=pos+V(math.cos(a)*r,math.sin(a)*r*.35+math.sin(a)*p.Tilt*r*.3,-math.sin(a)*r*.6-1)
  self:Place(p.Body,CF(c))
  local fade=clamp01(out*1.4)
  if p.Art then p.Art.Image.ImageTransparency=fade else p.Body.Transparency=fade end
  if p.Shell then self:Place(p.Shell,CF(c));p.Shell.Transparency=.84+.16*fade end
  if p.Ring then self:Place(p.Ring,CF(c)*ANG(.4,0,math.pi/2+.3));p.Ring.Transparency=math.max(.45,fade)end
 end
 local g=clamp01((t-tl.SpinUp)/.6);local suck=clamp01((t-tl.Implode)/math.max(.05,tl.Silence-tl.Implode))
 local n=#self.Galaxy/2
 for _,s in ipairs(self.Galaxy)do
  local k=s.J/n;local spin=(t-tl.SpinUp)*(1.2+5*clamp01((t-tl.SpinUp)/math.max(.05,tl.Implode-tl.SpinUp)))
  local a=k*math.pi*1.6+(s.Arm-1)*math.pi+spin;local r=(1.6+k*5.5)*(1-suck)
  self:Place(s.Part,CF(pos+V(math.cos(a)*r,math.sin(a)*r*.45,math.sin(a)*r*.3)))
  s.Part.Transparency=(g<=0 or burst>=0)and 1 or 1-g*(.15+.85*(1-k*.5))
 end
 local core=0
 if t>=tl.Implode and t<tl.Climax then local a=t-tl.Implode;local up=clamp01(a/.25);local down=clamp01((t-tl.Implode-.25)/math.max(.05,tl.Silence-tl.Implode-.25));core=1.8*up*(1-down)+.15 end
 self.Core.Size=V(core,core,core);self:Place(self.Core,CF(pos));self.Core.Transparency=core>0 and .05 or 1
 local nk=clamp01(burst/.8)
 local d=.5+nk*(self.Reduced and 6 or 16);self.Nova.Size=V(d,d,d);self:Place(self.Nova,CF(pos));self.Nova.Transparency=burst<0 and 1 or .25+.75*nk
 for i,w in ipairs(self.Waves)do local k=clamp01((burst-(i-1)*.15)/.8);self:PlaceRing(w,pos,.6+k*(self.Reduced and 3 or 10),.25*(1-k)+.03,(burst<(i-1)*.15)and 1 or .1+.9*k)end
 self.Star.Size=V(1,1,1)*(.5+1.6*glow);self:Place(self.Star,CF(spos));self.Star.Transparency=(burst<0 or glow<=.02)and 1 or .15+.6*(1-glow)
 self.Trail.Enabled=burst>=0 and glow>.05 and not self.Reduced
 -- (R152: turned by the clock, not by a fixed step per frame: at 240 fps the nebulae spun four times as fast as at 60)
 for i,n2 in ipairs(self.Nebula)do if not self.Reduced then n2.CFrame=self.NebulaBase[i]*ANG(.03*i*t,0,0)end end
 for i,a in pairs(self.NebulaArt or{})do a.Image.Rotation=self.Reduced and 0 or t*(1.5+i*.4)end -- (the clouds turn very slowly, by the clock)
end
function Scene:_updateThrone(t,tl,pos,burst,spos)
 -- the carry beam follows the pack down the carpet
 self.CarryBeam:Update(t,(self.Origin*CF(pos-V(0,Rules.PackHeroHeight*.5,0))).Position)
 self.CrownBeam:Update(t)
 -- trumpets raise and sound at the fanfare
 local raise=clamp01((t-tl.Fanfare+.35)/.35)
 for _,tr in ipairs(self.Trumpets)do
  -- each trumpet points out over the hall, tilting up as it sounds (the cylinder's axis is X: lookAt * 90 deg about Y)
  local top=V(tr.X,4.2,-1.4);local dir=V(tr.X>0 and .3 or -.3,.12+.6*raise,1).Unit
  local frame=CFrame.lookAt(top,top+dir)*ANG(0,math.pi/2,0)
  self:Place(tr.Tube,frame*CF(1.3,0,0));self:Place(tr.Bell,frame*CF(2.6,0,0));self:Place(tr.Flag,frame*CF(1.3,-.55,0)*ANG(0,math.pi/2,0))
 end
 -- the crown: descends in the beam onto the pack, then lifts with the seed
 local centre,scale,calpha=Rules.CrownPose(tl,t)
 local spin=self.Reduced and 0 or t*.6
 for _,c in ipairs(self.Crown)do
  local a=c.A+spin;local r=1.0*scale
  local off
  if c.Kind=='Band'then off=CF(math.cos(a)*r,0,math.sin(a)*r)*ANG(0,-a+math.pi/2,0)
  elseif c.Kind=='Point'then off=CF(math.cos(a)*r,.48*scale,math.sin(a)*r)*ANG(0,-a+math.pi/2,0)
  elseif c.Kind=='Tip'then off=CF(math.cos(a)*r,.86*scale,math.sin(a)*r)
  else off=CF(math.cos(a)*(r+.08),0,math.sin(a)*(r+.08))*ANG(0,-a+math.pi/2,0)end
  self:Place(c.Part,CF(centre)*off);c.Part.Size=(c.Kind=='Band'and V(.7,.42,.16)or c.Kind=='Point'and V(.26,.62,.14)or c.Kind=='Tip'and V(.22,.22,.22)or V(.18,.18,.12))*scale
  c.Part.Transparency=1-calpha
 end
 -- the burst: rays, shockwave on the floor, confetti
 for i,r in ipairs(self.Rays)do
  local k=clamp01(burst/.3);local fade=clamp01((burst-.4)/1.6);local a=i/#self.Rays*math.pi*2+(self.Reduced and 0 or burst*.4)
  local len=.5+9*k
  r.Size=V(.18+.25*(i%2),len,.05)
  self:Place(r,CF(pos+V(math.cos(a)*(1+len*.5),math.sin(a)*(1+len*.5),-.6))*ANG(0,0,a-math.pi/2))
  r.Transparency=burst<0 and 1 or .2+.8*fade
 end
 local wk=clamp01(burst/.9)
 self:PlaceRing(self.Wave,V(pos.X,.12,pos.Z),1+wk*(self.Reduced and 5 or 16),.35*(1-wk)+.05,burst<0 and 1 or .1+.9*wk)
 if burst>=0 and not self.ConfettiDone then self.ConfettiDone=true;pcall(function()self.Confetti:Emit(self.Lite and 50 or 130)end)end
 self.Sparkles.Enabled=burst>=0 and t<tl.FloatEnd
end
function Scene:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true
 if self.Motion then pcall(function()self.Motion:Destroy()end)end
 self.Folder:Destroy()
end
return S
