-- R120: shop chrome built from native frames only (no image ids): outlined text, light rays,
-- studded / "L" textures, glossy stripes, Robux and gift glyphs, price buttons and pass emblems.
local RS=game:GetService('ReplicatedStorage');local TextService=game:GetService('TextService')
local Bright=require(RS.BrightUI);local Theme=require(RS.GardenTheme)
local A={};local C=Color3.fromRGB
A.Ink=C(12,14,22)
A.Colors={Gift=C(203,74,236),Gem=C(155,104,255),Robux=C(96,224,40),Owned=C(255,196,52),Off=C(110,118,140),Close=C(226,30,38),Header=C(84,230,58)}
function A.Frame(parent,name,color,transparency)
 local f=Instance.new('Frame');f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=color or Color3.new(1,1,1);f.BackgroundTransparency=transparency or 0;f.Active=false;f.Parent=parent;return f
end
function A.Corner(root,radius)
 local c=root:FindFirstChildOfClass('UICorner')or Instance.new('UICorner');c.CornerRadius=typeof(radius)=='UDim'and radius or UDim.new(0,radius or 8);c.Parent=root;return c
end
function A.Stroke(root,color,thickness,name)
 local s=root:FindFirstChild(name or'Border')or Instance.new('UIStroke');s.Name=name or'Border';s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color or A.Ink;s.Thickness=thickness or 3;s.Parent=root;return s
end
function A.Gradient(root,colors,rotation)
 local g=root:FindFirstChild('Fill')or Instance.new('UIGradient');g.Name='Fill'
 if typeof(colors)=='ColorSequence'then g.Color=colors
 else local keys={};for i,c in ipairs(colors)do keys[i]=ColorSequenceKeypoint.new((i-1)/math.max(1,#colors-1),c)end;g.Color=ColorSequence.new(keys)end
 g.Rotation=rotation or 90;g.Parent=root;return g
end
-- Bold white lettering with a thick dark outline, like the reference shop.
function A.Text(parent,name,text,size,color,outline)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=text;t.BackgroundTransparency=1;t.TextWrapped=false
 Theme.Text(t,size,true,color or Color3.new(1,1,1));t.TextStrokeTransparency=1;t.TextXAlignment=Enum.TextXAlignment.Center
 local s=Instance.new('UIStroke');s.Name='Outline';s.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;s.Color=A.Ink;s.Thickness=outline or math.max(1.5,size/10);s.LineJoinMode=Enum.LineJoinMode.Round;s.Parent=t
 t.Active=false;t.Parent=parent;return t
end
function A.SetTextSize(label,size,minimum)
 label.TextSize=size;require(RS.GardenTextFit).Attach(label,size,math.min(size,minimum or 10));local s=label:FindFirstChild('Outline');if s then s.Thickness=math.max(1.5,size/10)end
end
-- Static radial light rays (no per-frame work).
function A.Rays(parent,count,transparency)
 local root=A.Frame(parent,'LightRays',nil,1);root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.42);root.Size=UDim2.fromScale(1.6,1.6)
 local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.Parent=root
 for i=0,(count or 8)-1 do
  local ray=A.Frame(root,'Ray',Color3.new(1,1,1),transparency or .8);ray.AnchorPoint=Vector2.new(.5,.5);ray.Position=UDim2.fromScale(.5,.5);ray.Size=UDim2.fromScale(.07,1);ray.Rotation=i*180/(count or 8)
  local fade=Instance.new('UIGradient');fade.Rotation=90;fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)});fade.Parent=ray
 end
 return root
end
-- Faint "L" marks (the reference's studded plate texture). Positions are scale-based: built once.
function A.LPattern(parent,cols,rows,color,transparency)
 local root=A.Frame(parent,'LPattern',nil,1);root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
 for r=0,rows-1 do for c=0,cols-1 do
  local x,y=(c+.3)/cols,(r+.25)/rows
  local v=A.Frame(root,'L',color,transparency);v.Position=UDim2.fromScale(x,y);v.Size=UDim2.new(0,2,.45/rows,0)
  local hz=A.Frame(root,'L',color,transparency);hz.Position=UDim2.new(x,0,y+.45/rows,-2);hz.Size=UDim2.new(.32/cols,0,0,2)
 end end
 return root
end
-- Studded dark plate: a grid of faint dots drawn as short dashes on a few long rows.
function A.Studs(parent,cols,rows,color,transparency)
 local root=A.Frame(parent,'Studs',nil,1);root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
 for r=0,rows-1 do
  local row=A.Frame(root,'StudRow',nil,1);row.Position=UDim2.fromScale(0,(r+.5)/rows);row.Size=UDim2.new(1,0,0,4)
  for c=0,cols-1 do local d=A.Frame(row,'Stud',color,transparency);d.Position=UDim2.fromScale((c+.5)/cols,0);d.Size=UDim2.fromOffset(4,4);A.Corner(d,1)end
 end
 return root
end
-- Diagonal glossy stripes across a header.
function A.Stripes(parent)
 local root=A.Frame(parent,'GlossStripes',nil,1);root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
 for i,spec in ipairs({{.52,.06},{.6,.1},{.7,.035}})do
  local s=A.Frame(root,'Stripe'..i,Color3.new(1,1,1),.72);s.AnchorPoint=Vector2.new(.5,.5);s.Position=UDim2.fromScale(spec[1],.5);s.Size=UDim2.new(spec[2],0,3,0);s.Rotation=35
 end
 local gloss=A.Frame(root,'TopGloss',Color3.new(1,1,1),.8);gloss.Size=UDim2.fromScale(1,.45)
 local fade=Instance.new('UIGradient');fade.Rotation=90;fade.Transparency=NumberSequence.new(.4,1);fade.Parent=gloss
 return root
end
-- Robux glyph: rounded hexagon ring with a square core.
function A.RobuxIcon(parent)
 local root=A.Frame(parent,'RobuxIcon',nil,1);local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.Parent=root
 local ring=A.Frame(root,'Ring',Color3.new(1,1,1));ring.AnchorPoint=Vector2.new(.5,.5);ring.Position=UDim2.fromScale(.5,.5);ring.Size=UDim2.fromScale(.9,.9);A.Corner(ring,UDim.new(.32,0));A.Stroke(ring,A.Ink,1.5)
 local hole=A.Frame(ring,'Hole',C(46,150,30));hole.AnchorPoint=Vector2.new(.5,.5);hole.Position=UDim2.fromScale(.5,.5);hole.Size=UDim2.fromScale(.56,.56);A.Corner(hole,UDim.new(.25,0))
 local core=A.Frame(hole,'Core',Color3.new(1,1,1));core.AnchorPoint=Vector2.new(.5,.5);core.Position=UDim2.fromScale(.5,.5);core.Size=UDim2.fromScale(.5,.5);A.Corner(core,UDim.new(.2,0))
 return root
end
-- White gift box with a ribbon.
function A.GiftIcon(parent)
 local root=A.Frame(parent,'GiftIcon',nil,1);local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.Parent=root
 local box=A.Frame(root,'Box',Color3.new(1,1,1));box.Position=UDim2.fromScale(.16,.42);box.Size=UDim2.fromScale(.68,.5);A.Corner(box,2);A.Stroke(box,A.Ink,1.5)
 local lid=A.Frame(root,'Lid',Color3.new(1,1,1));lid.Position=UDim2.fromScale(.1,.28);lid.Size=UDim2.fromScale(.8,.17);A.Corner(lid,2);A.Stroke(lid,A.Ink,1.5)
 A.Frame(root,'Ribbon',C(203,74,236)).Position=UDim2.fromScale(.45,.28);root.Ribbon.Size=UDim2.fromScale(.1,.64)
 for i,r in ipairs({-35,35})do
  local bow=A.Frame(root,'Bow'..i,Color3.new(1,1,1));bow.AnchorPoint=Vector2.new(.5,.5);bow.Position=UDim2.fromScale(i==1 and .38 or .62,.2);bow.Size=UDim2.fromScale(.22,.13);bow.Rotation=r;A.Corner(bow,UDim.new(.5,0));A.Stroke(bow,A.Ink,1.5)
 end
 return root
end
-- Right-pointing play triangle (a rotated square, half clipped).
function A.Triangle(parent,color)
 local clip=A.Frame(parent,'Arrow',nil,1);clip.ClipsDescendants=true
 local sq=A.Frame(clip,'Body',color or Color3.new(1,1,1));sq.AnchorPoint=Vector2.new(.5,.5);sq.Position=UDim2.fromScale(0,.5);sq.Size=UDim2.fromScale(1.41,.705);sq.Rotation=45
 local ratio=Instance.new('UIAspectRatioConstraint');ratio.AspectRatio=1;ratio.Parent=sq;A.Stroke(sq,A.Ink,2)
 return clip
end
-- Rainbow stopwatch (Growth pass), sized by its parent.
function A.Clock(parent)
 local holder=A.Frame(parent,'ClockHolder',nil,1);holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromScale(.5,.5);holder.Size=UDim2.fromScale(1,1)
 local ratio=Instance.new('UIAspectRatioConstraint');ratio.AspectRatio=1;ratio.Parent=holder
 local top=A.Frame(holder,'ClockButton',C(255,90,70));top.Position=UDim2.fromScale(.41,0);top.Size=UDim2.fromScale(.18,.14);A.Corner(top,3);A.Stroke(top,A.Ink,2)
 local rim=A.Frame(holder,'RainbowClock',Color3.new(1,1,1));rim.Position=UDim2.fromScale(.05,.1);rim.Size=UDim2.fromScale(.9,.9);A.Corner(rim,UDim.new(.5,0));A.Stroke(rim,A.Ink,3)
 local rainbow=Instance.new('UIGradient');rainbow.Color=Bright.Rainbow;rainbow.Rotation=25;rainbow.Parent=rim
 local face=A.Frame(rim,'Face',C(250,253,255));face.Position=UDim2.fromScale(.13,.13);face.Size=UDim2.fromScale(.74,.74);A.Corner(face,UDim.new(.5,0))
 local hand=A.Frame(face,'Minute',A.Ink);hand.Position=UDim2.fromScale(.46,.16);hand.Size=UDim2.fromScale(.08,.36);A.Corner(hand,2)
 local hour=A.Frame(face,'Hour',A.Ink);hour.Position=UDim2.fromScale(.46,.44);hour.Size=UDim2.fromScale(.3,.08);A.Corner(hour,2)
 return holder
end
-- Gold coin with an emblem (Speed pass), like the reference "x2 Money" coin.
function A.Coin(parent,kind)
 local holder=A.Frame(parent,'Coin',nil,1);holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromScale(.5,.5);holder.Size=UDim2.fromScale(1,1)
 local ratio=Instance.new('UIAspectRatioConstraint');ratio.AspectRatio=1;ratio.Parent=holder
 local rim=A.Frame(holder,'Rim',Color3.new(1,1,1));rim.Size=UDim2.fromScale(1,1);A.Corner(rim,UDim.new(.5,0));A.Stroke(rim,C(92,52,6),3)
 A.Gradient(rim,{C(255,240,140),C(255,186,30),C(214,128,10)},60)
 local inner=A.Frame(rim,'Inner',Color3.new(1,1,1));inner.Position=UDim2.fromScale(.12,.12);inner.Size=UDim2.fromScale(.76,.76);A.Corner(inner,UDim.new(.5,0))
 A.Gradient(inner,{C(255,214,70),C(255,246,170)},-60)
 local art=A.Frame(inner,'Art',nil,1);art.Position=UDim2.fromScale(.12,.12);art.Size=UDim2.fromScale(.76,.76)
 require(RS.PremiumEmblems).Draw(art,kind)
 return holder
end
-- Pile of 1..n icons, bigger tiers show more (reference: 1 shoe -> chest of shoes).
function A.Pile(parent,kind,count)
 local stage=A.Frame(parent,'BundleArtwork',nil,1)
 local list
 if count<=1 then list={{.5,.5,.9}}
 elseif count==2 then list={{.35,.55,.72},{.65,.45,.72}}
 elseif count==3 then list={{.3,.6,.64},{.7,.6,.64},{.5,.4,.68}}
 elseif count==4 then list={{.26,.64,.56},{.74,.64,.56},{.4,.42,.6},{.62,.38,.6}}
 else list={{.22,.66,.5},{.78,.66,.5},{.5,.7,.54},{.36,.4,.54},{.64,.38,.56}}end
 for i,s in ipairs(list)do
  local icon=A.Frame(stage,'Icon'..i,nil,1);icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(s[1],s[2]);icon.Size=UDim2.fromScale(s[3],s[3]);icon.Rotation=(i%2==0 and 1 or -1)*(count>1 and 8 or 0)
  require(RS.PremiumEmblems).Draw(icon,kind)
 end
 return stage
end
-- Glossy purchase button with an optional icon left of the caption.
function A.Button(parent,name,color,icon)
 local b=Instance.new('TextButton');b.Name=name;b.Text='';b.TextSize=18;b.BorderSizePixel=0;b.AutoButtonColor=true;b.ZIndex=5;b.Parent=parent
 Bright.Button(b,color);A.Stroke(b,A.Ink,2.5,'BrightOutline')
 local content=A.Frame(b,'Content',nil,1);content.AnchorPoint=Vector2.new(.5,.5);content.Position=UDim2.fromScale(.5,.5);content.ZIndex=(b.ZIndex or 1)+5
 local glyph
 if icon=='Robux'then glyph=A.RobuxIcon(content)elseif icon=='Gift'then glyph=A.GiftIcon(content)elseif icon=='Gem'then glyph=require(RS.GemIcon).new(content)end
 if glyph then glyph.Name='Icon';glyph.ZIndex=content.ZIndex+1 end
 local label=A.Text(content,'Price','',18);label.ZIndex=content.ZIndex+2;label.TextXAlignment=Enum.TextXAlignment.Left
 b:SetAttribute('ButtonIcon',icon)
 return b
end
local function measure(text,size)
 local ok,v=pcall(function()return TextService:GetTextSize(text,size,Theme.Font,Vector2.new(4000,400))end)
 return ok and v and v.X or #text*size*.55
end
-- Lay out icon + caption centred in the button. Call after the button gets its pixel Size.
function A.Fit(b)
 local w,h=b.Size.X.Offset,b.Size.Y.Offset
 if w<=0 or h<=0 then return end
 local content=b:FindFirstChild('Content');if not content then return end
 local label=content.Price;local icon=content:FindFirstChild('Icon')
 local text=b:GetAttribute('Caption')or'';local showIcon=icon~=nil and b:GetAttribute('IconVisible')~=false
 if icon then icon.Visible=showIcon end
 local iconSize=showIcon and math.floor(h*.66)or 0;local spacing=showIcon and text~=''and 4 or 0
 local size=math.max(11,math.floor(h*.56));local avail=w-10-iconSize-spacing
 local tw=measure(text,size)
 while tw>avail and size>11 do size-=1;tw=measure(text,size)end
 tw=math.min(tw,avail)
 A.SetTextSize(label,size)
 local total=iconSize+spacing+tw+6
 content.Size=UDim2.fromOffset(total,h)
 if icon then icon.Position=UDim2.fromOffset(0,(h-iconSize)/2);icon.Size=UDim2.fromOffset(iconSize,iconSize)end
 label.Position=UDim2.fromOffset(iconSize+spacing,0);label.Size=UDim2.fromOffset(tw+6,h)
 label.Text=text
end
-- caption: text; icon: show the button's glyph; color: optional recolour.
function A.SetCaption(b,caption,showIcon,color)
 b:SetAttribute('Caption',caption);b:SetAttribute('IconVisible',showIcon~=false)
 local key=color and string.format('%d,%d,%d',color.R*255,color.G*255,color.B*255)
 if key and b:GetAttribute('ButtonColor')~=key then
  b:SetAttribute('ButtonColor',key);Bright.Button(b,color);A.Stroke(b,A.Ink,2.5,'BrightOutline')
 end
 A.Fit(b)
end
-- Rounded card with thick dark border, bright gradient, light rays and a soft vignette.
function A.Card(parent,name,colors,rays)
 local card=A.Frame(parent,name,Color3.new(1,1,1));card.ClipsDescendants=true;A.Corner(card,10);A.Stroke(card,A.Ink,3)
 A.Gradient(card,colors,90)
 if rays~=false then A.Rays(card,8,.84)end
 A.LPattern(card,6,3,Color3.new(1,1,1),.9)
 return card
end
return A
