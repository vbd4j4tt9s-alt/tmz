-- Elderbloom retains its ancient tree; each old flower cluster becomes one apple.
local A={}
function A.Convert(source)
 local d=table.clone(source);d.Specs={};d.FruitCenters={};d.FruitRadii={}
 for _,s in ipairs(source.Specs)do if(s.g or 0)==0 then table.insert(d.Specs,s)end end
 for i,socket in ipairs(source.Sockets)do
  local origin=CFrame.new(table.unpack(socket));local center=origin*Vector3.new(0,-.61,0)
  d.FruitCenters[i]={center.X,center.Y,center.Z};d.FruitRadii[i]=1.0
  local function piece(name,shape,pos,size,color,material,rotation)
   local at=origin*CFrame.new(table.unpack(pos))*(rotation or CFrame.new())
   table.insert(d.Specs,{s=shape,r='Fruit',g=i,p=80,f=name,z=size,k=color,m=material or'SmoothPlastic',t=0,c={at:GetComponents()}})
  end
  piece('Elder apple','Block',{0,-.62,0},{1.03,.86,.96},{126,169,79})
  piece('Apple shaded base','Block',{0,-1.02,0},{.80,.18,.76},{85,126,56})
  piece('Apple shoulder left','Ball',{-.26,-.24,0},{.56,.26,.92},{161,194,99})
  piece('Apple shoulder right','Ball',{.26,-.24,0},{.56,.26,.92},{153,185,88})
  piece('Apple stem','Cylinder',{0,-.08,0},{.10,.22,.10},{101,72,46},'Wood')
  piece('Apple leaf','LeafBlade',{.25,-.08,.03},{.23,.50,.06},{80,133,71},nil,CFrame.Angles(0,0,-1.05))
  piece('Ancient apple rune','Block',{0,-.54,-.485},{.08,.27,.018},{255,225,138},'Neon')
  piece('Ancient apple rune cross','Block',{0,-.48,-.486},{.21,.06,.018},{255,225,138},'Neon')
  for j=1,3 do piece('Golden apple fleck','Block',{-.35+j*.17,-.77+(j%2)*.08,-.488},{.035,.055,.012},{222,208,131})end
 end
 return d
end
return A
