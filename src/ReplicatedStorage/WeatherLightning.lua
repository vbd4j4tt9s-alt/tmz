-- R78: fixed 32-part lightning pool, reused for global and server-timed biome strikes.
local L={};L.__index=L
function L.New(parent)
 local folder=Instance.new('Folder');folder.Name='PooledLightning';folder.Parent=parent
 local self=setmetatable({Folder=folder,Parts={},Count=0,Phase=0},L)
 for i=1,16 do for layer=1,2 do
  local p=Instance.new('Part');p.Name=layer==1 and 'Lightning core'or 'Lightning glow'
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Material=Enum.Material.Neon;p.Color=layer==1 and Color3.fromRGB(239,248,255)or Color3.fromRGB(118,182,255)
  p.Transparency=1;p.Parent=folder;table.insert(self.Parts,p)
 end end
 return self
end
function L:Clear()
 if self.Phase~=0 then for _,p in ipairs(self.Parts)do if p.Transparency~=1 then p.Transparency=1 end end end
 self.Phase=0;self.At=nil
end
function L:Strike(top,bottom,now,low,reduced,seed)
 self:Clear();local random=Random.new(seed or math.floor(now*100))
 local points={top};local count=low and 6 or 10
 for i=1,count do
  local p=top:Lerp(bottom,i/count)
  if i<count then p+=Vector3.new(random:NextNumber(-5,5),0,random:NextNumber(-5,5))end
  table.insert(points,p)
 end
 local segments={}
 for i=1,#points-1 do table.insert(segments,{points[i],points[i+1],1})end
 if not low then for branch=1,2 do
  local start=points[branch*3];local last=start
  for j=1,3 do
   local p=start+Vector3.new((branch==1 and -1 or 1)*j*7,-j*7,random:NextNumber(-7,7))
   table.insert(segments,{last,p,.48});last=p
  end
 end end
 for i,s in ipairs(segments)do
  local delta=s[2]-s[1];local up=math.abs(delta.Unit:Dot(Vector3.yAxis))>.98 and Vector3.xAxis or Vector3.yAxis;local frame=CFrame.lookAt((s[1]+s[2])/2,s[2],up)
  for layer=1,2 do local p=self.Parts[(i-1)*2+layer];local width=(layer==1 and .72 or 1.8)*s[3]
   p.Size=Vector3.new(width,width,math.max(.01,delta.Magnitude)+.2);p.CFrame=frame
  end
 end
 self.Count=#segments*2;self.At=now;self.Reduced=reduced;self.Phase=-1;self:Step(now)
end
function L:Step(now)
 if not self.At then return false end
 local age=now-self.At
 local phase=age<.11 and 1 or age<.18 and 2 or age<.32 and 1 or 0
 if self.Reduced then phase=age<.26 and 2 or 0 end
 if phase~=self.Phase then
  self.Phase=phase
  for i,p in ipairs(self.Parts)do
   local alpha=(phase==0 or i>self.Count)and 1 or i%2==0 and .78 or phase==2 and .62 or .06
   if p.Transparency~=alpha then p.Transparency=alpha end
  end
 end
 if phase==0 then self.At=nil end
 return phase==1 and not self.Reduced
end
function L:Destroy()self.Folder:Destroy();table.clear(self.Parts);self.At=nil end
return L
