-- Native, pooled cosmetic pieces: dripping water, frost, arcs and mechanical scanner teeth.
local E={};local W=require(script.Parent.WeatherTraits)
local function part(parent,name,color,shape)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.one*.1;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=color;p.Transparency=1
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
function E.New(parent,weather,mech)
 local e={Weather=W.Key(weather),Mech=mech,Parts={},Layers={}};local folder=Instance.new('Folder');folder.Name='ItemCosmetics';folder.Parent=parent;e.Folder=folder
 -- Each trait keeps its own animation and colour; coats and rarity auras remain untouched.
 for _,key in ipairs(W.List(e.Weather))do
  local layer={Weather=key,Parts={}};table.insert(e.Layers,layer)
  for i=1,8 do
   local p=part(folder,key,W.Traits[key].Color,key=='Drippy'and Enum.PartType.Ball or nil)
   table.insert(layer.Parts,p);table.insert(e.Parts,p)
  end
 end
 if mech then e.Gears={};for i=1,12 do e.Gears[i]=part(folder,'Mechanical scanner',i%3==0 and Color3.fromRGB(255,186,76)or Color3.fromRGB(67,223,255))end end
 return e
end
local function move(p,frame,batch)
 if batch then batch:Set(p,frame)else p.CFrame=frame end
end
local function line(p,a,b,width,batch)
 p.Size=Vector3.new(width,width,(b-a).Magnitude);move(p,CFrame.lookAt((a+b)/2,b),batch)
end
-- Weather sizes and scanner widths depend on radius, not animation time.
local function sizeParts(e,radius,thickness)
 if e.SizedRadius==radius then return end;e.SizedRadius=radius
 for _,layer in ipairs(e.Layers)do for _,p in ipairs(layer.Parts)do
  if layer.Weather=='Drippy'then p.Size=Vector3.new(thickness,thickness*3.2,thickness)
  elseif layer.Weather=='Frosted'then p.Size=Vector3.new(thickness*2.2,thickness*.35,thickness*2.2)end
 end end
 for i,p in ipairs(e.Gears or{})do p.Size=i<=10 and Vector3.new(thickness*1.5,thickness*.75,thickness*3.4)or Vector3.new(radius*1.55,thickness*.6,thickness*.6)end
end
function E.Step(e,frame,radius,height,t,opacity,batch)
 radius=math.clamp(radius or 1,.2,35);height=math.clamp(height or radius*2,.3,60);opacity=opacity or 1
 local thickness=math.clamp(radius*.055,.055,.32);sizeParts(e,radius,thickness)
 for _,layer in ipairs(e.Layers)do for i,p in ipairs(layer.Parts)do
  local weather=layer.Weather
  local a=i*2.39996;local phase=(t*.85+i*.137)%1
  if weather=='Drippy'then
   move(p,frame*CFrame.new(math.cos(a)*radius*.82,height*.45-phase*height*.95,math.sin(a)*radius*.82),batch)
   p.Transparency=1-(.65*math.sin(math.pi*phase))*opacity
  elseif weather=='Frosted'then
   local r=radius*(.92+.06*math.sin(t+i))
   move(p,frame*CFrame.new(math.cos(a+t*.11)*r,math.sin(a*2)*height*.38,math.sin(a+t*.11)*r)*CFrame.Angles(.3,t*.4+i,math.pi/4),batch)
   p.Transparency=1-(.55+.2*math.sin(t*1.1+i))*opacity
  else
   local pulse=(t*.55)%1;local on=pulse<.30;local theta=(i-1)*math.pi/4+t*.07
   if on then
    local a0=frame*Vector3.new(math.cos(theta)*radius*.9,math.sin(theta*2)*height*.27,math.sin(theta)*radius*.9)
    local a1=frame*Vector3.new(math.cos(theta+math.pi/4)*radius*.95,math.sin((theta+math.pi/4)*2)*height*.27,math.sin(theta+math.pi/4)*radius*.95)
    line(p,a0,a1,thickness*.7,batch)
   end
   local alpha=on and 1-.78*opacity or 1;if p.Transparency~=alpha then p.Transparency=alpha end
  end
 end end
 for i,p in ipairs(e.Gears or{})do
  local a=(i-1)*math.pi/5+t*.7;local r=radius*1.12
  if i<=10 then
   move(p,frame*CFrame.new(math.cos(a)*r,math.sin(t*.9)*height*.32,math.sin(a)*r)*CFrame.Angles(0,-a,0),batch)
  else
   local y=(((t*.38+(i-11)*.5)%1)-.5)*height
   move(p,frame*CFrame.new(0,y,-radius*.52),batch)
  end
  local alpha=1-(i<=10 and .78 or .48)*opacity;if p.Transparency~=alpha then p.Transparency=alpha end
 end
end
function E.Destroy(e)e.Folder:Destroy()end
return E
