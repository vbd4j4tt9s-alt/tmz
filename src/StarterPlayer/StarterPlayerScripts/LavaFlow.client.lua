do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- V092: one continuous, visual-only route from the volcano outlet into its pool.
local Run=game:GetService('RunService')
-- V134: cache world-space flow nodes only after the expanded layout is ready.
local map=workspace:WaitForChild('ChestChaseMap',20)
if map then
 local deadline=os.clock()+20
 while not map:GetAttribute('RoutesExpandedV134')and os.clock()<deadline do task.wait(.1)end
 if not map:GetAttribute('RoutesExpandedV134')then warn('[V134] Lava flow waiting for a valid route layout.');return end
end
local routes={};local pending={};local elapsed=0
-- Bounded local motion, 20 Hz, only nearby pools. No server frame replication.
local pools={}
local function registerPool(m)
 if pools[m]or not m:IsA('Model')or not m:GetAttribute('MagmaPoolV127')then return end
 local center=m:GetAttribute('PoolCenter');local radii=m:GetAttribute('PoolRadii')
 if typeof(center)~='Vector3'or typeof(radii)~='Vector3'then return end
 pools[m]={Center=center,Radii=radii,Crust={},Surface={},Currents={}}
end
local function addMagma(v)
 if v:IsA('Model')then registerPool(v)end
 local m=v.Parent
 if not m or not m:IsA('Model')or not m:GetAttribute('MagmaPoolV127')then return end
 registerPool(m);local p=pools[m];if not p then return end
 if v:IsA('BasePart')then
  local rest=v:GetAttribute('MagmaRest');local drift=v:GetAttribute('MagmaDrift');local pulse=v:GetAttribute('MagmaPulse')
  if typeof(rest)=='CFrame'and type(drift)=='number'then p.Crust[v]={Rest=rest,Phase=drift}
  elseif type(pulse)=='number'then p.Surface[v]=pulse end
 elseif v:IsA('Beam')and v:GetAttribute('MagmaCurrent')then p.Currents[v]=v:GetAttribute('MagmaCurrent')end
end
-- R121: reused BulkMoveTo buffers (were two new tables every 20 Hz tick).
local magmaParts,magmaFrames={},{}
local function animateMagma(t,camera)
 local parts,frames=magmaParts,magmaFrames;table.clear(parts);table.clear(frames)
 for m,p in pairs(pools)do
  if not m:IsDescendantOf(workspace)then pools[m]=nil
  elseif (camera-p.Center).Magnitude<280 then
   for v,d in pairs(p.Crust)do
    if v.Parent~=m then p.Crust[v]=nil
    else
     table.insert(parts,v)
     table.insert(frames,d.Rest*CFrame.new(math.sin(t*.22+d.Phase)*.18,math.sin(t*.39+d.Phase)*.016,math.cos(t*.19+d.Phase)*.13)*CFrame.Angles(0,math.sin(t*.16+d.Phase)*.035,0))
    end
   end
   for v,phase in pairs(p.Surface)do
    if v.Parent~=m then p.Surface[v]=nil
    else v.Color=Color3.fromRGB(220,62,13):Lerp(Color3.fromRGB(238,82,18),.5+.5*math.sin(t*.65+phase))end
   end
   for b,i in pairs(p.Currents)do
    if b.Parent~=m then p.Currents[b]=nil
    elseif b.Attachment0 and b.Attachment1 then
     local a=t*.10+i*math.pi*.5;local rx,rz=p.Radii.X,p.Radii.Z
     b.Attachment0.Position=Vector3.new(math.cos(a)*rx*.30,.065,math.sin(a)*rz*.30)
     b.Attachment1.Position=Vector3.new(math.cos(a+.8)*rx*.54,.065,math.sin(a+.8)*rz*.54)
    end
   end
  end
 end
 -- Flushed by the caller together with the route glows (one BulkMoveTo per tick).
end

local function register(m)
 if not m:IsA('Model') or not(m:GetAttribute('LavaRouteV092')or m:GetAttribute('LavaRouteV128')) or routes[m]then return end
 local count=m:GetAttribute('NodeCount');if type(count)~='number' or count<2 or count>64 then return end
 local nodes,lengths,total={},{},0
 for i=1,count do
  local node=m:GetAttribute('Node'..i);if typeof(node)~='Vector3' then return end;nodes[i]=node
  if i>1 then local len=(node-nodes[i-1]).Magnitude;if len<.01 then return end;lengths[i-1]=len;total+=len end
 end
 -- R121: the route version tag is read once here instead of twice per glow per tick.
 routes[m]={Nodes=nodes,Lengths=lengths,Total=total,Speed=m:GetAttribute('FlowSpeed')or 7,Glows={},V128=m:GetAttribute('LavaRouteV128')and true or false}
 for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart') and type(p:GetAttribute('FlowPhase'))=='number'then routes[m].Glows[p]=p:GetAttribute('FlowPhase')end end
end
local function add(v)
 addMagma(v)
 if v:IsA('Model') and (v:GetAttribute('LavaRouteV092')or v:GetAttribute('LavaRouteV128'))then pending[v]=true
 elseif v:IsA('BasePart') and type(v:GetAttribute('FlowPhase'))=='number' and v.Parent then
  register(v.Parent);local route=routes[v.Parent];if route then route.Glows[v]=v:GetAttribute('FlowPhase')end
 end
end
for _,v in ipairs(workspace:GetDescendants())do add(v)end
workspace.DescendantAdded:Connect(add)
Run.RenderStepped:Connect(function(dt)
 elapsed+=dt;if elapsed<.05 then return end;elapsed=0
 for m in pairs(pending)do register(m);pending[m]=nil end
 local camera=workspace.CurrentCamera;if not camera then return end
 local t=workspace:GetServerTimeNow()
 animateMagma(t,camera.CFrame.Position)
 for model,route in pairs(routes)do
  if not model:IsDescendantOf(workspace)then routes[model]=nil
  else
   local nearest=math.huge
   for _,node in ipairs(route.Nodes)do nearest=math.min(nearest,(camera.CFrame.Position-node).Magnitude)end
   if nearest<350 then
    for p,phase in pairs(route.Glows)do
     if p.Parent~=model then route.Glows[p]=nil
     else
      local distance=(t*route.Speed+phase*route.Total)%route.Total
      if route.V128 then
       p.Transparency=.48+.52*math.max(1-math.clamp(distance/3,0,1),1-math.clamp((route.Total-distance)/7,0,1))
      end
      for i,len in ipairs(route.Lengths)do
       if distance<=len then
        local a,b=route.Nodes[i],route.Nodes[i+1];local pos=a:Lerp(b,distance/len)+Vector3.new(0,route.V128 and .055 or .18,0)
        local delta=b-a
        table.insert(magmaParts,p)
        table.insert(magmaFrames,CFrame.new(pos)*CFrame.Angles(0,math.atan2(-delta.X,-delta.Z),0)*CFrame.Angles(math.atan2(delta.Y,Vector3.new(delta.X,0,delta.Z).Magnitude),0,0));break
       end
       distance-=len
      end
     end
    end
   end
  end
 end
 if #magmaParts>0 then workspace:BulkMoveTo(magmaParts,magmaFrames,Enum.BulkMoveMode.FireCFrameChanged)end
end)
