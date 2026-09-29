-- Static colour/material treatment. No frame loop, textures to fetch or per-plant lights.
local Style={};local V,CF=Vector3.new,CFrame.new
local palettes={
 ElderbloomSeed={{76,120,92},{164,204,114},{96,75,51}},
 AncientWorldrootSeed={{46,128,95},{174,185,83},{91,69,48}},
 MirageFigSeed={{101,100,144},{211,153,197},{101,74,91}},
 StarfruitSeed={{141,158,69},{232,189,87},{137,91,55}},
 SolarStarfruitSeed={{197,134,49},{255,213,106},{128,80,46}},
 WinterCrownwoodSeed={{103,160,194},{207,239,243},{64,92,135}},
 EmberEmperorSeed={{115,48,59},{226,105,43},{60,45,55}},
 PrismMonarchSeed={{118,85,184},{189,178,242},{57,59,106}},
 PulsarStarfruitSeed={{86,107,165},{139,201,218},{58,66,105}},
 StormSovereignSeed={{64,76,123},{143,189,209},{45,52,87}},
}
local function blend(a,b,t)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
local function curve(s,a,b,lift,back)
 local out={};local length=(b-a).Magnitude
 local p1=a+(b-a)*.22+V(0,lift,back)
 local p2=b+V(0,lift*.62,back*.25)
 local prev=a
 for j=1,12 do
  local t=j/12;local u=1-t;local pt=a*u^3+p1*(3*u*u*t)+p2*(3*u*t*t)+b*t^3
  local delta=pt-prev;local y=delta.Unit;local x=y:Cross(V(0,0,1));if x.Magnitude<.01 then x=y:Cross(V(1,0,0))end;x=x.Unit
  local q=table.clone(s);q.z={s.s=='CylinderX'and s.z[2]or s.z[1],delta.Magnitude+.035*length,s.s=='CylinderX'and s.z[3]or s.z[3]}
  q.s='Cylinder';q.f='Arched hanging stem';q.c={CFrame.fromMatrix((prev+pt)*.5,x,y,x:Cross(y)):GetComponents()};q.arc=true;q.tx=nil
  table.insert(out,q);prev=pt
 end
 return out
end
function Style.Key(id,crop)
 if id~='EmberEmperorSeed'and id~='StormSovereignSeed'and id~='PrismMonarchSeed'then return ''end
 return ':'..tostring(crop and(crop.SourceCropId or crop.Id)or'preview')
end
function Style.Apply(id,def,source,crop)
 local seed=137;local identity=tostring(crop and(crop.SourceCropId or crop.Id)or'preview')
 for i=1,#identity do seed=(seed*33+identity:byte(i))%2147483647 end
 -- Avalanche neighbouring saved IDs so their crack paths differ visibly.
 for _=1,4 do seed=(seed*48271)%2147483647 end
 local function rand(salt)return ((seed%65521)*salt+7919)%65521/65520 end
 local result={};local palette=palettes[id];local spots=0;local crest;local infusions={};local grains=0
 for i,original in ipairs(source)do
  local s=table.clone(original);s.k=table.clone(s.k);local name=string.lower(s.f or '')
  local leaf=s.r=='Leaf'or s.r=='Canopy'or name:find('canopy')or name:find('crown')or name:find('leaf')or name:find('frond')
  local bark=def.Tree and s.g==0 and(s.r=='Stem'or name:find('trunk')or name:find('bark')or name:find('branch'))
  if bark and s.s=='CylinderX'then
   local at=CF(table.unpack(s.c));s.c={CFrame.fromMatrix(at.Position,-at.UpVector,at.RightVector,-at.LookVector):GetComponents()};s.z={s.z[2],s.z[1],s.z[3]};s.s='Cylinder'
  end
  if s.m~='Neon'and s.m~='Glass'then
   if palette and leaf then s.k=blend(palette[1],palette[2],.10+(i*17%11)/14)
   elseif palette and bark then s.k=blend(palette[3],{25,28,36},(i%4)*.055)
   elseif leaf then s.k=blend(s.k,i%3==0 and{220,234,203}or{22,51,32},i%3==0 and .055 or .045)end
   if bark then s.m='Wood';if (id=='EmberEmperorSeed'or id=='StormSovereignSeed'or id=='PrismMonarchSeed')and s.z[2]>def.Height*.065 then table.insert(infusions,s)end;if not crest and s.z[2]>def.Height*.15 and not s.mesh then crest=s end end
  end
  -- Static highlights/shadows are retained even when a device reduces dynamic lighting.
  s.shaded=true
  if s.m~='Neon'and s.m~='Glass'then
   local h=math.clamp(s.c[2]/math.max(1,def.Height),0,1)
   s.k=blend(s.k,h>.55 and{250,240,221}or{20,28,38},h>.55 and .045 or .055)
  end
  if not s.mesh and not s.tx and grains<4 and(s.s=='Ball'or s.s=='Petal'or s.s=='Block'or s.s=='Shrub')and(s.r=='Leaf'or s.r=='Canopy'or s.g>0)and math.min(s.z[1],s.z[2])>def.Height*.035 then
   s.tx='grain';grains+=1
  end
  -- Two narrow grooves on the larger trunks. Fruit stipples are sparse and bounded.
  if bark and not s.mesh and s.z[2]>def.Height*.12 and spots<6 then s.tx='bark';spots+=1
  elseif s.g>0 and not s.tx and not s.mesh and(s.f=='Berry'or s.f=='Ash tomato body'or s.f=='Apple cube'or s.f=='Melon body'or s.f=='Pear body')and spots<6 then s.tx='speckle';spots+=1 end
  -- The attachment endpoints are unchanged. The stalk bows up and drops into the bell/fruit.
  local curved=false
  if id=='SilentFrostbellSeed'and s.g==0 and s.r=='Stem'and not s.f then
   local at=CF(table.unpack(s.c));local a=at.Position-at.UpVector*s.z[2]*.5
   local b=at.Position+at.UpVector*s.z[2]*.5
   -- Snap the tip to the authored socket; the original stems overlapped it by their radius.
   local nearest=V(table.unpack(def.Sockets[1]));for _,socket in ipairs(def.Sockets)do local p=V(table.unpack(socket));if(p-b).Magnitude<(nearest-b).Magnitude then nearest=p end end
   b=nearest;a=V(a.X,math.max(.04,a.Y),a.Z)
   for _,q in ipairs(curve(s,a,b,(b.Y-a.Y)*.85,-(b.Y-a.Y)*.12))do table.insert(result,q)end;curved=true
  elseif id=='VenomVineSeed'and s.f=='Curled pitcher stalk'then
   local at=CF(table.unpack(s.c));local a=at.Position-at.RightVector*s.z[1]*.5;local b=at.Position+at.RightVector*s.z[1]*.5
   if a.Y>b.Y then a,b=b,a end
   for _,q in ipairs(curve(s,a,b,(b-a).Magnitude*.65,0))do table.insert(result,q)end;curved=true
  elseif id=='LanternFernSeed'and s.g==0 and s.s=='CylinderX'then
   local at=CF(table.unpack(s.c));local a=at.Position-at.RightVector*s.z[1]*.5;local b=at.Position+at.RightVector*s.z[1]*.5
   for _,socket in ipairs(def.Sockets)do
    local tip=V(table.unpack(socket))
    if math.min((a-tip).Magnitude,(b-tip).Magnitude)<.08 then
     if(a-tip).Magnitude<(b-tip).Magnitude then a,b=b,a end;b=tip
     for _,q in ipairs(curve(s,a,b,math.max(.35,(b-a).Magnitude*.65),.08))do table.insert(result,q)end;curved=true;break
    end
   end
  end
  if not curved then table.insert(result,s)end
 end
 if crest and palette and def.Rank>=5 then
  local at=CF(table.unpack(crest.c));local width=math.min(crest.z[1],crest.z[3]);local height=math.min(crest.z[2]*.48,def.Height*.13)
  for j=1,3 do
   local f=at*CF((j-2)*width*.22,(j==2 and .1 or -.10)*height,crest.z[3]*.49)*CFrame.Angles(0,0,(j-2)*.20)
   table.insert(result,{s='Gem',z={width*.18,height*(j==2 and 1 or .62),width*.085},c={f:GetComponents()},k=palette[2],g=0,r='Detail',f='Royal bark inlay',m='Neon',t=0,p=45})
  end
 end
 -- Prioritize continuous main-trunk wood and the exposed split-bark panels.
 table.sort(infusions,function(a,b)
  local function score(s)
   local radial=math.sqrt(s.c[1]^2+s.c[3]^2)
   return s.z[2]+math.min(s.z[1],s.z[3])*3-radial*3+(s.f=='Split bark'and 12 or 0)
  end
  return score(a)>score(b)
 end)
 while #infusions>3 do table.remove(infusions)end
 for _,s in ipairs(infusions)do s.elementSupport=true end
 if id=='ElderbloomSeed'or id=='AncientWorldrootSeed'then
  local h=def.Height;local worldroot=id=='AncientWorldrootSeed'
  local wood=worldroot and{78,66,44}or{97,82,62};local moss=worldroot and{75,126,72}or{111,137,84}
  local function add(name,form,z,at,color,material)
   table.insert(result,{f=name,s=form,z=z,c={at:GetComponents()},k=color,m=material or'Wood',t=0,g=0,r='Detail',element=true,shaded=true,p=35})
  end
  for _,s in ipairs(result)do
   if s.g==0 and s.r=='Stem'and s.c[2]<h*.40 and math.abs(s.c[1])+math.abs(s.c[3])<h*.13 then
    s.z=table.clone(s.z);s.z[1]*=1.45;s.z[3]*=1.45;s.elementSupport=true;s.tx='bark'
   end
  end
  for i=1,7 do
   local angle=i*math.pi*2/7+(rand(i*37)-.5)*.28
   local a=V(math.cos(angle)*h*.025,h*.15,math.sin(angle)*h*.025)
   local b=V(math.cos(angle)*h*(.14+rand(i*43)*.045),h*.010,math.sin(angle)*h*(.14+rand(i*43)*.045))
   local delta=b-a;local y=delta.Unit;local x=y:Cross(V(0,1,0)).Unit
   local at=CFrame.fromMatrix((a+b)*.5,x,y,x:Cross(y))
   add('Ancient buttress root','Cylinder',{h*.045,delta.Magnitude+h*.025,h*.060},at,wood)
   add('Old root moss','Block',{h*.027,delta.Magnitude*.67,h*.008},at*CF(0,-delta.Magnitude*.05,h*.030),moss,'Grass')
  end
  local trunk=crest
  if trunk then
   local at=CF(table.unpack(trunk.c));local w,h0,d=trunk.z[1],trunk.z[2],trunk.z[3]
   for i=1,6 do
    local a=(i-1)*math.pi/3;local frame=at*CF(math.cos(a)*w*.52,-h0*.18,math.sin(a)*d*.52)*CFrame.Angles(0,-a+math.pi/2,0)
    add('Ancient bark ridge','Block',{w*.14,h0*(.52+rand(i*61)*.18),d*.10},frame,blend(wood,{25,30,25},.15))
   end
   for i=1,5 do
    local y=(i-3)*h0*.14;local x=math.sin(i*1.7)*w*.19
    add('Ancient living rune','Block',{w*.25,h0*.025,d*.035},at*CF(x,y,d*.61)*CFrame.Angles(0,0,i%2==0 and .6 or -.6),worldroot and{137,221,154}or{240,214,158},'Neon')
   end
  end
 end
 -- Thin surface-fitted seams. Shared widths and shallow joins replace stacked plates.
 local color=id=='EmberEmperorSeed'and{224,81,17}or id=='StormSovereignSeed'and{57,167,211}or{133,80,207}
 for n,trunk in ipairs(infusions)do
  local at=CF(table.unpack(trunk.c));local w,h,d=trunk.z[1],trunk.z[2],trunk.z[3]
  for _,side in ipairs({-1,1})do
   local points={};local segments=2+math.floor(rand(n*127+side*17)*1.99)
   local width=w*(.026+rand(n*43+side*29)*.008)
   local offset=(rand(n*59+side*31)-.5)*.16*w
   local span=h*(.72+rand(n*71+side*17)*.12)
   local function surface(x,y)
    local z=trunk.s=='Cylinder'and d*.5*math.sqrt(math.max(0,1-(x/(w*.5))^2))or d*.5
    return V(x,y,side*(z+d*.0015))
   end
   for j=0,segments do
    local x=offset+(j%2==0 and -1 or 1)*w*(.035+rand(n*31+j*47)*.025)
    points[j+1]=V(x,(j/segments-.5)*span,0)
   end
   for j=1,segments do
    -- A midpoint follows curved trunks closely without making separate branch cracks.
    local steps=trunk.s=='Cylinder'and 2 or 1
    for sub=1,steps do
     local a0=points[j]:Lerp(points[j+1],(sub-1)/steps);local b0=points[j]:Lerp(points[j+1],sub/steps)
     local a,b=surface(a0.X,a0.Y),surface(b0.X,b0.Y)
     local y=(b-a).Unit;local outward=trunk.s=='Cylinder'and V((a.X+b.X)/w,0,side).Unit or V(0,0,side)
     local x=y:Cross(outward).Unit;local z=x:Cross(y);local middle=(a+b)*.5
     for layer=1,2 do
      local thickness=d*(layer==1 and .003 or .0018)
      local f=at*CFrame.fromMatrix(middle+z*(layer==1 and 0 or d*.002),x,y,z)
      table.insert(result,{s='Block',z={width*(layer==1 and 1 or .42),(b-a).Magnitude+width*.16,thickness},c={f:GetComponents()},k=layer==1 and{32,29,43}or color,g=0,r='Detail',f=layer==1 and'Element bark fissure'or'Infused bark channel',m=layer==1 and'SmoothPlastic'or'Neon',t=0,element=true,p=45})
     end
    end
   end
  end
  if id=='PrismMonarchSeed'then
   local f=at*CF(w*(rand(n*97)-.5)*.30,h*(rand(n*101)-.5)*.38,d*.68)*CFrame.Angles(-.18-rand(n*107)*.2,0,(rand(n*109)-.5)*.65)
   table.insert(result,{s='Crystal',z={w*.30,h*.32,w*.30},c={f:GetComponents()},k={160+n*12,173,247},g=0,r='Detail',f='Bark-grown prism',m='Glass',t=.12,element=true,p=45})
  end
 end
 return result
end
return Style
