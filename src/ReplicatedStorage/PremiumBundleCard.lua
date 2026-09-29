local RS=game:GetService('ReplicatedStorage');local Bright=require(RS.BrightUI);local Theme=require(RS.GardenTheme);local Fit=require(RS.GardenTextFit)
local B={}
local function text(parent,name,value,pos,size,font)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=pos;t.Size=size;t.BackgroundTransparency=1;t.TextWrapped=false;t.TextXAlignment=Enum.TextXAlignment.Center;Bright.Text(t,font);Fit.Attach(t,font,15);t.Parent=parent;return t
end
local function button(parent,name,caption,pos,size,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=caption;b.Position=pos;b.Size=size;b.TextSize=19;b.BorderSizePixel=0;Bright.Button(b,color);Fit.Attach(b,19,13);b.Parent=parent;return b
end
function B.Create(parent,row,index)
 local cash=row.Kind=='Cash';local c=Instance.new('Frame');c.Name=row.Key..'Bundle';c.BorderSizePixel=0;c.ClipsDescendants=true;c.Parent=parent
 Bright.Card(c,cash and Color3.fromRGB(74,245,124)or Color3.fromRGB(97,225,255),false)
 Bright.Gradient(c,cash and Color3.fromRGB(35,177,81)or Color3.fromRGB(33,196,245),cash and Color3.fromRGB(15,85,58)or Color3.fromRGB(40,80,198),30)
 if cash then text(c,'Tier',row.Tier:upper(),UDim2.fromOffset(10,7),UDim2.new(1,-20,0,28),22)end
 local stage=Instance.new('Frame');stage.Name='BundleArtwork';stage.AnchorPoint=Vector2.new(.5,0);stage.Position=UDim2.new(.5,0,0,cash and 37 or 43);stage.Size=UDim2.fromOffset(154,cash and 118 or 108);stage.BackgroundTransparency=1;stage.Parent=c
 local count=index<=2 and 1 or index<=4 and 2 or 3
 for i=1,count do
  local icon=Instance.new('Frame');icon.Name='Icon'..i;icon.BackgroundTransparency=1;icon.Size=UDim2.fromScale(count==1 and 1 or .79,count==1 and 1 or .88)
  icon.Position=UDim2.fromScale(count==1 and 0 or(i-1)*.13,count==1 and 0 or(i-1)*.055);icon.Rotation=count==1 and 0 or(i-2)*8;icon.Parent=stage
  require(RS.PremiumEmblems).Draw(icon,row.Emblem)
 end
 text(c,'Amount',cash and row.Name or require(RS.CashNumbers).Compact(row.Amount),cash and UDim2.fromOffset(8,156)or UDim2.fromOffset(8,2),UDim2.new(1,-16,0,40),29)
 button(c,'GemBundle',row.GemPrice..' Gems',UDim2.new(0,10,1,cash and -75 or -106),UDim2.new(1,-20,0,cash and 29 or 44),Color3.fromRGB(164,103,251))
 button(c,'RobuxBundle','Unavailable',UDim2.new(0,10,1,cash and -41 or -56),UDim2.new(1,-20,0,cash and 32 or 44),Color3.fromRGB(146,244,39))
 require(RS.GuiShine).Attach(c,false);return c
end
return B
