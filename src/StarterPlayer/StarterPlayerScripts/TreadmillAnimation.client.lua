local Players=game:GetService('Players');local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
local Playback=require(RS:WaitForChild('TreadmillPlayback'));local player=Players.LocalPlayer;local current;local elapsed=0
local function clear()if current then current:Destroy();current=nil end end
local function attach(character)clear();current=Playback.new(player,character)end
local added=player.CharacterAdded:Connect(attach);local removed=player.CharacterRemoving:Connect(clear)
local heartbeat=Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed<1/30 then return end;local step=elapsed;elapsed=0;if current then current:Step(step)end end)
local state=player:GetAttributeChangedSignal('TreadmillTraining'):Connect(function()if current then current:Step(0)end end)
if player.Character then attach(player.Character)end
script.Destroying:Connect(function()clear();added:Disconnect();removed:Disconnect();heartbeat:Disconnect();state:Disconnect()end)
