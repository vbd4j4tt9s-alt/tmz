-- R66: retained black-screen ritual, fixed central star, orbit trails and outward fracture.
local RS=game:GetService('ReplicatedStorage');local Sequence=require(RS.RarityRevealSequence);local Emblems=require(RS.PremiumEmblems)
local R={};local C=Color3.fromRGB
local function frame(parent,name,size,pos,color,z)
 local f=Instance.new('Frame');f.Name=name;f.Size=size;f.Position=pos;f.AnchorPoint=Vector2.new(.5,.5);f.BackgroundColor3=color;f.BorderSizePixel=0;f.Active=false;f.ZIndex=z or 22;f.Parent=parent;return f
end
local function line(parent,name,color,z)
 return frame(parent,name,UDim2.fromScale(.001,.001),UDim2.fromScale(.5,.5),color,z)
end
local function placeLine(p,a,b,width)
 local d=b-a;p.Position=UDim2.fromScale((a.X+b.X)*.5,(a.Y+b.Y)*.5);p.Size=UDim2.fromScale(d.Magnitude+.0007,width);p.Rotation=math.deg(math.atan2(d.Y,d.X))
end
local function circle(parent,name,r,color)
 local f=frame(parent,name,UDim2.fromScale(r,r),UDim2.fromScale(.5,.5),color);f.BackgroundTransparency=1
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(1,0);c.Parent=f
 local s=Instance.new('UIStroke');s.Thickness=2;s.Color=color;s.Parent=f;return {Root=f,Stroke=s}
end
function R.Create(gui)
 local root=frame(gui,'RaritySequence',UDim2.fromScale(1,1),UDim2.fromScale(.5,.5),C(0,0,0),20);root.Visible=false
 local stage=frame(root,'Stage',UDim2.fromScale(1,1),UDim2.fromScale(.5,.5),C(0,0,0));stage.BackgroundTransparency=1
 local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Height;aspect.Parent=stage
 local star=Emblems.Draw(stage,'RadiantStar');star.AnchorPoint=Vector2.new(.5,.5);star.Position=UDim2.fromScale(.5,.5);star.Size=UDim2.fromScale(.27,.27);star.ZIndex=26
 local crown=Emblems.Draw(stage,'Crown');crown.AnchorPoint=Vector2.new(.5,.5);crown.Position=UDim2.fromScale(.5,.5);crown.Size=UDim2.fromScale(.34,.34);crown.ZIndex=26
 local secret=frame(stage,'Secret core',UDim2.fromScale(.095,.095),UDim2.fromScale(.5,.5),C(236,250,255),26);secret.Rotation=45
 local slit=frame(secret,'Black diamond',UDim2.fromScale(.74,.74),UDim2.fromScale(.5,.5),C(0,0,0),27)
 local coreParts={};for _,p in ipairs(star:GetDescendants())do if p:IsA('Frame')then coreParts[#coreParts+1]=p;p.ZIndex=26 end end
 local crownParts={};for _,p in ipairs(crown:GetDescendants())do if p:IsA('Frame')then crownParts[#crownParts+1]=p;p.ZIndex=26 end end
 local rings={};for i=1,3 do
  local holder=frame(stage,'Orbit'..i,UDim2.fromScale(1,1),UDim2.fromScale(.5,.5),C(0,0,0));holder.BackgroundTransparency=1
  local segments={};for j=1,48 do segments[j]=line(holder,'Arc'..j,C(170,158,255))end
  rings[i]={Root=holder,Segments=segments}
 end
 local halos={};for i=1,4 do halos[i]=circle(stage,'Soft halo '..i,.12+i*.07,C(137,153,255))end
 local rays={};for i=1,16 do rays[i]=line(stage,'Radiant ray '..i,C(234,224,255),23)end
 local shards={};for i=1,28 do shards[i]=line(stage,'Burst shard '..i,C(212,201,255),25);shards[i].Visible=false end
 local pulse=circle(stage,'Shockwave',.01,C(234,231,255));pulse.Root.Visible=false;pulse.Root.ZIndex=24
 local flash=frame(gui,'Reveal white',UDim2.fromScale(1,1),UDim2.fromScale(.5,.5),C(255,255,255),40);flash.Visible=false
 local api={Root=root,Flash=flash,Rings=rings,Crown=crown,Star=star,Secret=secret,Shards=shards,Halos=halos}
 function api:Hide()root.Visible=false;flash.Visible=false end
 function api:Step(rank,t,reduced)
  local s=Sequence.Sample(rank,t,reduced);root.Visible=rank>=6 and not s.Done
  if not root.Visible then flash.Visible=false;return s end
  root.BackgroundColor3=C(0,0,0);root.BackgroundTransparency=1-s.Cover
  local color=rank==8 and C(255,211,98)or rank==7 and C(162,175,255)or C(191,236,255)
  star.Visible=rank==7 and s.CoreVisible;crown.Visible=rank==8 and s.CoreVisible;secret.Visible=rank==6 and s.CoreVisible
  -- Only brightness changes: the emblem never grows toward the viewer.
  star.Rotation=reduced and 0 or math.sin(t*.5)*4
  for _,p in ipairs(coreParts)do p.BackgroundTransparency=s.CoreAlpha;p.BackgroundColor3=color:Lerp(C(255,255,255),s.Charge)end
  for _,p in ipairs(crownParts)do p.BackgroundTransparency=math.max(0,.8-s.Charge*1.8)end
  secret.BackgroundTransparency=s.CoreAlpha;secret.Rotation=reduced and 45 or 45+math.sin(t*1.4)*6
  for i,e in ipairs(rings)do
   e.Root.Visible=rank~=6 or i==1
   for j,p in ipairs(e.Segments)do
    local theta=(j-1)/48*math.pi*2
    local rotation=rank==8 and s.Rotation*.42 or s.Rotation
    local a=Sequence.OrbitPoint(i,theta,rotation);local b=Sequence.OrbitPoint(i,theta+math.pi*2/48,rotation)
    placeLine(p,a,b,.0015+(rank==8 and .0007 or .0004)*s.Charge)
    local tail=(j%16)/16;p.BackgroundColor3=color:Lerp(C(255,255,255),tail*.55)
    p.BackgroundTransparency=s.Burst and 1 or math.clamp(.9-s.Charge*.62-tail*.19,0,1)
   end
  end
  for i,e in ipairs(halos)do
   e.Root.Visible=s.CoreVisible;e.Stroke.Color=color;e.Stroke.Thickness=1+i*1.4
   e.Stroke.Transparency=math.clamp(.98-s.Charge^2*(.17-i*.022),0,1)
  end
  for i,p in ipairs(rays)do
   local a=i*math.pi/8+(rank==8 and .12 or 0);local inner=rank==8 and .23 or .11;local outer=inner+.035+s.Charge^3*.18
   placeLine(p,Vector2.new(.5+math.cos(a)*inner,.5+math.sin(a)*inner),Vector2.new(.5+math.cos(a)*outer,.5+math.sin(a)*outer),i%2==0 and .002 or .001)
   p.BackgroundColor3=color;p.BackgroundTransparency=s.Burst and 1 or s.RaysAlpha;p.Visible=s.CoreVisible and(rank~=6 or i%2==0)
  end
  for i,p in ipairs(shards)do
   p.Visible=s.Burst
   if s.Burst then
    local a=i*math.pi*2/#shards+(i%3)*.045;local speed=.34+(i%5)*.07;local radius=.06+s.BurstProgress*speed*(reduced and .2 or 1)
    local length=(.015+(i%4)*.011)*(1-s.BurstProgress)
    placeLine(p,Vector2.new(.5+math.cos(a)*radius,.5+math.sin(a)*radius),Vector2.new(.5+math.cos(a)*(radius+length),.5+math.sin(a)*(radius+length)),.002)
    p.BackgroundColor3=color;p.BackgroundTransparency=.10+s.BurstProgress*.9
   end
  end
  pulse.Root.Visible=s.Burst;local diameter=.12+s.BurstProgress*(reduced and .3 or 1.55);pulse.Root.Size=UDim2.fromScale(diameter,diameter);pulse.Stroke.Color=color;pulse.Stroke.Transparency=.1+s.BurstProgress*.9
  flash.Visible=s.Flash>0;flash.BackgroundTransparency=1-s.Flash
  return s
 end
 return api
end
return R
