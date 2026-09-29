local RS=game:GetService('ReplicatedStorage');local Feed=require(RS:WaitForChild('NoticeFeed83'))
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('Notice83')
local c=remote.OnClientEvent:Connect(function(text,color,duration)Feed.Plain(text,color,duration)end)
script.Destroying:Connect(function()c:Disconnect()end)
