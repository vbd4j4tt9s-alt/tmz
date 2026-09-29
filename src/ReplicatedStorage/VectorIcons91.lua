-- Small, resolution-independent GUI icons. No asset requests or image permissions.
local I={Primary={RobuxShop=true,Index=true,Money=true,Bolt=true,Forest=true,Jungle=true,Desert=true,Snow=true,Crystal=true,Lava=true,Storm=true,Mech=true}}
local C=Color3.fromRGB
function I.Draw(parent,kind,silhouette)
 local root=Instance.new('Frame');root.Name='InstantIcon';root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Active=false;root.ZIndex=math.max(4,(parent.ZIndex or 1)+1);root.Parent=parent
 local canvas=Instance.new('Frame');canvas.Name='Drawing';canvas.BackgroundTransparency=1;canvas.AnchorPoint=Vector2.new(.5,.5);canvas.Position=UDim2.fromScale(.5,.5);canvas.Size=UDim2.fromScale(.94,.94);canvas.ZIndex=root.ZIndex;canvas.Active=false;canvas.Parent=root
 local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.AspectType=Enum.AspectType.FitWithinMaxSize;aspect.Parent=canvas
 local ink=C(21,40,49);local cream=C(255,241,187);local green=C(65,222,131);local gold=C(255,203,63);local cyan=C(89,218,250)
 local function shape(name,x,y,w,h,color,angle,round,outline)
  local p=Instance.new('Frame');p.Name=name;p.Position=UDim2.fromScale(x,y);p.Size=UDim2.fromScale(w,h);p.BackgroundColor3=silhouette and C(42,53,74)or color;p.BorderSizePixel=0;p.Active=false;p.Rotation=angle or 0;p.ZIndex=root.ZIndex+1;p.Parent=canvas
  if round then local c=Instance.new('UICorner');c.CornerRadius=UDim.new(round,0);c.Parent=p end
  if outline then local s=Instance.new('UIStroke');s.Color=silhouette and C(150,170,199)or ink;s.Thickness=1.7;s.Parent=p end
  return p
 end
 local function glyph(parent,text,color)
  local t=Instance.new('TextLabel');t.Name='Symbol';t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Text=text;t.TextScaled=true;t.Font=Enum.Font.FredokaOne;t.TextColor3=silhouette and C(169,185,205)or color;t.ZIndex=root.ZIndex+2;t.Active=false;t.Parent=parent
 end
 local function leaf(x,y,w,h,color,angle)return shape('Leaf',x,y,w,h,color,angle,.45,true)end
 local function bolt()
  shape('Bolt top',.43,.12,.20,.43,gold,28,.05,true)
  shape('Bolt middle',.27,.43,.45,.15,gold,-8,.05,true)
  shape('Bolt tip',.37,.49,.18,.39,gold,28,.04,true)
 end
 local function gem(color)
  shape('Crystal',.25,.25,.50,.50,color,45,.07,true)
  shape('Facet',.32,.27,.25,.30,cream,45,.02)
  shape('Highlight',.38,.16,.10,.28,C(236,253,255),45,.08)
 end
 if kind=='RobuxShop'then
  local h=shape('Bag handle',.32,.12,.36,.37,gold,0,.45,true);h.BackgroundTransparency=1
  shape('Bag',.17,.33,.66,.51,C(81,203,137),-5,.12,true)
  shape('Bag edge',.70,.36,.11,.43,C(33,143,94),-5,.10)
  shape('Seal',.37,.43,.28,.28,gold,0,1,true)
  shape('Seal gem',.45,.51,.12,.12,cream,45,.05)
 elseif kind=='Index'then
  shape('Book cover',.12,.24,.78,.60,C(48,174,191),-5,.10,true)
  shape('Left page',.16,.19,.33,.56,cream,-5,.06,true)
  shape('Right page',.50,.19,.33,.56,C(255,251,222),5,.06,true)
  shape('Spine',.475,.23,.04,.53,C(165,116,58),0,.05)
  leaf(.23,.36,.17,.11,green,-30);leaf(.62,.43,.14,.10,green,30)
  for _,y in ipairs({.57,.64})do shape('Page line',.57,y,.18,.018,C(184,158,108),5)end
 elseif kind=='Money'then
  shape('Notes behind',.15,.22,.68,.40,C(41,144,86),-13,.12,true)
  shape('Cash note',.12,.30,.72,.42,C(88,225,122),-5,.10,true)
  local badge=shape('Cash seal',.36,.34,.27,.28,C(185,255,137),-5,1);glyph(badge,'$',C(28,117,71))
  for j=0,2 do shape('Coin',.67,.69-j*.075,.19,.09,gold,0,.4,true)end
 elseif kind=='Bolt'or kind=='Storm'then bolt()
 elseif kind=='Crystal'or kind=='Gem'or kind=='Mech'then gem(kind=='Mech'and cyan or C(175,118,252))
 elseif kind=='Snow'or kind=='WeatherSnow'then
  for i=0,2 do shape('Ice arm',.46,.14,.08,.72,cyan,i*60,.18,true)end
  shape('Ice heart',.39,.39,.22,.22,C(225,254,255),45,.08)
 elseif kind=='Desert'then
  shape('Sand',.12,.74,.76,.12,gold,0,.40)
  shape('Cactus trunk',.42,.19,.19,.62,C(73,181,108),0,.45,true)
  shape('Cactus arm',.21,.32,.12,.28,green,0,.4,true);shape('Cactus elbow',.24,.51,.24,.12,green,0,.4)
  shape('Cactus arm',.68,.38,.10,.25,green,0,.4,true);shape('Cactus elbow',.55,.55,.21,.10,green,0,.4)
 elseif kind=='Lava'then
  shape('Mountain',.25,.35,.50,.50,C(98,74,83),45,.12,true)
  shape('Magma',.43,.27,.14,.52,C(255,143,56),-7,.18,true)
  shape('Crater',.32,.24,.35,.14,C(255,94,44),0,.4,true)
 elseif kind=='Forest'then
  shape('Trunk',.45,.54,.12,.32,C(157,104,63),0,.12,true)
  for i=0,2 do local size=.29+i*.13;shape('Pine tier',.5-size/2,.17+i*.16,size,size,C(53,177-i*15,93),45,.10,true)end
 else
  shape('Stem',.47,.40,.065,.42,green,0,.4)
  leaf(.20,.23,.35,.20,green,30);leaf(.50,.32,.30,.18,C(157,238,106),-28)
  shape('Seed',.30,.72,.39,.14,C(170,114,66),0,.5,true)
 end
 root:SetAttribute('VectorIcon91',kind)
 return root
end
return I
