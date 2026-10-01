-- Shared UI tokens. R123: rarity has no emblem; its identity is the card border (GardenCardMotion.Rarity).
local Fit=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTextFit'));local Borders=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenCardMotion'))
local Stars=require(game:GetService('ReplicatedStorage'):WaitForChild('CosmicLettering'))
local T={Font=Enum.Font.FredokaOne,Bold=Enum.Font.FredokaOne,Title=Enum.Font.FredokaOne}
T.RarityFont=Enum.Font.FredokaOne -- Same weight as the biome notifier.
local RGB=Color3.fromRGB
local function bands(colors)
 local keys={};for i,color in ipairs(colors)do keys[i]=ColorSequenceKeypoint.new((i-1)/(#colors-1),color)end
 return ColorSequence.new(keys)
end
T.Colors={Panel=RGB(31,34,70),Card=RGB(48,54,106),Inset=RGB(25,32,65),Text=RGB(255,255,255),Muted=RGB(204,224,255),Mint=RGB(147,255,69),Gold=RGB(255,229,71),Peach=RGB(255,147,207),Ink=RGB(16,30,40),Line=RGB(106,144,225)}
T.Rarities={
 Common={Color=Color3.fromRGB(213,224,210),Accent=Color3.fromRGB(154,176,152)},
 Uncommon={Color=Color3.fromRGB(151,228,154),Accent=Color3.fromRGB(80,159,108)},
 Rare={Color=Color3.fromRGB(131,199,255),Accent=Color3.fromRGB(67,129,218)},
 Legendary={Color=RGB(255,209,83),Accent=RGB(227,158,36),Outline=RGB(62,32,8),Fill=bands({RGB(255,226,132),RGB(255,187,40),RGB(255,251,207),RGB(226,141,18),RGB(255,212,92)})},
 Mythic={Color=RGB(255,100,104),Accent=RGB(222,42,52),Outline=RGB(58,8,17),Fill=bands({RGB(255,128,123),RGB(246,46,60),RGB(255,208,197),RGB(181,15,38),RGB(255,72,83)})},
 Secret={Color=RGB(255,255,255),Accent=RGB(180,184,192),Outline=RGB(0,0,0)},
 Cosmic={Color=RGB(172,159,242),Accent=RGB(158,148,218),Outline=RGB(255,255,255),TextColor=RGB(5,6,10)},
 King={Color=RGB(255,230,151),Accent=RGB(247,178,46),Outline=RGB(105,57,9),Fill=bands({RGB(255,247,209),RGB(255,216,100),RGB(255,255,240),RGB(231,160,30),RGB(255,241,176)})},
}
function T.Rarity(name)return T.Rarities[name]or T.Rarities.Common end
-- Reusable on labels: reapplying a rarity never stacks gradients or outlines.
-- Static five-stop gloss costs no per-frame text animation. UIStroke is separate
-- from the fill; do not also enable the legacy TextStroke on gradient lettering.
function T.RarityText(label,rarity,size,motion)
 local style=T.Rarity(rarity)
 label.Font=T.RarityFont;label.TextSize=size or 12;label.RichText=false
 label.TextStrokeTransparency=1;label.TextColor3=style.Fill and RGB(255,255,255)or style.TextColor or style.Color
 if rarity=='Cosmic'and motion~=false then Stars.Apply(label)else Stars.Clear(label)end
 local stroke=label:FindFirstChild('RarityOutline')
 if not stroke then stroke=Instance.new('UIStroke');stroke.Name='RarityOutline';stroke.Parent=label end
 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;stroke.LineJoinMode=Enum.LineJoinMode.Round
 stroke.Color=style.Outline or RGB(19,31,28);stroke.Thickness=(size or 12)<=12 and .8 or(rarity=='King'and 1.25 or 1)
 local gradient=label:FindFirstChild('RarityFill')
 if style.Fill then
  if not gradient then gradient=Instance.new('UIGradient');gradient.Name='RarityFill';gradient.Parent=label end
  gradient.Color=style.Fill;gradient.Rotation=90
 elseif gradient then gradient:Destroy()end
 Fit.Attach(label,size or 12,8);return label
end
function T.Text(label,size,bold,color)
 label.Font=bold and T.Bold or T.Font;label.TextSize=size;label.TextColor3=color or T.Colors.Text
 label.TextStrokeTransparency=1;label.RichText=false;Fit.Attach(label,size or 12,8);return label
end
local shining={Legendary=true,Mythic=true,Secret=true,Cosmic=true,King=true}
function T.ItemShine(rarity)return shining[rarity]==true end
-- R123: one distinct border per rarity (see GardenCardMotion.Styles); unknown or '' reads as Common.
function T.CardBorder(parent,rarity)return Borders.Rarity(parent,rarity)end
function T.Corner(parent,radius)local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,radius or 8);c.Parent=parent;return c end
local function shape(parent,name,x,y,w,h,color,round,rotation)
 local p=Instance.new('Frame');p.Name=name;p.Position=UDim2.fromScale(x,y);p.Size=UDim2.fromScale(w,h);p.BorderSizePixel=0;p.BackgroundColor3=color;p.Rotation=rotation or 0;p.Active=false;p.Parent=parent
 if round then T.Corner(p,100)end;return p
end
function T.ControlIcon(parent,kind)
 local root=Instance.new('Frame');root.Name='ControlIcon';root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(14,14);root.Active=false;root.Parent=parent
 local c=T.Colors.Text
 if kind=='chevron'then shape(root,'Left',.18,.35,.42,.12,c,false,45);shape(root,'Right',.43,.35,.42,.12,c,false,-45)
 elseif kind=='Seeds'then shape(root,'Seed',.28,.18,.42,.60,c,true,-25);shape(root,'Sprout',.56,.03,.24,.24,T.Colors.Mint,true,35)
 elseif kind=='Fruit'then shape(root,'Fruit',.16,.30,.66,.58,c,true);shape(root,'Leaf',.53,.08,.31,.21,T.Colors.Mint,true,-30)
 elseif kind=='Tools'then shape(root,'Shaft',.43,.12,.13,.52,c,false,30);shape(root,'Blade',.27,.60,.42,.29,c,true,30)
 else for x=0,1 do for y=0,1 do shape(root,'Tile',.14+x*.40,.14+y*.40,.27,.27,c,false)end end end
 return root
end
return T
