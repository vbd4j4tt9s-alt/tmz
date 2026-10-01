local Players=game:GetService('Players');local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
local Playback=require(RS:WaitForChild('TreadmillPlayback'));local player=Players.LocalPlayer;local current;local elapsed=0
local function clear()if current then current:Destroy();current=nil end end
local function attach(character)clear();current=Playback.new(player,character)end
local added=player.CharacterAdded:Connect(attach);local removed=player.CharacterRemoving:Connect(clear)
local heartbeat=Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed<1/30 then return end;local step=elapsed;elapsed=0;if current then current:Step(step)end end)
local state=player:GetAttributeChangedSignal('TreadmillTraining'):Connect(function()if current then current:Step(0)end end)
if player.Character then attach(player.Character)end
-- R117: tier effects (emitters/lights/pulses/orbits/arcs) for nearby treadmills. A failure here never stops run playback.
local stopFx,stopped
script.Destroying:Connect(function()stopped=true;clear();added:Disconnect();removed:Disconnect();heartbeat:Disconnect();state:Disconnect();if stopFx then stopFx()end end)
local fxOk,fxStop=pcall(function()return require(RS:WaitForChild('TreadmillFx',10)).Start(player)end)
if not fxOk then warn('[R117] Treadmill effects disabled: '..tostring(fxStop))elseif stopped then fxStop()else stopFx=fxStop end
