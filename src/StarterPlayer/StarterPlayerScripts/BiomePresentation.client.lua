-- R73: 5-Hz location checks, 20-Hz transitions, no property writes once settled.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Lighting=game:GetService('Lighting')
local player=game:GetService('Players').LocalPlayer;local Mood=require(RS:WaitForChild('BiomeMood'));local Renderer=require(RS:WaitForChild('EnvironmentLighting'))
local elapsed,scan=0,1;local stage=0;local renderer;local dead=false
local connection=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;scan+=dt;if elapsed<.05 then return end;local step=elapsed;elapsed=0
 local map=workspace:FindFirstChild('ChestChaseMap')
 local refresh=Lighting:GetAttribute('TrackRefreshActive')==true or(map and map:GetAttribute('BiomesRefreshing')==true)
 if not renderer then
  -- Joining during a refresh must not restore the daytime sky or capture temporary night values.
  if not map or refresh then return end;renderer=Renderer.new(Lighting)
 end
 if scan>=.2 then
  scan=0;local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart');local hum=character and character:FindFirstChildOfClass('Humanoid')
  stage=Mood.Stage(map,root and hum and hum.Health>0 and root.Position or nil,stage)
 end
 renderer:Step(stage,RS:GetAttribute('GlobalWeather')or'Clear',player:GetAttribute('FastMode')==true,refresh,step)
end)
script.Destroying:Connect(function()if dead then return end;dead=true;connection:Disconnect();if renderer then renderer:Destroy()end end)
