-- Pure cosmetic forms derived from saved per-fruit harvest cycles; original specs remain immutable.
local H=require(script.Parent.HologramProjection)
local F={};local cache,order={},{}
local function scaled(v,s)return Vector3.new(v.X*s.X,v.Y*s.Y,v.Z*s.Z)end
function F.Get(id,base,crop)
 if not H.Is(id)then return base end
 local key=H.Key(id,crop);if cache[key]then return cache[key]end
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
 for _,source in ipairs(base.Specs)do
  local s=table.clone(source);s.hologram=not s.mechFixed;s.z=table.clone(source.z);s.c=table.clone(source.c)
  local form=s.g>0 and H.Form(crop,s.g)or 0
  if s.g>0 and form>0 then
   local palette=form==1 and{96,248,225}or{160,166,255};s.k=palette
   if id=='HoloAppleTreeSeed'then
    -- Stretch in the original fruit's axes so rotated wire edges still meet at the corners.
    local frame,scale=frames[s.g],scales[s.g];local cf=CFrame.new(table.unpack(s.c));local relative=frame:ToObjectSpace(cf)
    local axes={relative.RightVector,relative.UpVector,-relative.LookVector}
    for a=1,3 do s.z[a]*=scaled(axes[a],scale).Magnitude end
    local point=frame*scaled(relative.Position,scale);s.c[1]=point.X;s.c[2]=point.Y;s.c[3]=point.Z
    if s.f:find('outline',1,true)then for a=1,3 do if source.z[a]<.08 then s.z[a]*=form==1 and .85 or 1.25 end end end
    s.f=s.f:gsub('apple',form==1 and'pear'or'orange'):gsub('Apple',form==1 and'Pear'or'Orange')
   else
    if s.f=='Hologram stripe'then
     -- Thin netting for cantaloupe; broad ribs for the square pumpkin.
     if form==1 then
      s.z[1]*=.45
     else for a=1,3 do if s.z[a]<.12 then s.z[a]*=1.7 end end;s.f='Pumpkin projection rib'end
    elseif s.f=='Square melon edge'then s.f=form==1 and'Square cantaloupe edge'or'Square pumpkin edge'
    elseif s.f:find('Fruit stem',1,true)and form==2 then s.z[1]*=1.25;s.z[3]*=1.25 end
   end
  end
  table.insert(art.Specs,s)
 end
 if id=='HoloMelonSeed'and H.Form(crop,1)==1 then
  local anchor=Vector3.new(table.unpack(base.Sockets[1]));local half=Vector3.zero;local template
  for _,s in ipairs(base.Specs)do
   if s.f=='Square melon edge'then local d=Vector3.new(table.unpack(s.c,1,3))-anchor;half=Vector3.new(math.max(half.X,math.abs(d.X)),math.max(half.Y,math.abs(d.Y)),math.max(half.Z,math.abs(d.Z)))end
   if s.f=='Hologram stripe'then template=s end
  end
  if template then for _,offset in ipairs({-.45,.4})do for face=1,3 do
   local scan=table.clone(template);scan.hologram=true;scan.f='Cantaloupe cross scan';scan.k={96,248,225}
   local top=face==3;scan.z=top and{half.X*1.94,.034,.055}or{half.X*1.94,.055,.034}
   local point=anchor+Vector3.new(0,top and half.Y-.013 or half.Y*offset,top and half.Z*offset or(face==1 and -1 or 1)*(half.Z-.013))
   scan.c={CFrame.new(point):GetComponents()};table.insert(art.Specs,scan)
  end end end
 end
 cache[key]=art;table.insert(order,key);if #order>32 then cache[table.remove(order,1)]=nil end
 return art
end
return F
