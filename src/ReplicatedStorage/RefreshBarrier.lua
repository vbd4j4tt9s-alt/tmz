-- R69: one opaque collision wall, with reusable local moon/sign presentation.
local B={}
function B.Build(line,startZ,parent)
 local wall=Instance.new('Part');wall.Name='BiomeRefreshWall';wall.Size=Vector3.new(math.max(180,line.Size.X)+4,140,4)
 wall.CFrame=CFrame.new(line.Position.X,line.Position.Y+69,math.min(startZ,line.Position.Z))
 wall.Anchored=true;wall.CanCollide=true;wall.CanTouch=false;wall.CanQuery=true;wall.CastShadow=false
 wall.Color=Color3.fromRGB(15,25,40);wall.Material=Enum.Material.SmoothPlastic;wall.TopSurface=Enum.SurfaceType.Smooth;wall.BottomSurface=Enum.SurfaceType.Smooth;wall:SetAttribute('BiomeRefreshBarrier',true)
 local function trim(name,x,y,size,color)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=wall.CFrame*CFrame.new(x,y,0);p.Color=color;p.Material=Enum.Material.SmoothPlastic
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=wall
 end
 local width=wall.Size.X
 for i=-2,2 do trim('Midnight panel seam',i*width/5,0,Vector3.new(.45,139,4.08),Color3.fromRGB(24,43,61))end
 for _,side in ipairs({-1,1})do trim('Timber gate post',side*(width/2-.7),0,Vector3.new(1.5,140,4.7),Color3.fromRGB(85,65,50))end
 for _,y in ipairs({-69,-51,69})do trim('Warm gate trim',0,y,Vector3.new(width,.25,4.4),Color3.fromRGB(182,149,92))end
 local labels={}
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
  local gui=Instance.new('SurfaceGui');gui.Name='RefreshingSign';gui.Face=face;gui.CanvasSize=Vector2.new(1800,1400);gui.LightInfluence=0;gui.Parent=wall
  local panel=Instance.new('Frame');panel.Name='NightSign';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(1480,350);panel.BackgroundColor3=Color3.fromRGB(25,45,66);panel.BorderSizePixel=0;panel.Parent=gui
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,20);corner.Parent=panel
  local rim=Instance.new('UIStroke');rim.Color=Color3.fromRGB(244,219,149);rim.Thickness=3;rim.Transparency=.15;rim.Parent=panel
  local moon=Instance.new('Frame');moon.Name='MoonSlot';moon.Position=UDim2.fromOffset(45,52);moon.Size=UDim2.fromOffset(230,230);moon.BackgroundTransparency=1;moon.Parent=panel
  local function text(name,value,x,w,size,color)
   local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=UDim2.fromOffset(x,68);t.Size=UDim2.fromOffset(w,180);t.BackgroundTransparency=1;t.Font=Enum.Font.FredokaOne;t.TextSize=size;t.TextColor3=color;t.TextStrokeTransparency=.7;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=panel;return t
  end
  text('Title','Refreshing',310,765,115,Color3.fromRGB(247,242,224))
  text('Dots','.',1070,175,115,Color3.fromRGB(248,220,130))
  local label=text('Refreshing','10',1240,190,125,Color3.fromRGB(183,236,247));label.TextXAlignment=Enum.TextXAlignment.Center;labels[#labels+1]=label
  local rail=Instance.new('Frame');rail.Name='Rail';rail.Position=UDim2.fromOffset(315,282);rail.Size=UDim2.fromOffset(1095,12);rail.BackgroundColor3=Color3.fromRGB(15,30,49);rail.BorderSizePixel=0;rail.Parent=panel
  local fill=Instance.new('Frame');fill.Name='Fill';fill.Size=UDim2.fromScale(1,1);fill.BackgroundColor3=Color3.fromRGB(240,211,137);fill.BorderSizePixel=0;fill.Parent=rail
 end
 wall.Parent=parent;return wall,labels
end
function B.Decorate(wall)
 local panels={}
 for _,gui in ipairs(wall:GetChildren())do if gui:IsA('SurfaceGui')then
  local panel=gui:FindFirstChild('NightSign')
  if panel then
   local moon=panel:FindFirstChild('MoonSlot');local rail=panel:FindFirstChild('Rail')
   if not moon or not rail or not rail:FindFirstChild('Fill')or not panel:FindFirstChild('Dots')or not panel:FindFirstChild('Refreshing')then return nil end
   if not moon:FindFirstChild('GeneratedMoon')then require(script.Parent.HudArtwork).Attach(moon,'Moon')end
   panels[#panels+1]=panel
  end
 end end
 if #panels<2 then return nil end
 return function(now,remaining)
  local dots=string.rep('.',math.floor(now*2.5)%3+1);local seconds=tostring(math.max(0,math.ceil(remaining)));local fraction=math.clamp(remaining/10,0,1)
  for _,panel in ipairs(panels)do if panel.Parent then
   if panel.Dots.Text~=dots then panel.Dots.Text=dots end
   if panel.Refreshing.Text~=seconds then panel.Refreshing.Text=seconds end
   panel.Rail.Fill.Size=UDim2.fromScale(fraction,1)
  end end
 end
end
return B
