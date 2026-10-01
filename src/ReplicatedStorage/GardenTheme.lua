-- Shared UI tokens. Rarity lettering and its decoration live in separate objects.
local Run=game:GetService('RunService')
local Players=game:GetService('Players')
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
 Common={Color=Color3.fromRGB(213,224,210),Accent=Color3.fromRGB(154,176,152),Symbol='seed'},
 Uncommon={Color=Color3.fromRGB(151,228,154),Accent=Color3.fromRGB(80,159,108),Symbol='leaf'},
 Rare={Color=Color3.fromRGB(131,199,255),Accent=Color3.fromRGB(67,129,218),Symbol='diamond'},
 Legendary={Color=RGB(255,209,83),Accent=RGB(227,158,36),Symbol='sun',Outline=RGB(62,32,8),Fill=bands({RGB(255,226,132),RGB(255,187,40),RGB(255,251,207),RGB(226,141,18),RGB(255,212,92)})},
 Mythic={Color=RGB(255,100,104),Accent=RGB(222,42,52),Symbol='star',Outline=RGB(58,8,17),Fill=bands({RGB(255,128,123),RGB(246,46,60),RGB(255,208,197),RGB(181,15,38),RGB(255,72,83)})},
 Secret={Color=RGB(255,255,255),Accent=RGB(180,184,192),Symbol='key',Outline=RGB(0,0,0)},
 Cosmic={Color=RGB(172,159,242),Accent=RGB(158,148,218),Symbol='orbit',Outline=RGB(255,255,255),TextColor=RGB(5,6,10)},
 King={Color=RGB(255,230,151),Accent=RGB(247,178,46),Symbol='crown',Outline=RGB(105,57,9),Fill=bands({RGB(255,247,209),RGB(255,216,100),RGB(255,255,240),RGB(231,160,30),RGB(255,241,176)})},
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
function T.CardBorder(parent,rarity)return Borders.Apply(parent,T.Rarity(rarity).Accent,T.ItemShine(rarity))end
function T.Corner(parent,radius)local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,radius or 8);c.Parent=parent;return c end
local function shape(parent,name,x,y,w,h,color,round,rotation)
 local p=Instance.new('Frame');p.Name=name;p.Position=UDim2.fromScale(x,y);p.Size=UDim2.fromScale(w,h);p.BorderSizePixel=0;p.BackgroundColor3=color;p.Rotation=rotation or 0;p.Active=false;p.Parent=parent
 if round then T.Corner(p,100)end;return p
end
-- R122: emblem helpers (top-to-bottom gradient fill and a thin outline ring).
local function fill(frame,top,bottom,rotation)
 local g=Instance.new('UIGradient');g.Color=ColorSequence.new(top,bottom);g.Rotation=rotation or 90;g.Parent=frame;return g
end
local function ring(frame,color,thickness)
 local st=Instance.new('UIStroke');st.Color=color;st.Thickness=thickness or 1;st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Parent=frame;return st
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
function T.Icon(parent,rarity)
 local style=T.Rarity(rarity);local root=Instance.new('Frame');root.Name='RarityDecoration';root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(20,20);root.Active=false;root.Parent=parent
 local c,a=style.Color,style.Accent
 if style.Symbol=='crown'then
  shape(root,'Bronze outline',.06,.66,.88,.26,RGB(147,90,28),false)
  shape(root,'Gold band',.09,.68,.82,.19,RGB(244,187,57),false)
  for i=1,5 do local h=i==3 and .49 or(i==2 or i==4)and .37 or .27;local x=.08+(i-1)*.175
   shape(root,'Crown point'..i,x,.69-h,.14,h,c,false,(i-3)*7)
   shape(root,'Crown tip'..i,x+.022,.64-h,.095,.095,RGB(255,235,157),true)
  end
  shape(root,'Diamond gem',.43,.69,.14,.14,RGB(255,249,218),false,45)
 elseif style.Symbol=='orbit'then
  local ring=shape(root,'Orbit',.08,.28,.84,.44,c,true,-25);ring.BackgroundTransparency=1
  local line=Instance.new('UIStroke');line.Thickness=1.2;line.Color=a;line.Parent=ring
  shape(root,'Planet',.32,.26,.36,.48,RGB(13,12,36),true)
  shape(root,'PlanetGleam',.39,.31,.10,.10,RGB(216,208,255),true)
  shape(root,'Star',.17,.12,.10,.10,RGB(255,255,255),false,45);shape(root,'Satellite',.73,.17,.13,.13,RGB(235,232,255),true)
  shape(root,'DistantStar',.81,.76,.08,.08,RGB(255,255,255),false,45)
 elseif style.Symbol=='star'then
  -- R122 Mythic: a crimson crest gem in a dark frame with a bright core and two side sparks.
  local glow=shape(root,'MythicGlow',.10,.10,.80,.80,a,true);glow.BackgroundTransparency=.55
  local frame=shape(root,'CrestFrame',.17,.17,.66,.66,style.Outline,false,45)
  local gem=shape(root,'CrestGem',.24,.24,.52,.52,Color3.new(1,1,1),false,45);fill(gem,RGB(255,150,140),RGB(196,18,40),90)
  local core=shape(root,'CrestCore',.37,.37,.26,.26,Color3.new(1,1,1),false,45);fill(core,RGB(255,250,238),RGB(255,150,130),90)
  shape(root,'SparkLeft',.02,.44,.13,.13,RGB(255,214,206),false,45)
  shape(root,'SparkRight',.85,.44,.13,.13,RGB(255,214,206),false,45)
  shape(root,'Glint',.37,.25,.08,.08,Color3.new(1,1,1),true)
 elseif style.Symbol=='sun'then
  -- R122 Legendary: a golden sunburst medallion (8 rays, outlined disc, shine).
  for i=0,3 do local ray=shape(root,'Ray'..i,.43,.02,.14,.96,Color3.new(1,1,1),false,i*45);fill(ray,RGB(255,236,150),RGB(232,150,22),90)end
  local disc=shape(root,'SunDisc',.21,.21,.58,.58,Color3.new(1,1,1),true);fill(disc,RGB(255,248,196),RGB(240,166,24),45);ring(disc,style.Outline,1)
  shape(root,'SunCore',.36,.36,.28,.28,RGB(255,252,226),true)
  shape(root,'Glint',.31,.29,.10,.10,Color3.new(1,1,1),true)
 elseif style.Symbol=='key'then
  -- R122 Secret: a black seal with a silver ring and a glowing white keyhole.
  local seal=shape(root,'Seal',.08,.08,.84,.84,Color3.new(1,1,1),true);fill(seal,RGB(58,60,70),RGB(4,4,8),90);ring(seal,RGB(214,218,228),1)
  shape(root,'KeyEye',.38,.24,.24,.24,Color3.new(1,1,1),true)
  shape(root,'Keyhole',.43,.40,.14,.32,Color3.new(1,1,1),false)
  shape(root,'SealGlint',.25,.20,.09,.09,RGB(200,204,214),true)
 elseif style.Symbol=='diamond'then
  local gem=shape(root,'Gem',.22,.18,.56,.62,Color3.new(1,1,1),false,45);fill(gem,RGB(186,228,255),RGB(46,118,214),90);ring(gem,RGB(22,58,120),1)
  shape(root,'GemGlint',.40,.30,.10,.10,Color3.new(1,1,1),true)
 elseif style.Symbol=='leaf'then
  local leaf=shape(root,'Leaf',.22,.13,.50,.70,Color3.new(1,1,1),true,35);fill(leaf,RGB(186,246,170),RGB(56,160,84),90);ring(leaf,RGB(28,92,48),1)
  shape(root,'Stem',.47,.43,.07,.47,a,false,35)
 else local seed=shape(root,'Seed',.30,.22,.40,.58,c,true,-25);ring(seed,RGB(96,110,94),1)end
 return root
end
local animations={};local connection;local clock=0
local function visible(root)
 local p=root
 while p do
  if p:IsA('GuiObject')and not p.Visible then return false end
  if p:IsA('LayerCollector')and not p.Enabled then return false end
  if p:IsA('GuiObject')and p.ClipsDescendants then
   local lo,hi=root.AbsolutePosition,root.AbsolutePosition+root.AbsoluteSize;local a,b=p.AbsolutePosition,p.AbsolutePosition+p.AbsoluteSize
   if hi.X<a.X or hi.Y<a.Y or lo.X>b.X or lo.Y>b.Y then return false end
  end
  p=p.Parent
 end
 return root.Parent~=nil
end
local function animate(icon)
 animations[icon]=true
 icon.Destroying:Connect(function()animations[icon]=nil;if not next(animations)and connection then connection:Disconnect();connection=nil end end)
 if connection then return end
 connection=Run.Heartbeat:Connect(function(dt)
  clock+=dt;if clock<.10 then return end;clock=0
  local p=Players.LocalPlayer;local mode=p and p:GetAttribute('StudioPlantEffects');local cap=(mode=='low'or mode=='off'or(p and p:GetAttribute('FastMode')) )and 0 or 3
  local count=0;local t=os.clock()
  for icon0 in pairs(animations)do if count<cap and visible(icon0)then
   count+=1;local dot=icon0:FindFirstChild('Satellite');if dot then dot.Position=UDim2.fromScale(.44+math.cos(t*.7)*.37,.44+math.sin(t*.7)*.20)end
  end end
 end)
end
function T.Badge(parent,rarity,compact,motion)
 local root=Instance.new('Frame');root.Name='RarityBadge';root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(compact and 20 or 110,22);root.Active=false;root.Parent=parent
 local icon=T.Icon(root,rarity);icon.Position=UDim2.fromOffset(0,1)
 if not compact then
  local word=Instance.new('TextLabel');word.Name='RarityName';word.BackgroundTransparency=1;word.Position=UDim2.fromOffset(25,0);word.Size=UDim2.new(1,-25,1,0);word.Text=rarity or'Common';word.TextXAlignment=Enum.TextXAlignment.Left;word.TextWrapped=false;T.RarityText(word,rarity,rarity=='King'and 14 or 12,false);word.Parent=root
 end
 if rarity=='Cosmic'and motion then animate(icon)end
 return root
end
return T
