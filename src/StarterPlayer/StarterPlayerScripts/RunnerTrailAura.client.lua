-- R117: client trail auras (RunnerTrailAuraFx) for the local runner and a capped set of nearby on-screen runners.
-- Follows the server's ChestChaseCosmetics folder (TrailId84/TrailLow84/TrailHigh84): new/changed/removed trails,
-- respawns and leaving players are picked up by the scan. Budget: ClientFxBudget (FastMode = low), graphics level,
-- Reduced Motion. Boot effects stay in RunnerTrailClient; this script never touches the boot pools.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local RS=game:GetService('ReplicatedStorage')
local Aura=require(RS:WaitForChild('RunnerTrailAuraFx'))
local Quality=require(RS:WaitForChild('ClientFxBudget'))
local localPlayer=Players.LocalPlayer
local fx=Aura.new();local scan=math.huge
local function graphicsLevel()
 local ok,level=pcall(function()return UserSettings():GetService('UserGameSettings').SavedQualityLevel.Value end)
 return ok and level or nil
end
local heartbeat=RunService.Heartbeat:Connect(function(dt)
 scan+=dt
 if scan>=.25 then
  scan=0
  fx:Scan(Players:GetPlayers(),localPlayer,workspace.CurrentCamera,Aura.Budget(Quality.Get(),Gui.ReducedMotionEnabled,graphicsLevel()))
 end
 fx:Step(dt,os.clock())
end)
local removing=Players.PlayerRemoving:Connect(function(player)fx:Release(player)end)
script.Destroying:Connect(function()heartbeat:Disconnect();removing:Disconnect();fx:Destroy()end)
