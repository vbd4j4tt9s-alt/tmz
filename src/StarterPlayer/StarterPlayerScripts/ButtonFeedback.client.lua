local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local stop=require(RS:WaitForChild('ButtonHighlights')).Start(Players.LocalPlayer:WaitForChild('PlayerGui'))
script.Destroying:Connect(stop)
