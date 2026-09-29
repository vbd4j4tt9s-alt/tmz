-- R43. The client requests a swing; the server chooses and validates its victim.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local C=require(RS:WaitForChild('BatConfig'))
local Hitbox=require(RS.BatHitbox)
local Art=require(script.Parent.BatArt)
local M={};M.__index=M
function M.new(chase)
 return setmetatable({Chase=chase,Tools={},Characters={},Connections={},Swings={},NextSwing={},NextRequest={},SpawnAt={},Serial=0},M)
end
function M:_eligible(player,swingOnly)
 local character,hum,root=self.Chase:_validCharacter(player)
 if not character or root.Anchored or hum.PlatformStand or self.Chase.Map.Refreshing
  or player:GetAttribute('GuardianRagdollActive')or player:GetAttribute('GuardianFlingActive')then return nil end
 if not swingOnly then
  if character:FindFirstChildOfClass('ForceField')or os.clock()-(self.SpawnAt[player]or os.clock())<C.SpawnGrace then return nil end
  if C.RequireBiome and (not self.Chase.Map:IsInsideBiomeTrack(root.Position)
   or root.Position.Z<=self.Chase.Map.BaseBoundaryLine.Position.Z+C.SafeLineMargin)then return nil end
 end
 return character,hum,root
end
function M:Request(player)
 if not require(script.Parent.SecurityGate).Allow(player,'BatSwing')or not require(script.Parent.MovementGuard).Check(player)then return false end
 local now=os.clock()
 if now<(self.NextRequest[player]or 0)then return false end
 self.NextRequest[player]=now+.08
 if now<(self.NextSwing[player]or 0)then return false end
 local character,_,root=self:_eligible(player,true);local tool=self.Tools[player]
 if not character or not tool or tool.Parent~=character or not tool.Enabled
  or self.Chase.Chests:IsOpening(player)then return false end
 self.NextSwing[player]=now+C.Cooldown;self.Serial+=1
 local swing={Character=character,Tool=tool,At=workspace:GetServerTimeNow(),ImpactAt=now+C.Windup,
  Serial=self.Serial,Origin=root.Position}
 self.Swings[player]=swing
 self.Remote:FireAllClients({Kind='Swing',Character=character,At=swing.At,Serial=swing.Serial})
 return true
end
function M:_target(attacker,root)
 -- A swing is visible in the hub too; hits still require both players in a combat area.
 if not self:_eligible(attacker)then return nil end
 local best,bestDistance
 for _,victim in ipairs(Players:GetPlayers())do if victim~=attacker and self.Chase.Ragdoll:CanHit(victim)then
  local character,_,other=self:_eligible(victim)
  if character then
   local offset=other.Position-root.Position;local flat=Vector3.new(offset.X,0,offset.Z);local distance=flat.Magnitude
   if Hitbox.Contains(root.CFrame,other.Position)
    and (not bestDistance or distance<bestDistance)then
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={root.Parent,character};params.RespectCanCollide=true
    if not workspace:Raycast(root.Position,offset,params)then best={Player=victim,Character=character};bestDistance=distance end
   end
  end
 end end
 return best
end
function M:Step()
 local now=os.clock()
 for player,swing in pairs(self.Swings)do
  local character,hum,root=self:_eligible(player,true)
  if character~=swing.Character or self.Tools[player]~=swing.Tool or swing.Tool.Parent~=character
   or not swing.Tool.Enabled or not root or (root.Position-swing.Origin).Magnitude>math.max(18,hum.WalkSpeed*C.Windup*1.8)then
   self.Swings[player]=nil
  elseif now>=swing.ImpactAt then
   self.Swings[player]=nil -- Reserve this impact before hit/drop work; one victim per swing.
   if now-swing.ImpactAt<=.30 then
    local target=self:_target(player,root)
    if target then self.Chase:HitByBat(player,target.Player,target.Character)end
   end
  end
 end
end
function M:Give(player,character)
 if not character or not player.Parent or player.Character~=character then return end
 self.Swings[player]=nil;self.SpawnAt[player]=os.clock()
 local old=self.Tools[player];if old then old:Destroy()end;self.Tools[player]=nil
 local backpack=player:FindFirstChildOfClass('Backpack')or player:WaitForChild('Backpack',10)
 if not backpack or not player.Parent or player.Character~=character then return end
 local tool=Art.Create();self.Tools[player]=tool;tool.Parent=backpack
end
function M:CleanupPlayer(player)
 self.Swings[player]=nil;self.NextSwing[player]=nil;self.NextRequest[player]=nil;self.SpawnAt[player]=nil
 local tool=self.Tools[player];self.Tools[player]=nil;if tool then tool:Destroy()end
 local links=self.Characters[player];self.Characters[player]=nil
 for _,link in ipairs(links or{})do link:Disconnect()end
end
function M:Start()
 if self.Started then return end;self.Started=true
 local folder=self.Chase.RunAlertRemote.Parent
 local remote=folder:FindFirstChild('BatSwing')
 if not remote then remote=Instance.new('RemoteEvent');remote.Name='BatSwing';remote.Parent=folder end
 assert(remote:IsA('RemoteEvent'),'BatSwing must be a RemoteEvent');self.Remote=remote
 table.insert(self.Connections,remote.OnServerEvent:Connect(function(player)self:Request(player)end))
 table.insert(self.Connections,Run.Heartbeat:Connect(function()self:Step()end))
 local function setup(player)
  if self.Characters[player]then return end
  self.Characters[player]={player.CharacterAdded:Connect(function(character)self:Give(player,character)end),
   player.CharacterRemoving:Connect(function()self.Swings[player]=nil end)}
  local character=player.Character
  if character then task.spawn(function()self:Give(player,character)end)end
 end
 table.insert(self.Connections,Players.PlayerAdded:Connect(setup))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(player)self:CleanupPlayer(player)end))
 for _,player in ipairs(Players:GetPlayers())do setup(player)end
end
return M
