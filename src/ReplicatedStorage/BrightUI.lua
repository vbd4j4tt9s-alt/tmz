-- R59: shared chromatic menu treatment. Animation belongs to the bounded card scheduler.
local Theme=require(script.Parent.GardenTheme)
local B={}
local RGB=Color3.fromRGB
local function corner(root,radius)local c=root:FindFirstChildOfClass('UICorner')or Instance.new('UICorner');c.CornerRadius=UDim.new(0,radius);c.Parent=root end
B.Rainbow=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(80,230,255)),ColorSequenceKeypoint.new(.25,RGB(161,112,255)),ColorSequenceKeypoint.new(.5,RGB(255,102,217)),ColorSequenceKeypoint.new(.75,RGB(255,216,71)),ColorSequenceKeypoint.new(1,RGB(109,255,123))})
function B.Gradient(root,a,b,angle)
 local g=root:FindFirstChild('BrightFill')or Instance.new('UIGradient');g.Name='BrightFill';g.Color=ColorSequence.new(a,b);g.Rotation=angle or 90;g.Parent=root;return g
end
function B.Outline(root,color,width)
 local s=root:FindFirstChild('BrightOutline')or Instance.new('UIStroke');s.Name='BrightOutline';s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color or RGB(12,17,38);s.Thickness=width or 3;s.Parent=root;return s
end
function B.Text(label,size,color)
 Theme.Text(label,size,true,color or Color3.new(1,1,1));label.TextStrokeColor3=RGB(8,13,24);label.TextStrokeTransparency=.08;return label
end
function B.Panel(root)
 root.BackgroundColor3=Color3.new(1,1,1);B.Gradient(root,RGB(65,76,143),RGB(25,30,64));B.Outline(root,nil,3);corner(root,9)
end
function B.Header(root)
 root.BackgroundColor3=Color3.new(1,1,1);B.Gradient(root,RGB(184,255,111),RGB(64,201,75),25);B.Outline(root,RGB(18,50,31),2)
end
-- R123: pass a rarity to give the card that rarity's own border (GardenCardMotion.Rarity) instead of a flat outline.
function B.Card(root,accent,limited,rarity)
 root.BackgroundColor3=Color3.new(1,1,1);B.Gradient(root,accent:Lerp(RGB(18,30,74),.6),RGB(26,35,76),40);corner(root,8)
 if limited then require(script.Parent.GardenCardMotion).Limited(root)
 elseif rarity then local old=root:FindFirstChild('BrightOutline');if old then old:Destroy()end;Theme.CardBorder(root,rarity)
 else B.Outline(root,accent,2)end
end
function B.Button(root,color)
 root.BackgroundColor3=Color3.new(1,1,1);B.Gradient(root,color:Lerp(Color3.new(1,1,1),.24),color:Lerp(Color3.new(),.12),90);B.Outline(root,nil,2);corner(root,6)
 local font=math.max(root:GetAttribute('BrightFontSize')or 0,root.TextSize or 18);root:SetAttribute('BrightFontSize',font);B.Text(root,font)
 -- A gradient on a TextButton also tints its letters. Draw the caption separately
 -- so white lettering stays readable over every purchase-button color.
 if not root:FindFirstChild('BrightCaption')then
  local caption=Instance.new('TextLabel');caption.Name='BrightCaption';caption.BackgroundTransparency=1;caption.Size=UDim2.fromScale(1,1);caption.Active=false;caption.Parent=root
  local keys={'Text','TextSize','Font','TextColor3','TextStrokeColor3','TextStrokeTransparency','TextWrapped','TextScaled','TextXAlignment','TextYAlignment','RichText'}
  local function sync()
   for _,key in ipairs(keys)do caption[key]=root[key]end
   caption.ZIndex=(root.ZIndex or 1)+4;caption.Visible=root.Text~=''
  end
  for _,key in ipairs(keys)do root:GetPropertyChangedSignal(key):Connect(sync)end
  root:GetPropertyChangedSignal('ZIndex'):Connect(sync);sync()
 end
 root.TextTransparency=1
 if root.Name~='Shade'and root.Name~='Backdrop'then
  if not root:FindFirstChild('GlassHighlight')then
   local glass=Instance.new('Frame');glass.Name='GlassHighlight';glass.Position=UDim2.fromOffset(3,3);glass.Size=UDim2.new(1,-6,.46,-3);glass.BorderSizePixel=0;glass.BackgroundColor3=Color3.new(1,1,1);glass.BackgroundTransparency=.86;glass.Active=false;glass.ZIndex=(root.ZIndex or 1)+1;glass.Parent=root;Theme.Corner(glass,5)
   local fade=Instance.new('UIGradient');fade.Rotation=90;fade.Transparency=NumberSequence.new(0,1);fade.Parent=glass
   local trim=Instance.new('Frame');trim.Name='InsetRim';trim.BackgroundTransparency=1;trim.Position=UDim2.fromOffset(2,2);trim.Size=UDim2.new(1,-4,1,-4);trim.Active=false;trim.ZIndex=glass.ZIndex;trim.Parent=root;Theme.Corner(trim,5)
   local edge=Instance.new('UIStroke');edge.Color=Color3.new(1,1,1);edge.Thickness=1;edge.Transparency=.45;edge.Parent=trim
  end
  require(script.Parent.GuiShine).Attach(root)
 end
end
return B
