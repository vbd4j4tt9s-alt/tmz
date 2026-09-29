-- R103: the shared mechanical rig animates only while its shop card is visible.
local A={}
local RGB=Color3.fromRGB
local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local function visible(view)
 if not view.Parent or view.AbsoluteSize.X<=0 or view.AbsoluteSize.Y<=0 then return false end
 local lo,hi=view.AbsolutePosition,view.AbsolutePosition+view.AbsoluteSize;local node=view
 while node do
  if node:IsA('GuiObject')then
   if not node.Visible then return false end
   if node.ClipsDescendants then
    local p,q=node.AbsolutePosition,node.AbsolutePosition+node.AbsoluteSize
    if hi.X<=p.X or hi.Y<=p.Y or lo.X>=q.X or lo.Y>=q.Y then return false end
   end
  elseif node:IsA('ScreenGui')and not node.Enabled then return false end
  node=node.Parent
 end
 return true
end
local function panel(parent,name,position,size,color)
 local f=Instance.new('Frame');f.Name=name;f.Position=position;f.Size=size;f.BorderSizePixel=0;f.BackgroundColor3=color;f.Active=false;f.Parent=parent;return f
end
function A.DecorateCard(parent)
 local old=parent:FindFirstChild('MechHangarBackground');if old then return old end
 -- Native frames stay sharp on phones and wide screens; no enlarged raster.
 local background=panel(parent,'MechHangarBackground',UDim2.fromScale(0,0),UDim2.fromScale(1,1),RGB(14,30,48));background.ClipsDescendants=true
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=background
 local gradient=Instance.new('UIGradient');gradient.Color=ColorSequence.new(RGB(35,64,86),RGB(11,22,38));gradient.Rotation=90;gradient.Parent=background
 local header=panel(background,'HangarHeader',UDim2.fromOffset(9,16),UDim2.new(1,-18,0,83),RGB(23,43,63));header.BackgroundTransparency=.12
 for _,right in ipairs({false,true})do
  local x=right and 1 or 0;local direction=right and -1 or 1
  local rail=panel(background,'HangarRail',UDim2.new(x,direction*7,0,17),UDim2.new(0,2,1,-34),RGB(69,124,147));rail.AnchorPoint=Vector2.new(right and 1 or 0,0)
  for i=1,3 do
   local seam=panel(header,'HeaderCircuit',UDim2.new(x,direction*12,0,16+i*16),UDim2.new(.14,0,0,2),i==2 and RGB(181,137,62)or RGB(46,102,125));seam.AnchorPoint=Vector2.new(right and 1 or 0,0)
  end
  for i=1,4 do
   local slit=panel(background,'HangarSeam',UDim2.new(x,direction*12,.22+i*.145,0),UDim2.fromOffset(3,18),RGB(39,95,117));slit.AnchorPoint=Vector2.new(right and 1 or 0,0)
  end
 end
 for i=1,5 do
  local warning=panel(background,'HazardTrim',UDim2.new(.5,(i-3)*15,1,-7),UDim2.fromOffset(9,3),i%2==0 and RGB(218,166,78)or RGB(87,164,177));warning.AnchorPoint=Vector2.new(.5,0)
 end
 return background
end
function A.Create(parent)
 local halo=Instance.new('Frame');halo.Name='MechDockingBay';halo.AnchorPoint=Vector2.new(.5,0);halo.Position=UDim2.new(.5,0,0,106);halo.Size=UDim2.new(1,-30,0,169);halo.BackgroundColor3=RGB(24,55,76);halo.BackgroundTransparency=0;halo.BorderSizePixel=0;halo.ClipsDescendants=true;halo.Parent=parent
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=halo
 local stroke=Instance.new('UIStroke');stroke.Color=RGB(71,185,214);stroke.Transparency=.38;stroke.Thickness=1;stroke.Parent=halo
 local gradient=Instance.new('UIGradient');gradient.Rotation=90;gradient.Color=ColorSequence.new(RGB(76,127,151),RGB(30,61,82));gradient.Parent=halo
 local function detail(name,position,size,color)
  local f=Instance.new('Frame');f.Name=name;f.Position=position;f.Size=size;f.BorderSizePixel=0;f.BackgroundColor3=color;f.BackgroundTransparency=.2;f.Parent=halo;return f
 end
 for _,right in ipairs({false,true})do
  local x,offset=right and 1 or 0,right and -13 or 13
  local rib=detail('DockRib',UDim2.new(x,right and -28 or 28,0,34),UDim2.new(.12,0,1,-68),RGB(10,34,52));rib.AnchorPoint=Vector2.new(right and 1 or 0,0);rib.BackgroundTransparency=.38
  for i=1,3 do
   local line=detail('DockVent',UDim2.new(x,right and -36 or 36,0,55+i*15),UDim2.new(.055,0,0,2),RGB(84,160,183));line.AnchorPoint=Vector2.new(right and 1 or 0,0)
  end
  for _,bottom in ipairs({false,true})do
   local y,dy=bottom and 1 or 0,bottom and -13 or 13
   local h=detail('DockBracket',UDim2.new(x,offset,y,dy),UDim2.fromOffset(20,2),RGB(119,236,249));h.AnchorPoint=Vector2.new(right and 1 or 0,bottom and 1 or 0)
   local v=detail('DockBracket',UDim2.new(x,offset,y,dy),UDim2.fromOffset(2,13),RGB(119,236,249));v.AnchorPoint=h.AnchorPoint
  end
 end
 for i=1,3 do detail('DockStatus'..i,UDim2.new(0,22+(i-1)*11,1,-24),UDim2.fromOffset(6,3),i==3 and RGB(255,188,76)or RGB(74,213,235))end
 local view=Instance.new('ViewportFrame');view.Name='MechPackPreview';view.BackgroundTransparency=1
 view.AnchorPoint=Vector2.new(.5,0);view.Position=UDim2.new(.5,0,0,108);view.Size=UDim2.new(1,-32,0,166)
 view.Ambient=RGB(255,255,255);view.LightColor=Color3.new(1,1,1);view.LightDirection=Vector3.new(-.4,-.5,1);view.Parent=parent
 local world=Instance.new('WorldModel');world.Parent=view
 local visuals=require(script.Parent.SeedPackVisuals);local b=visuals.Bounds(8,'MechLimited',1)
 local bag=visuals.Bag(CFrame.Angles(0,.22,-.025),world,1,nil,8,'MechLimited',1,1,'None')
 game:GetService('CollectionService'):RemoveTag(bag,'BiomeSeedPackVisual');bag:SetAttribute('WorldPack',false)
 -- Viewports lack environment reflections. Keep the shared colours and geometry,
 -- using matte metal only in this preview so the small seal trim stays readable.
 for _,part in ipairs(bag:GetDescendants())do if part:IsA('BasePart')then
  part.CastShadow=false
  if part.Material==Enum.Material.Metal then part.Material=Enum.Material.SmoothPlastic end
 end end
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.Parent=view;view.CurrentCamera=camera
 local target=Vector3.new(0,(b.MinY+b.MaxY)/2,0)
 camera.CFrame=CFrame.lookAt(target+Vector3.new(0,.06,-math.max(b.MaxY-b.MinY,b.Radius*2)*1.95),target)
 if Run:IsClient()then
  local motion=require(script.Parent.SpecialPackArt89).CaptureMotion(bag)
  local clock=0;local connection;local destroyed
  connection=Run.RenderStepped:Connect(function(dt)
   clock+=dt
   local player=game:GetService('Players').LocalPlayer
   if clock<(player and player:GetAttribute('FastMode')and 1/15 or 1/30)then return end
   clock=0
   if visible(view)then motion:Step(Gui.ReducedMotionEnabled and 0 or workspace:GetServerTimeNow(),bag.PrimaryPart.CFrame)end
  end)
  destroyed=view.Destroying:Connect(function()
   connection:Disconnect();destroyed:Disconnect();motion:Reset()
  end)
 end
 return view
end
return A
