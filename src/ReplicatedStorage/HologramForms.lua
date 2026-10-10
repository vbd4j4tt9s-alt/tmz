-- Pure cosmetic forms derived from saved per-fruit harvest cycles; original specs remain immutable.
-- R158d (owner: "do a mini rework on the holo melon and holo tree: use the updated melon and pumpkin meshes for the holo melon, the updated apples for the tree"):
--  * Holo Melon: the three forms are the game's real fruit shapes drawn as holograms. The melon and the cantaloupe are the Watermelon's baked mesh (FruitMeshes149, as the
--    HoloMelon158 key: the same vertices, its colours turned into brightness), the pumpkin is the Ember Pumpkin's mesh (HoloPumpkin158). Neon, translucent, in the form's
--    cyan / teal / violet; the real stem, tendril and leaf; a few thin scan rings (the cantaloupe has two more across, its netting). 7 - 9 parts a fruit instead of 36.
--  * Holo Apple Tree: each fruit is the real Apple's parts (TreeReworkArt 'AppleSeed': body, two shoulders, base tone, dimple, stem, leaf), Neon and translucent, with two scan
--    rings; the pear and the orange stretch it as before. 10 parts a fruit instead of 22.
--  If the Holo Melon's two meshes are not usable (the bake failed, or this server never baked: FruitMeshes149.UsesMesh) it keeps its R57 wire forms ('Square melon edge').
local H=require(script.Parent.HologramProjection)
local FM=require(script.Parent.FruitMeshes149)
local Trees=require(script.Parent.TreeReworkArt)
local F={};local cache,order={},{}
local function scaled(v,s)return Vector3.new(v.X*s.X,v.Y*s.Y,v.Z*s.Z)end
local function mix(a,b,t)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
local WHITE,DEEP={255,255,255},{14,30,92}
local PALETTE={[0]={96,219,255},{96,248,225},{160,166,255}} -- form 0 keeps the plant's own cyan; the cantaloupe / pear is teal, the pumpkin / orange violet
local function frameOf(rel)return CFrame.new(rel[1],rel[2],rel[3],table.unpack(rel,4,12))end

-- A new fruit part from the group's own spec (so it carries the Mech fields: group, role, mech name, hologram), Neon and translucent.
local function part(proto,n,name,shape,z,cf,k,t,mesh)
 local s=table.clone(proto);s.f=name;s.s=shape;s.z=z;s.c={cf:GetComponents()};s.k=k;s.t=t;s.m='Neon';s.hologram=true;s.mesh=mesh;s._ArtIndex=n;s.tm=nil;s.tp=nil
 return s
end
-- A thin scan ring: a flat disc through (or round) the fruit. Along X (CylinderX: z = thickness, height, depth) or along Y (Cylinder: z = width, thickness, depth).
local function ring(proto,n,cf,alongX,z,k,t)return part(proto,n,'Hologram scan ring',alongX and'CylinderX'or'Cylinder',z,cf,k,t)end

-- 1. Holo Melon: the real fruit's stem, tendril and leaf, relative to the mesh body (read off the R149 Watermelon and Ember Pumpkin art; a test compares them) ----------
local MELON={
 {'Melon stem','Cylinder',{0.2032,0.6654,0.2032},{1.9407,0.8129,0.0254,0.7657,0.6413,-0.0491,-0.6432,0.7635,-0.0585,0.0000,0.0764,0.9971},.2},
 {'Melon tendril','Cylinder',{0.0914,0.3978,0.0914},{2.3167,1.0923,-0.0610,0.1544,0.8173,0.5552,-0.9880,0.1277,0.0867,0.0000,-0.5619,0.8272},.2},
 {'Melon leaf','Ball',{0.9653,0.0711,0.5588},{1.9814,1.0364,0.4268,0.8244,0.3009,0.4794,-0.2208,0.9508,-0.2171,-0.5212,0.0731,0.8503},.35},
}
local PUMPKIN={
 {'Pumpkin stem','Cylinder',{0.4200,0.8063,0.4200},{0.0500,1.3500,0.0000,0.9923,0.1240,0.0000,-0.1240,0.9923,0.0000,0.0000,0.0000,1.0000},.2},
 {'Pumpkin stem curl','Cylinder',{0.3000,0.4855,0.3000},{0.3100,1.8350,-0.0400,0.4803,0.8651,0.1445,-0.8771,0.4738,0.0791,0.0000,-0.1648,0.9863},.2},
 {'Pumpkin leaf','Ball',{1.1500,0.0800,0.7000},{-0.7000,1.3300,0.2500,0.8989,-0.2010,0.3894,0.2726,0.9522,-0.1376,-0.3432,0.2299,0.9107},.35},
}
-- the mesh bodies' real sizes (the Watermelon rind, the Ember Pumpkin body) and the sizes the three forms draw them at
local REAL_MELON,REAL_PUMPKIN=Vector3.new(3.7595,3.0076,3.0076),Vector3.new(4.0001,2.6201,3.8565)
local BODY={
 [0]={Mesh='HoloMelon158',Name='Holo melon body',Size=REAL_MELON,Real=REAL_MELON,Parts=MELON,Rings=3},
 {Mesh='HoloMelon158',Name='Holo cantaloupe body',Size=Vector3.new(3.3,3.15,3.15),Real=REAL_MELON,Parts=MELON,Rings=3,Net=true},
 {Mesh='HoloPumpkin158',Name='Holo pumpkin body',Size=REAL_PUMPKIN*.9,Real=REAL_PUMPKIN,Parts=PUMPKIN,Rings=3,Up=true},
}
local function melonFruit(out,proto,at,form,k)
 local b=BODY[form];local size=b.Size;local n=#out
 local function add(s)n+=1;s._ArtIndex=n;table.insert(out,s)end
 add(part(proto,n,b.Name,'ApprovedMesh',{size.X,size.Y,size.Z},CFrame.new(at),mix(k,WHITE,.08),.38,b.Mesh))
 -- the real stem, tendril and leaf sit where they do on the real fruit, scaled to the drawn size
 local fx,fy,fz=size.X/b.Real.X,size.Y/b.Real.Y,size.Z/b.Real.Z;local small=math.min(fx,fy,fz)
 for _,p in ipairs(b.Parts)do
  local rel=table.clone(p[4]);rel[1]*=fx;rel[2]*=fy;rel[3]*=fz
  add(part(proto,n,p[1],p[2],{p[3][1]*small,p[3][2]*small,p[3][3]*small},CFrame.new(at)*frameOf(rel),mix(k,WHITE,p[1]:find('leaf')and .35 or .5),p[5]))
 end
 -- scan rings: slices through the fruit at -1/2, 0 and +1/2 of its length (its height for the pumpkin), a little wider than the body
 local scan=mix(k,WHITE,.3)
 for _,a in ipairs({-.5,0,.5})do
  if b.Up then
   local fall=(1-a*a)^.36*1.03
   add(ring(proto,n,CFrame.new(at+Vector3.new(0,a*size.Y/2,0)),false,{size.X*fall,.045,size.Z*fall},scan,.62))
  else
   local fall=(1-a*a)^.45*1.03
   add(ring(proto,n,CFrame.new(at+Vector3.new(a*size.X/2,0,0)),true,{.045,size.Y*fall,size.Z*fall},scan,.62))
  end
 end
 if b.Net then -- the cantaloupe's netting: a ring round it the other two ways
  add(ring(proto,n,CFrame.new(at),false,{size.X*1.03,.045,size.Z*1.03},scan,.62))
  add(ring(proto,n,CFrame.new(at)*CFrame.Angles(0,math.pi/2,0),true,{.045,size.Y*1.03,size.X*1.03},scan,.62))
 end
end

-- 2. Holo Apple Tree: the real Apple's parts relative to its body (TreeReworkArt 'AppleSeed', fruit 1; the four apples are the same) ------------------------------------------------
local appleParts
local function apple()
 if appleParts then return appleParts end
 local art=Trees.Base('AppleSeed');local body
 for _,s in ipairs(art.Specs)do if s.g==1 and s.f=='Apple body'then body=s;break end end
 local at=CFrame.new(table.unpack(body.c));local list={}
 for _,s in ipairs(art.Specs)do if s.g==1 and s.f~='Apple hanging stem'then table.insert(list,{f=s.f,s=s.s,z=s.z,rel=at:ToObjectSpace(CFrame.new(table.unpack(s.c)))})end end
 appleParts=list;return list
end
-- how the parts look: how far to lighten / deepen the form colour, and how clear
local APPLE_LOOK={['Apple body']={0,.38},['Apple shoulder']={.1,.62},['Apple base tone']={-.2,.6},['Apple dimple']={-.55,.3},['Apple stem']={.45,.15},['Apple leaf']={.4,.3}}
local function appleFruit(out,proto,at,basis,k)
 local body=CFrame.new(at)*basis;local n=#out
 for _,p in ipairs(apple())do
  local look=APPLE_LOOK[p.f]or{0,.5};local c=look[1]>=0 and mix(k,WHITE,look[1])or mix(k,DEEP,-look[1])
  n+=1;table.insert(out,part(proto,n,p.f,p.s,table.clone(p.z),body*p.rel,c,look[2]))
 end
 local z=apple()[1].z;local scan=mix(k,WHITE,.3)
 for _,dy in ipairs({-.42,.38})do -- two scan rings, a little wider than the body at that height
  local d=z[1]*math.sqrt(1-(dy/(z[2]/2))^2)*1.03;n+=1
  table.insert(out,ring(proto,n,body*CFrame.new(0,dy,0),false,{d,.045,d*z[3]/z[1]},scan,.72))
 end
end

-- The art skeleton: fruit centres, radii and the per-fruit frames / scales (the apple tree's pear is tall and narrow, its orange is wide and low).
local function skeleton(id,base,crop)
 local art=table.clone(base);art.Specs={};art.FruitCenters={};art.FruitRadii={}
 local frames,scales={},{}
 for _,s in ipairs(base.Specs)do if s.g>0 and s.f:find('Canopy apple',1,true)then frames[s.g]=CFrame.new(table.unpack(s.c)).Rotation end end
 for i,socket in ipairs(base.Sockets)do
  local form=H.Form(crop,i);local center=Vector3.new(table.unpack(base.FruitCenters[i]));local anchor=Vector3.new(table.unpack(socket))
  local scale=id=='HoloAppleTreeSeed'and(form==1 and Vector3.new(.82,1.16,.82)or form==2 and Vector3.new(1.04,.9,1.04)or Vector3.one)or Vector3.one
  local basis=frames[i]or CFrame.new();frames[i]=CFrame.new(anchor)*basis;scales[i]=scale
  local c=frames[i]*scaled(frames[i]:PointToObjectSpace(center),scale)
  art.FruitCenters[i]={c.X,c.Y,c.Z};art.FruitRadii[i]=base.FruitRadii[i]*math.max(scale.X,scale.Y,scale.Z)
 end
 return art,frames,scales
end
-- Stretch a spec in the original fruit's axes so its parts stay together (the pear / orange).
local function stretch(s,frame,scale)
 local cf=CFrame.new(table.unpack(s.c));local relative=frame:ToObjectSpace(cf)
 local axes={relative.RightVector,relative.UpVector,-relative.LookVector}
 for a=1,3 do s.z[a]*=scaled(axes[a],scale).Magnitude end
 local point=frame*scaled(relative.Position,scale);s.c[1]=point.X;s.c[2]=point.Y;s.c[3]=point.Z
end

local function appleTree(id,base,crop)
 local art,frames,scales=skeleton(id,base,crop)
 local first={}
 for _,source in ipairs(base.Specs)do
  if source.g==0 then
   local s=table.clone(source);s.hologram=not s.mechFixed;s.z=table.clone(source.z);s.c=table.clone(source.c);table.insert(art.Specs,s)
  else
   first[source.g]=first[source.g]or source
   if source.f:find('hanging stem',1,true)then -- the stem that joins the apple to the crown stays where it was authored (only the pear / orange form stretch it)
    local s=table.clone(source);s.hologram=true;s.z=table.clone(source.z);s.c=table.clone(source.c)
    local form=H.Form(crop,s.g)
    if form>0 then
     s.k=table.clone(PALETTE[form]);stretch(s,frames[s.g],scales[s.g]);s.f=s.f:gsub('apple',form==1 and'pear'or'orange'):gsub('Apple',form==1 and'Pear'or'Orange')
    end
    table.insert(art.Specs,s)
   end
  end
 end
 for g=1,#base.Sockets do
  local proto=first[g];local form=H.Form(crop,g);local k=PALETTE[form]
  local canopy;for _,source in ipairs(base.Specs)do if source.g==g and source.f:find('Canopy apple',1,true)then canopy=source;break end end
  local at=Vector3.new(canopy.c[1],canopy.c[2],canopy.c[3])
  local from=#art.Specs;appleFruit(art.Specs,proto,at,CFrame.new(table.unpack(canopy.c)).Rotation,k)
  if form>0 then for i=from+1,#art.Specs do
   local s=art.Specs[i];stretch(s,frames[g],scales[g]);s.f=s.f:gsub('apple',form==1 and'pear'or'orange'):gsub('Apple',form==1 and'Pear'or'Orange')
  end end
 end
 return art
end

local function melon(id,base,crop)
 local art=skeleton(id,base,crop);local form=H.Form(crop,1)
 local proto
 for _,source in ipairs(base.Specs)do
  if source.g==0 then
   local s=table.clone(source);s.hologram=not s.mechFixed;s.z=table.clone(source.z);s.c=table.clone(source.c);table.insert(art.Specs,s)
  elseif not proto then proto=source end
 end
 melonFruit(art.Specs,proto,Vector3.new(table.unpack(base.Sockets[1])),form,PALETTE[form])
 return art
end

-- R57's square wire forms: what the Holo Melon keeps when its meshes cannot be used.
local function wire(id,base,crop)
 local art,frames=skeleton(id,base,crop)
 for _,source in ipairs(base.Specs)do
  local s=table.clone(source);s.hologram=not s.mechFixed;s.z=table.clone(source.z);s.c=table.clone(source.c)
  local form=s.g>0 and H.Form(crop,s.g)or 0
  if s.g>0 and form>0 then
   s.k=table.clone(PALETTE[form])
   if s.f=='Hologram stripe'then
    -- Thin netting for cantaloupe; broad ribs for the square pumpkin.
    if form==1 then
     s.z[1]*=.45
    else for a=1,3 do if s.z[a]<.12 then s.z[a]*=1.7 end end;s.f='Pumpkin projection rib'end
   elseif s.f=='Square melon edge'then s.f=form==1 and'Square cantaloupe edge'or'Square pumpkin edge'
   elseif s.f:find('Fruit stem',1,true)and form==2 then s.z[1]*=1.25;s.z[3]*=1.25 end
  end
  table.insert(art.Specs,s)
 end
 if H.Form(crop,1)==1 then
  local anchor=Vector3.new(table.unpack(base.Sockets[1]));local half=Vector3.zero;local template
  for _,s in ipairs(base.Specs)do
   if s.f=='Square melon edge'then local d=Vector3.new(table.unpack(s.c,1,3))-anchor;half=Vector3.new(math.max(half.X,math.abs(d.X)),math.max(half.Y,math.abs(d.Y)),math.max(half.Z,math.abs(d.Z)))end
   if s.f=='Hologram stripe'then template=s end
  end
  if template then for _,offset in ipairs({-.45,.4})do for face=1,3 do
   local scan=table.clone(template);scan.hologram=true;scan.f='Cantaloupe cross scan';scan.k=table.clone(PALETTE[1])
   local top=face==3;scan.z=top and{half.X*1.94,.034,.055}or{half.X*1.94,.055,.034}
   local point=anchor+Vector3.new(0,top and half.Y-.013 or half.Y*offset,top and half.Z*offset or(face==1 and -1 or 1)*(half.Z-.013))
   scan.c={CFrame.new(point):GetComponents()};table.insert(art.Specs,scan)
  end end end
 end
 return art
end

function F.Get(id,base,crop)
 if not H.Is(id)then return base end
 -- (the key carries the Holo Melon's mesh choice, like PlantVisuals' spec key: a server whose bake failed never reuses the mesh forms)
 local meshes=id=='HoloMelonSeed'and FM.UsesMesh(id)
 local key=H.Key(id,crop)..(meshes and''or id=='HoloMelonSeed'and'|wire'or'');if cache[key]then return cache[key]end
 local art=id=='HoloAppleTreeSeed'and appleTree(id,base,crop)or meshes and melon(id,base,crop)or wire(id,base,crop)
 cache[key]=art;table.insert(order,key);if #order>32 then cache[table.remove(order,1)]=nil end
 return art
end
return F
