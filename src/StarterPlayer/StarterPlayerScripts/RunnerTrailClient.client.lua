do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R47: one bounded cosmetic scheduler for local and nearby players.
-- R111: boot prints/bursts/idle aura for every boot tier; per-runner detail from distance and screen position,
-- pool sizes from the shared client quality (ClientFxBudget, Effects quality setting, graphics level, Reduced Motion).
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('RunnerTrailRules'))
local Styles=require(RS:WaitForChild('RunnerTrailStyles'))
local Effects=require(RS:WaitForChild('RunnerTrailEffects'))
local Fx=require(RS:WaitForChild('ClientFxBudget'))
local localPlayer=Players.LocalPlayer
local fx=Effects.new();local records={};local elapsed,scan,ticks=0,0,0;local chosen={}
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.RespectCanCollide=true
local function release(player)
 local r=records[player];if r then fx:Release(r);records[player]=nil end
end
local function graphicsLevel()
 local ok,level=pcall(function()return UserSettings():GetService('UserGameSettings').SavedQualityLevel.Value end)
 return ok and level or nil
end
local function selectRunners()
 local budget=Styles.Budget(Fx.Get(),Gui.ReducedMotionEnabled,graphicsLevel());fx:SetBudget(budget)
 local camera=workspace.CurrentCamera;local eye=camera and camera.CFrame.Position
 local candidates={};local skip={fx.Folder}
 for _,player in ipairs(Players:GetPlayers())do
  local character=player.Character
  if character then
   table.insert(skip,character)
   local root=character:FindFirstChild('HumanoidRootPart');local folder=character:FindFirstChild('ChestChaseCosmetics')
   if root and folder and folder:GetAttribute('CosmeticVersion')==91 then
    local distance=eye and(root.Position-eye).Magnitude or math.huge
    if player==localPlayer or distance<=Rules.Range then table.insert(candidates,{Player=player,Character=character,Folder=folder,Root=root,Distance=player==localPlayer and -1 or distance})end
   end
  end
 end
 table.sort(candidates,function(a,b)return a.Distance<b.Distance end);chosen={};params.FilterDescendantsInstances=skip
 local wanted={}
 for i=1,math.min(Rules.MaxCharacters,budget.Characters,#candidates)do
  local c=candidates[i];local r=records[c.Player]
  if r and(r.Character~=c.Character or r.Cosmetics~=c.Folder or r.ThemeName~=Styles.ThemeName(c.Folder))then release(c.Player);r=nil end
  if not r then r=fx:Bind(c.Character,c.Folder,c.Player==localPlayer);records[c.Player]=r end
  fx:RefreshBody(r)
  local onScreen=true
  if camera and c.Player~=localPlayer then local _,visible=camera:WorldToViewportPoint(c.Root.Position);onScreen=visible end
  r.Detail=Styles.Detail(c.Player==localPlayer,c.Distance,onScreen,budget)
  table.insert(chosen,r);wanted[c.Player]=true
 end
 for player in pairs(records)do if not wanted[player]then release(player)end end
end
local removal=Players.PlayerRemoving:Connect(release)
local heartbeat=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;scan+=dt
 if elapsed<Rules.Interval then return end
 local step=elapsed;elapsed=0;local now=os.clock();ticks+=1
 if scan>=.20 then scan=0;selectRunners()end
 for _,r in ipairs(chosen)do if fx.Records[r]then
  -- On the low budget, far runners (ribbons only) update every other tick.
  r.Pending=(r.Pending or 0)+step
  if r.Detail>1 or fx.Budget.Tier>1 or ticks%2==0 then fx:Step(r,r.Pending,now,params,r.Detail);r.Pending=0 end
 end end
 fx:StepMarks(now)
end)
script.Destroying:Connect(function()heartbeat:Disconnect();removal:Disconnect();fx:Destroy()end)
