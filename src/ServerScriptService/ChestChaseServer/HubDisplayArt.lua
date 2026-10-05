-- R151 (rebuilt in R152): the shape of the two hub displays (HubDisplayService owns what they say and when). R152 (owner: "make sure that the avatar is sized up and dancing while the seed rotates around
-- and the effects are actually on the seed not behind ... a billboard is not needed ... the same format and look as the fruit of the hour type pedestal"): a display is just
--
--        [ label ]               the market's FRUIT OF THE HOUR pedestal (MarketLayout.Pedestal: stone plinth with a gold trim and four studs, teal column with its inlays and a plaque, gold band, stone
--         ITEM  (turns)          capital, gold-deep top, four gold prongs: same shapes, same palette), built Scale times bigger, the winning seed / fruit floating over its prongs, and the champion's
--   [plaque]   AVATAR (dances)   avatar, 25 studs tall, standing on the floor beside it. Front (what players see) is local -Z, toward the market; local +X is on the viewer's left.
--   [=== pedestal ===]
--
--  * No sign board, posts, stage slab, halo disc or plinth for the avatar, and NOT the Fruit of the Hour's hollow projector tube: only the pedestal, the item and the avatar.
--  * Words, small like the Fruit of the Hour's: an engraved plaque on the column (SurfaceGui: a dark plate, gold lettering; the title, the winner, a line, the countdown) and a label over the
--    item (BillboardGui: the title, the winner's name, the seed / fruit; HubDisplayRules.Plaque / Label / SignText).
--  * The item (the game's own seed or fruit art, <= ItemParts parts) carries its effects: an invisible core part at its centre holds a PointLight (the champion's colour), and the client puts a sparkle
--    emitter on the same core while it is near; the client turns the whole item (HubDisplayClient), so light and sparkles move with it. Nothing flat behind it.
--  * Space: everything inside Rules.Layout.Footprint (36 x 24 studs half size) around the display's centre, under the hub walls' height. Collision: the plinth, column, capital and its top are solid;
--    everything else (trims, inlays, plaque, prongs, the item, the avatar) is for show (CanCollide / CanQuery / CanTouch off).
-- Cost: 17 static parts for the pedestal, one SurfaceGui, one BillboardGui, one light, plus the item (<= ItemParts) and the avatar (a rig, <= 10 accessories). Nothing is animated here: the turn, the
-- sparkles and the cheer are the client's, only near the camera; the dance is the Animator's (HubDisplayAvatar.Animate).
-- Rules for the parts: surfaces that face the same way are never within .02 stud of each other where they overlap (the tests check the frame itself and the finished hub with the R149 detector).
local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Rules=require(RS:WaitForChild('HubDisplayRules'))
local A={}
local RGB=Color3.fromRGB
local V3,CF=Vector3.new,CFrame.new
-- the Fruit of the Hour pedestal's palette (MarketLayout.P) and its plaque's dark plate
local STONE,TEAL,TEALD,GOLD,GOLDD,PLATE=RGB(232,224,206),RGB(36,141,144),RGB(22,92,108),RGB(247,209,119),RGB(241,187,78),RGB(30,34,50)
local SILHOUETTE=RGB(10,9,16)
-- Local numbers (studs; origin = the display's centre on the floor, X to the viewer's left, Y up, Z away from the viewers). The pedestal's own numbers are MarketLayout.Pedestal's (its units) x Scale.
A.Dim={
 Scale=3.2,                                      -- the pedestal is the Fruit of the Hour's x 3.2: 19.8 wide, 15.9 tall
 Pedestal={X=15},                                -- its centre (the viewer's left)
 Avatar={X=-15},                                -- where the avatar's soles stand (on the floor; Rules.AvatarTurn turns it toward the pedestal)
 Inlay={W=3.4,H=1.9},                            -- the column's front inlay, in pedestal units (wider than the market's 2.6 x 1.5: it frames the bigger plaque)
 ItemTop=6.5,                                    -- the item's bottom floats over the prong tips: pedestal units
 LabelGap=1.2,                                   -- from the item's top to the label's bottom (studs)
}
function A.CapitalTop()return 4.955*A.Dim.Scale end                    -- (local Y of the pedestal's top slab's top)
function A.ItemBase()return A.Dim.ItemTop*A.Dim.Scale end              -- (local Y of the item's lowest point: just over the prongs' tips, 20.8)
function A.AvatarFeet()return 0 end                                    -- (local Y of the soles: the floor)
local function part(parent,name,size,frame,color,material,solid)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=solid==true;p.CanQuery=solid==true;p.CanTouch=false;p.CastShadow=solid==true
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- A round part standing up (a Cylinder's axis is X): height first. (Only the gem stand-in uses one.)
local function disc(parent,name,height,diameter,frame,color,material,solid)
 local p=part(parent,name,V3(height,diameter,diameter),frame*CFrame.Angles(0,0,math.pi/2),color,material,solid)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function ball(parent,name,diameter,frame,color,material)
 local p=part(parent,name,V3(diameter,diameter,diameter),frame,color,material);p.Shape=Enum.PartType.Ball;return p
end
local function c3(t)return RGB(t[1],t[2],t[3])end
-- The frame ------------------------------------------------------------------------------------------------------------------------------------------
-- parent: where the display's Model goes. kind: 'Pull' | 'Fruit'. layout: HubDisplayRules.Layout. floorTop: the hub floor's top (world Y). Returns the display handle.
function A.BuildFrame(parent,kind,layout,floorTop)
 local D=A.Dim;local S=D.Scale
 local spot=(kind=='Fruit'and layout.Fruit or layout.Pull).Center
 local origin=V3(spot.X,floorTop,spot.Z)
 local F=CFrame.lookAt(origin,V3(layout.Target.X,floorTop,layout.Target.Z)) -- local -Z (the front) faces the market
 local function L(x,y,z)return F*CF(x,y,z)end
 local model=Instance.new('Model');model.Name=kind=='Fruit'and'BiggestFruitDisplay'or'BestPullDisplay'
 model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent -- (StreamingEnabled: a landmark; it must be there from afar, never streamed out and back as new instances)
 model:SetAttribute('HubDisplay',Rules.Version);model:SetAttribute('Kind',kind);model:SetAttribute('State','Empty');model:SetAttribute('Rev',0)
 local d={Kind=kind,Model=model,F=F,Plate={},Tag={}}
 -- the pedestal: MarketLayout.Pedestal's parts and palette (u = its units, x Scale), without its projector tube and its flat cradle glow ----------------------------------------------
 local ped=Instance.new('Folder');ped.Name='Pedestal';ped.Parent=model
 local px=D.Pedestal.X
 local function u(name,w,h,l,x,y,z,color,solid,rot)return part(ped,name,V3(w*S,h*S,l*S),L(px+x*S,y*S,z*S)*(rot or CFrame.new()),color,nil,solid)end
 u('Pedestal plinth',6,.8,6,0,.4,0,STONE,true)
 u('Plinth trim',6.2,.2,6.2,0,.9,0,GOLD)
 for _,x in ipairs({-2.7,2.7})do for _,z in ipairs({-2.7,2.7})do u('Plinth stud',.45,.45,.45,x,1.05,z,GOLDD,false,CFrame.Angles(0,math.rad(45),0))end end
 u('Pedestal column',3.8,2.4,3.8,0,2.2,0,TEAL,true)
 local I=D.Inlay
 u('Column inlay',I.W,I.H,.08,0,2.2,-1.92,TEALD);u('Column inlay',I.W,I.H,.08,0,2.2,1.92,TEALD)
 u('Column band',4.1,.25,4.1,0,3.5,0,GOLD)
 u('Pedestal capital',3.4,1,3.4,0,4.1,0,STONE,true)
 local top=u('Capital top',4,.35,4,0,4.78,0,GOLDD,true)
 for i=0,3 do
  local a=i*math.pi/2+math.pi/4
  u('Cradle prong',.22,1.7,.22,math.cos(a)*1.15,5.65,math.sin(a)*1.15,GOLDD,false,CFrame.Angles(0,-a,0)*CFrame.Angles(0,0,math.rad(-18)))
 end
 -- the plaque: a dark plate on the inlay's front (its back face on the inlay's front face), the engraved words a SurfaceGui
 local P=Rules.Plaque
 local plate=part(ped,'Pedestal plaque',V3(P.W,P.H,.2),L(px,2.2*S,-(1.96*S+.1)),PLATE)
 d.Plaque=plate
 A._buildPlaque(d,plate)
 -- the label over the item (the item's top is ItemHeight over its bottom): a BillboardGui on the pedestal's top, lifted in world space
 d.Top=top
 A._buildLabel(d,top)
 -- slots for what changes ------------------------------------------------------------------------------------------------------------------------
 d.ItemFolder=Instance.new('Folder');d.ItemFolder.Name='Item';d.ItemFolder.Parent=model
 d.AvatarFolder=Instance.new('Folder');d.AvatarFolder.Name='Avatar';d.AvatarFolder.Parent=model
 d.ItemAt=L(px,A.ItemBase(),0)                  -- where the item's bottom centre goes (the display's own turn in it)
 d.FeetAt=L(D.Avatar.X,A.AvatarFeet(),0)        -- where the avatar's soles go
 model:SetAttribute('ItemCenter',(d.ItemAt*CF(0,Rules.ItemHeight/2,0)).Position)
 model.Parent=parent
 CS:AddTag(model,Rules.Tag)
 return d
end
-- The words ----------------------------------------------------------------------------------------------------------------------------------------------
-- The plaque: the Fruit of the Hour plaque's look (dark plate, Fredoka One in gold) with four rows: HubDisplayRules.Plaque.Rows.
function A._buildPlaque(d,plate)
 local S=Rules.Plaque
 local gui=Instance.new('SurfaceGui');gui.Name='Lettering';gui.Face=Enum.NormalId.Front
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=S.PixelsPerStud
 gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.ResetOnSpawn=false
 pcall(function()gui.MaxDistance=S.MaxDistance end)
 gui.Parent=plate
 local W,H=S.Canvas.W,S.Canvas.H
 for _,key in ipairs({'Title','Name','Line','Footer'})do
  local row=S.Rows[key]
  local label=Instance.new('TextLabel');label.Name=key;label.BackgroundTransparency=1
  label.Position=UDim2.fromScale(row.X/W,row.Y/H);label.Size=UDim2.fromScale(row.W/W,row.H/H)
  label.Font=Enum.Font.FredokaOne;label.Text='';label.TextColor3=GOLD;label.TextScaled=true
  label.TextStrokeColor3=RGB(14,12,34);label.TextStrokeTransparency=key=='Footer'and .6 or .35;label.TextWrapped=false;label.Parent=gui
  local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=row.Max;fit.MinTextSize=8;fit.Parent=label
  d.Plate[key]=label
 end
 d.Gui=gui
end
-- The label: FruitOfHourDisplay's two-row label (white name over a coloured line), floating over the item, with the title above (rows in studs: HubDisplayRules.Label.Rows).
function A._buildLabel(d,top)
 local S=Rules.Label
 local gui=Instance.new('BillboardGui');gui.Name='Label';gui.Size=UDim2.fromScale(S.W,S.H)
 local itemTop=A.ItemBase()+Rules.ItemHeight
 gui.StudsOffsetWorldSpace=V3(0,itemTop+A.Dim.LabelGap+S.H/2-4.78*A.Dim.Scale,0) -- (from the top slab's centre)
 gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.ResetOnSpawn=false
 pcall(function()gui.MaxDistance=S.MaxDistance end)
 gui.Adornee=top;gui.Parent=top
 for _,key in ipairs({'Title','Name','Info'})do
  local row=S.Rows[key]
  local t=Instance.new('TextLabel');t.Name=key;t.Text='';t.BackgroundTransparency=1
  t.Position=UDim2.fromScale(row.X/S.W,row.Y/S.H);t.Size=UDim2.fromScale(row.W/S.W,row.H/S.H)
  t.Font=Enum.Font.FredokaOne;t.TextScaled=true;t.TextColor3=Color3.new(1,1,1);t.TextStrokeColor3=RGB(20,25,40);t.TextStrokeTransparency=.25;t.Parent=gui
  d.Tag[key]=t
 end
 d.LabelGui=gui
end
-- Writes the words (HubDisplayRules.SignText) into the plaque and the label.
function A.SetSign(d,text)
 if not d or not d.Plate then return end
 for _,pair in ipairs({{d.Plate,text.Plaque},{d.Tag,text.Label}})do
  for key,label in pairs(pair[1])do
   local row=pair[2]and pair[2][key]
   label.Text=row and row.Text or''
   if row and row.Color then label.TextColor3=c3(row.Color)end
  end
 end
 d.Model:SetAttribute('State',text.State or'Empty')
end
-- Colours: the item's light wears `accent` ({r,g,b}) and the client's sparkles read it (the model's Accent attribute); a calm display (nobody has taken the spot: state 'Empty') has
-- its light off and no sparkles (the Calm attribute). The pedestal itself keeps the Fruit of the Hour's colours. (A 4th argument, the old biome stage, is ignored.)
function A.Tint(d,accent,state)
 local color=c3(accent or{255,214,90})
 local calm=state=='Empty'
 d.Model:SetAttribute('Calm',calm)
 if not calm then d.Model:SetAttribute('Accent',color)end
 local light=d.ItemFolder:FindFirstChild('Glow',true)
 if light then light.Color=color;light.Enabled=not calm end
end
-- The showcase item ---------------------------------------------------------------------------------------------------------------------------------------
-- Static geometry only (the ItemPictures rule): no scripts, effects, lights, sounds, joints or tags; every part anchored and inert. (The one light is added below, on the item's own core.)
local KEEP={DataModelMesh=true,SurfaceAppearance=true,Decal=true,Texture=true,Model=true,Folder=true}
local function clean(model)
 for _,tag in ipairs(CS:GetTags(model))do CS:RemoveTag(model,tag)end
 for _,item in ipairs(model:GetDescendants())do
  if item.Parent then
   for _,tag in ipairs(CS:GetTags(item))do CS:RemoveTag(item,tag)end
   if item:IsA('BasePart')then
    if item.Transparency>=.95 then item:Destroy()
    else item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false;item.Massless=true end
   else
    local ok=false;for class in pairs(KEEP)do if item:IsA(class)then ok=true;break end end
    if not ok then item:Destroy()end
   end
  end
 end
end
local function parts(model)
 local list={};for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then list[#list+1]=p end end;return list
end
A.Parts=parts
-- Keeps at most `limit` parts: the biggest by volume stay (a dropped part is one of the smallest details).
local function cap(model,limit)
 local list=parts(model);if #list<=limit then return 0 end
 table.sort(list,function(a,b)
  local va,vb=a.Size.X*a.Size.Y*a.Size.Z,b.Size.X*b.Size.Y*b.Size.Z
  if va~=vb then return va>vb end
  return a.Name<b.Name
 end)
 local dropped=0
 for i=limit+1,#list do list[i]:Destroy();dropped+=1 end
 return dropped
end
local function bounds(model)return require(RS:WaitForChild('HarvestGeometry')).Bounds(model)end
-- A seed (SeedPackVisuals.Seed, the hotbar's own art) at its natural size, centred on the origin. mystery: a black silhouette.
local function seedModel(id,coat,mystery)
 local holder=Instance.new('Folder')
 local ok,model=pcall(function()return require(RS:WaitForChild('SeedPackVisuals')).Seed({Id=id},1,CF(),holder,1,nil,coat)end)
 if not ok or not model then return nil,model end
 if mystery then
  for _,d in ipairs(model:GetDescendants())do
   if d:IsA('BasePart')and d.Transparency<1 then d.Color=SILHOUETTE;d.Material=Enum.Material.SmoothPlastic;d.Reflectance=0
   elseif d:IsA('Decal')or d:IsA('SurfaceAppearance')or d:IsA('Texture')then d:Destroy()end
  end
 end
 model.Parent=nil;holder:Destroy()
 return model
end
-- A fruit (HarvestPresentation.Build, the hotbar's own art, stems left off) at its natural size; Gold / Diamond coats as in the Bag. Over the part cap it uses the plant
-- builder's simplified fruit (FruitProxy) instead when that is smaller.
local function fruitModel(id,coat)
 local H=require(RS:WaitForChild('HarvestPresentation'))
 local ok,model=pcall(function()
  return(H.Build({SeedId=id,Mutation=coat,Weather='None',VisualCrop={SourceCropId='hub151',FruitIndex=1,HarvestCycle=0}}))
 end)
 if not ok or not model then return nil,model end
 if #parts(model)>Rules.ItemParts then
  local Visuals=require(RS:WaitForChild('PlantVisuals'))
  local okProxy,proxy=pcall(function()
   local holder=Instance.new('Model');holder.Name='HubFruitProxy'
   Visuals.FruitProxy(holder,id,{Id='hub151',SeedId=id,PlantScale=1,SeedScale=1,Mutation=coat,Weather='None',HarvestCycle=0,PickedMask=0,ReadyAt=0},1,CF())
   Visuals.Coat(holder,coat)
   return holder
  end)
  if okProxy and proxy and #parts(proxy)>0 and #parts(proxy)<#parts(model)then model:Destroy();model=proxy else if okProxy and proxy then proxy:Destroy()end end
 end
 return model
end
-- The stand-in when a builder fails: a glossy gem ball on a gold ring (never an empty display).
local function gemModel(accent)
 local m=Instance.new('Model');m.Name='HubGem'
 ball(m,'Gem',3,CF(0,0,0),c3(accent or{255,214,90}),Enum.Material.Glass)
 disc(m,'Ring',.3,4.4,CF(0,0,0)*CFrame.Angles(math.pi/2,0,0),GOLD)
 return m
end
-- Builds the showcase item for a spec and floats it over the pedestal's prongs. spec: {Kind='Seed'|'Fruit', Id=, Coat=, Mystery=, Accent=, Calm=}. Returns the Model (parented to nothing), and
-- info {Parts=, Dropped=, Source='art'|'gem', Height=}. Never throws. The item carries its own effects: 'ItemCore', an invisible part at its centre (about 70% of its size), holds the
-- PointLight 'Glow' (the accent colour; off when Calm) and is where the client's sparkles go: all of it turns with the item.
function A.BuildItem(d,spec)
 local model;local source='art'
 local ok,built=pcall(function()
  if spec.Kind=='Fruit'then return(fruitModel(spec.Id,spec.Coat or'None'))end
  return(seedModel(spec.Id,spec.Coat or'None',spec.Mystery))
 end)
 if ok and built then model=built end
 if not model or #parts(model)==0 then
  if model then model:Destroy()end
  model=gemModel(spec.Accent);source='gem'
 end
 clean(model)
 local dropped=cap(model,Rules.ItemParts-1) -- (one more part follows: the core)
 -- size: the tallest side is ItemHeight (a wide, flat plant by a bit less), and nothing wider than 14 studs
 local center,size=bounds(model)
 local tall=math.max(size.Y,.6*math.max(size.X,size.Z),.01)
 local k=math.min(Rules.ItemHeight/tall,14/math.max(size.X,size.Z,.01))
 local bottom=V3(center.X,center.Y-size.Y/2,center.Z)
 local F=d.ItemAt
 for _,p in ipairs(parts(model))do
  local cf=p.CFrame
  p.Size=p.Size*k
  local art=p:GetAttribute('ArtSize');if typeof(art)=='Vector3'then p:SetAttribute('ArtSize',art*k)end
  p.CFrame=F*CF((cf.Position-bottom)*k)*cf.Rotation
  CS:AddTag(p,'GiantVisualPart') -- (the camera right up against it fades it: GiantVisualSafety, like the giant plants)
 end
 -- the core: where the item's light and sparkles live (an invisible part in the item: whatever turns the item turns it)
 local core=Instance.new('Part');core.Name='ItemCore';core.Size=V3(math.max(size.X*k*.7,1),math.max(size.Y*k*.7,1),math.max(size.Z*k*.7,1));core.CFrame=F*CF(0,size.Y*k/2,0)
 core.Transparency=1;core.Anchored=true;core.CanCollide=false;core.CanQuery=false;core.CanTouch=false;core.CastShadow=false;core.Massless=true;core.Parent=model
 local light=Instance.new('PointLight');light.Name='Glow';light.Color=c3(spec.Accent or{255,214,90});light.Brightness=1.6;light.Range=40;light.Shadows=false
 light.Enabled=spec.Calm~=true;light.Parent=core
 model.Name='GiantItem';model.PrimaryPart=nil
 model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 model:SetAttribute('Spin',true)
 return model,{Parts=#parts(model),Dropped=dropped,Source=source,Scale=k,Height=size.Y*k}
end
-- Puts a built item (or nil) in the display's item slot. The old one goes first.
function A.SetItem(d,model)
 for _,c in ipairs(d.ItemFolder:GetChildren())do c:Destroy()end
 if model then model.Parent=d.ItemFolder end
end
function A.SetAvatar(d,model)
 for _,c in ipairs(d.AvatarFolder:GetChildren())do c:Destroy()end
 if model then model.Parent=d.AvatarFolder end
end
-- Counts for the tests and the owner's `hubdisplays` line.
function A.Counts(d)
 local n={Frame=0,Item=0,Avatar=0}
 for _,p in ipairs(parts(d.Model))do
  if p:IsDescendantOf(d.ItemFolder)then n.Item+=1
  elseif p:IsDescendantOf(d.AvatarFolder)then n.Avatar+=1
  else n.Frame+=1 end
 end
 return n
end
return A
