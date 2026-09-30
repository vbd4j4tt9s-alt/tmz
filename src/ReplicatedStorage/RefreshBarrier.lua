-- R69: one opaque collision wall, with reusable local moon/sign presentation.
-- R112: flat white night wall: outlined crescent moon + clouds and a huge "10s" countdown, drawn with
-- rounded Frames only (no uploaded images). Collision part, size and placement are unchanged.
local B={}
B.Ink=Color3.fromRGB(70,72,79);B.Outline=Color3.new(0,0,0);B.Paper=Color3.fromRGB(242,242,242)
B.PixelsPerStud=5;B.SignHeight=.40 -- sign centre, as a fraction of the wall height from the bottom
function B.Format(seconds)return tostring(math.max(0,math.ceil(tonumber(seconds)or 0)))..'s'end
local function frame(name,parent,x,y,w,h,color,round)
 local f=Instance.new('Frame');f.Name=name;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h)
 f.BackgroundColor3=color or Color3.new();f.BackgroundTransparency=color and 0 or 1;f.BorderSizePixel=0;f.Parent=parent
 if round then local c=Instance.new('UICorner');c.CornerRadius=round==true and UDim.new(.5,0)or UDim.new(0,round);c.Parent=f end
 return f
end
local function stroke(parent,thickness)
 local s=Instance.new('UIStroke');s.Color=B.Outline;s.Thickness=thickness;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=parent
end
-- 280 x 280 icon. The crescent is disc A minus disc B; clipping at their radical line (x0) keeps
-- only the outline arcs that belong to the crescent, so no stray ring shows outside the moon.
local function icon(parent,x,y)
 local box=frame('MoonIcon',parent,x,y,280,280)
 local T,rA,rB,d=12,100,85,80
 local x0=(d*d+rA*rA-rB*rB)/(2*d)
 local clip=frame('Crescent',box,0,0,T+rA+math.floor(x0),2*(rA+T));clip.ClipsDescendants=true
 local disc=frame('Moon',clip,T,T,2*rA,2*rA,B.Ink,true);stroke(disc,T)
 local bite=frame('Bite',clip,T+d,T+rA-rB,2*rB,2*rB,B.Paper,true);stroke(bite,T);bite.ZIndex=2
 -- Cloud: black silhouettes grown by T first, grey fills on top, so only the union's edge is outlined.
 local shapes={{95,178,180,68,true},{112,128,92,92,true},{160,100,112,112,true},{214,146,72,72,true}}
 for layer,grow in ipairs({T,0})do
  for _,s in ipairs(shapes)do
   local f=frame(layer==1 and'CloudEdge'or'Cloud',box,s[1]-grow,s[2]-grow,s[3]+2*grow,s[4]+2*grow,layer==1 and B.Outline or B.Ink,true)
   f.ZIndex=2+layer
  end
 end
 return box
end
function B.Build(line,startZ,parent)
 local wall=Instance.new('Part');wall.Name='BiomeRefreshWall';wall.Size=Vector3.new(math.max(180,line.Size.X)+4,140,4)
 wall.CFrame=CFrame.new(line.Position.X,line.Position.Y+69,math.min(startZ,line.Position.Z))
 wall.Anchored=true;wall.CanCollide=true;wall.CanTouch=false;wall.CanQuery=true;wall.CastShadow=false
 wall.Color=B.Paper;wall.Material=Enum.Material.SmoothPlastic;wall.TopSurface=Enum.SurfaceType.Smooth;wall.BottomSurface=Enum.SurfaceType.Smooth;wall:SetAttribute('BiomeRefreshBarrier',true)
 local canvas=Vector2.new(math.floor(wall.Size.X*B.PixelsPerStud),math.floor(wall.Size.Y*B.PixelsPerStud))
 local labels={}
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
  local gui=Instance.new('SurfaceGui');gui.Name='RefreshingSign';gui.Face=face;gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
  gui.CanvasSize=canvas;gui.LightInfluence=0;gui.Brightness=1;gui.Parent=wall
  -- Unlit full-face paper: the wall reads flat white under the black refresh sky.
  local panel=frame('NightSign',gui,0,0,canvas.X,canvas.Y,B.Paper)
  local sign=frame('Sign',panel,0,0,730,300);sign.AnchorPoint=Vector2.new(.5,.5);sign.Position=UDim2.fromScale(.5,1-B.SignHeight)
  icon(sign,0,10)
  local scale=2.6
  local count=Instance.new('TextLabel');count.Name='Count';count.AnchorPoint=Vector2.new(0,.5);count.Position=UDim2.fromOffset(310,150)
  count.Size=UDim2.fromOffset(math.floor(420/scale),math.floor(300/scale));count.BackgroundTransparency=1;count.Font=Enum.Font.FredokaOne
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
  local count=sign and sign:FindFirstChild('Count')
  if not count or not sign:FindFirstChild('MoonIcon')then return nil end
  labels[#labels+1]=count
 end end
 if #labels<2 then return nil end
 return function(_,remaining)
  local text=B.Format(remaining)
  for _,label in ipairs(labels)do if label.Parent and label.Text~=text then label.Text=text end end
 end
end
return B
