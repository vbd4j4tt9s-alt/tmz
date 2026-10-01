-- R69: one opaque collision wall, with reusable local moon/sign presentation.
-- R112: flat white night wall: outlined crescent moon + clouds and a huge "10s" countdown, drawn with
-- rounded Frames only (no uploaded images). Collision part, size and placement are unchanged.
-- R122: the wall is only the track's size (field + side walls, 188 wide; 53 tall, just above the 48-stud
-- track walls and the TrackBlackout roof at Y 55) instead of 140 tall. The hand-drawn moon + cloud is
-- replaced by the HUD's own HudArtwork 'Moon' (same image as the refresh timer), attached on the client.
local B={}
B.Ink=Color3.fromRGB(70,72,79);B.Outline=Color3.new(0,0,0);B.Paper=Color3.fromRGB(242,242,242)
B.PixelsPerStud=8;B.SignHeight=.52 -- sign centre, as a fraction of the wall height from the bottom
B.SideMargin=4;B.Height=53 -- side walls reach ±94 on a 180 field; bottom stays at line.Y-1 (top ~Y 56)
B.SignSize=Vector2.new(860,320);B.MoonSize=300;B.CountScale=2.8
function B.Format(seconds)return tostring(math.max(0,math.ceil(tonumber(seconds)or 0)))..'s'end
local function frame(name,parent,x,y,w,h,color,round)
 local f=Instance.new('Frame');f.Name=name;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h)
 f.BackgroundColor3=color or Color3.new();f.BackgroundTransparency=color and 0 or 1;f.BorderSizePixel=0;f.Parent=parent
 if round then local c=Instance.new('UICorner');c.CornerRadius=UDim.new(.5,0);c.Parent=f end
 return f
end
function B.Build(line,startZ,parent)
 local wall=Instance.new('Part');wall.Name='BiomeRefreshWall';wall.Size=Vector3.new(math.max(180,line.Size.X)+2*B.SideMargin,B.Height,4)
 wall.CFrame=CFrame.new(line.Position.X,line.Position.Y-1+B.Height/2,math.min(startZ,line.Position.Z))
 wall.Anchored=true;wall.CanCollide=true;wall.CanTouch=false;wall.CanQuery=true;wall.CastShadow=false
 wall.Color=B.Paper;wall.Material=Enum.Material.SmoothPlastic;wall.TopSurface=Enum.SurfaceType.Smooth;wall.BottomSurface=Enum.SurfaceType.Smooth;wall:SetAttribute('BiomeRefreshBarrier',true)
 local canvas=Vector2.new(math.floor(wall.Size.X*B.PixelsPerStud),math.floor(wall.Size.Y*B.PixelsPerStud))
 local labels={}
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
  local gui=Instance.new('SurfaceGui');gui.Name='RefreshingSign';gui.Face=face;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
  gui.CanvasSize=canvas;gui.LightInfluence=0;gui.Brightness=1;gui.Parent=wall
  -- Unlit full-face paper: the wall reads flat white under the black refresh sky.
  local panel=frame('NightSign',gui,0,0,canvas.X,canvas.Y,B.Paper)
  local sign=frame('Sign',panel,0,0,B.SignSize.X,B.SignSize.Y);sign.AnchorPoint=Vector2.new(.5,.5);sign.Position=UDim2.fromScale(.5,1-B.SignHeight)
  -- Empty slot; Decorate (client) fills it with HudArtwork 'Moon'. Generated images do not replicate.
  frame('MoonIcon',sign,0,(B.SignSize.Y-B.MoonSize)/2,B.MoonSize,B.MoonSize)
  local scale=B.CountScale;local left=B.MoonSize+30
  local count=Instance.new('TextLabel');count.Name='Count';count.AnchorPoint=Vector2.new(0,.5);count.Position=UDim2.fromOffset(left,B.SignSize.Y/2)
  count.Size=UDim2.fromOffset(math.floor((B.SignSize.X-left)/scale),math.floor(B.SignSize.Y/scale));count.BackgroundTransparency=1;count.Font=Enum.Font.FredokaOne
  count.Text=B.Format(10);count.TextSize=100;count.TextColor3=B.Ink;count.TextStrokeTransparency=1;count.TextXAlignment=Enum.TextXAlignment.Left;count.Parent=sign
  local grow=Instance.new('UIScale');grow.Scale=scale;grow.Parent=count -- TextSize caps at 100 px
  local edge=Instance.new('UIStroke');edge.Color=B.Outline;edge.Thickness=5;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;edge.Parent=count
  -- MapService writes plain seconds into .Text; route that through the shared "Ns" format.
  labels[#labels+1]=setmetatable({},{__index=function(_,key)return count[key]end,__newindex=function(_,key,value)
   if key=='Text'then value=B.Format(value)end;count[key]=value
  end})
 end
 wall.Parent=parent;return wall,labels
end
function B.Decorate(wall)
 local labels={}
 for _,gui in ipairs(wall:GetChildren())do if gui:IsA('SurfaceGui')then
  local panel=gui:FindFirstChild('NightSign');local sign=panel and panel:FindFirstChild('Sign')
  local count=sign and sign:FindFirstChild('Count');local moon=sign and sign:FindFirstChild('MoonIcon')
  if not count or not moon then return nil end
  if not moon:FindFirstChild('GeneratedMoon')then require(script.Parent.HudArtwork).Attach(moon,'Moon')end
  labels[#labels+1]=count
 end end
 if #labels<2 then return nil end
 return function(_,remaining)
  local text=B.Format(remaining)
  for _,label in ipairs(labels)do if label.Parent and label.Text~=text then label.Text=text end end
 end
end
return B
