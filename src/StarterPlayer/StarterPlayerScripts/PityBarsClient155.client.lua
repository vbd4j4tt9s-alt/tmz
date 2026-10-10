do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R155 (owner): the pack pity's two bars above the hotbar (gold = normal pity, purple = event pity), always on the HUD; everything is in ReplicatedStorage.PityBars155.
-- Its own script, so the hotbar (Hotbar.client.lua) is not touched: the bars find the hotbar's frame by name at every layout change.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local bars=require(RS:WaitForChild('PityBars155')).Start(Players.LocalPlayer)
script.Destroying:Connect(function()bars:Destroy()end)
