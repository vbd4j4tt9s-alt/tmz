-- R151: the shape of the two hub displays (HubDisplayService owns what they say and when). Both are the same stage, built from static anchored parts in the game's
-- chunky cartoon style (slate, gold trims, glowing gems: the R150 mystery pedestal's own art, MysteryPedestalArt, scaled up for the item's podium):
--
--      [ crown ]                  front (what players see) is local -Z, toward the market; local +X is on the viewer's left
--   |  SIGN BOARD 48 x 20  |      the board stands on two slate posts with gold collars and a glowing gem on top; its words are a SurfaceGui (SignText)
--   |                      |
--        (halo)                  the halo disc, the gems and the ring on the podium wear the champion's colour (the rarity's, for a pull)
--    ITEM on a PODIUM   AVATAR   the giant item (cheap detail: <= 150 parts) stands on the podium; the champion's avatar on its own low plinth beside it
--   [========= stage =========]  slate stage with a gold skirt, one front step, and a wide apron
--
-- Space: everything stays inside the 60 x 36 apron (HubDisplayRules.Footprint) around the display's centre, and under 48 studs tall (the hub's walls). Collision: the apron,
-- stage, step, podium (its four solid pieces), avatar plinth and the posts are solid; everything else is for show (CanCollide / CanQuery off, CanTouch off).
-- Cost: about 100 static parts for the frame, one SurfaceGui, one PointLight, plus the item (<= ItemParts) and the avatar. Nothing is animated here: motion, sparkles and the
-- cheer are the client's (HubDisplayClient), only near the camera.
-- Rules for the parts: surfaces that face the same way are never within .02 stud of each other where they overlap (tools/zfight.py runs on the built scene in the tests).
local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Rules=require(RS:WaitForChild('HubDisplayRules'))
local PedestalArt=require(script.Parent.MysteryPedestalArt)
local A={}
local RGB=Color3.fromRGB
local V3,CF=Vector3.new,CFrame.new
local SLATE,SLATE2,GOLD,NAVY=RGB(105,117,106),RGB(124,136,125),RGB(255,198,72),RGB(24,28,54)
local SILHOUETTE=RGB(10,9,16)
-- Local numbers (studs; origin = the centre of the stage on the floor, X to the viewer's left, Y up, Z away from the viewers).
A.Dim={
 Apron={X=60,Z=36,H=.4},Stage={X=54,Z=30,H=.8},StageTop=1.2,
 Step={X=20,Z=3,H=.4,Z0=-16.5},
 Podium={X=13,Z=-1,Scale=1.2},        -- the item's podium (MysteryPedestalArt x 1.2): its top glow ring is 6.41 x 1.2 above the stage
 Plinth={X=-13,Z=-1,D=9.6,H=1.0},     -- the avatar's low round plinth
 Board={W=Rules.Sign.BoardW,H=Rules.Sign.BoardH,Bottom=21,Z=11.5,Thick=1.2},
 PostX=25.8,PostD=2.4,PostTop=40,
 ItemGap=.5,                          -- the item's bottom floats this far over the podium's top
 Halo={D=16,Back=5},                  -- the halo disc behind the item
}
function A.PodiumTop()return A.Dim.StageTop+6.41*A.Dim.Podium.Scale end  -- (local Y of the glowing ring on top of the podium)
function A.ItemBase()return A.PodiumTop()+A.Dim.ItemGap end              -- (local Y of the item's lowest point)
function A.AvatarFeet()return A.Dim.StageTop+A.Dim.Plinth.H+.1 end        -- (local Y of the soles: on the plinth's glow pad)
local function part(parent,name,size,frame,color,material,solid)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=solid==true;p.CanQuery=solid==true;p.CanTouch=false;p.CastShadow=solid==true
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
-- A round part standing up (a Cylinder's axis is X): height first.
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
 local D=A.Dim
 local spot=(kind=='Fruit'and layout.Fruit or layout.Pull).Center
 local origin=V3(spot.X,floorTop,spot.Z)
 local F=CFrame.lookAt(origin,V3(layout.Target.X,floorTop,layout.Target.Z)) -- local -Z (the front) faces the market
 local function L(x,y,z)return F*CF(x,y,z)end
 local model=Instance.new('Model');model.Name=kind=='Fruit'and'BiggestFruitDisplay'or'BestPullDisplay'
 model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent -- (StreamingEnabled: a landmark; it must be there from afar, never streamed out and back as new instances)
 model:SetAttribute('HubDisplay',Rules.Version);model:SetAttribute('Kind',kind);model:SetAttribute('State','Empty');model:SetAttribute('Rev',0)
 local d={Kind=kind,Model=model,F=F,Lit={},Ribbon=nil,Labels={}}
 -- the stage -------------------------------------------------------------------------------------------------------------------------------------
 local base=Instance.new('Folder');base.Name='Stage';base.Parent=model
 part(base,'Apron',V3(D.Apron.X,D.Apron.H,D.Apron.Z),L(0,D.Apron.H/2,0),SLATE,Enum.Material.Slate,true)
 part(base,'Stage',V3(D.Stage.X,D.Stage.H,D.Stage.Z),L(0,D.Apron.H+D.Stage.H/2,0),SLATE2,Enum.Material.Slate,true)
 part(base,'Stage skirt',V3(D.Stage.X+.8,.3,D.Stage.Z+.8),L(0,D.Apron.H+.15,0),GOLD)
 part(base,'Front step',V3(D.Step.X,D.Step.H,D.Step.Z),L(0,D.Apron.H+D.Step.H/2,D.Step.Z0),SLATE,Enum.Material.Slate,true)
 -- the item's podium: the R150 pedestal art, scaled up -------------------------------------------------------------------------------------------
 local podium=Instance.new('Model');podium.Name='Podium';podium.Parent=model
 local o=L(D.Podium.X,D.StageTop,D.Podium.Z)
 local art=PedestalArt.Build(podium,o)
 local pivot=part(podium,'PodiumPivot',V3(1,1,1),o,SLATE);pivot.Transparency=1
 podium.PrimaryPart=pivot
 podium:ScaleTo(D.Podium.Scale)
 d.Podium=podium;d.PodiumArt=art
 for _,p in ipairs(art.Lit)do d.Lit[#d.Lit+1]=p end
 -- the avatar's plinth ----------------------------------------------------------------------------------------------------------------------------
 local plinth=Instance.new('Folder');plinth.Name='AvatarPlinth';plinth.Parent=model
 local px,pz=D.Plinth.X,D.Plinth.Z
 disc(plinth,'Plinth skirt',.16,D.Plinth.D+.7,L(px,D.StageTop+.08,pz),GOLD)
 disc(plinth,'Plinth',D.Plinth.H,D.Plinth.D,L(px,D.StageTop+D.Plinth.H/2,pz),SLATE,Enum.Material.Slate,true)
 d.Lit[#d.Lit+1]=disc(plinth,'Plinth glow',.1,D.Plinth.D-1.2,L(px,D.StageTop+D.Plinth.H+.05,pz),GOLD,Enum.Material.Neon)
 -- the sign board, on two posts ---------------------------------------------------------------------------------------------------------------------
 local B=D.Board
 local back=Instance.new('Folder');back.Name='SignStand';back.Parent=model
 local boardMid=B.Bottom+B.H/2
 for _,side in ipairs({-1,1})do
  local x=side*D.PostX
  disc(back,'Post',D.PostTop-D.StageTop,D.PostD,L(x,D.StageTop+(D.PostTop-D.StageTop)/2,B.Z),SLATE,Enum.Material.Slate,true)
  disc(back,'Post foot',.6,D.PostD+1,L(x,D.StageTop+.3,B.Z),GOLD)
  disc(back,'Post collar',.5,D.PostD+.8,L(x,B.Bottom+.6,B.Z),GOLD)
  disc(back,'Post collar',.5,D.PostD+.8,L(x,B.Bottom+B.H-.6,B.Z),GOLD)
  disc(back,'Post cap',.5,D.PostD+1,L(x,D.PostTop+.25,B.Z),GOLD)
  d.Lit[#d.Lit+1]=ball(back,'Post gem',2,L(x,D.PostTop+1.5,B.Z),GOLD,Enum.Material.Neon)
 end
 part(back,'Sign frame',V3(B.W+1.2,B.H+1.6,B.Thick+.5),L(0,boardMid,B.Z+.5),GOLD)
 local board=part(back,'Sign board',V3(B.W,B.H,B.Thick),L(0,boardMid,B.Z),NAVY)
 d.Board=board
 -- the crown on the frame's top edge: a band and three jewels (the middle one a little higher); the top is 4.7 over the frame, under the hub walls
 local top=boardMid+(B.H+1.6)/2
 part(back,'Crown band',V3(16,1.2,B.Thick+.5),L(0,top+.6,B.Z+.5),GOLD)
 for i,x in ipairs({-5.5,0,5.5})do
  local rise=i==2 and .8 or 0
  d.Lit[#d.Lit+1]=part(back,'Crown jewel',V3(2.4,2.4,B.Thick),L(x,top+2.55+rise,B.Z+.5)*CFrame.Angles(0,0,math.pi/4),GOLD,Enum.Material.Neon)
 end
 -- the halo behind the item, and the item's light -------------------------------------------------------------------------------------------------
 local halo=part(model,'Halo',V3(.3,D.Halo.D,D.Halo.D),L(D.Podium.X,A.ItemBase()+Rules.ItemHeight/2,D.Podium.Z+D.Halo.Back)*CFrame.Angles(0,math.pi/2,0),GOLD,Enum.Material.Neon)
 halo.Shape=Enum.PartType.Cylinder;halo.Transparency=1 -- (a Cylinder's axis is X: the quarter turn about Y above points it at the viewers)
 d.Halo=halo
 local anchor=part(model,'ItemAnchor',V3(1,1,1),L(D.Podium.X,A.ItemBase()+Rules.ItemHeight/2,D.Podium.Z),GOLD);anchor.Transparency=1
 local light=Instance.new('PointLight');light.Name='Glow';light.Color=GOLD;light.Range=26;light.Brightness=1.1;light.Shadows=false;light.Enabled=false;light.Parent=anchor
 d.Anchor=anchor;d.Light=light
 -- slots for what changes ------------------------------------------------------------------------------------------------------------------------
 d.ItemFolder=Instance.new('Folder');d.ItemFolder.Name='Item';d.ItemFolder.Parent=model
 d.AvatarFolder=Instance.new('Folder');d.AvatarFolder.Name='Avatar';d.AvatarFolder.Parent=model
 d.ItemAt=L(D.Podium.X,A.ItemBase(),D.Podium.Z)   -- where the item's bottom centre goes (the display's own turn in it)
 d.FeetAt=L(D.Plinth.X,A.AvatarFeet(),D.Plinth.Z)  -- where the avatar's soles go
 model:SetAttribute('ItemCenter',(d.ItemAt*CF(0,Rules.ItemHeight/2,0)).Position)
 -- the sign's words ----------------------------------------------------------------------------------------------------------------------------------
 A._buildSign(d)
 model.Parent=parent
 CS:AddTag(model,Rules.Tag)
 return d
end
-- The sign ---------------------------------------------------------------------------------------------------------------------------------------------
function A._buildSign(d)
 local S=Rules.Sign
 local gui=Instance.new('SurfaceGui');gui.Name='Sign';gui.Face=Enum.NormalId.Front
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=S.PixelsPerStud
 gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.ResetOnSpawn=false
 pcall(function()gui.MaxDistance=S.MaxDistance end)
 gui.Parent=d.Board
 local W,H=S.Canvas.W,S.Canvas.H
 local bg=Instance.new('Frame');bg.Name='Background';bg.Size=UDim2.fromScale(1,1);bg.BackgroundColor3=NAVY;bg.BorderSizePixel=0;bg.Parent=gui
 local shade=Instance.new('UIGradient');shade.Color=ColorSequence.new(RGB(46,54,98),RGB(18,20,42));shade.Rotation=90;shade.Parent=bg
 local function box(row)return UDim2.fromScale(row.X/W,row.Y/H),UDim2.fromScale(row.W/W,row.H/H)end
 -- the ribbon behind the title: the champion's colour
 local ribbon=Instance.new('Frame');ribbon.Name='Ribbon';ribbon.BorderSizePixel=0;ribbon.BackgroundColor3=GOLD
 ribbon.Position=UDim2.fromScale(.02,.02);ribbon.Size=UDim2.fromScale(.96,(S.Rows.Title.H+10)/H);ribbon.Parent=bg
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.28,0);corner.Parent=ribbon
 local edge=Instance.new('UIStroke');edge.Color=GOLD;edge.Thickness=5;edge.Parent=ribbon
 d.Ribbon=ribbon;d.RibbonEdge=edge
 for _,key in ipairs({'Title','Name','Line','Odds','Footer'})do
  local row=S.Rows[key];local pos,size=box(row)
  local label=Instance.new('TextLabel');label.Name=key;label.BackgroundTransparency=1;label.Position=pos;label.Size=size
  label.Font=Enum.Font.FredokaOne;label.Text='';label.TextColor3=Color3.new(1,1,1);label.TextScaled=true
  label.TextStrokeColor3=RGB(14,12,34);label.TextStrokeTransparency=key=='Footer'and .6 or .25;label.TextWrapped=false;label.ZIndex=2;label.Parent=bg
  local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=row.Max;fit.MinTextSize=8;fit.Parent=label
  d.Labels[key]=label
 end
 d.Gui=gui
end
-- Writes the sign's words (HubDisplayRules.SignText) and the ribbon's colour.
function A.SetSign(d,text)
 if not d or not d.Labels then return end
 for key,label in pairs(d.Labels)do
  local row=text.Rows[key]
  label.Text=row and row.Text or''
  if row and row.Color then label.TextColor3=c3(row.Color)end
 end
 local accent=text.Accent or{255,214,90}
 if d.Ribbon then d.Ribbon.BackgroundColor3=c3(accent):Lerp(RGB(20,18,40),.62)end
 if d.RibbonEdge then d.RibbonEdge.Color=c3(accent)end
 d.Model:SetAttribute('State',text.State or'Empty')
end
-- Colours: the lit parts (podium ring and gems, post gems, plinth glow, crown jewels), the halo and the light wear `accent` ({r,g,b}); an empty display is calm (violet,
-- no halo, light off). stage: the biome whose colours the podium wears (the pulled seed's or the fruit's), nil = the violet default.
function A.Tint(d,accent,state,stage)
 local color=c3(accent or{255,214,90})
 if state=='Empty'then
  PedestalArt.Tint(d.PodiumArt,'Locked',nil)
  for _,p in ipairs(d.Lit)do p.Color=RGB(176,118,255)end
  d.Halo.Transparency=1;d.Light.Enabled=false
  return
 end
 PedestalArt.Tint(d.PodiumArt,'Ready',stage)
 for _,p in ipairs(d.Lit)do p.Color=color;p.Material=Enum.Material.Neon;p.Transparency=0 end
 d.Halo.Color=color;d.Halo.Transparency=.8
 d.Light.Color=color;d.Light.Enabled=true
 d.Model:SetAttribute('Accent',color)
end
-- The giant item ----------------------------------------------------------------------------------------------------------------------------------------
-- Static geometry only (the ItemPictures rule): no scripts, effects, lights, sounds, joints or tags; every part anchored and inert.
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
-- Builds the giant item for a spec and stands it on the podium. spec: {Kind='Seed'|'Fruit', Id=, Coat=, Mystery=, Accent=}. Returns the Model (parented to nothing), and
-- info {Parts=, Dropped=, Source='art'|'gem', Height=}. Never throws.
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
 local dropped=cap(model,Rules.ItemParts)
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
