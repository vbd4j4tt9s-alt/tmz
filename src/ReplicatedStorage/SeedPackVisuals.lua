-- V124. The same approved meshes serve world, dropped, held and opening packs.
local Rules = require(script.Parent.SeedPackRules)
local Shadow = require(script.Parent.SmallShadow154) -- R154 (lag audit B1): a part under 1.5 studs casts no shadow
local Visuals = {}
local function part(model,name,size,frame,color,root,shape)
    local p = Instance.new("Part")
    p.Name=name; p.Size=size; p.CFrame=frame; p.Color=color
    p.Material=Enum.Material.SmoothPlastic
    p.Anchored=root==nil or root.Anchored; p.Massless=true
    p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    Shadow.Part(p)
    p.Parent=model
    if root and not p.Anchored then
        local w=Instance.new("WeldConstraint"); w.Part0=root; w.Part1=p; w.Parent=p
    end
    return p
end
local function rootPart(model,origin,weldRoot)
    local p=part(model,"VisualRoot",Vector3.new(.1,.1,.1),origin,Color3.new(),weldRoot)
    p.Transparency=1; model.PrimaryPart=p
    return p
end
-- Solid server-authored geometry stays visible independently of client animation.
-- R151: the chip-bag shape of the pouch. `defaultShape` (true): the design's own mesh with no shape variation, whatever `shape` says: what the catalogue, shop, reward and market
-- pictures pass (the bag is flagged DefaultPackShape; ItemPictures and the renderers follow the flag). `shape` (optional, 0..6) is the pack's own variation
-- (PackShapes151): the world pack's / the item record's PackShape. No shape (nil / 0) is the default shape too: ONE default shape for every context.
function Visuals.Bag(origin,parent,scale,weldRoot,stage,variantKey,seedScale,packSize,mutation,displaySize,defaultShape,shape)
    local variant=Rules.GetVariant(variantKey);local theme=Rules.GetTheme(stage)
    packSize=Rules.SanitizePackSize(packSize);mutation=Rules.MutationKey(mutation)
    scale=(scale or 1)*variant.BagScale*theme.Scale*(displaySize or packSize)
    local m=Instance.new("Model");m.Name="SeedPacket";m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
    m:SetAttribute('PackSize',packSize);m:SetAttribute('PackMutation',mutation)
    local root=rootPart(m,origin,weldRoot)
    -- World geometry is fully anchored. Only held geometry needs welds.
    local visualWeldRoot=root
    local seal=theme.Ink
    if stage==3 then seal=Color3.fromRGB(172,222,241) end
    part(m,"BottomSeal",Vector3.new(1.9,.16,.035)*scale,origin*CFrame.new(0,-1.12*scale,0),seal,visualWeldRoot)
    for i=1,8 do
        local strip=part(m,"TearStrip"..i,Vector3.new(1.9/8+.001,.18,.035)*scale,
            origin*CFrame.new((-1.9/2+(i-.5)*1.9/8)*scale,1.11*scale,0),seal,visualWeldRoot)
        strip:SetAttribute("TearIndex",i);strip:SetAttribute("TearCount",8)
    end
    -- R151: GiantVisualSafety fades every GiantVisualPart near the camera, and the pouch's own builders (SeedPackRenderer, EclipsePackArt, SpecialPackArt89
    -- and the Verity pack's) tag the pouch's parts for a giant (> 10x) pack, but the seal and the 8 tear strips (built here) were never tagged: close to a
    -- giant pack the pouch faded away and nine solid bars stayed behind in the air. They fade with the rest now.
    if packSize>10 then for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart')and p~=root then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end end end
    for _,side in ipairs({-1,1}) do
        local grip=Instance.new("Attachment");grip.Name=side<0 and "LeftGrip" or "RightGrip"
        grip.CFrame=CFrame.new(Vector3.new(side*.73,-.30,.12)*scale);grip.Parent=root
    end
    m:SetAttribute("SeedArtVersion",123);m:SetAttribute("VisualScale",scale);m:SetAttribute("TearLipY",1.11)
    m:SetAttribute("Stage",stage or 1);m:SetAttribute("BagVariant",Rules.VariantKey(variantKey))
    m:SetAttribute("PackArtKey",Rules.DesignKey(stage,variantKey));m:SetAttribute("PackVisible",true)
    if defaultShape==true then m:SetAttribute('DefaultPackShape',true)
    elseif shape~=nil then local Shapes=require(script.Parent.PackShapes151);if Shapes.Applies(variantKey)then m:SetAttribute("PackShape",Shapes.Sanitize(shape))end end
    m:SetAttribute("SeedScale",Rules.SanitizeSeedScale(seedScale));m:SetAttribute("PaperColor",theme.Body)
    m:SetAttribute("BiomeMark",theme.Mark)
    local tier,rank=Rules.GetPackTier(variantKey)
    m:SetAttribute("PackRarity",tier.Name);m:SetAttribute("PackRank",rank)
    m:SetAttribute("HoverOrigin",origin);m:SetAttribute("WorldPack",weldRoot==nil)
    m:SetAttribute("HoverPhase",(origin.Position.X*.17+origin.Position.Z*.07)%6.28)
    -- Prepared meshes preserve the approved art without runtime triangle generation.
    require(script.Parent.SeedPackRenderer).Build(m,function()return true end)
    local coating=Rules.PackMutations[mutation]
    if coating.Color then
        m:SetAttribute('PaperColor',coating.Color)
        for _,p in ipairs(m:GetDescendants())do if p:IsA('BasePart')and p~=root then
            -- Remove a mesh's appearance override so Roblox's real material shades it.
            for _,v in ipairs(p:GetChildren())do if v:IsA('SurfaceAppearance')then v:Destroy()end end
            p.Color=coating.Color;p.Material=coating.Material;p.MaterialVariant=''
            if p:IsA('MeshPart')then p.TextureID=''end
            p.Reflectance=mutation=='Gold'and .38 or mutation=='Diamond'and .28 or 0
            if mutation=='Diamond'then
                -- Low transparency retains a readable faceted silhouette at distance.
                p.Transparency=p:IsA('MeshPart')and .20 or .10
            end
        end end
    end
    -- Material shading stays visible; bounded local glints are owned by SeedPackRender.
    m.Parent=parent
    game:GetService("CollectionService"):AddTag(m,"BiomeSeedPackVisual")
    return m,m:GetChildren()
end
function Visuals.Seed(seed,index,origin,parent,scale,weldRoot,mutation)
 if require(script.Parent.MechCatalog).Is(seed.Id)then
  local m=require(script.Parent.MechArt).BuildNative(seed.Id,origin,parent,scale or 1,weldRoot,mutation)
  m.Name='LooseSeed';m:SetAttribute('SeedId',seed.Id);m:SetAttribute('SeedArtVersion',157)
  m:SetAttribute('Rarity',Rules.GetRarity(seed.Id));m:SetAttribute('SeedVisualScale',scale or 1);m:SetAttribute('SeedBiome','Mech')
  m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  game:GetService('CollectionService'):AddTag(m,Rules.SeedMotion.Tag);return m
 end
 if require(script.Parent.VerityCatalog).Is(seed.Id)then
  -- R147: the Verity seed is one small ball with Verity's face (VerityPlantArt); coat, King sparkle and motion tag as for every seed.
  local Cat=require(script.Parent.VerityCatalog);scale=scale or 1
  local m=require(script.Parent.VerityPlantArt).BuildSeed(origin,scale,weldRoot)
  m:SetAttribute('SeedId',seed.Id);m:SetAttribute('SeedArtVersion',147);m:SetAttribute('Rarity',Cat.Rarity)
  m:SetAttribute('SeedVisualScale',scale);m:SetAttribute('SeedBiome',Cat.Biome);m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  require(script.Parent.PlantVisuals).Coat(m,mutation)
  local style=Rules.Rarities[Cat.Rarity]
  local glow=Instance.new("ParticleEmitter");glow.Name="SeedRaritySparkles"
  glow.Texture="rbxasset://textures/particles/sparkles_main.dds";glow.Color=ColorSequence.new(style.Color)
  glow.LightEmission=1;glow.Rate=style.Rank>=4 and 3 or 1;glow.Lifetime=NumberRange.new(.5,.85)
  glow.Speed=NumberRange.new(.2,.4);glow.SpreadAngle=Vector2.new(180,180);glow.LightInfluence=0
  glow.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.05*scale),NumberSequenceKeypoint.new(.3,.08*scale),NumberSequenceKeypoint.new(1,.02*scale)})
  glow.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.15),NumberSequenceKeypoint.new(1,1)})
  glow.Parent=m.PrimaryPart
  if style.Rank>=3 then game:GetService("CollectionService"):AddTag(m,Rules.SeedMotion.Tag)end
  m.Parent=parent;return m
 end
 local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
 local function rgb(hex)return RGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))end
 scale=scale or 1
 local spec=assert(Rules.SeedDesignById[seed.Id],"Unknown seed design: "..tostring(seed.Id))
 -- R134: seeds that shared a recoloured design get their own signature (SeedSignatures).
 local sig=require(script.Parent.SeedSignatures).Get(seed.Id)
 local pattern=sig and sig.Pattern or spec.pattern
 local m=Instance.new("Model");m.Name="LooseSeed";m:SetAttribute("SeedId",seed.Id)
 m:SetAttribute("SeedArtVersion",139);m:SetAttribute("Rarity",spec.rarity)
 m:SetAttribute("SeedVisualScale",scale);m:SetAttribute("SeedBiome",spec.biome)
 m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local root=rootPart(m,origin,weldRoot)
 local top,bottom,ink=rgb(spec.top),rgb(spec.bottom),rgb(spec.ink)

 local function p(name,size,frame,color,mat,shape)
  local item=part(m,name,size*scale,origin*CF(frame.Position*scale)*frame.Rotation,color,weldRoot,shape);item.Material=mat or Enum.Material.SmoothPlastic;item.CastShadow=false;if scale>10 then game:GetService('CollectionService'):AddTag(item,'GiantVisualPart')end;return item
 end
 local function oval(name,pos,size,color,rot,mat)
  local item=p(name,V(1,1,1),CF(pos)*(rot or CF()),color,mat)
  local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=size;mesh.Parent=item;item:SetAttribute("ArtSize",size*scale)
  return item
 end
 local function line(name,a,b,width,color,mat)
  return p(name,V(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b,math.abs((b-a).Unit.Y)>.98 and Vector3.zAxis or Vector3.yAxis),color,mat)
 end
 -- R134: the body follows the seed's shape (SeedShapes); 'Oval' is exactly the V119 body (28 bands).
 local Shapes=require(script.Parent.SeedShapes)
 local body=Shapes.Body(require(script.Parent.SeedSignatures).Shape(seed.Id))
 local capColor=top:Lerp(Color3.new(0,0,0),.45)
 for _,band in ipairs(body.Bands)do for _,sp in ipairs(band.Spans)do
  local color=sp.Cap and capColor or bottom:Lerp(top,(band.T+1)/2)
  if body.Faceted then
   p('Gradient',V(body.Step+.008,sp.W/1.414,sp.D/1.414),CF(sp.X,band.Y,0)*CFrame.Angles(0,math.pi/4,0)*CFrame.Angles(0,0,math.pi/2),color)
  elseif body.Classic then
   -- The classic oval stays exactly as before (part cylinders are round: min(width, depth) across).
   p('Gradient',V(body.Step+.008,sp.W,sp.D),CF(sp.X,band.Y,0)*CFrame.Angles(0,0,math.pi/2),color,nil,Enum.PartType.Cylinder)
  else
   -- Other shapes need wide, flat slices: stretched sphere slices overlap into a smooth body.
   oval('Gradient',V(sp.X,band.Y,0),V(sp.W,body.Step*3.2,sp.D),color)
  end
 end end
 local function mark(x,y,w,h,angle)
  y=y*body.H/.75
  local z=Shapes.FrontZ(body,x,y);if not z then return end
  oval('Mark',V(x,y,z-.017),V(w,h,.03),ink,CFrame.Angles(0,0,angle or 0))
 end
 if pattern=='None'then
 elseif pattern=='Stripes'then
  for _,x in ipairs({-.23,0,.23})do for j=-2,2 do mark(x+math.sin(j*.9)*.024,j*.12,.058,.16)end end
 elseif pattern=='Dots'then for j=-1,1 do mark(j*.11,j*.18,.14,.14)end
 elseif pattern=='Specks'then for _,v in ipairs({{0,.29},{-.23,.06},{.23,.06},{-.13,-.23},{.13,-.23}})do mark(v[1],v[2],.085,.135)end
 elseif pattern=='Leaf'then mark(0,.06,.23,.40,-.6);mark(-.09,-.16,.035,.2,-.6)
 else mark(0,0,.08,.45);mark(0,0,.38,.08)
  -- R134: the sparkle sits on the front surface of whatever shape the body is (it floated off non-oval bodies).
  local z=Shapes.FrontZ(body,0,0);if z then p('Sparkle',V(.19,.19,.03),CF(0,0,z-.02)*CFrame.Angles(0,0,math.pi/4),ink)end
 end
 local a=(sig and not sig.KeepAddition)and'none'or spec.addition
 -- R134 (owner: "remove that wing like design, it's ugly"): the side crystal/thorn shards are gone for every seed.
 if a=='crystals'or a=='thorns'then a='none'end
 local topY,bottomY=Shapes.Extent(body)
 local leafColor=(spec.biome=='Snow'and RGB(175,230,231))or(spec.biome=='Crystal'and RGB(210,220,238))or RGB(64,133,66)
 local function leaf(x,y,z,angle,color,size)
  oval('Petal',V(x,y,z),size or V(.25,.65,.09),color or leafColor,CFrame.Angles(0,0,angle or 0))
 end
 local function shard(pos,h,color)
  p('Crystal',V(.17,h,.18),CF(pos)*CFrame.Angles(0,.4,.35),color,Enum.Material.Glass).Transparency=.2
  p('Crystal tip',V(.17,.17,.17),CF(pos+V(0,h/2,0))*CFrame.Angles(0,0,math.pi/4),color,Enum.Material.Glass).Transparency=.12
 end
 if a=='leaves'or a=='cap'or a=='stem'then
  if a=='stem'then line('Stem',V(0,.65,0),V(.1,.98,0),.1,RGB(115,77,44),Enum.Material.Wood);leaf(.24,.89,0,-.8)
  else for i=1,(a=='cap'and 5 or 2)do local t=(i-3)*.4;leaf(t*.6,.72+math.abs(t)*.12,0,-t)end end
 elseif a=='mushrooms'then
  for i=1,2 do local x=.43+i*.14;local y=.30+i*.28;line('Mushroom stalk',V(x,y-.35,.05),V(x,y,.05),.06,ink);oval('Mushroom cap',V(x,y,.05),V(.4,.17,.3),top)end
 elseif a=='lanterns'then
  for _,sign in ipairs({-1,1})do line('Lantern stem',V(sign*.27,.6,0),V(sign*.74,.56,0),.055,leafColor);oval('Amber bud',V(sign*.75,.32,0),V(.24,.39,.24),RGB(255,197,73),nil,Enum.Material.Neon)end
 elseif a=='petals'or a=='crest'then
  local count=a=='crest'and 5 or 8
  for i=1,count do local t=a=='crest'and(-.9+(i-1)*.45)or(i*math.pi*2/count)
   leaf(math.sin(t)*.56,math.cos(t)*.66,.1,-t,ink,V(.25,.55,.10))end
 elseif a=='crystals'or a=='thorns'then
  for i=1,(spec.rarity=='Mythic'and 7 or 3)do
   local sign=i%2==0 and -1 or 1;shard(V(sign*(.44+.03*i),-.3+i*.15,0),.3+i*.065,a=='thorns'and ink or bottom)
  end
 end
 if a=='horns'or a=='antlers'or a=='crownHorns'then
  for _,sign in ipairs({-1,1})do
   local points={V(sign*.40,.30,.08),V(sign*.76,.69,.08),V(sign*.83,1.03,.08),V(sign*.67,1.35,.05)}
   for i=1,3 do line(a,points[i],points[i+1],.18-i*.035,a=='antlers'and RGB(120,92,56)or RGB(48,32,40),Enum.Material.Wood)end
   if a=='antlers'then
    line('Branch',points[2],V(sign*1.0,1.0,.08),.065,RGB(120,92,56),Enum.Material.Wood)
    for j=1,3 do oval('Blossom',V(sign*(.57+j*.08),.53+j*.17,-.05),V(.14,.14,.11),ink)end
   end
  end
 end
 if a=='antennae'then for _,sign in ipairs({-1,1})do line('Reed',V(sign*.27,.5,0),V(sign*.48,1.08,0),.055,ink);shard(V(sign*.48,1.1,0),.15,ink)end end
 local function ring(radius,tilt,broken,color)
  local frame=CFrame.Angles(0,0,tilt)*CFrame.Angles(math.rad(65),0,0)
  for i=1,28 do
   if not broken or i%5~=0 then
    local aa=(i-1)*math.pi*2/28;local bb=i*math.pi*2/28
    line('Orbit',frame:PointToWorldSpace(V(math.cos(aa)*radius,0,math.sin(aa)*radius)),frame:PointToWorldSpace(V(math.cos(bb)*radius,0,math.sin(bb)*radius)),broken and .055 or .025,color,Enum.Material.Neon)
   end
  end
 end
 if a=='brokenHalo'then ring(.99,0,true,ink)
 elseif a=='orbit'then ring(.94,.5,false,ink);if spec.biome=='Crystal'then ring(1.06,-.45,false,top)end
  for i=1,4 do shard(V(math.cos(i*1.6)*.92,math.sin(i*1.6)*.8,0),.15,ink)end
 end
 local function bolt(x,y,side)
  local pts={V(x,y+.38,-.12),V(x-side*.18,y+.1,-.12),V(x+side*.14,y+.16,-.12),V(x-side*.13,y-.21,-.12)}
  for i=1,3 do line('Lightning',pts[i],pts[i+1],.055,ink,Enum.Material.Neon)end
 end
 if a=='bolts'or a=='crownBolts'then bolt(-.67,.24,-1);bolt(.67,.24,1);ring(.86,.15,true,ink)end
 if a:sub(1,5)=='crown'then
  -- R134: the crown hugs the body just below its top (it used to float in a fixed ring on non-oval bodies).
  local cy=topY-.08;local cx,hw,hd=Shapes.Span(body,cy);hw=math.max(hw,.16);hd=math.max(hd,.14)
  for i=1,7 do
   local angle=(i-1)*math.pi*2/7;local nextAngle=angle+math.pi*2/7
   local x,z=cx+math.sin(angle)*hw,math.cos(angle)*hd
   line('Crown rim',V(x,cy,z),V(cx+math.sin(nextAngle)*hw,cy,math.cos(nextAngle)*hd),.09,ink,Enum.Material.Metal)
   if sig and sig.Crown=='ice'then line('Icicle spike',V(x,cy,z),V(x,cy+.36+.14*(i%2),z),.08,RGB(205,240,255),Enum.Material.Glass)
   else shard(V(x,cy+.17,z),.34+(.12*(i%2)),spec.biome=='Lava'and RGB(74,43,39)or ink)end
  end
  local gz=Shapes.FrontZ(body,0,cy-.06)or-hd
  p('Royal gem',V(.24,.32,.07),CF(0,cy-.06,gz-.03)*CFrame.Angles(0,0,math.pi/4),spec.biome=='Snow'and RGB(48,117,219)or top,Enum.Material.Glass)
 end
 if sig and sig.Draw then
  -- R134: the kit also knows the body (top/bottom, spans, surface points) so every addition attaches to it, and
  -- k.anim tags parts the client animates on Legendary+ seeds (Flicker, Pulse or Twinkle; see SeedMotion).
  local function lay(name,at,dir,len,width,thick,color,mat)
   return oval(name,at,V(width,thick,len),color,CFrame.lookAt(Vector3.zero,dir.Unit,math.abs(dir.Unit.Y)>.98 and Vector3.zAxis or Vector3.yAxis),mat)
  end
  local function path(name,points,width,color,mat)
   local made={};for i=1,#points-1 do made[#made+1]=line(name,points[i],points[i+1],width,color,mat)end;return made
  end
  local function anim(item,kind)
   if typeof(item)=='Instance'then item:SetAttribute('SeedAnim',kind)else for _,x in ipairs(item)do x:SetAttribute('SeedAnim',kind)end end
   return item
  end
  sig.Draw({p=p,oval=oval,line=line,leaf=leaf,shard=shard,ring=ring,bolt=bolt,top=top,bottom=bottom,ink=ink,leafColor=leafColor,
   H=topY,Bottom=bottomY,body=body,span=function(y)return Shapes.Span(body,y)end,surface=function(a,y,out)return Shapes.Surface(body,a,y,out)end,
   front=function(x,y)return Shapes.FrontZ(body,x,y)end,lay=lay,path=path,anim=anim,V=V,CF=CF,RGB=RGB})
 end
 -- V139: the approved soft motes replace the small straight rarity rays.

 require(script.Parent.PlantVisuals).Coat(m,mutation)
 local style=Rules.Rarities[spec.rarity]
 local glow=Instance.new("ParticleEmitter");glow.Name="SeedRaritySparkles"
 glow.Texture="rbxasset://textures/particles/sparkles_main.dds";glow.Color=ColorSequence.new(style.Color)
 glow.LightEmission=1;glow.Rate=style.Rank>=4 and 3 or 1;glow.Lifetime=NumberRange.new(.5,.85)
 glow.Speed=NumberRange.new(.2,.4);glow.SpreadAngle=Vector2.new(180,180)
 -- R123: motes fade in and taper out (were born at full size/opacity and popped); unlit so they read the same day and night.
 glow.LightInfluence=0
 glow.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.05*scale),NumberSequenceKeypoint.new(.3,.08*scale),NumberSequenceKeypoint.new(1,.02*scale)})
 glow.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.15),NumberSequenceKeypoint.new(1,1)})
 glow.Parent=root
 if style.Rank>=3 then game:GetService("CollectionService"):AddTag(m,Rules.SeedMotion.Tag)end
 m.Parent=parent;return m
end
function Visuals.CarryLayout(character,stage,variantKey,packSize)
    local display=Rules.SanitizePackSize(packSize)
    local visual=Rules.GetVariant(variantKey).BagScale*Rules.GetTheme(stage).Scale*display
    local bounds=Visuals.Bounds(stage,variantKey,display)
    local anchor,frame,avatar,info=require(script.Parent.PackCarryLayout).Calculate(character,bounds,visual)
    return anchor,frame,avatar,display,visual,info
end
function Visuals.CarryFrame(character,stage,variantKey,packSize)
    local torso,frame,avatar=Visuals.CarryLayout(character,stage,variantKey,packSize)
    return torso,frame,avatar
end
function Visuals.CarryBag(character,stage,variantKey,seedScale,packSize,mutation,shape)
    local torso,frame,avatar,display,visual,info=Visuals.CarryLayout(character,stage,variantKey,packSize)
    if not torso then return nil end
    -- Base scale 1 exactly matches world/dropped geometry, regardless of avatar body size.
    local m=Visuals.Bag(frame,character,1,torso,stage,variantKey,seedScale,packSize,mutation,display,nil,shape)
    m.Name='CarriedSeed';m:SetAttribute('SeedPackCarry',true);m:SetAttribute('AvatarScale',avatar)
    m:SetAttribute('CarryDisplayMultiplier',display)
    m:SetAttribute('CarryRootOffset',info.Offset);m:SetAttribute('CarryBackZ',info.BackZ)
    for _,side in ipairs({'Left','Right'})do
        local sign=side=='Left'and -1 or 1
        local grip=m.PrimaryPart:FindFirstChild(side..'Grip')
        grip.CFrame=require(script.Parent.PackCarryLayout).Grip(frame,torso,avatar,visual,info,sign)
    end
    return m
end

local boundsCache={}
function Visuals.Bounds(stage,variant,size)
    if variant=='EclipseReliquary'then
        return require(script.Parent.EclipsePackArt).Bounds(Rules.GetVariant(variant).BagScale*Rules.GetTheme(stage).Scale*Rules.SanitizePackSize(size))
    end
    if variant=='MechLimited'then
        return require(script.Parent.SpecialPackArt89).Bounds(variant,Rules.GetVariant(variant).BagScale*Rules.GetTheme(stage).Scale*Rules.SanitizePackSize(size))
    end
    local key=Rules.DesignKey(stage,variant)
    local b=boundsCache[key]
    if not b then
        b={Radius=1,MinY=-1.22,MaxY=1.22,MinZ=-.02,MaxZ=.02}
        local template=require(script.Parent.SeedPackRenderer).GetGeometry(key)
        assert(template,'Missing pack geometry: '..key)
        for _,p in ipairs(template:GetChildren())do if p:IsA('MeshPart')then
            local cf=p:GetAttribute('PackLocalFrame')or p.CFrame
            for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
                local v=cf*Vector3.new(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)
                b.Radius=math.max(b.Radius,Vector3.new(v.X,0,v.Z).Magnitude)
                b.MinY=math.min(b.MinY,v.Y);b.MaxY=math.max(b.MaxY,v.Y)
                b.MinZ=math.min(b.MinZ,v.Z);b.MaxZ=math.max(b.MaxZ,v.Z)
            end end end
        end end
        for _,spec in ipairs(require(script.Parent.PackTierEmblem).Specs(key,template))do
            for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
                local v=spec.Frame*Vector3.new(spec.Size.X*x,spec.Size.Y*y,spec.Size.Z*z)
                b.Radius=math.max(b.Radius,Vector3.new(v.X,0,v.Z).Magnitude)
                b.MinY=math.min(b.MinY,v.Y);b.MaxY=math.max(b.MaxY,v.Y);b.MinZ=math.min(b.MinZ,v.Z);b.MaxZ=math.max(b.MaxZ,v.Z)
            end end end
        end
        b.Radius+=math.max(math.abs(b.MinY),b.MaxY)*.03
        b.MinY-=b.Radius*.03;b.MaxY+=b.Radius*.03
        boundsCache[key]=b
    end
    local scale=Rules.GetVariant(variant).BagScale*Rules.GetTheme(stage).Scale*Rules.SanitizePackSize(size)
    return {Radius=b.Radius*scale,MinY=b.MinY*scale,MaxY=b.MaxY*scale,MinZ=b.MinZ*scale,MaxZ=b.MaxZ*scale}
end
-- Stationary spawn furniture. Never included in Bag(), carried or opening models.
local stoneThemes={
 [1]={Stone=Color3.fromRGB(109,121,104),Material=Enum.Material.Slate,Moss=Color3.fromRGB(74,106,39)},
 [2]={Stone=Color3.fromRGB(200,164,109),Material=Enum.Material.Sandstone},
 [3]={Stone=Color3.fromRGB(147,182,200),Material=Enum.Material.Slate,Ice=true},
 [4]={Stone=Color3.fromRGB(49,42,43),Material=Enum.Material.Basalt,Vein=Color3.fromRGB(255,121,27)},
 [5]={Stone=Color3.fromRGB(133,118,154),Material=Enum.Material.Marble,Vein=Color3.fromRGB(202,162,255)},
 [6]={Stone=Color3.fromRGB(62,82,63),Material=Enum.Material.Slate,Moss=Color3.fromRGB(58,105,39)},
 [7]={Stone=Color3.fromRGB(64,77,98),Material=Enum.Material.Slate,Vein=Color3.fromRGB(137,220,255)},
}
function Visuals.PlatformDimensions(stage,variant,size)
 local bounds=Visuals.Bounds(stage,variant,size)
 local radius=math.max(.86,bounds.Radius*1.13)
 return {Radius=radius,Height=math.clamp(radius*.16,.20,.46),PackMinY=bounds.MinY}
end
function Visuals.Platform(origin,stage,variant,size)
 local d=Visuals.PlatformDimensions(stage,variant,size);local theme=stoneThemes[stage]or stoneThemes[1]
 local m=Instance.new('Model');m.Name='PackPlatform';m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 m:SetAttribute('PlatformVersion',128);m:SetAttribute('Stage',stage);m:SetAttribute('PackSize',size)
 m:SetAttribute('PlatformRadius',d.Radius)
 local bottom=origin.Position.Y+d.PackMinY-.58
 local center=Vector3.new(origin.Position.X,bottom,origin.Position.Z)
 local function disk(name,radius,height,y,color,material,offset,ratio)
  local p=part(m,name,Vector3.new(height,radius*2,radius*2*(ratio or 1)),
    CFrame.new(center+(offset or Vector3.zero)+Vector3.new(0,y,0))*CFrame.Angles(0,0,math.pi/2),color,nil,Enum.PartType.Cylinder)
  p.Material=material;p.CastShadow=false;return p
 end
 local stone=disk('BiomeStone',d.Radius,d.Height*.72,d.Height*.50,theme.Stone,theme.Material)
 m.PrimaryPart=stone
 disk('LowerBevel',d.Radius*.96,d.Height*.18,d.Height*.09,theme.Stone:Lerp(Color3.new(),.12),theme.Material)
 disk('TopBevel',d.Radius*.96,d.Height*.16,d.Height*.92,theme.Stone:Lerp(Color3.new(1,1,1),.05),theme.Material)
 local top=d.Height+.007
 if theme.Moss then
  for i,a in ipairs({.6,3.5,4.4})do
   local offset=Vector3.new(math.cos(a),0,math.sin(a))*d.Radius*.72
   -- R151: .028 thick (was .022): a patch's top stood .018 over the pad's top face, inside the .02 band where two same-way faces can flicker at a distance (tools/zfight.py); .021 now
   disk('MossPatch',d.Radius*(i==1 and .22 or .15),.028,top,theme.Moss,Enum.Material.Grass,offset,.72)
  end
 end
 if theme.Ice then
  local ice=disk('IceGlaze',d.Radius*.95,.030,top,Color3.fromRGB(207,244,255),Enum.Material.Glass) -- R151: .030 thick (was .024), its top .022 over the pad's, like the moss
  ice.Transparency=.28;ice.Reflectance=.12
 end
 local color=theme.Vein or theme.Stone:Lerp(Color3.new(),.25)
 local material=theme.Vein and Enum.Material.Neon or Enum.Material.SmoothPlastic
 local vertices={{-.76,-.17},{-.34,-.07},{-.12,.14},{.17,.03},{.56,.23},{.80,.19}}
 for i=1,#vertices-1 do
  local a=Vector3.new(vertices[i][1]*d.Radius,top+.012,vertices[i][2]*d.Radius)
  local b=Vector3.new(vertices[i+1][1]*d.Radius,top+.012,vertices[i+1][2]*d.Radius)
  local p=part(m,'StoneVein',Vector3.new(math.max(.018,d.Radius*.012),.012,(b-a).Magnitude),
      CFrame.lookAt(center+(a+b)/2,center+b),color,nil)
  p.Material=material;p.CastShadow=false
 end
 return m
end

-- V139 client-only seed decoration. Never moves or welds the authoritative seed.
-- One owner updates/destroys each returned object; no per-particle event loops.
local SeedMotion={};SeedMotion.__index=SeedMotion
-- R152 perf: a seed aura's per-frame values are written only when they change (its own pieces; PropCache152, without it every write as before)
local Cache do local ok,m=pcall(require,script.Parent.PropCache152);Cache=ok and m or{new=function()return{Set=function(o,k,v)o[k]=v end}end}end
local V,CF=Vector3.new,CFrame.new
local SOFT="rbxasset://textures/particles/flare_main.dds"
local biomeColors={Forest=Color3.fromRGB(198,239,160),Jungle=Color3.fromRGB(255,203,104),
 Desert=Color3.fromRGB(255,220,140),Snow=Color3.fromRGB(172,239,255),Lava=Color3.fromRGB(255,156,67),
 Crystal=Color3.fromRGB(180,233,255),Storm=Color3.fromRGB(255,240,117)}
local function scaled(frame,s)return CF(frame.Position*s)*frame.Rotation end
local function fxPart(parent,name,size,color,transparency,shape,material)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Transparency=transparency or 0
 p.Shape=shape or Enum.PartType.Block;p.Material=material or Enum.Material.Neon
 p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Parent=parent;return p
end
local function softGlow(parent,anchor,color,size,opacity)
 local gui=Instance.new("BillboardGui");gui.Name="Soft seed light";gui.Adornee=anchor
 gui.Size=UDim2.fromScale(size,size);gui.AlwaysOnTop=false;gui.LightInfluence=0;gui.MaxDistance=Rules.SeedMotion.MaxDistance
 local image=Instance.new("ImageLabel");image.BackgroundTransparency=1;image.Size=UDim2.fromScale(1,1)
 image.Image=SOFT;image.ImageColor3=color;image.ImageTransparency=1;image.Parent=gui;gui.Parent=parent
 return {Gui=gui,Image=image,Size=size,Opacity=opacity}
end
local function piece(group,name,size,frame,color,alpha,shape,material)
 local p=fxPart(group.Parent,name,size,color,alpha,shape,material)
 local entry={Part=p,Size=size,Frame=frame,Alpha=alpha or 0};table.insert(group.Pieces,entry);return p
end
local function linePiece(group,name,a,b,width,color)
 local delta=b-a
 return piece(group,name,V(width,width,delta.Magnitude),CFrame.lookAt((a+b)/2,b,math.abs(delta.Unit.Y)>.98 and Vector3.zAxis or Vector3.yAxis),color,0)
end
local function group(parent)return {Parent=parent,Pieces={}}end
local function orbitObject(self,size,trail)
 local g=group(self.Folder);local b,color=self.Biome,biomeColors[self.Biome]or self.Color
 local core
 if b=="Storm"then
  local pts={V(-.13,.22,0)*size*3,V(.02,.05,0)*size*3,V(-.10,.02,0)*size*3,V(.13,-.24,0)*size*3}
  for i=1,3 do core=linePiece(g,"Orbiting lightning",pts[i],pts[i+1],.06*size*3,color)end
 elseif b=="Forest"or b=="Jungle"then
  core=piece(g,"Drifting leaf",V(.75,1.4,.24)*size,CF()*CFrame.Angles(0,0,.65),color,0,Enum.PartType.Ball,Enum.Material.SmoothPlastic)
 else
  local h=b=="Snow"and 1.9 or 1.35
  local glass=b=="Snow"or b=="Crystal"
  core=piece(g,b=="Lava"and "Ember stone"or "Orbiting crystal",V(.9,h,.7)*size,
   CFrame.Angles(.15,.3,.3),b=="Lava"and Color3.fromRGB(56,32,29)or color,glass and .18 or 0,nil,glass and Enum.Material.Glass or Enum.Material.SmoothPlastic)
  -- A faceted tip reads as ice/crystal rather than an identical round satellite.
  piece(g,"Crystal glint",V(.56,.56,.5)*size,CF(0,h*size*.5,0)*CFrame.Angles(0,0,math.pi/4),color,glass and .12 or .04,nil,glass and Enum.Material.Glass or Enum.Material.Neon)
  if b=="Lava"then linePiece(g,"Ember seam",V(-.4,-.3,-.4)*size,V(.36,.5,-.4)*size,.09*size,color)end
 end
 g.Glow=softGlow(self.Folder,core,color,size*1.8,.55);table.insert(self.GlowItems,g.Glow)
 if trail then
  local a=Instance.new("Attachment");a.Name="Comet start";a.Position=V(0,.035,0);a.Parent=core
  local b=Instance.new("Attachment");b.Name="Comet end";b.Position=V(0,-.035,0);b.Parent=core
  local t=Instance.new("Trail");t.Name="Seed comet trail";t.Attachment0=a;t.Attachment1=b
  t.Color=ColorSequence.new(self.Color);t.Lifetime=.30;t.MinLength=.025;t.FaceCamera=true
  t.LightEmission=1;t.LightInfluence=0;t.Enabled=false
  t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,1)})
  t.Parent=core;g.Trail=t;g.TrailEnds={a,b};table.insert(self.Trails,t)
 end
 table.insert(self.Groups,g);return g
end
local function ring(self,radius,width,color,alpha,segments,gap)
 local anchor=fxPart(self.Folder,"Orbit frame",Vector3.one*.02,color,1)
 local result={Anchor=anchor,Radius=radius,Width=width,Arcs={},Alpha=alpha,Gap=gap or 0}
 local n=segments or 4
 for i=1,n do
  local a=Instance.new("Attachment");a.Parent=anchor
  local b=Instance.new("Attachment");b.Parent=anchor
  local beam=Instance.new("Beam");beam.Name="Continuous orbit";beam.Attachment0=a;beam.Attachment1=b
  beam.Color=ColorSequence.new(color);beam.FaceCamera=true;beam.LightEmission=1;beam.LightInfluence=0
  beam.Segments=8;beam.Enabled=false;beam.Transparency=NumberSequence.new(alpha);beam.Parent=anchor
  table.insert(result.Arcs,{A=a,B=b,Beam=beam,Start=(i-1)*math.pi*2/n,Finish=i*math.pi*2/n-result.Gap})
 end
 table.insert(self.Rings,result);return result
end
local function addOrbit(self,radius,x,z,direction,count,index)
 local o={Radius=radius,TiltX=x,TiltZ=z,Direction=direction,Speed=.35+index*.12,Index=index,Nodes={}}
 o.Ring=ring(self,radius,.012,self.Color,.80)
 for i=1,count do
  local g=orbitObject(self,self.Rank>=7 and .17 or .13,self.Rank>=5)
  table.insert(o.Nodes,{Group=g,Phase=(i-1)*math.pi*2/count+index})
 end
 table.insert(self.Orbits,o)
end
function Visuals.CreateSeedMotion(seed,parent,detailed)
 local _,style=Rules.GetRarity(seed:GetAttribute("SeedId"))
 if style.Rank<3 or not seed.PrimaryPart then return nil end
 local self=setmetatable({Seed=seed,Rank=style.Rank,Color=style.Color,
  Biome=seed:GetAttribute("SeedBiome")or "Forest",Detailed=detailed~=false,
  Groups={},Rings={},Orbits={},Motes={},GlowItems={},Trails={},Destroyed=false},SeedMotion)
 self.Set=Cache.new().Set
 local folder=Instance.new("Folder");folder.Name="SeedMotionV139";self.Folder=folder
 self.Anchor=fxPart(folder,"Seed aura anchor",Vector3.one*.02,self.Color,1)
 self.Core=softGlow(folder,self.Anchor,self.Color,self.Rank>=7 and 3.35 or 2.5,self.Rank>=7 and .19 or .14)
 table.insert(self.GlowItems,self.Core)
 local light=Instance.new("PointLight");light.Name="Soft rarity light";light.Color=self.Color
 light.Shadows=false;light.Enabled=false;light.Parent=self.Anchor;self.Light=light
 local n=self.Detailed and(self.Rank>=7 and 9 or self.Rank>=4 and 6 or 4)or 3
 for i=0,n-1 do
  local p=fxPart(folder,"Drifting rarity mote",Vector3.one*.02,self.Color,1)
  local glow=softGlow(folder,p,self.Color,.14+(i%3)*.035,.55)
  table.insert(self.GlowItems,glow)
  table.insert(self.Motes,{Part=p,Glow=glow,Phase=i*2.39996+.4,Speed=.085+(i%5)*.012,Offset=(i*.618034)%1,Index=i})
 end
 if self.Detailed then
  if self.Rank==4 then addOrbit(self,1.17,.12,.3,1,3,0)
  elseif self.Rank==5 then addOrbit(self,1.18,.50,.2,1,3,0);addOrbit(self,1.43,-.52,-.25,-1,3,1)
  elseif self.Rank==6 then
   self.Eclipse=ring(self,1.24,.055,self.Color,.23,12,math.pi/18)
   addOrbit(self,1.45,.27,.1,-.65,4,0)
  elseif self.Rank>=7 then
   addOrbit(self,1.38,.68,.30,1,4,0);addOrbit(self,1.62,-.61,-.55,-1,4,1)
   self.Inner=softGlow(folder,self.Anchor,self.Rank==8 and Color3.new(1,1,1)or Color3.fromRGB(198,223,255),1.75,.12)
   table.insert(self.GlowItems,self.Inner)
  end
  if self.Rank==8 then
   self.Crown=ring(self,.61,.038,self.Color,.13);self.CrownJewels={};self.CrownTeeth=group(folder)
   table.insert(self.Groups,self.CrownTeeth)
   for i=0,7 do
    local a=i*math.pi/4
    linePiece(self.CrownTeeth,"Royal crown point",V(math.cos(a)*.61,0,math.sin(a)*.61),V(math.cos(a)*.68,.34+(i%2)*.1,math.sin(a)*.68),.04,self.Color)
    table.insert(self.CrownJewels,{Group=orbitObject(self,.14,false),Angle=a,Height=.14+(i%2)*.065})
   end
  end
 end
 -- Parent once all objects are configured; first Update sets their visible transforms.
 -- R134 (owner: "rare can just add minor effects, and as we scale up more and more effects and animations"):
 -- Legendary and rarer seeds animate their own signature parts (flames flicker, crystals twinkle, glows pulse;
 -- colour only, so welded held seeds are never moved), and King seeds add slow golden rays behind them.
 self.Anim={}
 if self.Rank>=4 and self.Detailed then
  for _,d in ipairs(seed:GetDescendants())do
   local kind=d:IsA('BasePart')and d:GetAttribute('SeedAnim')
   if kind then table.insert(self.Anim,{Part=d,Kind=kind,Color=d.Color,Phase=#self.Anim*1.7})end
  end
 end
 if self.Rank==8 and self.Detailed then
  self.Rays=group(folder)
  for i=0,7 do
   local a=i*math.pi/4;local r=1.05+(i%2)*.28
   linePiece(self.Rays,'Royal ray',V(math.sin(a)*.5,math.cos(a)*.5,.4),V(math.sin(a)*r,math.cos(a)*r,.4),.07,self.Color)
   self.Rays.Pieces[#self.Rays.Pieces].Alpha=.45
  end
  table.insert(self.Groups,self.Rays)
 end
 folder.Parent=parent;return self
end
local function placeGroup(S,g,frame,scale,opacity,rescale)
 for _,p in ipairs(g.Pieces)do
  S(p.Part,'CFrame',frame*scaled(p.Frame,scale))
  if rescale then p.Part.Size=p.Size*scale end
  S(p.Part,'Transparency',1-(1-p.Alpha)*opacity)
 end
 if g.Trail then
  if rescale then g.TrailEnds[1].Position=V(0,.035*scale,0);g.TrailEnds[2].Position=V(0,-.035*scale,0)end
  S(g.Trail,'Enabled',opacity>.05)
 end
end
local function placeRing(S,r,frame,scale,opacity,rescale)
 S(r.Anchor,'CFrame',frame)
 for _,a in ipairs(r.Arcs)do
  if rescale then
   local radius=r.Radius*scale
   local function at(t)return CFrame.fromMatrix(V(math.cos(t)*radius,0,math.sin(t)*radius),V(-math.sin(t),0,math.cos(t)),Vector3.yAxis)end
   a.A.CFrame=at(a.Start);a.B.CFrame=at(a.Finish)
   local curve=4/3*math.tan((a.Finish-a.Start)/4)*radius
   a.Beam.CurveSize0=curve;a.Beam.CurveSize1=curve;a.Beam.Width0=r.Width*scale;a.Beam.Width1=r.Width*scale
  end
  S(a.Beam,'Enabled',opacity>.01)
  if r.LastOpacity~=opacity then a.Beam.Transparency=NumberSequence.new(1-(1-r.Alpha)*opacity)end
 end
 r.LastOpacity=opacity
end
function SeedMotion:Update(frame,age,scale,opacity)
 if self.Destroyed then return end
 scale=math.clamp(scale or 1,.02,12);opacity=math.clamp(opacity or 1,0,1)
 local rescale=self.Scale~=scale;self.Scale=scale
 -- Clear retained trail history after teleports and hidden/reappearing transitions.
 if self.LastPosition and(self.LastPosition-frame.Position).Magnitude>math.max(8,4*scale)or opacity==0 then
  for _,t in ipairs(self.Trails)do t:Clear()end
 end
 local S=self.Set
 self.LastPosition=frame.Position;S(self.Anchor,'CFrame',frame)
 S(self.Light,'Enabled',opacity>.01);S(self.Light,'Brightness',(.4+.14*math.sin(age*1.35))*opacity)
 S(self.Light,'Range',math.min(18,6*scale))
 for _,g in ipairs(self.GlowItems)do
  if rescale then g.Gui.Size=UDim2.fromScale(g.Size*scale,g.Size*scale)end
  S(g.Gui,'Enabled',opacity>.01);S(g.Image,'ImageTransparency',1-g.Opacity*opacity)
 end
 S(self.Core.Image,'ImageTransparency',1-(self.Core.Opacity+.035*math.sin(age*1.35))*opacity)
 for _,p in ipairs(self.Motes)do
  local life=(age*p.Speed+p.Offset)%1;local fade=math.sin(life*math.pi)^2
  local x=math.cos(p.Phase)*(1.05+(p.Index%3)*.13)+math.sin(age*.48+p.Phase)*.15
  local z=math.sin(p.Phase)*(.78+(p.Index%4)*.12)+math.sin(age*.33+p.Phase*1.4)*.14
  S(p.Part,'CFrame',frame*CF(V(x,-.86+life*2.3,z)*scale))
  S(p.Glow.Image,'ImageTransparency',1-fade*(.44+.12*math.sin(age*.9+p.Phase))*opacity)
 end
 for _,o in ipairs(self.Orbits)do
  local plane=frame*CFrame.Angles(o.TiltX,math.sin(age*.17+o.Index)*.1,o.TiltZ)
  placeRing(S,o.Ring,plane,scale,opacity,rescale)
  for _,item in ipairs(o.Nodes)do
   local a=item.Phase+age*o.Speed*o.Direction
   local offset=CF(V(math.cos(a)*o.Radius,0,math.sin(a)*o.Radius)*scale)*CFrame.Angles(age*.32,a,age*.22)
   placeGroup(S,item.Group,plane*offset,scale,opacity,rescale)
  end
 end
 if self.Eclipse then
  placeRing(S,self.Eclipse,frame*CFrame.Angles(math.pi/2,0,.18-age*.10),scale,opacity*(.8+.2*math.sin(age*1.2)),rescale)
 end
 for _,a in ipairs(self.Anim)do
  local t=age+a.Phase;local k
  if a.Kind=='Flicker'then k=.5+.5*math.sin(t*11)*math.sin(t*6.7+1.3)
  elseif a.Kind=='Twinkle'then k=math.max(0,math.sin(t*2.6))^6
  else k=.5+.5*math.sin(t*2.2)end
  k=1-(1-k)*opacity
  local dark,bright=a.Color:Lerp(Color3.new(0,0,0),.4),a.Color:Lerp(Color3.new(1,1,1),.35)
  S(a.Part,'Color',dark:Lerp(bright,k)) -- (the seed's own part: only this aura writes its colour while it runs)
 end
 if self.Rays then placeGroup(S,self.Rays,frame*CFrame.Angles(0,0,age*.25),scale,opacity*(.75+.25*math.sin(age*1.1)),rescale)end
 if self.Crown then
  local cf=frame*CF(0,(1.72+math.sin(age*1.3)*.04)*scale,0)*CFrame.Angles(0,-age*.16,0)
  placeRing(S,self.Crown,cf,scale,opacity,rescale);placeGroup(S,self.CrownTeeth,cf,scale,opacity,rescale)
  for _,j in ipairs(self.CrownJewels)do placeGroup(S,j.Group,cf*CF(V(math.cos(j.Angle)*.61,j.Height,math.sin(j.Angle)*.61)*scale),scale,opacity,rescale)end
 end
end
function SeedMotion:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true;self.Folder:Destroy()
 for _,a in ipairs(self.Anim or{})do if a.Part.Parent then a.Part.Color=a.Color end end
 table.clear(self.Groups);table.clear(self.Rings);table.clear(self.Orbits);table.clear(self.Motes);table.clear(self.GlowItems);table.clear(self.Trails)
end

return Visuals
