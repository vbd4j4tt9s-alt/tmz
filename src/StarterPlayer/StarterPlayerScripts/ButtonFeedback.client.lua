do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Highlights=require(RS:WaitForChild('ButtonHighlights'));local playerGui=Players.LocalPlayer:WaitForChild('PlayerGui')
local stop=Highlights.Start(playerGui)
local stopMenus=Highlights.WatchMenus(playerGui) -- R150: open / close sounds for every menu, from any input
script.Destroying:Connect(function()stop();stopMenus()end)
