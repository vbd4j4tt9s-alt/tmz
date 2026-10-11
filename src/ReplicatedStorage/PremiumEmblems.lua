-- R64: static native vector-style silhouettes, independent of font/emoji rendering.
local E={};local C=Color3.fromRGB
local function polygon(root,name,points,color)
 local last
 for row=0,95 do
  local y=(row+.5)/96;local hits={}
  for i,a in ipairs(points)do local b=points[i%#points+1];if(a[2]<=y and b[2]>y)or(b[2]<=y and a[2]>y)then hits[#hits+1]=a[1]+(y-a[2])/(b[2]-a[2])*(b[1]-a[1])end end
  table.sort(hits)
  for i=1,#hits-1,2 do
   local x=math.floor(hits[i]*96);local width=math.ceil(hits[i+1]*96)-x
   if width>0 then
    if last and last.X==x and last.W==width and last.Y+last.H==row then last.H+=1;last.Part.Size=UDim2.fromScale(width/96,(last.H+.5)/96)
    else local f=Instance.new('Frame');f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=color;f.Position=UDim2.fromScale(x/96,row/96);f.Size=UDim2.fromScale(width/96,1.5/96);f.Active=false;f.Parent=root;last={X=x,W=width,Y=row,H=1,Part=f}end
   end
  end
 end
end
local function box(root,name,x,y,w,h,color,radius)
 local f=Instance.new('Frame');f.Name=name;f.Position=UDim2.fromScale(x,y);f.Size=UDim2.fromScale(w,h);f.BorderSizePixel=0;f.BackgroundColor3=color;f.Active=false;f.Parent=root
 if radius then local c=Instance.new('UICorner');c.CornerRadius=UDim.new(1,0);c.Parent=f end;return f
end
function E.Draw(parent,kind)
 local root=Instance.new('Frame');root.Name=kind;root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=parent
 local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.Parent=root
 if kind=='Bolt'or kind=='Money'then
  require(script.Parent.HudArtwork).Attach(root,kind)
 elseif kind=='Crown'then
  local points={{.08,.31},{.23,.44},{.28,.20},{.40,.41},{.50,.10},{.60,.41},{.72,.20},{.77,.44},{.92,.31},{.83,.78},{.17,.78}}
  polygon(root,'Crown silhouette',points,C(37,22,7));local inner={};for _,p in ipairs(points)do inner[#inner+1]={.5+(p[1]-.5)*.89,.45+(p[2]-.45)*.87}end
  polygon(root,'Gold',inner,C(255,199,66));box(root,'Lower band',.18,.71,.64,.09,C(255,225,123));box(root,'Band shadow',.19,.80,.62,.045,C(187,113,34))
  local gem=box(root,'Royal jewel',.455,.585,.09,.09,C(180,119,255));gem.Rotation=45
  for _,x in ipairs({.28,.68})do box(root,'Side jewel',x,.635,.045,.045,C(231,252,255),true)end
 elseif kind=='RadiantStar'then
  local points={};for i=0,15 do local a=-math.pi/2+i*math.pi/8;local r=i%2==1 and .065 or i%4==0 and .49 or .25;points[#points+1]={.5+math.cos(a)*r,.5+math.sin(a)*r}end
  polygon(root,'Starlight',points,C(231,236,255))
  box(root,'White core',.473,.473,.054,.054,C(255,255,255),true)
 elseif kind=='Featured'then
  -- R125 (owner): the shop's Featured logo. A gold star with a dark outline, a lighter bevel, a glint and a sparkle.
  local function star(cx,cy,ro,ri)local pts={};for i=0,9 do local a=-math.pi/2+i*math.pi/5;local r=i%2==0 and ro or ri;pts[#pts+1]={cx+math.cos(a)*r,cy+math.sin(a)*r}end;return pts end
  polygon(root,'Star outline',star(.47,.54,.47,.21),C(52,28,6))
  polygon(root,'Gold',star(.47,.54,.40,.18),C(255,178,32))
  polygon(root,'Bevel',star(.47,.52,.27,.12),C(255,226,110))
  local glint=box(root,'Glint',.36,.42,.07,.07,C(255,255,245));glint.Rotation=45
  local sparkle={};for i=0,7 do local a=-math.pi/2+i*math.pi/4;local r=i%2==0 and .14 or .035;sparkle[#sparkle+1]={.83+math.cos(a)*r,.2+math.sin(a)*r}end
  polygon(root,'Sparkle',sparkle,C(255,250,225))
 elseif kind=='Star'then
  local points={};for i=0,9 do local a=-math.pi/2+i*math.pi/5;local r=i%2==0 and .44 or .19;points[#points+1]={.5+math.cos(a)*r,.5+math.sin(a)*r}end
  polygon(root,'Star',points,C(242,243,255));polygon(root,'Star core',{{.5,.2},{.58,.48},{.5,.64},{.42,.48}},C(255,255,255))
 elseif kind=='Clover'then
  -- R153: a 4 Leaf Clover from boxes only (the plain one: CloverIcon153 shows it until the owner's picture is there). A leaf is a heart: a square plus a circle on each of its two outer
  -- edges; four of them meet at the middle. Dark outline pieces first (a little bigger), then the green ones, the two veins, a shine on every leaf and the stem.
  local s,o,cx,cy=.29,.028,.5,.43
  local function leaf(sx,sy,grow,color,tag)
   local side=s+grow*2
   box(root,tag..' square',cx+sx*s/2-side/2,cy+sy*s/2-side/2,side,side,color)
   box(root,tag..' lobe',cx+sx*s-side/2,cy+sy*s/2-side/2,side,side,color,true)
   box(root,tag..' lobe',cx+sx*s/2-side/2,cy+sy*s-side/2,side,side,color,true)
  end
  local stem=function(grow,color,tag)local b=box(root,tag..' stem',cx-.03-grow,cy+.05-grow,.06+grow*2,.47+grow*2,color,true);b.Rotation=-9 end
  for _,q in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}})do leaf(q[1],q[2],o,C(12,66,30),'Outline')end;stem(o,C(12,66,30),'Outline')
  stem(0,C(54,168,58),'Green')
  for _,q in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}})do leaf(q[1],q[2],0,C(72,204,64),'Leaf')end
  box(root,'Vein',cx-.01,cy-s*1.35,.02,s*2.7,C(30,132,48));box(root,'Vein',cx-s*1.35,cy-.01,s*2.7,.02,C(30,132,48))
  for _,q in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}})do
   local shine=box(root,'Shine',cx+q[1]*s*1.02-.045,cy+q[2]*s*.55-.045,.09,.09,C(176,248,112),true);shine.BackgroundTransparency=.25
  end

 end
 return root
end
return E
