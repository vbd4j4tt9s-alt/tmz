-- V091 sparse, asymmetric scenery. Decorations never become invisible blockers.
local Design={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local green=RGB(63,127,52);local wood=RGB(103,76,49);local stone=RGB(91,102,109)
local function part(parent,name,size,cf,color,kind,material)
 local p=Instance.new(kind=='W' and 'WedgePart' or 'Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
 p.Material=material or Enum.Material.Plastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if kind=='C' then p.Shape=Enum.PartType.Cylinder end
 p.Parent=parent;return p
end
local function link(parent,name,a,b,width,color,material)
 return part(parent,name,V(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,nil,material)
end
local function leaves(parent,cf,scale,color)
 for i=1,3 do part(parent,'Leaves',V(7-i,2.2,5-i)*scale,cf*CF((i-2)*2*scale,i*1.4*scale,0)*CFrame.Angles(0,i*.5,0),color)end
end
local function pine(parent,pos,scale)
 part(parent,'Pine trunk',V(1.3,9,1.3)*scale,CF(pos+V(0,4.5*scale,0)),wood)
 for i=1,3 do
  part(parent,'Pine branches',V(9-i*1.7,6,9-i*1.7)*scale,CF(pos+V(0,(3+i*3)*scale,0))*CFrame.Angles(0,i*.5,0),RGB(48,97,82),'W')
  part(parent,'Snow on branches',V(8-i*1.7,1,7-i*1.5)*scale,CF(pos+V(0,(5+i*3)*scale,0))*CFrame.Angles(0,i*.5,0),RGB(229,242,244),'W')
 end
end
function Design.Biome(stage,start,length)
 local model=Instance.new('Model');model.Name='BiomeDesignV091';model:SetAttribute('Stage',stage);model:SetAttribute('VisualVersion',91)
 local walls=Instance.new('Folder');walls.Name='WallDesign';walls.Parent=model
 local extra=Instance.new('Folder');extra.Name='GroundDetails';extra.Parent=model
 local function group(parent,name)local f=Instance.new('Model');f.Name=name;f.Parent=parent;return f end
 local function p(parent,name,s,x,y,z,c,k,rot)
  return part(parent,name,s,CF(x,y,start+z)*CFrame.Angles(table.unpack(rot or {0,0,0})),c,k)
 end
 -- Two unequal wall features per biome. Never a length-based strip or mirrored stamp.
 if stage==1 then
  local a=group(walls,'Roots and one leafy branch')
  link(a,'Crooked root',V(-88,5,start+length*.23),V(-87.2,21,start+length*.23-3),1.65,wood)
  link(a,'One branch',V(-87.2,20,start+length*.23-3),V(-84.8,27,start+length*.23+5),1.15,wood)
  leaves(a,CF(-85.5,26,start+length*.23+4),1.35,green)
  local b=group(walls,'Small vine')
  local pts={V(88,32,start+length*.78),V(87.4,26,start+length*.78+2),V(87.4,21,start+length*.78-1)}
  for i=1,2 do link(b,'Vine',pts[i],pts[i+1],.38,green)end
  part(b,'Single leaf',V(.4,2.5,3.5),CF(87.2,24,start+length*.78+1)*CFrame.Angles(.6,0,0),RGB(83,143,52),'W')
  local c=group(extra,'Fallen log and two mushrooms')
  p(c,'Fallen log',V(3,3,12),72,6.5,length*.68,wood,nil,{0,.53,0})
  for _,n in ipairs({{65,3},{68,5}})do
   p(c,'Stem',V(.6,1.4,.6),n[1],5.7,length*.68+n[2],RGB(223,210,168))
   p(c,'Cap',V(2.2,.7,2.2),n[1],6.6,length*.68+n[2],RGB(171,66,45))
  end
 elseif stage==2 then
  local a=group(walls,'One wind cut')
  p(a,'Sand shelf',V(2.1,2.4,22),-87.8,14,length*.29,RGB(222,186,110),'W',{.13,0,0})
  p(a,'Broken shelf end',V(1.3,1.1,8),-87.3,16,length*.29+12,RGB(239,204,135),'W',{-.25,0,0})
  local b=group(walls,'Low sandstone corner')
  p(b,'Sandstone foot',V(3.5,8,14),87,9,length*.82,RGB(212,172,96),'W',{-.12,0,0})
 elseif stage==3 then
  local a=group(walls,'One snow shelf')
  p(a,'Snow shelf',V(4,1.7,23),-87,31,length*.24,RGB(234,243,244))
  for _,d in ipairs({{-7,5},{-2,3},{6,7}})do p(a,'Icicle',V(1.05,d[2],1.7),-85.6,30-d[2]/2,length*.24+d[1],RGB(179,217,235),'W',{math.pi,0,0})end
  local b=group(walls,'Low ice seam')
  p(b,'Ice foot',V(3.5,12,16),87,11,length*.73,RGB(162,200,216),'W',{.18,0,0})
  p(b,'Small snow drift',V(5,2,10),85,6,length*.73+8,RGB(228,240,244),'W',{0,.2,0})
  local c=group(extra,'Two uneven pines');pine(c,V(-73,5,start+length*.79),1.1);pine(c,V(-66,5,start+length*.79+10),.68)
 elseif stage==4 then
  local a=group(walls,'Single lava fault')
  p(a,'Dark rock shoulder',V(3.8,19,18),-87,14,length*.31,RGB(49,44,47),'W',{.14,0,0})
  local pts={V(-84.8,29,start+length*.31-4),V(-84.8,20,start+length*.31+2),V(-84.8,11,start+length*.31-1)}
  for i=1,2 do link(a,'Hot fault',pts[i],pts[i+1],.45,RGB(232,92,29),Enum.Material.Neon)end
  local b=group(walls,'Broken basalt foot');p(b,'Basalt foot',V(4,9,16),87,9,length*.8,RGB(62,54,54),'W',{-.17,0,0})
  local c=group(extra,'One short lava stream')
  local pts={V(-70,5.05,start+length*.22),V(-62,5.05,start+length*.29),V(-64,5.05,start+length*.38),V(-54,5.05,start+length*.45),V(-58,5.05,start+length*.53)}
  for i=1,#pts-1 do
   local cf=CFrame.lookAt((pts[i]+pts[i+1])/2,pts[i+1]);local len=(pts[i+1]-pts[i]).Magnitude
   part(c,'Lava bank',V(7.5,.12,len+1),cf,RGB(55,39,35))
   part(c,'Lava stream',V(5,.13,len+.25),cf*CF(0,.1,0),RGB(218,69,24),nil,Enum.Material.Neon)
   local glow=part(c,'Flowing lava',V(1.8,.08,2.5),cf*CF(0,.22,0),RGB(255,177,52),nil,Enum.Material.Neon)
   glow:SetAttribute('LavaFlowFrame',cf*CF(0,.22,0));glow:SetAttribute('LavaFlowLength',len);glow:SetAttribute('LavaFlowPhase',i*.37)
  end
 elseif stage==5 then
  local a=group(walls,'One crystal pocket')
  for _,d in ipairs({{-5,6,2.3},{0,12,3},{5,8,2.1}})do p(a,'Crystal shard',V(2.5,d[2],d[3]),-87,8+d[2]/2,length*.3+d[1],RGB(146,100,190),'W',{.2,0,-.12})end
  local b=group(walls,'Small pale vein')
  link(b,'Pale seam',V(87.8,10,start+length*.8-5),V(87.8,16,start+length*.8+4),.28,RGB(143,192,207))
 elseif stage==6 then
  local a=group(walls,'Broken mossy arch')
  p(a,'Tall pillar',V(3.3,19,4),-87,14.5,length*.2,stone)
  p(a,'Short pillar',V(3.3,9,4),-87,9.5,length*.2+16,stone)
  p(a,'Broken lintel',V(3.6,3.6,11),-87,24,length*.2+3.5,RGB(111,119,101),'W',{0,0,0})
  p(a,'Moss cap',V(3.8,.5,7),-87,26,length*.2+2,green)
  local b=group(walls,'Two hanging vines')
  for _,d in ipairs({{0,11},{5,6}})do
   local pts={V(88,34,start+length*.77+d[1]),V(87.4,29,start+length*.77+d[1]-1),V(87.4,34-d[2],start+length*.77+d[1]+2)}
   for i=1,2 do link(b,'Loose vine',pts[i],pts[i+1],.48,green)end
  end
  local c=group(extra,'One jungle tree')
  p(c,'Jungle trunk',V(3,16,3),74,13,length*.27,wood);leaves(c,CF(74,21,start+length*.27),2,RGB(39,100,54))
  p(c,'Broad fern',V(1,4,7),66,7,length*.27+5,green,'W',{.2,.7,.3})
  local d=group(extra,'Small moss ruin')
  p(d,'Ruin step',V(20,2,16),-69,6,length*.71,stone)
  p(d,'Broken column',V(5,8,5),-74,11,length*.71+3,RGB(112,120,102))
  p(d,'Moss on column',V(5.4,.5,5.4),-74,15.3,length*.71+3,green)
  p(d,'Fallen block',V(6,4,5),-63,8,length*.71-3,stone,nil,{0,.4,.2})
 else
  local a=group(walls,'One high rocky ledge')
  p(a,'Slanted ledge',V(4,8,20),-87,26,length*.25,RGB(70,88,112),'W',{.15,0,0})
  p(a,'Cloud lip',V(4.5,1.4,13),-86.7,31,length*.25-2,RGB(162,181,200))
  local b=group(walls,'Short storm split')
  local pts={V(87.4,21,start+length*.76-3),V(87.4,15,start+length*.76+1),V(87.4,11,start+length*.76-1)}
  for i=1,2 do link(b,'Storm seam',pts[i],pts[i+1],.3,RGB(131,172,204))end
  local c=group(extra,'One stone perch')
  p(c,'Wide foot',V(20,3,16),-68,6.5,length*.6,RGB(65,79,96))
  p(c,'High rock',V(11,16,12),-73,15,length*.6+3,RGB(95,116,139),'W',{0,.25,0})
  p(c,'Lower rock',V(9,9,10),-63,11,length*.6-2,RGB(113,132,151),'W',{0,-.3,0})
  p(c,'One cloud cap',V(10,1.3,7),-73,23.6,length*.6+2,RGB(179,197,211))
 end
 return model
end
function Design.Garden(pad)
 local folder=Instance.new('Folder');folder.Name='PerimeterFence'
 local cream=RGB(219,204,162);local trim=RGB(114,95,64)
 local function p(name,size,position,c)
  local v=part(folder,name,size,pad.CFrame*CF(position),c)
  v.CanCollide=false;v.CanQuery=false;return v
 end
 for _,side in ipairs({-1,1}) do
  for z=-86,82,14 do
   p('Fence post',V(1.5,4.2,1.5),V(side*58.2,2.6,z),trim)
   p('Post cap',V(2,.5,2),V(side*58.2,4.95,z),cream)
  end
  for _,y in ipairs({1.8,3.5})do p('Side rail',V(.7,.65,176),V(side*58.2,y,0),cream)end
 end
 for _,z in ipairs({-88.5,88.5})do
  for x=-56,56,14 do if z<0 or math.abs(x)>=21 then
   p('Fence post',V(1.5,4.2,1.5),V(x,2.6,z),trim);p('Post cap',V(2,.5,2),V(x,4.95,z),cream)
  end end
  for _,y in ipairs({1.8,3.5})do
   if z<0 then p('Back rail',V(116,.65,.7),V(0,y,z),cream)
   else for _,s in ipairs({-1,1})do p('Entry rail',V(36,.65,.7),V(s*40,y,z),cream)end end
  end
 end
 -- R95: the entrance stays open, without posts, a beam or a roof.

 -- Keep the aisle, beds, treadmill, spawn and crop offsets clear.
 for _,side in ipairs({-1,1})do
  local base=pad.CFrame*CF(side*49,1,74)
  local box=part(folder,'Tool box',V(7,3,5),base*CF(0,1.5,0),RGB(159,112,57));box.CanCollide=false;box.CanQuery=false
  part(folder,'Box rim',V(7.5,.5,5.5),base*CF(0,3,0),cream)
  part(folder,'Watering can',V(2.4,2.3,2.4),base*CF(0,4.3,0),RGB(83,139,162))
  link(folder,'Can spout',(base*CF(1.2,4,0)).Position,(base*CF(2.8,5,0)).Position,.6,RGB(83,139,162))
 end
 return folder
end
return Design
