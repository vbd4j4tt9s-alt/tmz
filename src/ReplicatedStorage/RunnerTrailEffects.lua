-- R47: one client scheduler, two ground ribbons per eligible runner and a bounded reusable mark pool.
local Rules=require(script.Parent.RunnerTrailRules)
local E={};E.__index=E
local V,CF=Vector3.new,CFrame.new
local function cosmetic(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Size=V(.1,.1,.1);p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Parent=parent;return p
end
local function deactivate(trail,clear)
 trail.Enabled=false;if clear then trail:Clear()end
end
function E.new(parent)
 local old=(parent or workspace):FindFirstChild('RunnerGroundEffects');if old then old:Destroy()end
 local folder=Instance.new('Folder');folder.Name='RunnerGroundEffects';folder.Parent=parent or workspace
 return setmetatable({Folder=folder,Marks={},Cursor=0,Records={}},E)
end
function E:Bind(character,cosmetics)
 local r={Character=character,Cosmetics=cosmetics,Root=character:FindFirstChild('HumanoidRootPart'),Humanoid=character:FindFirstChildOfClass('Humanoid'),Body={},Ground={},LastStamp=-math.huge,Side=0}
 self:RefreshBody(r)
 r.ThemeName=cosmetics:GetAttribute('BootGroundTheme');r.Theme=Rules.Theme(r.ThemeName)
 if r.Theme then
  for i=1,2 do
   local p=cosmetic(self.Folder,'Ground ribbon anchor');local a=Instance.new('Attachment');a.Position=V(-.24,0,0);a.Parent=p
   local b=Instance.new('Attachment');b.Position=V(.24,0,0);b.Parent=p
   local t=Instance.new('Trail');t.Name='Boot ground ribbon';t.Attachment0=a;t.Attachment1=b;t.Color=ColorSequence.new(r.Theme.Color,r.Theme.Tail)
   t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.20),NumberSequenceKeypoint.new(.55,.48),NumberSequenceKeypoint.new(1,1)})
   t.WidthScale=NumberSequence.new(1,0);t.LightEmission=.65;t.LightInfluence=.15;t.FaceCamera=false;t.MinLength=.09;t.Lifetime=.2;t.Enabled=false;t.Parent=p
   table.insert(r.Ground,{Part=p,Trail=t,A=a,B=b})
  end
 end
 self.Records[r]=true;return r
end
function E:RefreshBody(r)
 local body={}
 for _,p in ipairs(r.Cosmetics:GetDescendants())do if p:IsA('Trail')and p:GetAttribute('RunnerMovementTrail')then table.insert(body,p)end end
 r.Body=body
end
-- Compatibility for a still-running older trail client; creates no PNG effects.
function E:Premium(r,_on,_now)
 if r.Sprites then for _,s in ipairs(r.Sprites)do if s.Anchor then s.Anchor:Destroy()end end;r.Sprites=nil end
end
function E:Disable(r,clear)
 for _,t in ipairs(r.Body)do if t.Parent then deactivate(t,clear)end end
 for _,g in ipairs(r.Ground)do deactivate(g.Trail,clear)end
end
function E:Release(r)
 self:Premium(r,false,0)
 self:Disable(r,true)
 for _,g in ipairs(r.Ground)do g.Part:Destroy()end
 self.Records[r]=nil
end
local function groundFrame(position,normal,forward)
 local along=forward-normal*forward:Dot(normal)
 if along.Magnitude<.001 then along=V(0,0,-1)-normal*V(0,0,-1):Dot(normal)end
 if along.Magnitude<.001 then return nil end
 along=along.Unit;local right=along:Cross(normal).Unit
 return CFrame.fromMatrix(position+normal*.035,right,normal,-along)
end
function E:Stamp(frame,theme,scale,now)
 self.Cursor=self.Cursor%Rules.MaxMarks+1
 local m=self.Marks[self.Cursor]
 if not m then
  m={Parts={}};for i=1,3 do table.insert(m.Parts,cosmetic(self.Folder,'Fading boot mark'))end;self.Marks[self.Cursor]=m
 end
 m.Born=now;m.Life=theme.Life;m.Live=true;m.Count=theme.Kind=='Ember'and 2 or 3
 for i,p in ipairs(m.Parts)do
  p.Color=i==1 and theme.Color or theme.Tail;p.Transparency=i<=m.Count and .22 or 1
  if theme.Kind=='Ember'then p.Size=V(.62,.035,.15)*scale;p.CFrame=frame*CF(0,.006,(i-1.5)*.38*scale)
  elseif theme.Kind=='Crystal'then
   local width=i==1 and .46 or .20;p.Size=V(width,.024,width)*scale
   p.CFrame=frame*CF(i==1 and 0 or(i==2 and -.27 or .27)*scale,.006,(i-2)*.16*scale)*CFrame.Angles(0,math.pi/4,0)
  else
   local x0=({-.14,.18,-.18})[i];local x1=({.18,-.18,.14})[i];local z0=(i-2)*.32-.16;local z1=z0+.32
   p.Size=V(.11,.035,math.sqrt((x1-x0)^2+(z1-z0)^2))*scale
   p.CFrame=frame*CF((x0+x1)*.5*scale,.006,(z0+z1)*.5*scale)*CFrame.Angles(0,math.atan2(x1-x0,z1-z0),0)
  end
 end
end
function E:StepMarks(now)
 for _,m in ipairs(self.Marks)do if m.Live then
  local t=math.clamp((now-m.Born)/m.Life,0,1);local alpha=.22+.78*t*t
  for i=1,m.Count do m.Parts[i].Transparency=alpha end
  if t>=1 then m.Live=false end
 end end
end
function E:Step(r,dt,now,params)
 r.Humanoid=r.Humanoid or r.Character:FindFirstChildOfClass('Humanoid')
 local root,h=r.Root,r.Humanoid
 if not root or not root.Parent or not h or not r.Cosmetics.Parent then self:Disable(r,true);return end
 local v=root.AssemblyLinearVelocity;local speed=V(v.X,0,v.Z).Magnitude
 local position=root.Position;local distance=r.LastPosition and(position-r.LastPosition).Magnitude or 0
 local discontinuous=Rules.Discontinuous(distance,dt,speed);r.LastPosition=position
 local blocked=discontinuous or r.Character:GetAttribute('ChestChaseRagdollActive')==true or h.Sit or h.PlatformStand
 local moving=Rules.Moving(speed,h.Health>0,blocked)
 for _,trail in ipairs(r.Body)do if trail.Parent then
  if blocked then deactivate(trail,true)else trail.Lifetime=Rules.Lifetime(speed);trail.Enabled=moving end
 end end
 local grounded=h.FloorMaterial~=Enum.Material.Air
 if not r.Theme or not Rules.Ground(speed,grounded,h.Health>0,blocked)then
  for _,g in ipairs(r.Ground)do deactivate(g.Trail,blocked or not grounded)end
  r.StampPosition=nil;return
 end
 local hits={}
 for i,side in ipairs({'Left','Right'})do
  local foot=r.Character:FindFirstChild(side..'Foot')or r.Character:FindFirstChild(side..' Leg');local g=r.Ground[i]
  if foot and foot:IsA('BasePart')then
   local scale=math.clamp(foot.Size.X,.4,2.5)
   local sole=(foot.CFrame*CF(0,-foot.Size.Y*.5,0)).Position
   local hit=workspace:Raycast(sole+V(0,1.4*scale,0),V(0,-3.3*scale,0),params)
   local frame=hit and hit.Normal.Y>.5 and groundFrame(hit.Position,hit.Normal,root.CFrame.LookVector)
   if frame then
    g.Part.CFrame=frame;g.A.Position=V(-.24*scale,0,0);g.B.Position=V(.24*scale,0,0)
    g.Trail.Lifetime=math.clamp(5/math.max(speed,1),.04,.34);g.Trail.Enabled=true;hits[i]={Frame=frame,Scale=scale}
   else deactivate(g.Trail,false)end
  else deactivate(g.Trail,true)end
 end
 if now-r.LastStamp>=Rules.MarkInterval and(not r.StampPosition or(position-r.StampPosition).Magnitude>=Rules.MarkSpacing)then
  r.Side=r.Side%2+1;local hit=hits[r.Side]or hits[3-r.Side]
  if hit then self:Stamp(hit.Frame,r.Theme,hit.Scale,now);r.LastStamp=now;r.StampPosition=position end
 end
end
function E:Destroy()
 for r in pairs(self.Records)do self:Release(r)end
 self.Records={};self.Marks={};self.Folder:Destroy()
end
return E
