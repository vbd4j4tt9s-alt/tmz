-- R47: one bounded cosmetic scheduler for local and nearby players.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('RunnerTrailRules'))
local Effects=require(RS:WaitForChild('RunnerTrailEffects'))
local localPlayer=Players.LocalPlayer
local fx=Effects.new();local records={};local elapsed,scan=0,0;local chosen={}
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.RespectCanCollide=true
local function release(player)
 local r=records[player];if r then fx:Release(r);records[player]=nil end
end
local function selectRunners()
 local camera=workspace.CurrentCamera;local eye=camera and camera.CFrame.Position
 local candidates={};local skip={fx.Folder}
 for _,player in ipairs(Players:GetPlayers())do
  local character=player.Character
  if character then
   table.insert(skip,character)
   local root=character:FindFirstChild('HumanoidRootPart');local folder=character:FindFirstChild('ChestChaseCosmetics')
   if root and folder and folder:GetAttribute('CosmeticVersion')==91 then
    local distance=eye and(root.Position-eye).Magnitude or math.huge
    if player==localPlayer or distance<=Rules.Range then table.insert(candidates,{Player=player,Character=character,Folder=folder,Distance=player==localPlayer and -1 or distance})end
   end
  end
 end
 table.sort(candidates,function(a,b)return a.Distance<b.Distance end);chosen={};params.FilterDescendantsInstances=skip
 local wanted={}
 for i=1,math.min(Rules.MaxCharacters,#candidates)do
  local c=candidates[i];local r=records[c.Player]
  if r and(r.Character~=c.Character or r.Cosmetics~=c.Folder or r.ThemeName~=c.Folder:GetAttribute('BootGroundTheme'))then release(c.Player);r=nil end
  if not r then r=fx:Bind(c.Character,c.Folder);records[c.Player]=r end
  fx:RefreshBody(r)
  table.insert(chosen,r);wanted[c.Player]=true
 end
 for player in pairs(records)do if not wanted[player]then release(player)end end
end
local removal=Players.PlayerRemoving:Connect(release)
local heartbeat=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;scan+=dt
 if elapsed<Rules.Interval then return end
 local step=elapsed;elapsed=0;local now=os.clock()
 if scan>=.20 then scan=0;selectRunners()end
 for _,r in ipairs(chosen)do if fx.Records[r]then fx:Step(r,step,now,params)end end
 fx:StepMarks(now)
end)
script.Destroying:Connect(function()heartbeat:Disconnect();removal:Disconnect();fx:Destroy()end)
