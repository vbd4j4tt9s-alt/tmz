-- R73: a single local palette. Borrow and restore authored effects; never clear Lighting.
local Mood=require(script.Parent.BiomeMood)
local E={};E.__index=E;local active
function E.new(lighting)
 if active then active:Destroy()end
 local self=setmetatable({Lighting=lighting,Saved={},Created={},Detached={},Dead=false,Settled=false},E);active=self
 local function borrow(class,name)
  local item=lighting:FindFirstChild(name)
  if not item or not item:IsA(class)then
   item=Instance.new(class);item.Name=name;item.Parent=lighting;self.Created[item]=true
  end
  return item
 end
 self.Air=borrow('Atmosphere','ChestChaseAtmosphere');self.Grade=borrow('ColorCorrectionEffect','ChestChaseColor');self.Bloom=borrow('BloomEffect','Bloom')
 self.Sun=lighting:FindFirstChild('SunRays')
 if self.Sun and not self.Sun:IsA('SunRaysEffect')then self.Sun=nil end
 local sky=lighting:FindFirstChild('Sky');if not sky or not sky:IsA('Sky')then sky=lighting:FindFirstChildOfClass('Sky')end
 -- The R72 place has two skies and two atmospheres. Keep one authored sky and one air layer.
 for _,child in ipairs(lighting:GetChildren())do
  if(child:IsA('Atmosphere')and child~=self.Air)or(child:IsA('Sky')and child~=sky and child.Name~='TrackRefreshBlackSky')then
   table.insert(self.Detached,child);child.Parent=nil
  end
 end
 self:Write(lighting,'ClockTime',14.2);self:Write(lighting,'ShadowSoftness',.45)
 self:Write(lighting,'EnvironmentDiffuseScale',.70);self:Write(lighting,'EnvironmentSpecularScale',.35)
 self:Write(self.Grade,'Enabled',true);self:Write(self.Bloom,'Size',14);self:Write(self.Bloom,'Threshold',1.8)
 return self
end
function E:Write(item,key,value)
 if item[key]==value then return false end
 local record=self.Saved[item];if not record then record={};self.Saved[item]=record end
 if not record[key]then record[key]={Before=item[key]}end
 item[key]=value;record[key].Last=item[key];return true
end
local function close(a,b)
 if typeof(a)=='Color3' then return math.max(math.abs(a.R-b.R),math.abs(a.G-b.G),math.abs(a.B-b.B))<.0005 end
 return math.abs(a-b)<.0005
end
function E:Step(stage,weather,low,refresh,dt)
 if self.Dead then return end
 local key=tostring(stage)..':'..tostring(weather)..':'..tostring(low)..':'..tostring(refresh)
 if key~=self.Key then self.Key=key;self.Target=Mood.Palette(stage,weather,low,refresh);self.Settled=false end
 if self.Settled then return end
 local alpha=1-math.exp(-math.min(dt,.2)*2.8);local done=true
 local function apply(object,values)
  for name,target in pairs(values)do
   local current=object[name]
   if current~=target then
    local value=typeof(target)=='Color3'and current:Lerp(target,alpha)or current+(target-current)*alpha
    if close(value,target)then value=target else done=false end
    self:Write(object,name,value)
   end
  end
 end
 if not refresh then apply(self.Lighting,self.Target.Light);apply(self.Air,self.Target.Air)end
 apply(self.Grade,self.Target.Grade)
 self:Write(self.Bloom,'Enabled',not low and not refresh)
 if not low and not refresh then apply(self.Bloom,{Intensity=self.Target.Bloom})end
 if self.Sun then
  self:Write(self.Sun,'Enabled',not low and not refresh and self.Target.Sun>0)
  if not low and not refresh then apply(self.Sun,{Intensity=self.Target.Sun})end
 end
 self.Settled=done
end
function E:Destroy()
 if self.Dead then return end;self.Dead=true
 for item,fields in pairs(self.Saved)do
  if item.Parent or item==self.Lighting then
   for key,value in pairs(fields)do if item[key]==value.Last then item[key]=value.Before end end
  end
 end
 for item in pairs(self.Created)do item:Destroy()end
 for _,item in ipairs(self.Detached)do if item.Parent==nil then item.Parent=self.Lighting end end
 table.clear(self.Saved);table.clear(self.Created);table.clear(self.Detached)
 if active==self then active=nil end
end
return E
