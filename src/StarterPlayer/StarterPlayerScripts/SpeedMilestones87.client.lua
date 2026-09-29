-- First visible running gains reinforce short training / chase / garden loops.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local p=Players.LocalPlayer
local Feed=require(RS:WaitForChild('NoticeFeed83'));local Curve=require(RS:WaitForChild('BalanceValues81')).PointCurve
local previous=tonumber(p:GetAttribute('PhysicalWalkSpeed'))or 24;local pending;local scheduled=false;local alive=true
local c=p:GetAttributeChangedSignal('PhysicalWalkSpeed'):Connect(function()
 local speed=tonumber(p:GetAttribute('PhysicalWalkSpeed'));if not speed or speed~=speed or speed==math.huge then return end
 if p:GetAttribute('TreadmillTraining')and speed>previous then
  for _,k in ipairs(Curve)do if k[2]>previous and k[2]<=speed then pending=k[2]end end
  if pending and not scheduled then scheduled=true;task.delay(.75,function()
   scheduled=false;if not alive or not pending then return end
   local reached=pending;pending=nil;Feed.Plain('FASTER!  '..reached..' run speed',Color3.fromRGB(255,222,121),2.5,'speed-goal87:'..reached)
  end)end
 end
 previous=speed
end)
script.Destroying:Connect(function()alive=false;c:Disconnect()end)
