do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R67. Apply defaults only during treadmill training or pack carrying; restore avatar clips afterward.
local Players=game:GetService('Players')
local Policy=require(game:GetService('ReplicatedStorage'):WaitForChild('DefaultCharacterAnimations'))
local player=Players.LocalPlayer;local current
local function attach(character)
 if current then current:Destroy();current=nil end
 current=Policy.Bind(character,true,player)
end
local added=player.CharacterAdded:Connect(attach)
local removing=player.CharacterRemoving:Connect(function()if current then current:Destroy();current=nil end end)
if player.Character then attach(player.Character)end
script.Destroying:Connect(function()added:Disconnect();removing:Disconnect();if current then current:Destroy()end end)
