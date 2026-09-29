-- R48: rotate cameras around visible native products, with one shared scheduler.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Gui=game:GetService('GuiService')
local Art=require(RS:WaitForChild('ShopProductArt'));local Geometry=require(RS:WaitForChild('HarvestGeometry'))
local V={};local entries={};local connection;local elapsed=0
function V.Visible(view)
 if not view.Parent or view.AbsoluteSize.X<=0 or view.AbsoluteSize.Y<=0 then return false end
 local lo,hi=view.AbsolutePosition,view.AbsolutePosition+view.AbsoluteSize;local node=view
 while node do
  if node:IsA('GuiObject')then
   if not node.Visible then return false end
   if node.ClipsDescendants then
    local p,q=node.AbsolutePosition,node.AbsolutePosition+node.AbsoluteSize
    if hi.X<=p.X or hi.Y<=p.Y or lo.X>=q.X or lo.Y>=q.Y then return false end
   end
  elseif node:IsA('ScreenGui')and not node.Enabled then return false end
  node=node.Parent
 end
 return true
end
local function pose(e)
 local s=e.View.AbsoluteSize;if e.LastSize==s and e.LastAngle==e.Angle then return end;e.LastSize=s;e.LastAngle=e.Angle;local aspect=math.max(.25,s.X/math.max(1,s.Y))
 local distance=e.Radius/math.sin(math.atan(math.tan(math.rad(18))*math.min(1,aspect)))*1.1
 local direction=Vector3.new(math.sin(e.Angle),.43,math.cos(e.Angle)).Unit
 e.Camera.CFrame=CFrame.lookAt(e.Center+direction*distance,e.Center)
end
local function step(dt)
 elapsed+=dt;local player=game:GetService('Players').LocalPlayer;if elapsed<(player and player:GetAttribute('FastMode')and 1/15 or 1/30)then return end;local d=math.min(elapsed,.1);elapsed=0
 for e in pairs(entries)do if V.Visible(e.View)then
  if not Gui.ReducedMotionEnabled then e.Angle=(e.Angle+d*.48)%(2*math.pi)end
  pose(e)
 end end
end
function V.Attach(view,product,biome)
 local world=Instance.new('WorldModel');world.Name='ProductWorld';world.Parent=view
 local model=Art.Build(product,biome);model.Parent=world;local center,size=Geometry.Bounds(model)
 local camera=Instance.new('Camera');camera.FieldOfView=36;camera.Parent=view;view.CurrentCamera=camera
 local e={View=view,Camera=camera,Center=center,Radius=math.max(.3,size.Magnitude/2),Angle=product.Type=='Trail'and 1.05 or 3.55}
 entries[e]=true;pose(e);local destroy;local dead=false
 local function cleanup()
  if dead then return end;dead=true;entries[e]=nil;if destroy then destroy:Disconnect()end
  if view.CurrentCamera==camera then view.CurrentCamera=nil end
  world:Destroy();camera:Destroy()
  if not next(entries)and connection then connection:Disconnect();connection=nil;elapsed=0 end
 end
 destroy=view.Destroying:Connect(cleanup)
 if not connection then connection=Run.Heartbeat:Connect(step)end
 return cleanup
end
return V
