--!nocheck
-- R149: computes the new fruit specs of the seven redesigned fruit in the AUTHORED coordinates of each art module, from the BASE
-- commit's art (so the result never depends on what the checkout already holds). Run on the Roblox mock by port_fruit_models.sh;
-- prints PLAN rows that port_fruit_models.py turns into text edits of the art modules.
--   PLAN <module file> <key> <design> <group> <keep names, comma separated> <spec literals joined with ASCII 31 (one per spec)>
-- <key> is the seed id (PlantArt*), "-" for a single-plant module (TreeReworkData*, ApprovedPlantArt6). Spec literals use the module's own
-- style: PlantArt* lines are {s="Ball",z={..},...}; the others are {["z"]={..},["c"]={..},...,["_ArtIndex"]=n} (new indices continue after the
-- module's highest, so every untouched spec keeps its number).
-- Sizes / positions: PlantArt* modules are authored at 1/BaseScale (PlantVisuals.Specs multiplies by the catalog's BaseScale); the
-- Prickly Pear is authored at half size around its socket (ApprovedPlantArt.Get grows the fruit x2 around its socket, the rest x3);
-- the tree modules are final size.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Catalog=W.module('PlantCatalog');local D=W.module('FruitDesigns149')
local function num(v)
 local s=string.format('%.5f',v);s=s:gsub('0+$',''):gsub('%.$','');if s=='-0'or s==''then s='0'end;return s
end
local function arr(t)local o={};for i,v in ipairs(t)do o[i]=num(v)end;return '{'..table.concat(o,',')..'}'end
local function rgb(t)local o={};for i,v in ipairs(t)do o[i]=string.format('%d',math.floor(v+.5))end;return '{'..table.concat(o,',')..'}'end
-- literal of a spec in a module's style
local function literalA(s,p)
 local o={'s="'..s.s..'"','z='..arr(s.z),'c='..arr(s.c),'k='..rgb(s.k),'g='..s.g,'r="'..s.r..'"','f="'..s.f..'"','t='..num(s.t),'m="'..s.m..'"','p='..p}
 if s.tx then table.insert(o,'tx="'..s.tx..'"')end
 if s.decor then table.insert(o,'decor=true')end
 if s.rf then table.insert(o,'rf='..num(s.rf))end
 if s.canopy then table.insert(o,'canopy='..s.canopy);table.insert(o,'cd='..arr(s.cd))end
 return '{'..table.concat(o,',')..'}'
end
local function literalB(s,index,shaded)
 local o={'["z"]='..arr(s.z),'["c"]='..arr(s.c),'["t"]='..num(s.t),'["m"]="'..s.m..'"','["g"]='..s.g,'["k"]='..rgb(s.k),'["f"]="'..s.f..'"','["s"]="'..s.s..'"','["_ArtIndex"]='..index,'["r"]="'..s.r..'"'}
 if shaded then table.insert(o,'["shaded"]=true')end
 if s.tx then table.insert(o,'["tx"]="'..s.tx..'"')end
 if s.decor then table.insert(o,'["decor"]=true')end
 if s.rf then table.insert(o,'["rf"]='..num(s.rf))end
 return '{'..table.concat(o,',')..'}'
end
local function rotOf(c)local t={};for i=4,12 do t[#t+1]=c[i]end;return t end
local function first(list,g,name)for _,s in ipairs(list)do if s.g==g and s.f==name then return s end end end
local function all(list,g,name)local o={};for _,s in ipairs(list)do if s.g==g and s.f==name then o[#o+1]=s end end;return o end
local function copy(list)local o={};for i,s in ipairs(list)do local t=table.clone(s);t.z=table.clone(s.z);t.c=table.clone(s.c);t.k=table.clone(s.k);o[i]=t end;return o end
local SEP=string.char(31)
local function emit(file,key,design,group,keep,lits)
 print(table.concat({'PLAN',file,key,tostring(design),tostring(group),table.concat(keep,','),table.concat(lits,SEP)},'\t'))
end
local function maxIndex(specs)local m=0;for _,s in ipairs(specs)do m=math.max(m,s._ArtIndex or 0)end;return m end

-- PlantArt* modules: Watermelon, Snow Melon, Ember Pumpkin, Blueberry, Iceberry ------------------------------------------------------------
local function plantArt(file,id,design,bodyName,groundKey,keep,anchorMode)
 local raw=W.module(file)[id];local BS=Catalog[id].BaseScale
 for g=1,Catalog[id].FruitCount do
  local old;local oldTop,oldHalf
  local lits={}
  local specs=design()
  local p0=(anchorMode=='berries')
  -- the old body: its centre (final studs) and, for ground fruit, its half height
  local centre,half
  if anchorMode=='berries'then
   local bs=all(raw,g,'Berry');local sx,sy,sz,d=0,0,0,0
   for _,s in ipairs(bs)do sx+=s.c[1];sy+=s.c[2];sz+=s.c[3];d+=s.z[1]end
   centre=V3(sx,sy,sz)/#bs*BS;local k=(d/#bs*BS)/.767 -- the three berries' mean diameter against the design's
   D.fit(specs,k)
   -- the design's own berry centroid goes on the old berries' centroid
   local bsum=V3(0,0,0);local n=0;for _,s in ipairs(specs)do if s.f=='Berry'then bsum+=V3(s.c[1],s.c[2],s.c[3]);n+=1 end end
   centre=centre-bsum/n
  elseif anchorMode=='lobes'then
   local bs=all(raw,g,'Pumpkin lobe');local sx,sz=0,0;local ys,tall=0,0
   for _,s in ipairs(bs)do sx+=s.c[1];sz+=s.c[3];ys+=s.c[2];tall=s.z[2]end
   half=tall*BS/2;centre=V3(sx/#bs*BS,ys/#bs*BS,sz/#bs*BS)
   local k=tall*BS/3.065 -- the second pumpkin of the vine is the small one: the design scales with the old body (3.065 = the big one's height)
   D.fit(specs,k);centre=centre+V3(0,-half+D.BodyHalf[groundKey]*k,0)
  else
   old=first(raw,g,'Rind');half=old.z[2]*BS/2
   if groundKey=='SnowMelon'or groundKey=='Watermelon'then D.fit(specs,old.z[1]*BS/3.7);centre=V3(old.c[1],old.c[2],old.c[3])*BS+V3(0,-half+D.BodyHalf[groundKey]*(old.z[1]*BS/3.7),0)end
  end
  local first_berry=true
  for _,s in ipairs(specs)do
   s.g=g
   local c=V3(s.c[1],s.c[2],s.c[3])+centre
   s.c={c.X/BS,c.Y/BS,c.Z/BS,table.unpack(rotOf(s.c))};s.z={s.z[1]/BS,s.z[2]/BS,s.z[3]/BS}
   if anchorMode=='berries'and s.f=='Berry'and first_berry then
    first_berry=false;local old1=first(raw,g,'Berry');s.canopy=old1.canopy;s.cd=old1.cd
   end
   local pr=s.f:find('body')and 120 or s.f:find('stem')and 110 or 100
   if s.s=='Cylinder'then pr=110 elseif s.f:find('glint')or s.f:find('gloss')then pr=60 end
   table.insert(lits,literalA(s,pr))
  end
  emit(file,id,0,g,keep,lits)
 end
end
plantArt('PlantArtForest','SunflowerSeed',D.Watermelon,'Rind','Watermelon',{'Fruit stem'},'rind')
plantArt('PlantArtSnow','SnowdropSeed',D.SnowMelon,'Rind','SnowMelon',{'Fruit stem'},'rind')
plantArt('PlantArtLava','EmberBloomSeed',D.EmberPumpkin,'Pumpkin lobe','EmberPumpkin',{'Fruit stem'},'lobes')
plantArt('PlantArtForest','BluebellSeed',D.Blueberry,'Berry',nil,{},'berries')
plantArt('PlantArtSnow','IceberrySeed',D.Iceberry,'Berry',nil,{},'berries')

-- Tree modules (final size): Apple, Elderbloom's elder apple ------------------------------------------------------------------------------
local function tree(file,design,bodyName,keep,refWidth)
 local art=W.module(file);local next_=maxIndex(art.Specs)
 for g=1,#art.Sockets do
  local body=first(art.Specs,g,bodyName);local centre=V3(body.c[1],body.c[2],body.c[3])
  local lits={}
  -- each fruit keeps its own size: the design (refWidth wide) scales to the old body's mean width
  for _,s in ipairs(D.fit(design(),math.sqrt(body.z[1]*body.z[3])/refWidth))do
   s.g=g;local c=V3(s.c[1],s.c[2],s.c[3])+centre
   s.c={c.X,c.Y,c.Z,table.unpack(rotOf(s.c))};next_+=1
   table.insert(lits,literalB(s,next_,true))
  end
  emit(file,'-',1,g,keep,lits)
 end
end
tree('TreeReworkData2',D.Apple,'Canopy apple',{'Apple hanging stem'},2.3)
tree('TreeReworkData4',D.ElderApple,'Elder apple',{},1.035)

-- Prickly Pear (ApprovedPlantArt6, two designs): authored at half size around the socket ---------------------------------------------------
-- NOT ported any more: after fruit_models_built.png the owner said "keep prickly pear as it is", so ApprovedPlantArt6 stays the base's.
-- The block is kept: flip the `if` to bring the R149 barrel back.
if false then
 local designs=W.module('ApprovedPlantArt6');local next_=0
 for _,d in ipairs(designs)do next_=math.max(next_,maxIndex(d.Specs))end
 for di,d in ipairs(designs)do
  for g=1,#d.Sockets do
   local body=first(d.Specs,g,'Cactus pear');local S=V3(table.unpack(d.Sockets[g]))
   local halfOld=body.z[2]*2/2 -- final half height (the fruit is grown x2 about its socket)
   local fa=V3(body.c[1],body.c[2],body.c[3]);local final=S*3+(fa-S)*2
   local k=body.z[1]*2/2.51 -- 2.51 = the big pears' width (final studs): a smaller pear scales the design down
   local centre=final+V3(0,-halfOld+D.BodyHalf.PricklyPear*k,0)
   local lits={}
   for _,s in ipairs(D.fit(D.PricklyPear(),k))do
    s.g=g;local f=V3(s.c[1],s.c[2],s.c[3])+centre
    local a=S+(f-S*3)/2
    s.c={a.X,a.Y,a.Z,table.unpack(rotOf(s.c))};s.z={s.z[1]/2,s.z[2]/2,s.z[3]/2};next_+=1
    table.insert(lits,literalB(s,next_,false))
   end
   emit('ApprovedPlantArt6','-',di,g,{'Upper surface fruit attachment'},lits)
  end
 end
end
