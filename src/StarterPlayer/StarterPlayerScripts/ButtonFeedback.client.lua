local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Highlights=require(RS:WaitForChild('ButtonHighlights'));local playerGui=Players.LocalPlayer:WaitForChild('PlayerGui')
local stop=Highlights.Start(playerGui)
local stopMenus=Highlights.WatchMenus(playerGui) -- R150: open / close sounds for every menu, from any input
script.Destroying:Connect(function()stop();stopMenus()end)
