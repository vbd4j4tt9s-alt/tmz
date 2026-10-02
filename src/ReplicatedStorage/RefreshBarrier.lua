-- R69: one opaque collision wall, with reusable local moon/sign presentation.
-- R112: flat white night wall: outlined crescent moon + clouds and a huge "10s" countdown, drawn with
-- rounded Frames only (no uploaded images). Collision part, size and placement are unchanged.
-- R122: the wall is only the track's size (field + side walls, 188 wide; 53 tall, just above the 48-stud
-- track walls and the TrackBlackout roof at Y 55) instead of 140 tall. The hand-drawn moon + cloud is
-- replaced by the HUD's own HudArtwork 'Moon' (same image as the refresh timer), attached on the client.
-- R124: the moon + count are one group re-centred for every number (it sat left of centre), with a "REFRESHING"
-- caption whose three dots loop . .. ... on the client; a soft inset border and faint stars dress the white wall.
local B={}
B.Ink=Color3.fromRGB(70,72,79);B.Outline=Color3.new(0,0,0);B.Paper=Color3.fromRGB(242,242,242)
B.Soft=Color3.fromRGB(205,208,216);B.CaptionColor=Color3.fromRGB(112,116,128)
B.PixelsPerStud=8;B.SignHeight=.52 -- sign centre, as a fraction of the wall height from the bottom
B.SideMargin=4;B.Height=53 -- side walls reach ±94 on a 180 field; bottom stays at line.Y-1 (top ~Y 56)
B.SignSize=Vector2.new(860,320);B.MoonSize=230;B.CountScale=2.4;B.Gap=26;B.RowHeight=240
B.Caption='REFRESHING';B.CaptionSize=50;B.DotSize=16;B.DotGap=12;B.DotPeriod=.4
function B.Format(seconds)return tostring(math.max(0,math.ceil(tonumber(seconds)or 0)))..'s'end
local function textWidth(text,size)
 local ok,v=pcall(function()return game:GetService('TextService'):GetTextSize(text,size,Enum.Font.FredokaOne,Vector2.new(4000,400))end)
 return ok and typeof(v)=='Vector2'and v.X or #text*size*.56
end
-- Moon + count as one group, centred in the sign for the count's current text.
function B.Center(sign)
 local count=sign:FindFirstChild('Count');local moon=sign:FindFirstChild('MoonIcon');if not count or not moon then return end
 local w=textWidth(count.Text,100)*B.CountScale
 local left=math.floor((B.SignSize.X-(B.MoonSize+B.Gap+w))/2)
 moon.Position=UDim2.fromOffset(left,(B.RowHeight-B.MoonSize)/2)
 count.Position=UDim2.fromOffset(left+B.MoonSize+B.Gap,B.RowHeight/2)
 count.Size=UDim2.fromOffset(math.ceil(w/B.CountScale)+8,math.floor(B.RowHeight/B.CountScale))
end
-- The caption's dots: n = 0..3 lit (a full cycle every 4 * DotPeriod seconds).
function B.Dots(sign,now)
 local lit=math.floor((tonumber(now)or 0)/B.DotPeriod)%4
 for i=1,3 do local d=sign:FindFirstChild('Dot'..i);if d then local t=i<=lit and 0 or .85;if d.BackgroundTransparency~=t then d.BackgroundTransparency=t end end end
 return lit
end
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
  -- Soft inset border and a few faint four-point stars (static frames).
  local border=frame('InsetBorder',panel,18,18,canvas.X-36,canvas.Y-36);local bc=Instance.new('UICorner');bc.CornerRadius=UDim.new(0,36);bc.Parent=border
  local bs=Instance.new('UIStroke');bs.Color=B.Soft;bs.Thickness=6;bs.Parent=border
  for i,c in ipairs({{.08,.22,22},{.15,.72,14},{.27,.12,12},{.73,.14,14},{.86,.3,22},{.92,.7,14},{.8,.82,10},{.2,.86,10}})do
   local star=frame('Star'..i,panel,0,0,c[3],c[3],B.Soft);star.AnchorPoint=Vector2.new(.5,.5);star.Position=UDim2.fromScale(c[1],c[2]);star.Rotation=45
  end
  local sign=frame('Sign',panel,0,0,B.SignSize.X,B.SignSize.Y);sign.AnchorPoint=Vector2.new(.5,.5);sign.Position=UDim2.fromScale(.5,1-B.SignHeight)
  -- Empty slot; Decorate (client) fills it with HudArtwork 'Moon'. Generated images do not replicate.
  frame('MoonIcon',sign,0,(B.RowHeight-B.MoonSize)/2,B.MoonSize,B.MoonSize)
  local count=Instance.new('TextLabel');count.Name='Count';count.AnchorPoint=Vector2.new(0,.5);count.BackgroundTransparency=1;count.Font=Enum.Font.FredokaOne
  count.Text=B.Format(10);count.TextSize=100;count.TextColor3=B.Ink;count.TextStrokeTransparency=1;count.TextXAlignment=Enum.TextXAlignment.Left;count.Parent=sign
  local grow=Instance.new('UIScale');grow.Scale=B.CountScale;grow.Parent=count -- TextSize caps at 100 px
  local edge=Instance.new('UIStroke');edge.Color=B.Outline;edge.Thickness=5;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;edge.Parent=count
  -- Caption row: "REFRESHING" + three looping dots, centred under the moon + count.
  local captionW=textWidth(B.Caption,B.CaptionSize);local dotsW=3*B.DotSize+2*B.DotGap
  local rowLeft=math.floor((B.SignSize.X-(captionW+14+dotsW))/2);local rowY=B.RowHeight+(B.SignSize.Y-B.RowHeight)/2
  local caption=Instance.new('TextLabel');caption.Name='Caption';caption.AnchorPoint=Vector2.new(0,.5);caption.Position=UDim2.fromOffset(rowLeft,rowY)
  caption.Size=UDim2.fromOffset(math.ceil(captionW)+4,B.CaptionSize+10);caption.BackgroundTransparency=1;caption.Font=Enum.Font.FredokaOne;caption.Text=B.Caption
  caption.TextSize=B.CaptionSize;caption.TextColor3=B.CaptionColor;caption.TextXAlignment=Enum.TextXAlignment.Left;caption.Parent=sign
  for i=1,3 do
   local dot=frame('Dot'..i,sign,rowLeft+captionW+14+(i-1)*(B.DotSize+B.DotGap),rowY+B.CaptionSize*.22,B.DotSize,B.DotSize,B.CaptionColor,true)
   dot.AnchorPoint=Vector2.new(0,.5);dot.BackgroundTransparency=i==1 and 0 or .85
  end
  B.Center(sign)
  -- MapService writes plain seconds into .Text; route that through the shared "Ns" format.
  labels[#labels+1]=setmetatable({},{__index=function(_,key)return count[key]end,__newindex=function(_,key,value)
   if key=='Text'then value=B.Format(value)end;count[key]=value
   if key=='Text'then B.Center(sign)end
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
 return function(now,remaining)
  local text=B.Format(remaining)
  for _,label in ipairs(labels)do if label.Parent then
   if label.Text~=text then label.Text=text;B.Center(label.Parent)end
   B.Dots(label.Parent,now)
  end end
 end
end
return B
