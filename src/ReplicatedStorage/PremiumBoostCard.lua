-- R62: two large perk cards; existing entitlement and purchase code owns actions.
local RS=game:GetService('ReplicatedStorage')
local Theme=require(RS.GardenTheme);local Bright=require(RS.BrightUI);local Catalog=require(RS.MechCatalog)
local B={};local C=Color3.fromRGB;local Fit=require(RS.GardenTextFit)
local function frame(parent,name,pos,size,color,radius)
 local f=Instance.new('Frame');f.Name=name;f.Position=pos;f.Size=size;f.BackgroundColor3=color;f.BorderSizePixel=0;f.Active=false;f.Parent=parent
 if radius then Theme.Corner(f,radius)end;return f
end
local function text(parent,name,value,pos,size,font,color)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=pos;t.Size=size;t.BackgroundTransparency=1;Bright.Text(t,font,color);Fit.Attach(t,font,math.min(font,16));t.Parent=parent;return t
end
local function purchase(parent,name,value,pos,size,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=value;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.TextSize=21;Bright.Button(b,color);Fit.Attach(b,21,14);b.Parent=parent;return b
end
function B.Create(parent,pass,order)
 local growth=pass.Key=='Growth'
 local card=frame(parent,pass.Key,UDim2.new(),UDim2.fromOffset(440,300),Color3.new(1,1,1),9);card.LayoutOrder=order;card.ClipsDescendants=true
 local fill=Bright.Gradient(card,growth and C(255,211,107)or C(69,215,255),growth and C(166,154,255)or C(53,114,237),25)
 if growth then fill.Color=Bright.Rainbow end
 Bright.Outline(card,C(9,17,33),3)
 -- Bounded stud detail, independent of animated backgrounds and buttons.
 for row=0,5 do for col=0,10 do
  local stud=frame(card,'Stud',UDim2.new(col/10,-4,0,13+row*39),UDim2.fromOffset(7,7),C(255,255,255),1);stud.BackgroundTransparency=.9
 end end
 local stage=frame(card,'IconStage',UDim2.new(0,12,0,59),UDim2.new(.39,-16,0,155),Color3.new(1,1,1),80);stage.BackgroundTransparency=.85
 text(card,'Name',growth and '×2 GROWTH'or'×2 SPEED',UDim2.fromOffset(12,10),UDim2.new(1,-82,0,43),32)
 if growth then
  local holder=frame(stage,'ClockHolder',UDim2.fromScale(.5,.5),UDim2.fromScale(.94,.94),Color3.new(1,1,1));holder.AnchorPoint=Vector2.new(.5,.5);holder.BackgroundTransparency=1
  local ratio=Instance.new('UIAspectRatioConstraint');ratio.AspectRatio=1;ratio.Parent=holder
  local rim=frame(holder,'RainbowClock',UDim2.fromScale(.05,.1),UDim2.fromScale(.9,.9),Color3.new(1,1,1),100);Bright.Outline(rim,C(13,23,35),3)
  local rainbow=Instance.new('UIGradient');rainbow.Color=Bright.Rainbow;rainbow.Rotation=25;rainbow.Parent=rim
  frame(holder,'ClockButton',UDim2.fromScale(.4,0),UDim2.fromScale(.2,.13),C(255,173,77),3)
  local face=frame(rim,'Face',UDim2.fromScale(.1,.1),UDim2.fromScale(.8,.8),C(250,253,255),100)
  for i=0,3 do local a=i*math.pi/2;local mark=frame(face,'Hour',UDim2.fromScale(.5+math.sin(a)*.36,.5-math.cos(a)*.36),UDim2.fromScale(.035,.07),C(104,133,163),2);mark.AnchorPoint=Vector2.new(.5,.5);mark.Rotation=i*90 end
  local hand=frame(face,'Minute',UDim2.fromScale(.475,.21),UDim2.fromScale(.05,.3),C(16,35,61),3)
  frame(face,'HourHand',UDim2.fromScale(.48,.47),UDim2.fromScale(.26,.05),C(16,35,61),3)
  local pin=frame(face,'Pin',UDim2.fromScale(.5,.5),UDim2.fromScale(.095,.095),C(16,35,61),8);pin.AnchorPoint=Vector2.new(.5,.5)
 else
  require(RS.PremiumEmblems).Draw(stage,'Bolt')
 end
 require(RS.GuiShine).Attach(card,true)
 local copy=text(card,'Detail',growth and '×2 growth'or'×2 training',UDim2.new(.4,0,0,65),UDim2.new(.6,-12,0,106),27)
 copy.TextXAlignment=Enum.TextXAlignment.Center
 local badge=frame(card,'Permanent',UDim2.new(.43,0,0,176),UDim2.new(.54,-15,0,27),C(20,36,61),5);badge.BackgroundTransparency=.15
 text(badge,'Caption','PERMANENT',UDim2.new(),UDim2.fromScale(1,1),14,C(229,253,255))
 purchase(card,'GemPerk',Catalog.PassGemPrices[pass.Key]..' Gems',UDim2.new(0,12,1,-71),UDim2.new(.42,-17,0,54),C(155,104,255))
 purchase(card,'RobuxPass','Unavailable',UDim2.new(.42,3,1,-71),UDim2.new(.58,-15,0,54),C(129,246,38))
 local gift=purchase(card,'GiftPass','GIFT',UDim2.new(1,-70,0,10),UDim2.fromOffset(58,37),C(231,89,230));Fit.Attach(gift,16,13)
 return card
end
return B
